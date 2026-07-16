import Foundation

public enum AulaConstants {
    public static let wiredVendorID = 0x0c45
    public static let wiredProductID = 0x800a
    public static let dongleVendorID = 0x05ac
    public static let dongleProductID = 0x024f

    public static let wiredCommandUsagePage = 0xff13
    public static let wiredRawUsagePage = 0xff68
    public static let wirelessCommandUsagePage = 0xff59
    public static let wirelessRawUsagePage = 0xff60
    public static let commandUsagePage = wiredCommandUsagePage
    public static let rawUsagePage = wiredRawUsagePage
    public static let vendorUsage = 0x61

    public static let commandLength = 64
    public static let ackLength = 128
    public static let displayWidth = 128
    public static let displayHeight = 128
    public static let headerLength = 256
    public static let frameBytes = displayWidth * displayHeight * 2
    public static let chunkLength = 4096
    public static let maxFrames = 255
}

public enum AulaError: LocalizedError {
    case deviceNotFound
    case endpointNotFound(String)
    case openFailed(String)
    case hidFailed(String, Int32)
    case imageLoadFailed(String)
    case imageTooLarge(String)
    case invalidSlot
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "Aula F75 Max device was not found."
        case .endpointNotFound(let endpoint):
            return "Required HID endpoint was not found: \(endpoint)."
        case .openFailed(let detail):
            return "Failed to open HID device: \(detail)."
        case .hidFailed(let operation, let code):
            return "\(operation) failed with HID status \(code)."
        case .imageLoadFailed(let detail):
            return "Failed to load image: \(detail)."
        case .imageTooLarge(let detail):
            return "Image payload is too large: \(detail)."
        case .invalidSlot:
            return "Slot must be between 1 and 255."
        case .cancelled:
            return "Operation cancelled."
        }
    }
}

public struct HIDEndpointInfo: Identifiable, Hashable {
    public let id: String
    public let vendorID: Int
    public let productID: Int
    public let usagePage: Int
    public let usage: Int
    public let maxInputReportSize: Int
    public let maxOutputReportSize: Int
    public let maxFeatureReportSize: Int
    public let product: String
    public let transport: String

    public init(
        id: String,
        vendorID: Int,
        productID: Int,
        usagePage: Int,
        usage: Int,
        maxInputReportSize: Int,
        maxOutputReportSize: Int,
        maxFeatureReportSize: Int,
        product: String,
        transport: String
    ) {
        self.id = id
        self.vendorID = vendorID
        self.productID = productID
        self.usagePage = usagePage
        self.usage = usage
        self.maxInputReportSize = maxInputReportSize
        self.maxOutputReportSize = maxOutputReportSize
        self.maxFeatureReportSize = maxFeatureReportSize
        self.product = product
        self.transport = transport
    }

    public var role: String {
        if vendorID == AulaConstants.dongleVendorID && productID == AulaConstants.dongleProductID {
            if usagePage == AulaConstants.wirelessCommandUsagePage {
                return "2.4G command"
            }
            if usagePage == AulaConstants.wirelessRawUsagePage {
                return "2.4G raw"
            }
        }
        if usagePage == AulaConstants.wiredCommandUsagePage {
            return "Wired command"
        }
        if usagePage == AulaConstants.wiredRawUsagePage {
            return "Wired display"
        }
        if usagePage == 0x0001 && usage == 0x0006 {
            return "Keyboard"
        }
        if usagePage == 0x000c {
            return "Media"
        }
        return "HID"
    }

    public var summary: String {
        "\(role) usagePage=0x\(String(usagePage, radix: 16)) in=\(maxInputReportSize) out=\(maxOutputReportSize) feature=\(maxFeatureReportSize)"
    }
}

public struct DisplayUploadProgress: Sendable {
    public let sentChunks: Int
    public let totalChunks: Int

    public init(sentChunks: Int, totalChunks: Int) {
        self.sentChunks = sentChunks
        self.totalChunks = totalChunks
    }

    public var fraction: Double {
        guard totalChunks > 0 else { return 0 }
        return Double(sentChunks) / Double(totalChunks)
    }
}

public enum AulaChecksum {
    public static func apply(to bytes: inout [UInt8], checksumIndex: Int) {
        guard bytes.indices.contains(checksumIndex) else { return }
        bytes[checksumIndex] = 0
        let sum = bytes.reduce(UInt8(0)) { partial, byte in
            partial &+ byte
        }
        bytes[checksumIndex] = sum
    }
}

public enum AulaWiredPackets {
    public static func packet(_ first: UInt8, _ second: UInt8) -> [UInt8] {
        var data = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        data[0] = first
        data[1] = second
        return data
    }

    public static func timePayload(date: Date = Date(), calendar: Calendar = .current) -> [UInt8] {
        let parts = calendar.dateComponents([.month, .day, .hour, .minute, .second, .weekday], from: date)
        var payload = [UInt8](repeating: 0, count: AulaConstants.commandLength)
        payload[0] = 0x00
        payload[1] = 0x01
        payload[2] = 0x5a
        payload[3] = 0x1a
        payload[4] = UInt8(clamping: parts.month ?? 1)
        payload[5] = UInt8(clamping: parts.day ?? 1)
        payload[6] = UInt8(clamping: parts.hour ?? 0)
        payload[7] = UInt8(clamping: parts.minute ?? 0)
        payload[8] = UInt8(clamping: parts.second ?? 0)
        payload[10] = UInt8(clamping: max((parts.weekday ?? 1) - 1, 0))
        payload[62] = 0xaa
        payload[63] = 0x55
        return payload
    }
}

public enum AulaWirelessReports {
    public static func rgbCommitReport() -> [UInt8] {
        var report = [UInt8](repeating: 0, count: 32)
        report[0] = 0x0f
        AulaChecksum.apply(to: &report, checksumIndex: 31)
        return report
    }

    public static func rgbLEDReport(
        mode: Int,
        brightness: Int,
        speed: Int,
        direction: Int,
        colorful: Int,
        color: Int
    ) -> [UInt8] {
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
        AulaChecksum.apply(to: &report, checksumIndex: 31)
        return report
    }

    public static func keyResponseReport(responseLevel: Int, fnSwitch: Int, sleepTime: Int) -> [UInt8] {
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
        AulaChecksum.apply(to: &report, checksumIndex: 31)
        return report
    }

    public static func gameModeReport(
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
        AulaChecksum.apply(to: &report, checksumIndex: 31)
        return report
    }

    public static func batteryQuery(includeReportID: Bool, length: Int) -> [UInt8] {
        var payload = [UInt8](repeating: 0, count: max(length, 0))
        guard !payload.isEmpty else { return payload }
        if includeReportID {
            payload[0] = 0x00
            if payload.count > 1 { payload[1] = 0x20 }
            if payload.count > 2 { payload[2] = 0x01 }
        } else {
            payload[0] = 0x20
            if payload.count > 1 { payload[1] = 0x01 }
        }

        let checksumIndex = includeReportID ? 32 : 31
        AulaChecksum.apply(to: &payload, checksumIndex: checksumIndex)
        return payload
    }
}
