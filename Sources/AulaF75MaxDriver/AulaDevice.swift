import Foundation
import IOKit.hid

final class AulaDevice {
    private let commandDevice: IOHIDDevice
    private let rawDevice: IOHIDDevice?
    private var rawInputPipe: RawInputPipe?

    private init(commandDevice: IOHIDDevice, rawDevice: IOHIDDevice?) throws {
        self.commandDevice = commandDevice
        self.rawDevice = rawDevice

        try Self.open(commandDevice, label: "command endpoint")
        if let rawDevice {
            try Self.open(rawDevice, label: "raw display endpoint")
            self.rawInputPipe = RawInputPipe(device: rawDevice)
        }
    }

    deinit {
        rawInputPipe?.close()
        if let rawDevice {
            IOHIDDeviceClose(rawDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        IOHIDDeviceClose(commandDevice, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    static func connect() throws -> AulaDevice {
        let devices = matchingHIDDevices()
        guard !devices.isEmpty else {
            throw AulaError.deviceNotFound
        }

        let command = devices.first { usagePage($0) == AulaConstants.wiredCommandUsagePage }
            ?? devices.first { usagePage($0) == AulaConstants.wirelessCommandUsagePage }
            ?? devices.first { maxFeatureReportSize($0) >= AulaConstants.commandLength }
        guard let command else {
            throw AulaError.endpointNotFound("wired command channel 0xff13")
        }

        let raw = devices.first { usagePage($0) == AulaConstants.wiredRawUsagePage }
            ?? devices.first { usagePage($0) == AulaConstants.wirelessRawUsagePage }
            ?? devices.first {
                maxOutputReportSize($0) >= AulaConstants.chunkLength ||
                maxInputReportSize($0) >= AulaConstants.ackLength
            }

        return try AulaDevice(commandDevice: command, rawDevice: raw)
    }

    static func scanEndpoints() -> [HIDEndpointInfo] {
        matchingHIDDevices().enumerated().map { index, device in
            let vendorID = intProperty(device, kIOHIDVendorIDKey)
            let productID = intProperty(device, kIOHIDProductIDKey)
            let page = usagePage(device)
            let usage = usage(device)
            let product = stringProperty(device, kIOHIDProductKey) ?? "Aula F75 Max"
            let transport = stringProperty(device, kIOHIDTransportKey) ?? "USB"
            return HIDEndpointInfo(
                id: "\(index)-\(page)-\(usage)-\(maxInputReportSize(device))-\(maxOutputReportSize(device))",
                vendorID: vendorID,
                productID: productID,
                usagePage: page,
                usage: usage,
                maxInputReportSize: maxInputReportSize(device),
                maxOutputReportSize: maxOutputReportSize(device),
                maxFeatureReportSize: maxFeatureReportSize(device),
                product: product,
                transport: transport
            )
        }
        .sorted {
            if $0.usagePage != $1.usagePage { return $0.usagePage < $1.usagePage }
            return $0.usage < $1.usage
        }
    }

    func syncTime(date: Date = Date()) throws {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.month, .day, .hour, .minute, .second, .weekday], from: date)
        let month = parts.month ?? 1
        let day = parts.day ?? 1
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        let second = parts.second ?? 0
        let weekday = max((parts.weekday ?? 1) - 1, 0)

        try commandExchange(Self.packet(0x04, 0x18))

        var prepare = Self.packet(0x04, 0x28)
        prepare[8] = 0x01
        try commandExchange(prepare)

        var timePacket = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        timePacket[0] = 0x00
        timePacket[1] = 0x01
        timePacket[2] = 0x5a
        timePacket[3] = 0x1a
        timePacket[4] = UInt8(clamping: month)
        timePacket[5] = UInt8(clamping: day)
        timePacket[6] = UInt8(clamping: hour)
        timePacket[7] = UInt8(clamping: minute)
        timePacket[8] = UInt8(clamping: second)
        timePacket[10] = UInt8(clamping: weekday)
        timePacket[62] = 0xaa
        timePacket[63] = 0x55
        try commandExchange(timePacket)

        try commandExchange(Self.packet(0x04, 0x02))
    }

    func uploadDisplayStream(
        _ stream: Data,
        slot: Int,
        progress: @escaping @Sendable (DisplayUploadProgress) -> Void
    ) throws {
        guard (1...255).contains(slot) else {
            throw AulaError.invalidSlot
        }
        guard let rawDevice else {
            throw AulaError.endpointNotFound("wired display channel 0xff68")
        }

        let chunkCount = stream.count / AulaConstants.chunkLength
        guard chunkCount <= 0xffff else {
            throw AulaError.imageTooLarge("\(chunkCount) chunks exceeds UInt16 metadata")
        }

        try commandExchange(Self.packet(0x04, 0x18))

        var metadata = Self.packet(0x04, 0x72)
        metadata[2] = UInt8(slot)
        metadata[8] = UInt8(chunkCount & 0xff)
        metadata[9] = UInt8((chunkCount >> 8) & 0xff)
        try commandExchange(metadata)

        rawInputPipe?.start()
        _ = rawInputPipe?.waitForAck(timeout: 0.15)

        for chunkIndex in 0..<chunkCount {
            let offset = chunkIndex * AulaConstants.chunkLength
            let chunk = stream[offset..<(offset + AulaConstants.chunkLength)]
            try Self.setReport(
                device: rawDevice,
                type: kIOHIDReportTypeOutput,
                reportID: 0,
                bytes: Array(chunk),
                operation: "display chunk \(chunkIndex + 1)/\(chunkCount)"
            )
            _ = rawInputPipe?.waitForAck(timeout: 0.35)
            progress(DisplayUploadProgress(sentChunks: chunkIndex + 1, totalChunks: chunkCount))
        }

        try commandExchange(Self.packet(0x04, 0x02))
    }

    func factoryReset(progress: @escaping @Sendable (String) -> Void) throws {
        progress("Clearing display memory")
        try commandExchange(Self.packet(0x04, 0x19))
        var clearSlots = Self.packet(0x04, 0x15)
        clearSlots[8] = 0x08
        try commandExchange(clearSlots)
        try sendZeroPages(8)
        try commandExchange(Self.packet(0x04, 0x02))

        progress("Resetting keymap and macro data")
        try commandExchange(Self.packet(0x04, 0x18))
        var keymap = Self.packet(0x04, 0x11)
        keymap[8] = 0x09
        try commandExchange(keymap)
        try sendZeroPages(9)
        try commandExchange(Self.packet(0x04, 0x02))
        try commandExchange(Self.packet(0x04, 0xf0))

        progress("Resetting lighting data")
        try commandExchange(Self.packet(0x04, 0x18))
        var lighting = Self.packet(0x04, 0x27)
        lighting[8] = 0x09
        try commandExchange(lighting)
        try sendZeroPages(9)
        try commandExchange(Self.packet(0x04, 0x02))
        try commandExchange(Self.packet(0x04, 0xf0))

        progress("Sending reset footer")
        try commandExchange(Self.packet(0x04, 0x18))
        var resetPayloadHeader = Self.packet(0x04, 0x13)
        resetPayloadHeader[8] = 0x01
        try commandExchange(resetPayloadHeader)

        var resetPayload = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        resetPayload[0] = 0x0b
        resetPayload[1] = 0xff
        resetPayload[8] = 0x01
        resetPayload[9] = 0x05
        resetPayload[10] = 0x03
        resetPayload[14] = 0xaa
        resetPayload[15] = 0x55
        try commandExchange(resetPayload)
        try commandExchange(Self.packet(0x04, 0x02))
        try commandExchange(Self.packet(0x04, 0xf0))

        progress("Resetting display config")
        try commandExchange(Self.packet(0x04, 0x18))
        var displayReset = Self.packet(0x04, 0x17)
        displayReset[2] = 0x01
        displayReset[8] = 0x01
        try commandExchange(displayReset)

        var displayConfig = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        displayConfig[0] = 0x00
        displayConfig[1] = 0x01
        displayConfig[6] = 0x02
        displayConfig[8] = 0x02
        try commandExchange(displayConfig)
        try commandExchange(Self.packet(0x04, 0x02))
    }

    private func commandExchange(_ packet: [UInt8]) throws {
        try Self.setReport(
            device: commandDevice,
            type: kIOHIDReportTypeFeature,
            reportID: 0,
            bytes: packet,
            operation: "SET_REPORT"
        )

        var response = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        var responseLength = response.count
        let result = response.withUnsafeMutableBufferPointer { pointer in
            IOHIDDeviceGetReport(
                commandDevice,
                kIOHIDReportTypeFeature,
                0,
                pointer.baseAddress!,
                &responseLength
            )
        }
        guard result == kIOReturnSuccess else {
            throw AulaError.hidFailed("GET_REPORT", Int32(result))
        }
    }

    private func sendZeroPages(_ count: Int) throws {
        guard count > 0 else { return }
        let zero = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        for _ in 0..<(count - 1) {
            try Self.setReport(
                device: commandDevice,
                type: kIOHIDReportTypeFeature,
                reportID: 0,
                bytes: zero,
                operation: "zero page"
            )
            Thread.sleep(forTimeInterval: 0.04)
        }
        try commandExchange(zero)
    }

    private static func packet(_ first: UInt8, _ second: UInt8) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        data[0] = first
        data[1] = second
        return data
    }

    private static func open(_ device: IOHIDDevice, label: String) throws {
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            throw AulaError.openFailed("\(label), IOReturn 0x\(String(UInt32(result), radix: 16))")
        }
    }

    private static func setReport(
        device: IOHIDDevice,
        type: IOHIDReportType,
        reportID: CFIndex,
        bytes: [UInt8],
        operation: String
    ) throws {
        let result = bytes.withUnsafeBufferPointer { pointer in
            IOHIDDeviceSetReport(device, type, reportID, pointer.baseAddress!, bytes.count)
        }
        guard result == kIOReturnSuccess else {
            throw AulaError.hidFailed(operation, Int32(result))
        }
    }

    private static func matchingHIDDevices() -> [IOHIDDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        let matching: [String: Any] = [
            kIOHIDVendorIDKey: AulaConstants.wiredVendorID,
            kIOHIDProductIDKey: AulaConstants.wiredProductID
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        _ = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        defer {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        guard let deviceSet = IOHIDManagerCopyDevices(manager) else {
            return []
        }

        let count = CFSetGetCount(deviceSet)
        var rawValues = [UnsafeRawPointer?](repeating: nil, count: count)
        CFSetGetValues(deviceSet, &rawValues)
        return rawValues.compactMap { value in
            guard let value else { return nil }
            return Unmanaged<IOHIDDevice>.fromOpaque(value).retain().takeRetainedValue()
        }
    }

    private static func intProperty(_ device: IOHIDDevice, _ key: String) -> Int {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else {
            return 0
        }
        if CFGetTypeID(value) == CFNumberGetTypeID() {
            return (value as! NSNumber).intValue
        }
        return 0
    }

    private static func stringProperty(_ device: IOHIDDevice, _ key: String) -> String? {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else {
            return nil
        }
        return value as? String
    }

    private static func usagePage(_ device: IOHIDDevice) -> Int {
        let primary = intProperty(device, kIOHIDPrimaryUsagePageKey)
        return primary != 0 ? primary : intProperty(device, kIOHIDDeviceUsagePageKey)
    }

    private static func usage(_ device: IOHIDDevice) -> Int {
        let primary = intProperty(device, kIOHIDPrimaryUsageKey)
        return primary != 0 ? primary : intProperty(device, kIOHIDDeviceUsageKey)
    }

    private static func maxInputReportSize(_ device: IOHIDDevice) -> Int {
        intProperty(device, kIOHIDMaxInputReportSizeKey)
    }

    private static func maxOutputReportSize(_ device: IOHIDDevice) -> Int {
        intProperty(device, kIOHIDMaxOutputReportSizeKey)
    }

    private static func maxFeatureReportSize(_ device: IOHIDDevice) -> Int {
        intProperty(device, kIOHIDMaxFeatureReportSizeKey)
    }
}

private final class RawInputPipe {
    private let device: IOHIDDevice
    private var inputBuffer: [UInt8]
    private var ackCounter = 0
    private var started = false

    init(device: IOHIDDevice) {
        self.device = device
        let maxInput = max(512, AulaConstants.ackLength)
        self.inputBuffer = [UInt8](repeating: 0, count: maxInput)
    }

    func start() {
        guard !started else { return }
        started = true

        let context = Unmanaged.passUnretained(self).toOpaque()
        inputBuffer.withUnsafeMutableBufferPointer { pointer in
            IOHIDDeviceRegisterInputReportCallback(
                device,
                pointer.baseAddress!,
                pointer.count,
                { context, result, _, _, _, _, reportLength in
                    guard result == kIOReturnSuccess, reportLength > 0, let context else {
                        return
                    }
                    let pipe = Unmanaged<RawInputPipe>.fromOpaque(context).takeUnretainedValue()
                    pipe.ackCounter += 1
                },
                context
            )
        }
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    func waitForAck(timeout: TimeInterval) -> Bool {
        let baseline = ackCounter
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if ackCounter > baseline {
                return true
            }
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.02, true)
        }
        return ackCounter > baseline
    }

    func close() {
        guard started else { return }
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        started = false
    }
}
