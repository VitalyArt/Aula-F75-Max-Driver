import Foundation
import IOKit.hid

struct RGBMode: Identifiable, Hashable {
    let id: Int
    let titleKey: String

    var title: String {
        L10n.text(titleKey)
    }
}

enum WirelessAulaLabels {
    static var rgbModes: [RGBMode] {
        [
            RGBMode(id: 0, titleKey: "LED Off"),
            RGBMode(id: 1, titleKey: "Static"),
            RGBMode(id: 2, titleKey: "SingleOn"),
            RGBMode(id: 3, titleKey: "SingleOff"),
            RGBMode(id: 4, titleKey: "Glittering"),
            RGBMode(id: 5, titleKey: "Falling"),
            RGBMode(id: 6, titleKey: "Colourful"),
            RGBMode(id: 7, titleKey: "Breath"),
            RGBMode(id: 8, titleKey: "Spectrum"),
            RGBMode(id: 9, titleKey: "Outward"),
            RGBMode(id: 10, titleKey: "Scrolling"),
            RGBMode(id: 11, titleKey: "Rolling"),
            RGBMode(id: 12, titleKey: "Rotating"),
            RGBMode(id: 13, titleKey: "Explode"),
            RGBMode(id: 14, titleKey: "Launch"),
            RGBMode(id: 15, titleKey: "Ripples"),
            RGBMode(id: 16, titleKey: "Flowing"),
            RGBMode(id: 17, titleKey: "Pulsating"),
            RGBMode(id: 18, titleKey: "Tilt"),
            RGBMode(id: 19, titleKey: "Shuttle")
        ]
    }

    static func rgbModeTitle(_ mode: Int) -> String {
        rgbModes.first { $0.id == mode }?.title ?? L10n.format("Mode %d", mode)
    }

    static func directionTitle(_ direction: Int) -> String {
        switch direction {
        case 0: return L10n.text("Right")
        case 1: return L10n.text("Down")
        case 2: return L10n.text("Left")
        case 3: return L10n.text("Up")
        default: return L10n.format("Direction %d", direction)
        }
    }

    static func keyResponseTitle(_ level: Int) -> String {
        switch level {
        case 1: return L10n.text("Level 1 Fastest - 2.4G 5-6 ms")
        case 2: return L10n.text("Level 2 Balanced - 2.4G 7-9 ms")
        case 3: return L10n.text("Level 3 Stable - 2.4G 10-12 ms")
        case 4: return L10n.text("Level 4 Conservative - 2.4G 15-17 ms")
        case 5: return L10n.text("Level 5 Max Stability - 2.4G 19-21 ms")
        default: return L10n.format("Level %d", level)
        }
    }

    static func sleepTitle(_ value: Int) -> String {
        switch value {
        case 0: return L10n.text("No Sleep")
        case 1: return L10n.text("1 min")
        case 2: return L10n.text("5 min")
        case 3: return L10n.text("30 min")
        default: return L10n.format("Value %d", value)
        }
    }
}

final class WirelessAulaDevice {
    private enum Transport {
        case dongleRaw
        case wiredControl

        var label: String {
            switch self {
            case .dongleRaw: return L10n.text("2.4G raw")
            case .wiredControl: return L10n.text("wired control")
            }
        }
    }

    private let rawDevice: IOHIDDevice
    private let outputReportSize: Int
    private let featureReportSize: Int
    private let transport: Transport
    private var batteryPipe: BatteryInputPipe?

    private init(rawDevice: IOHIDDevice, transport: Transport) throws {
        self.rawDevice = rawDevice
        self.outputReportSize = Self.intProperty(rawDevice, kIOHIDMaxOutputReportSizeKey)
        self.featureReportSize = Self.intProperty(rawDevice, kIOHIDMaxFeatureReportSizeKey)
        self.transport = transport
        let result = IOHIDDeviceOpen(rawDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            throw AulaError.openFailed("\(transport.label) endpoint, IOReturn 0x\(String(UInt32(result), radix: 16))")
        }
    }

    deinit {
        batteryPipe?.close()
        IOHIDDeviceClose(rawDevice, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    static func connect() throws -> WirelessAulaDevice {
        let devices = matchingDongleDevices()
        if let raw = devices.first(where: { usagePage($0) == AulaConstants.wirelessRawUsagePage }) {
            do {
                return try WirelessAulaDevice(rawDevice: raw, transport: .dongleRaw)
            } catch {
                throw error
            }
        }
        throw AulaError.endpointNotFound("2.4G raw 0xff60")
    }

    static func scanEndpoints() -> [HIDEndpointInfo] {
        matchingDongleDevices().enumerated().map { index, device in
            let vendorID = intProperty(device, kIOHIDVendorIDKey)
            let productID = intProperty(device, kIOHIDProductIDKey)
            let page = usagePage(device)
            let usage = usage(device)
            return HIDEndpointInfo(
                id: "dongle-\(index)-\(page)-\(usage)",
                vendorID: vendorID,
                productID: productID,
                usagePage: page,
                usage: usage,
                maxInputReportSize: intProperty(device, kIOHIDMaxInputReportSizeKey),
                maxOutputReportSize: intProperty(device, kIOHIDMaxOutputReportSizeKey),
                maxFeatureReportSize: intProperty(device, kIOHIDMaxFeatureReportSizeKey),
                product: stringProperty(device, kIOHIDProductKey) ?? "Aula F75 Max 2.4G",
                transport: stringProperty(device, kIOHIDTransportKey) ?? "USB"
            )
        }
        .sorted {
            if $0.usagePage != $1.usagePage { return $0.usagePage < $1.usagePage }
            return $0.usage < $1.usage
        }
    }

    func queryBattery() throws -> Int? {
        let pipe = BatteryInputPipe(device: rawDevice)
        batteryPipe = pipe
        pipe.start()

        let lengths = [
            min(max(outputReportSize, 32), 64),
            outputReportSize >= 33 ? 33 : outputReportSize
        ].filter { $0 > 0 }

        for length in lengths {
            try sendBatteryQuery(includeReportID: false, length: length)
            if let percent = pipe.waitForPercent(timeout: 0.25) {
                return percent
            }
            try sendBatteryQuery(includeReportID: true, length: length)
            if let percent = pipe.waitForPercent(timeout: 0.25) {
                return percent
            }
        }

        return pipe.percent
    }

    func applyRGB(mode: Int, brightness: Int, speed: Int, direction: Int, colorful: Bool, color: Int) throws {
        let normalizedMode = min(max(mode, 0), 31)
        let normalizedBrightness = min(max(brightness, 1), 5)
        let normalizedSpeed = min(max(speed, 1), 5)
        let normalizedDirection = min(max(direction, 0), 3)
        let normalizedColor = min(max(color, 0), 0xffffff)

        switch transport {
        case .dongleRaw:
            try validateRawOutput()
            try sendRawReport(Self.rgbCommitReport())
            Thread.sleep(forTimeInterval: 0.05)
            try sendRawReport(Self.rgbLEDReport(
                mode: normalizedMode,
                brightness: normalizedBrightness,
                speed: normalizedSpeed,
                direction: normalizedDirection,
                colorful: colorful ? 1 : 0,
                color: normalizedColor
            ))
        case .wiredControl:
            try applyWiredStandardRGB(
                mode: normalizedMode,
                brightness: normalizedBrightness,
                speed: normalizedSpeed,
                direction: normalizedDirection,
                colorful: colorful ? 1 : 0,
                color: normalizedColor
            )
        }
    }

    func applyPerformance(level: Int, sleepTime: Int) throws {
        let report = Self.keyResponseReport(
            responseLevel: min(max(level, 1), 5),
            fnSwitch: 1,
            sleepTime: min(max(sleepTime, 0), 3)
        )
        switch transport {
        case .dongleRaw:
            try validateRawOutput()
            try sendRawReport(report)
        case .wiredControl:
            try sendRawCompatibleReport(report, operation: "wired performance fallback")
        }
    }

    func setGameMode(enabled: Bool, level: Int, sleepTime: Int) throws {
        let value = enabled ? 1 : 0
        let report = Self.gameModeReport(
            responseLevel: min(max(level, 1), 5),
            fnSwitch: 1,
            sleepTime: min(max(sleepTime, 0), 3),
            gameMode: value,
            disableAltTab: value,
            disableAltF4: value,
            disableWin: value
        )
        switch transport {
        case .dongleRaw:
            try validateRawOutput()
            try sendRawReport(report)
        case .wiredControl:
            try sendRawCompatibleReport(report, operation: "wired game mode fallback")
        }
    }

    private func validateRawOutput() throws {
        guard outputReportSize >= 32 else {
            throw AulaError.endpointNotFound("2.4G raw output report size >= 32")
        }
    }

    private func sendRawReport(_ report: [UInt8]) throws {
        let result = report.withUnsafeBufferPointer { pointer in
            IOHIDDeviceSetReport(rawDevice, kIOHIDReportTypeOutput, 0, pointer.baseAddress!, report.count)
        }
        guard result == kIOReturnSuccess else {
            throw AulaError.hidFailed("\(transport.label) SET_REPORT", Int32(result))
        }
    }

    private func sendRawCompatibleReport(_ report: [UInt8], operation: String) throws {
        guard outputReportSize >= report.count || featureReportSize >= report.count else {
            throw AulaError.endpointNotFound("\(transport.label) report size >= \(report.count)")
        }

        var lastResult: IOReturn?
        if outputReportSize >= report.count {
            var payload = [UInt8](repeating: 0, count: min(max(outputReportSize, report.count), 64))
            payload.replaceSubrange(0..<report.count, with: report)
            let result = payload.withUnsafeBufferPointer { pointer in
                IOHIDDeviceSetReport(rawDevice, kIOHIDReportTypeOutput, 0, pointer.baseAddress!, payload.count)
            }
            if result == kIOReturnSuccess {
                return
            }
            lastResult = result
        }

        if featureReportSize >= report.count {
            var payload = [UInt8](repeating: 0, count: min(max(featureReportSize, report.count), 64))
            payload.replaceSubrange(0..<report.count, with: report)
            let result = payload.withUnsafeBufferPointer { pointer in
                IOHIDDeviceSetReport(rawDevice, kIOHIDReportTypeFeature, 0, pointer.baseAddress!, payload.count)
            }
            guard result == kIOReturnSuccess else {
                throw AulaError.hidFailed(operation, Int32(result))
            }
            return
        }

        throw AulaError.hidFailed(operation, Int32(lastResult ?? kIOReturnError))
    }

    private func applyWiredStandardRGB(mode: Int, brightness: Int, speed: Int, direction: Int, colorful: Int, color: Int) throws {
        guard featureReportSize >= 64 else {
            throw AulaError.endpointNotFound("wired RGB feature report size >= 64")
        }

        var body = [UInt8](repeating: 0, count: 64)
        body[0] = 0x04
        body[1] = 0x18
        try sendFeatureBody64(body, operation: "wired RGB begin")
        Thread.sleep(forTimeInterval: 0.04)

        body = [UInt8](repeating: 0, count: 64)
        body[0] = 0x04
        body[1] = 0x13
        body[8] = 0x01
        try sendFeatureBody64(body, operation: "wired RGB select")
        Thread.sleep(forTimeInterval: 0.04)

        body = [UInt8](repeating: 0, count: 64)
        body[0] = UInt8(mode)
        if mode != 0 {
            body[1] = UInt8(color & 0xff)
            body[2] = UInt8((color >> 8) & 0xff)
            body[3] = UInt8((color >> 16) & 0xff)
            body[8] = UInt8(colorful)
            body[9] = UInt8(brightness)
            body[10] = UInt8(speed)
            body[11] = UInt8(direction)
        }
        body[14] = 0xaa
        body[15] = 0x55
        try sendFeatureBody64(body, operation: "wired RGB payload")
        Thread.sleep(forTimeInterval: 0.04)

        body = [UInt8](repeating: 0, count: 64)
        body[0] = 0x04
        body[1] = 0x02
        try sendFeatureBody64(body, operation: "wired RGB apply")
        Thread.sleep(forTimeInterval: 0.04)

        body = [UInt8](repeating: 0, count: 64)
        body[0] = 0x04
        body[1] = 0xf0
        try sendFeatureBody64(body, operation: "wired RGB finish")
    }

    private func sendFeatureBody64(_ body: [UInt8], operation: String) throws {
        var payload = [UInt8](repeating: 0, count: 64)
        payload.replaceSubrange(0..<min(body.count, 64), with: body.prefix(64))
        let result = payload.withUnsafeBufferPointer { pointer in
            IOHIDDeviceSetReport(rawDevice, kIOHIDReportTypeFeature, 0, pointer.baseAddress!, payload.count)
        }
        guard result == kIOReturnSuccess else {
            throw AulaError.hidFailed(operation, Int32(result))
        }
    }

    private func sendBatteryQuery(includeReportID: Bool, length: Int) throws {
        guard length > 0 else { return }
        var payload = [UInt8](repeating: 0, count: length)
        if includeReportID {
            payload[0] = 0x00
            if length > 1 { payload[1] = 0x20 }
            if length > 2 { payload[2] = 0x01 }
        } else {
            payload[0] = 0x20
            if length > 1 { payload[1] = 0x01 }
        }

        let checksumIndex = includeReportID ? 32 : 31
        if length > checksumIndex {
            applyChecksum(&payload, checksumIndex: checksumIndex)
        }

        let result = payload.withUnsafeBufferPointer { pointer in
            IOHIDDeviceSetReport(rawDevice, kIOHIDReportTypeOutput, 0, pointer.baseAddress!, payload.count)
        }
        guard result == kIOReturnSuccess else {
            throw AulaError.hidFailed("battery query", Int32(result))
        }
    }

    private static func rgbCommitReport() -> [UInt8] {
        var report = [UInt8](repeating: 0, count: 32)
        report[0] = 0x0f
        applyChecksum(&report, checksumIndex: 31)
        return report
    }

    private static func rgbLEDReport(mode: Int, brightness: Int, speed: Int, direction: Int, colorful: Int, color: Int) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: 32)
        report[0] = 0x05
        report[1] = 0x10
        report[2] = 0x00
        report[3] = UInt8(mode)
        if mode != 0 {
            report[4] = UInt8(color & 0xff)
            report[5] = UInt8((color >> 8) & 0xff)
            report[6] = UInt8((color >> 16) & 0xff)
            report[11] = UInt8(colorful)
            report[12] = UInt8(brightness)
            report[13] = UInt8(speed)
            report[14] = UInt8(direction)
        }
        report[17] = 0xaa
        report[18] = 0x55
        applyChecksum(&report, checksumIndex: 31)
        return report
    }

    private static func keyResponseReport(responseLevel: Int, fnSwitch: Int, sleepTime: Int) -> [UInt8] {
        var report = [UInt8](repeating: 0, count: 32)
        report[0] = 0x07
        report[1] = 0x10
        report[2] = 0x00
        report[3] = 0x00
        report[4] = 0x01
        report[5] = 0x01
        report[6] = 0x01
        report[7] = 0x01
        report[8] = UInt8(fnSwitch)
        report[9] = UInt8(sleepTime)
        report[11] = UInt8(responseLevel)
        report[17] = 0xaa
        report[18] = 0x55
        applyChecksum(&report, checksumIndex: 31)
        return report
    }

    private static func gameModeReport(
        responseLevel: Int,
        fnSwitch: Int,
        sleepTime: Int,
        gameMode: Int,
        disableAltTab: Int,
        disableAltF4: Int,
        disableWin: Int
    ) -> [UInt8] {
        var report = keyResponseReport(responseLevel: responseLevel, fnSwitch: fnSwitch, sleepTime: sleepTime)
        report[12] = UInt8(gameMode)
        report[13] = UInt8(disableAltTab)
        report[14] = UInt8(disableAltF4)
        report[15] = UInt8(disableWin)
        applyChecksum(&report, checksumIndex: 31)
        return report
    }

    private static func matchingDongleDevices() -> [IOHIDDevice] {
        matchingDevices(vendorID: AulaConstants.dongleVendorID, productID: AulaConstants.dongleProductID)
    }

    private static func matchingWiredDevices() -> [IOHIDDevice] {
        matchingDevices(vendorID: AulaConstants.wiredVendorID, productID: AulaConstants.wiredProductID)
    }

    private static func matchingDevices(vendorID: Int, productID: Int) -> [IOHIDDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: vendorID,
            kIOHIDProductIDKey: productID
        ] as CFDictionary)
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
}

private func applyChecksum(_ bytes: inout [UInt8], checksumIndex: Int) {
    guard bytes.indices.contains(checksumIndex) else { return }
    bytes[checksumIndex] = 0
    let sum = bytes.reduce(UInt8(0)) { partial, byte in
        partial &+ byte
    }
    bytes[checksumIndex] = sum
}

private final class BatteryInputPipe {
    private let device: IOHIDDevice
    private var inputBuffer: [UInt8]
    private(set) var percent: Int?
    private var started = false

    init(device: IOHIDDevice) {
        self.device = device
        self.inputBuffer = [UInt8](repeating: 0, count: 512)
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
                { context, result, _, _, _, report, reportLength in
                    guard result == kIOReturnSuccess, let context, reportLength >= 4 else {
                        return
                    }
                    if report[0] == 0x20, report[1] == 0x01, report[3] > 0, report[3] <= 100 {
                        let pipe = Unmanaged<BatteryInputPipe>.fromOpaque(context).takeUnretainedValue()
                        pipe.percent = Int(report[3])
                    }
                },
                context
            )
        }
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    }

    func waitForPercent(timeout: TimeInterval) -> Int? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let percent {
                return percent
            }
            CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.02, true)
        }
        return percent
    }

    func close() {
        guard started else { return }
        IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        started = false
    }
}
