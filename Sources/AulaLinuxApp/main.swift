import AulaCore
import AulaLinuxHID
import CAulaLinuxGTK
import Foundation
import Glibc

let status = aula_linux_app_run(CommandLine.argc, CommandLine.unsafeArgv)
exit(status)

@_cdecl("aula_linux_refresh")
public func aulaLinuxRefresh(_ buffer: UnsafeMutablePointer<CChar>?, _ capacity: Int32) {
    writeResult(buffer, capacity) {
        let backend = LinuxHIDBackend()
        let endpoints = backend.scanEndpoints()
        guard !endpoints.isEmpty else {
            return L10n.text("Aula F75 Max wired USB device was not found.")
        }
        return endpoints.map { endpoint in
            "\(L10n.text(endpoint.role)): \(endpoint.product) vid=0x\(String(endpoint.vendorID, radix: 16)) pid=0x\(String(endpoint.productID, radix: 16)) \(endpoint.summary)"
        }.joined(separator: "\n")
    }
}

@_cdecl("aula_linux_query_battery")
public func aulaLinuxQueryBattery(_ buffer: UnsafeMutablePointer<CChar>?, _ capacity: Int32) {
    writeResult(buffer, capacity) {
        let backend = LinuxHIDBackend()
        if let percent = try backend.queryBattery() {
            return L10n.format("Battery: %d%%.", percent)
        }
        return L10n.text("Battery query sent, but no percentage report was received.")
    }
}

@_cdecl("aula_linux_sync_time")
public func aulaLinuxSyncTime(_ buffer: UnsafeMutablePointer<CChar>?, _ capacity: Int32) {
    writeResult(buffer, capacity) {
        let backend = LinuxHIDBackend()
        try backend.syncTime()
        return L10n.text("Keyboard clock synced.")
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
        return L10n.format("Uploaded %d frame(s) to slot %d.", lastProgress.sentChunks, slot)
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
        messages.append(L10n.text("Factory reset complete."))
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
        let modeText = L10n.format("Mode %d", mode)
        let directionText = L10n.format("Direction %d", direction)
        let colorText = colorful != 0 ? L10n.text("Colorful") : String(format: "#%06X", Int(color) & 0xffffff)
        return L10n.format("RGB set: %@ B%d S%d %@ %@.", modeText, brightness, speed, directionText, colorText)
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
        let levelText = L10n.format("Level %d", level)
        let sleepText = L10n.format("Value %d", sleepTime)
        return L10n.format("Performance set: %@, sleep %@.", levelText, sleepText)
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
        return L10n.text("Command key restore sent; Fn layer unlocked.")
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
        return enabled != 0 ? L10n.text("Game Mode enabled.") : L10n.text("Game Mode disabled.")
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

