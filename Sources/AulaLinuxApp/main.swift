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

@_cdecl("aula_linux_apply_rgb")
public func aulaLinuxApplyRGB(_ buffer: UnsafeMutablePointer<CChar>?, _ capacity: Int32) {
    writeResult(buffer, capacity) {
        let backend = LinuxHIDBackend()
        try backend.applyRGB(
            mode: 11,
            brightness: 5,
            speed: 3,
            direction: 0,
            colorful: true,
            color: 0x4a90e2
        )
        return "Default RGB profile applied."
    }
}

@_cdecl("aula_linux_apply_performance")
public func aulaLinuxApplyPerformance(_ buffer: UnsafeMutablePointer<CChar>?, _ capacity: Int32) {
    writeResult(buffer, capacity) {
        let backend = LinuxHIDBackend()
        try backend.applyPerformance(level: 1, sleepTime: 1)
        return "Performance level 1 applied."
    }
}

@_cdecl("aula_linux_game_mode_off")
public func aulaLinuxGameModeOff(_ buffer: UnsafeMutablePointer<CChar>?, _ capacity: Int32) {
    writeResult(buffer, capacity) {
        let backend = LinuxHIDBackend()
        try backend.setGameMode(enabled: false, level: 1, sleepTime: 1)
        return "Game Mode disabled."
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
