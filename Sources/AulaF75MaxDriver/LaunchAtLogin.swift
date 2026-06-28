import Foundation
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status == .enabled {
                return true
            }
        }
        return FileManager.default.fileExists(atPath: legacyLaunchAgentURL.path)
    }

    static func setEnabled(_ enabled: Bool) throws -> String {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if enabled {
                if service.status == .enabled {
                    try? removeLegacyLaunchAgent()
                    return L10n.text("Launch at Login already enabled.")
                }
                do {
                    try service.register()
                    if service.status == .requiresApproval {
                        try writeLegacyLaunchAgent()
                        return L10n.text("Launch at Login requires approval; legacy LaunchAgent was written as fallback.")
                    }
                    try? removeLegacyLaunchAgent()
                    return L10n.text("Launch at Login enabled.")
                } catch {
                    try writeLegacyLaunchAgent()
                    return L10n.text("SMAppService failed; legacy LaunchAgent enabled.")
                }
            }

            if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
            try removeLegacyLaunchAgent()
            return L10n.text("Launch at Login disabled.")
        }

        if enabled {
            try writeLegacyLaunchAgent()
            return L10n.text("Launch at Login enabled.")
        }
        try removeLegacyLaunchAgent()
        return L10n.text("Launch at Login disabled.")
    }

    private static var legacyLaunchAgentURL: URL {
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        return library
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("art.vitaly.aula-macos-driver.login.plist")
    }

    private static func writeLegacyLaunchAgent() throws {
        let bundlePath = Bundle.main.bundleURL.path
        let plist: [String: Any] = [
            "Label": "art.vitaly.aula-macos-driver.login",
            "ProgramArguments": ["/usr/bin/open", "-g", bundlePath],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let directory = legacyLaunchAgentURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: legacyLaunchAgentURL, options: .atomic)
    }

    private static func removeLegacyLaunchAgent() throws {
        guard FileManager.default.fileExists(atPath: legacyLaunchAgentURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: legacyLaunchAgentURL)
    }
}
