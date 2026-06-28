import Foundation

enum AulaConstants {
    static let wiredVendorID = 0x0c45
    static let wiredProductID = 0x800a
    static let dongleVendorID = 0x05ac
    static let dongleProductID = 0x024f

    static let wiredCommandUsagePage = 0xff13
    static let wiredRawUsagePage = 0xff68
    static let wirelessCommandUsagePage = 0xff59
    static let wirelessRawUsagePage = 0xff60
    static let commandUsagePage = wiredCommandUsagePage
    static let rawUsagePage = wiredRawUsagePage
    static let vendorUsage = 0x61

    static let commandLength = 64
    static let ackLength = 128
    static let displayWidth = 128
    static let displayHeight = 128
    static let headerLength = 256
    static let frameBytes = displayWidth * displayHeight * 2
    static let chunkLength = 4096
    static let maxFrames = 255
}

enum AulaError: LocalizedError {
    case deviceNotFound
    case endpointNotFound(String)
    case openFailed(String)
    case hidFailed(String, Int32)
    case imageLoadFailed(String)
    case imageTooLarge(String)
    case invalidSlot
    case cancelled

    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return L10n.text("Aula F75 Max wired USB device was not found.")
        case .endpointNotFound(let endpoint):
            return L10n.format("Required HID endpoint was not found: %@.", endpoint)
        case .openFailed(let detail):
            return L10n.format("Failed to open HID device: %@.", detail)
        case .hidFailed(let operation, let code):
            return L10n.format("%@ failed with IOReturn 0x%08x.", operation, UInt32(bitPattern: code))
        case .imageLoadFailed(let detail):
            return L10n.format("Failed to load image: %@.", detail)
        case .imageTooLarge(let detail):
            return L10n.format("Image payload is too large: %@.", detail)
        case .invalidSlot:
            return L10n.text("Slot must be between 1 and 255.")
        case .cancelled:
            return L10n.text("Operation cancelled.")
        }
    }
}

struct HIDEndpointInfo: Identifiable, Hashable {
    let id: String
    let vendorID: Int
    let productID: Int
    let usagePage: Int
    let usage: Int
    let maxInputReportSize: Int
    let maxOutputReportSize: Int
    let maxFeatureReportSize: Int
    let product: String
    let transport: String

    var role: String {
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

    var summary: String {
        "\(role)  usagePage=0x\(String(usagePage, radix: 16))  in=\(maxInputReportSize) out=\(maxOutputReportSize) feature=\(maxFeatureReportSize)"
    }
}

struct DisplayUploadProgress: Sendable {
    let sentChunks: Int
    let totalChunks: Int

    var fraction: Double {
        guard totalChunks > 0 else { return 0 }
        return Double(sentChunks) / Double(totalChunks)
    }
}
