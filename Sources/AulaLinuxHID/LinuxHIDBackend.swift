#if os(Linux)
import AulaCore
import CHIDAPI
import Foundation

public final class LinuxHIDBackend {
    public init() {
        hid_init()
    }

    deinit {
        hid_exit()
    }

    public func scanEndpoints() -> [HIDEndpointInfo] {
        scan(vendorID: AulaConstants.wiredVendorID, productID: AulaConstants.wiredProductID) +
            scan(vendorID: AulaConstants.dongleVendorID, productID: AulaConstants.dongleProductID)
    }

    public func scanWiredEndpoints() -> [HIDEndpointInfo] {
        scan(vendorID: AulaConstants.wiredVendorID, productID: AulaConstants.wiredProductID)
    }

    public func scanDongleEndpoints() -> [HIDEndpointInfo] {
        scan(vendorID: AulaConstants.dongleVendorID, productID: AulaConstants.dongleProductID)
    }

    public func syncTime(date: Date = Date()) throws {
        let device = try openWiredCommand()
        defer { hid_close(device) }

        try commandExchange(device, AulaWiredPackets.packet(0x04, 0x18))
        var prepare = AulaWiredPackets.packet(0x04, 0x28)
        prepare[8] = 0x01
        try commandExchange(device, prepare)
        try commandExchange(device, AulaWiredPackets.timePayload(date: date))
        try commandExchange(device, AulaWiredPackets.packet(0x04, 0x02))
    }

    public func uploadDisplayStream(
        _ stream: Data,
        slot: Int,
        progress: (DisplayUploadProgress) -> Void
    ) throws {
        guard (1...255).contains(slot) else {
            throw AulaError.invalidSlot
        }

        let commandDevice = try openWiredCommand()
        defer { hid_close(commandDevice) }

        let rawDevice = try openWiredRaw()
        defer { hid_close(rawDevice) }

        let chunkCount = stream.count / AulaConstants.chunkLength
        guard chunkCount <= 0xffff else {
            throw AulaError.imageTooLarge("\(chunkCount) chunks exceeds UInt16 metadata")
        }

        try commandExchange(commandDevice, AulaWiredPackets.packet(0x04, 0x18))

        var metadata = AulaWiredPackets.packet(0x04, 0x72)
        metadata[2] = UInt8(slot)
        metadata[8] = UInt8(chunkCount & 0xff)
        metadata[9] = UInt8((chunkCount >> 8) & 0xff)
        try commandExchange(commandDevice, metadata)
        _ = waitForRawAck(rawDevice, timeoutMilliseconds: 150)

        for chunkIndex in 0..<chunkCount {
            let offset = chunkIndex * AulaConstants.chunkLength
            let chunk = Array(stream[offset..<(offset + AulaConstants.chunkLength)])
            try sendDisplayChunk(rawDevice, chunk, index: chunkIndex + 1, total: chunkCount)
            _ = waitForRawAck(rawDevice, timeoutMilliseconds: 350)
            progress(DisplayUploadProgress(sentChunks: chunkIndex + 1, totalChunks: chunkCount))
        }

        try commandExchange(commandDevice, AulaWiredPackets.packet(0x04, 0x02))
    }

    public func factoryReset(progress: (String) -> Void) throws {
        let device = try openWiredCommand()
        defer { hid_close(device) }

        progress("Clearing display memory")
        try commandExchange(device, AulaWiredPackets.packet(0x04, 0x19))
        var clearSlots = AulaWiredPackets.packet(0x04, 0x15)
        clearSlots[8] = 0x08
        try commandExchange(device, clearSlots)
        try sendZeroPages(device, 8)
        try commandExchange(device, AulaWiredPackets.packet(0x04, 0x02))

        progress("Resetting keymap and macro data")
        try commandExchange(device, AulaWiredPackets.packet(0x04, 0x18))
        var keymap = AulaWiredPackets.packet(0x04, 0x11)
        keymap[8] = 0x09
        try commandExchange(device, keymap)
        try sendZeroPages(device, 9)
        try commandExchange(device, AulaWiredPackets.packet(0x04, 0x02))
        try commandExchange(device, AulaWiredPackets.packet(0x04, 0xf0))

        progress("Resetting lighting data")
        try commandExchange(device, AulaWiredPackets.packet(0x04, 0x18))
        var lighting = AulaWiredPackets.packet(0x04, 0x27)
        lighting[8] = 0x09
        try commandExchange(device, lighting)
        try sendZeroPages(device, 9)
        try commandExchange(device, AulaWiredPackets.packet(0x04, 0x02))
        try commandExchange(device, AulaWiredPackets.packet(0x04, 0xf0))

        progress("Sending reset footer")
        try commandExchange(device, AulaWiredPackets.packet(0x04, 0x18))
        var resetPayloadHeader = AulaWiredPackets.packet(0x04, 0x13)
        resetPayloadHeader[8] = 0x01
        try commandExchange(device, resetPayloadHeader)

        var resetPayload = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        resetPayload[0] = 0x0b
        resetPayload[1] = 0xff
        resetPayload[8] = 0x01
        resetPayload[9] = 0x05
        resetPayload[10] = 0x03
        resetPayload[14] = 0xaa
        resetPayload[15] = 0x55
        try commandExchange(device, resetPayload)
        try commandExchange(device, AulaWiredPackets.packet(0x04, 0x02))
        try commandExchange(device, AulaWiredPackets.packet(0x04, 0xf0))

        progress("Resetting display config")
        try commandExchange(device, AulaWiredPackets.packet(0x04, 0x18))
        var displayReset = AulaWiredPackets.packet(0x04, 0x17)
        displayReset[2] = 0x01
        displayReset[8] = 0x01
        try commandExchange(device, displayReset)

        var displayConfig = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        displayConfig[0] = 0x00
        displayConfig[1] = 0x01
        displayConfig[6] = 0x02
        displayConfig[8] = 0x02
        try commandExchange(device, displayConfig)
        try commandExchange(device, AulaWiredPackets.packet(0x04, 0x02))
    }

    public func queryBattery() throws -> Int? {
        let device = try openDongleRaw()
        defer { hid_close(device) }

        let lengths = [64, 33, 32]
        for length in lengths {
            try sendOutputReport(device, AulaWirelessReports.batteryQuery(includeReportID: false, length: length), operation: "battery query")
            if let percent = readBatteryPercent(device, timeoutMilliseconds: 250) {
                return percent
            }

            try sendOutputReport(device, AulaWirelessReports.batteryQuery(includeReportID: true, length: length), operation: "battery query")
            if let percent = readBatteryPercent(device, timeoutMilliseconds: 250) {
                return percent
            }
        }
        return nil
    }

    public func applyRGB(mode: Int, brightness: Int, speed: Int, direction: Int, colorful: Bool, color: Int) throws {
        let device = try openDongleRaw()
        defer { hid_close(device) }

        try sendOutputReport(device, AulaWirelessReports.rgbCommitReport(), operation: "RGB commit")
        Thread.sleep(forTimeInterval: 0.05)
        try sendOutputReport(
            device,
            AulaWirelessReports.rgbLEDReport(
                mode: min(max(mode, 0), 31),
                brightness: min(max(brightness, 1), 5),
                speed: min(max(speed, 1), 5),
                direction: min(max(direction, 0), 3),
                colorful: colorful ? 1 : 0,
                color: min(max(color, 0), 0xffffff)
            ),
            operation: "RGB LED"
        )
    }

    public func applyPerformance(level: Int, sleepTime: Int) throws {
        let device = try openDongleRaw()
        defer { hid_close(device) }

        try sendOutputReport(
            device,
            AulaWirelessReports.keyResponseReport(
                responseLevel: min(max(level, 1), 5),
                fnSwitch: 1,
                sleepTime: min(max(sleepTime, 0), 3)
            ),
            operation: "performance"
        )
    }

    public func setGameMode(enabled: Bool, level: Int, sleepTime: Int) throws {
        let device = try openDongleRaw()
        defer { hid_close(device) }

        let value = enabled ? 1 : 0
        try sendOutputReport(
            device,
            AulaWirelessReports.gameModeReport(
                responseLevel: min(max(level, 1), 5),
                fnSwitch: 1,
                sleepTime: min(max(sleepTime, 0), 3),
                gameMode: value,
                disableAltTab: value,
                disableAltF4: value,
                disableWin: value
            ),
            operation: "game mode"
        )
    }

    private func scan(vendorID: Int, productID: Int) -> [HIDEndpointInfo] {
        guard let root = hid_enumerate(UInt16(vendorID), UInt16(productID)) else {
            return []
        }
        defer { hid_free_enumeration(root) }

        var endpoints: [HIDEndpointInfo] = []
        var current: UnsafeMutablePointer<hid_device_info>? = root
        while let info = current {
            let item = info.pointee
            let path = item.path.map { String(cString: $0) } ?? "\(vendorID):\(productID):\(endpoints.count)"
            let usagePage = Int(item.usage_page)
            let usage = Int(item.usage)
            endpoints.append(
                HIDEndpointInfo(
                    id: path,
                    vendorID: Int(item.vendor_id),
                    productID: Int(item.product_id),
                    usagePage: usagePage,
                    usage: usage,
                    maxInputReportSize: 512,
                    maxOutputReportSize: 64,
                    maxFeatureReportSize: 64,
                    product: productName(vendorID: Int(item.vendor_id), productID: Int(item.product_id)),
                    transport: "hidraw"
                )
            )
            current = item.next
        }

        return endpoints.sorted {
            if $0.usagePage != $1.usagePage { return $0.usagePage < $1.usagePage }
            return $0.usage < $1.usage
        }
    }

    private func openWiredCommand() throws -> OpaquePointer {
        let endpoints = scanWiredEndpoints()
        let endpoint = endpoints.first { $0.usagePage == AulaConstants.wiredCommandUsagePage }
            ?? endpoints.first { $0.maxFeatureReportSize >= AulaConstants.commandLength }
        guard let endpoint else {
            throw AulaError.endpointNotFound("wired command channel 0xff13")
        }
        return try open(path: endpoint.id, label: "wired command")
    }

    private func openWiredRaw() throws -> OpaquePointer {
        let endpoints = scanWiredEndpoints()
        let endpoint = endpoints.first { $0.usagePage == AulaConstants.wiredRawUsagePage }
            ?? endpoints.first { $0.maxOutputReportSize >= AulaConstants.chunkLength }
        guard let endpoint else {
            throw AulaError.endpointNotFound("wired display channel 0xff68")
        }
        return try open(path: endpoint.id, label: "wired display")
    }

    private func openDongleRaw() throws -> OpaquePointer {
        let endpoints = scanDongleEndpoints()
        guard !endpoints.isEmpty else {
            throw AulaError.endpointNotFound("2.4G raw 0xff60")
        }

        let candidates = endpoints.sorted { lhs, rhs in
            let lhsRaw = lhs.usagePage == AulaConstants.wirelessRawUsagePage
            let rhsRaw = rhs.usagePage == AulaConstants.wirelessRawUsagePage
            if lhsRaw != rhsRaw { return lhsRaw }
            if lhs.maxOutputReportSize != rhs.maxOutputReportSize {
                return lhs.maxOutputReportSize > rhs.maxOutputReportSize
            }
            return lhs.usagePage < rhs.usagePage
        }

        var failures: [String] = []
        for endpoint in candidates {
            if let device = tryOpen(path: endpoint.id) {
                hid_set_nonblocking(device, 0)
                return device
            }
            failures.append("\(endpoint.role) usagePage=0x\(String(endpoint.usagePage, radix: 16)) path=\(endpoint.id)")
        }

        throw AulaError.openFailed(
            "2.4G raw. Could not open any 05AC:024F hidraw endpoint. " +
            "Install the udev rule with `make linux-install-udev`, replug the receiver, then run the app again. " +
            "Tried: \(failures.joined(separator: "; "))"
        )
    }

    private func open(path: String, label: String) throws -> OpaquePointer {
        guard let device = tryOpen(path: path) else {
            throw AulaError.openFailed(
                "\(label) path=\(path). Install the udev rule with `make linux-install-udev`, replug the device, then run the app again."
            )
        }
        hid_set_nonblocking(device, 0)
        return device
    }

    private func tryOpen(path: String) -> OpaquePointer? {
        path.withCString { hid_open_path($0) }
    }

    private func commandExchange(_ device: OpaquePointer, _ packet: [UInt8]) throws {
        try sendFeatureReport(device, packet, operation: "SET_REPORT")
        var response = [UInt8](repeating: 0, count: AulaConstants.commandLength + 1)
        response[0] = 0x00
        let count = response.withUnsafeMutableBufferPointer { pointer in
            hid_get_feature_report(device, pointer.baseAddress!, pointer.count)
        }
        guard count >= 0 else {
            throw AulaError.hidFailed("GET_REPORT", Int32(count))
        }
    }

    private func sendZeroPages(_ device: OpaquePointer, _ count: Int) throws {
        guard count > 0 else { return }
        let zero = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        for _ in 0..<(count - 1) {
            try sendFeatureReport(device, zero, operation: "zero page")
            Thread.sleep(forTimeInterval: 0.04)
        }
        try commandExchange(device, zero)
    }

    private func sendDisplayChunk(_ device: OpaquePointer, _ bytes: [UInt8], index: Int, total: Int) throws {
        let written = writeOutput(device, bytes)
        guard written >= 0 else {
            throw AulaError.hidFailed("display chunk \(index)/\(total)", Int32(written))
        }
        guard written == Int32(bytes.count) else {
            throw AulaError.hidFailed("display chunk \(index)/\(total) short write \(written)/\(bytes.count)", Int32(written))
        }
    }

    private func waitForRawAck(_ device: OpaquePointer, timeoutMilliseconds: Int32) -> Bool {
        var buffer = [UInt8](repeating: 0, count: max(512, AulaConstants.ackLength))
        let count = buffer.withUnsafeMutableBufferPointer { pointer in
            hid_read_timeout(device, pointer.baseAddress!, pointer.count, timeoutMilliseconds)
        }
        return count > 0
    }

    private func sendOutputReport(_ device: OpaquePointer, _ bytes: [UInt8], operation: String) throws {
        let direct = writeOutput(device, bytes)
        if direct >= 0 {
            return
        }

        var prefixed = [UInt8](repeating: 0, count: bytes.count + 1)
        prefixed.replaceSubrange(1..<prefixed.count, with: bytes)
        let prefixedResult = writeOutput(device, prefixed)
        guard prefixedResult >= 0 else {
            throw AulaError.hidFailed(operation, Int32(prefixedResult))
        }
    }

    private func sendFeatureReport(_ device: OpaquePointer, _ bytes: [UInt8], operation: String) throws {
        let direct = writeFeature(device, bytes)
        if direct >= 0 {
            return
        }

        var prefixed = [UInt8](repeating: 0, count: bytes.count + 1)
        prefixed.replaceSubrange(1..<prefixed.count, with: bytes)
        let prefixedResult = writeFeature(device, prefixed)
        guard prefixedResult >= 0 else {
            throw AulaError.hidFailed(operation, Int32(prefixedResult))
        }
    }

    private func writeOutput(_ device: OpaquePointer, _ bytes: [UInt8]) -> Int32 {
        bytes.withUnsafeBufferPointer { pointer in
            hid_write(device, pointer.baseAddress!, bytes.count)
        }
    }

    private func writeFeature(_ device: OpaquePointer, _ bytes: [UInt8]) -> Int32 {
        bytes.withUnsafeBufferPointer { pointer in
            hid_send_feature_report(device, pointer.baseAddress!, bytes.count)
        }
    }

    private func readBatteryPercent(_ device: OpaquePointer, timeoutMilliseconds: Int32) -> Int? {
        var buffer = [UInt8](repeating: 0, count: 512)
        let count = buffer.withUnsafeMutableBufferPointer { pointer in
            hid_read_timeout(device, pointer.baseAddress!, pointer.count, timeoutMilliseconds)
        }
        guard count >= 4 else {
            return nil
        }

        if buffer[0] == 0x20, buffer[1] == 0x01, buffer[3] > 0, buffer[3] <= 100 {
            return Int(buffer[3])
        }
        if count >= 5, buffer[1] == 0x20, buffer[2] == 0x01, buffer[4] > 0, buffer[4] <= 100 {
            return Int(buffer[4])
        }
        return nil
    }

    private func productName(vendorID: Int, productID: Int) -> String {
        if vendorID == AulaConstants.dongleVendorID && productID == AulaConstants.dongleProductID {
            return "Aula F75 Max 2.4G"
        }
        return "Aula F75 Max"
    }
}
#endif
