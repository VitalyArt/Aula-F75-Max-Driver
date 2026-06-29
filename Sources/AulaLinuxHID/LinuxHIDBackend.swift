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

    public func queryBattery() throws -> Int? {
        let endpoint = try dongleRawEndpoint()
        let device = try open(path: endpoint.id, label: "2.4G raw")
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
        let endpoint = try dongleRawEndpoint()
        let device = try open(path: endpoint.id, label: "2.4G raw")
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
        let endpoint = try dongleRawEndpoint()
        let device = try open(path: endpoint.id, label: "2.4G raw")
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
        let endpoint = try dongleRawEndpoint()
        let device = try open(path: endpoint.id, label: "2.4G raw")
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

    private func dongleRawEndpoint() throws -> HIDEndpointInfo {
        let endpoints = scanDongleEndpoints()
        let endpoint = endpoints.first { $0.usagePage == AulaConstants.wirelessRawUsagePage }
            ?? endpoints.first
        guard let endpoint else {
            throw AulaError.endpointNotFound("2.4G raw 0xff60")
        }
        return endpoint
    }

    private func open(path: String, label: String) throws -> OpaquePointer {
        let device = path.withCString { hid_open_path($0) }
        guard let device else {
            throw AulaError.openFailed(label)
        }
        hid_set_nonblocking(device, 0)
        return device
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
