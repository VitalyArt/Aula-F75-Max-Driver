#if os(Linux)
import AulaCore
import AulaLinuxHID
import CAulaLinuxGTK
import Foundation
import Glibc

@main
struct AulaLinuxMain {
    static func main() {
        let status = aula_linux_app_run(CommandLine.argc, CommandLine.unsafeArgv)
        exit(status)
    }
}

@_cdecl("aula_linux_refresh")
public func aulaLinuxRefresh(_ buffer: UnsafeMutablePointer<CChar>?, _ capacity: Int32) {
    writeResult(buffer, capacity) {
        let backend = LinuxHIDBackend()
        let endpoints = backend.scanEndpoints()
        guard !endpoints.isEmpty else {
            return "No Aula F75 Max HID endpoints found. Check USB connection and udev permissions."
        }
        return endpoints.map { endpoint in
            "\(endpoint.role): \(endpoint.product) vid=0x\(String(endpoint.vendorID, radix: 16)) pid=0x\(String(endpoint.productID, radix: 16)) \(endpoint.summary)"
        }.joined(separator: "\n")
    }
}

@_cdecl("aula_linux_query_battery")
public func aulaLinuxQueryBattery(_ buffer: UnsafeMutablePointer<CChar>?, _ capacity: Int32) {
    writeResult(buffer, capacity) {
        let backend = LinuxHIDBackend()
        if let percent = try backend.queryBattery() {
            return "Battery: \(percent)%."
        }
        return "Battery query sent, but no percentage report was received."
    }
}

@_cdecl("aula_linux_sync_time")
public func aulaLinuxSyncTime(_ buffer: UnsafeMutablePointer<CChar>?, _ capacity: Int32) {
    writeResult(buffer, capacity) {
        let backend = LinuxHIDBackend()
        try backend.syncTime()
        return "Keyboard display clock synced."
    }
}

@_cdecl("aula_linux_upload_display")
public func aulaLinuxUploadDisplay(
    _ buffer: UnsafeMutablePointer<CChar>?,
    _ capacity: Int32,
    _ bytes: UnsafeRawPointer?,
    _ length: Int32,
    _ slot: Int32
) {
    writeResult(buffer, capacity) {
        guard let bytes, length > 0 else {
            throw AulaError.imageLoadFailed("encoded stream is empty")
        }
        let data = Data(bytes: bytes, count: Int(length))
        let backend = LinuxHIDBackend()
        var lastProgress = DisplayUploadProgress(sentChunks: 0, totalChunks: 0)
        try backend.uploadDisplayStream(data, slot: Int(slot)) { progress in
            lastProgress = progress
        }
        return "Uploaded image to slot \(slot). Chunks: \(lastProgress.sentChunks)/\(lastProgress.totalChunks)."
    }
}

@_cdecl("aula_linux_factory_reset")
public func aulaLinuxFactoryReset(_ buffer: UnsafeMutablePointer<CChar>?, _ capacity: Int32) {
    writeResult(buffer, capacity) {
        let backend = LinuxHIDBackend()
        var messages: [String] = []
        try backend.factoryReset { message in
            messages.append(message)
        }
        messages.append("Factory reset complete.")
        return messages.joined(separator: "\n")
    }
}

@_cdecl("aula_linux_endpoint_counts")
public func aulaLinuxEndpointCounts(_ wired: UnsafeMutablePointer<Int32>?, _ dongle: UnsafeMutablePointer<Int32>?) {
    let backend = LinuxHIDBackend()
    let endpoints = backend.scanEndpoints()
    wired?.pointee = Int32(endpoints.filter { $0.vendorID == AulaConstants.wiredVendorID && $0.productID == AulaConstants.wiredProductID }.count)
    dongle?.pointee = Int32(endpoints.filter { $0.vendorID == AulaConstants.dongleVendorID && $0.productID == AulaConstants.dongleProductID }.count)
}

@_cdecl("aula_linux_apply_rgb")
public func aulaLinuxApplyRGB(
    _ buffer: UnsafeMutablePointer<CChar>?,
    _ capacity: Int32,
    _ mode: Int32,
    _ brightness: Int32,
    _ speed: Int32,
    _ direction: Int32,
    _ colorful: Int32,
    _ color: Int32
) {
    writeResult(buffer, capacity) {
        let backend = LinuxHIDBackend()
        try backend.applyRGB(
            mode: Int(mode),
            brightness: Int(brightness),
            speed: Int(speed),
            direction: Int(direction),
            colorful: colorful != 0,
            color: Int(color)
        )
        let colorText = colorful != 0 ? "Colorful" : String(format: "#%06X", Int(color) & 0xffffff)
        return "RGB set: mode \(mode), brightness \(brightness), speed \(speed), direction \(direction), \(colorText)."
    }
}

@_cdecl("aula_linux_apply_performance")
public func aulaLinuxApplyPerformance(
    _ buffer: UnsafeMutablePointer<CChar>?,
    _ capacity: Int32,
    _ level: Int32,
    _ sleepTime: Int32
) {
    writeResult(buffer, capacity) {
        let backend = LinuxHIDBackend()
        try backend.applyPerformance(level: Int(level), sleepTime: Int(sleepTime))
        return "Performance set: response level \(level), sleep \(sleepTime)."
    }
}

@_cdecl("aula_linux_restore_command")
public func aulaLinuxRestoreCommand(
    _ buffer: UnsafeMutablePointer<CChar>?,
    _ capacity: Int32,
    _ level: Int32,
    _ sleepTime: Int32
) {
    writeResult(buffer, capacity) {
        let backend = LinuxHIDBackend()
        try backend.applyPerformance(level: Int(level), sleepTime: Int(sleepTime))
        return "Command key restore sent; Fn layer unlocked."
    }
}

@_cdecl("aula_linux_set_game_mode")
public func aulaLinuxSetGameMode(
    _ buffer: UnsafeMutablePointer<CChar>?,
    _ capacity: Int32,
    _ enabled: Int32,
    _ level: Int32,
    _ sleepTime: Int32
) {
    writeResult(buffer, capacity) {
        let backend = LinuxHIDBackend()
        try backend.setGameMode(enabled: enabled != 0, level: Int(level), sleepTime: Int(sleepTime))
        return enabled != 0 ? "Game Mode enabled." : "Game Mode disabled."
    }
}

private func writeResult(
    _ buffer: UnsafeMutablePointer<CChar>?,
    _ capacity: Int32,
    _ operation: () throws -> String
) {
    do {
        writeCString(try operation(), to: buffer, capacity: capacity)
    } catch {
        writeCString("Error: \(error.localizedDescription)", to: buffer, capacity: capacity)
    }
}

private func writeCString(_ message: String, to buffer: UnsafeMutablePointer<CChar>?, capacity: Int32) {
    guard let buffer, capacity > 0 else { return }
    let limit = max(Int(capacity) - 1, 0)
    let bytes = Array(message.utf8.prefix(limit))
    for index in bytes.indices {
        buffer[index] = CChar(bitPattern: bytes[index])
    }
    buffer[bytes.count] = 0
}
#endif
