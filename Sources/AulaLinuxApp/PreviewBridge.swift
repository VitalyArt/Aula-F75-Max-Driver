import AulaCore
import Foundation

@_cdecl("aula_preview_color")
func previewColor(_ mode: Int32, _ brightness: Int32, _ speed: Int32, _ direction: Int32,
                  _ colorful: Int32, _ color: Int32, _ x: Double, _ y: Double, _ time: Double,
                  _ output: UnsafeMutablePointer<Double>) {
    let settings = LightingSettings(mode: Int(mode), brightness: Int(brightness), speed: Int(speed),
        direction: Int(direction), colorful: colorful != 0, red: Int((color >> 16) & 255),
        green: Int((color >> 8) & 255), blue: Int(color & 255))
    let rgb = LightingEffectRenderer.color(for: settings, at: CGPoint(x: x, y: y), time: time)
    output[0] = rgb.r; output[1] = rgb.g; output[2] = rgb.b
}

@_cdecl("aula_preview_key")
func previewKey(_ index: Int32, _ geometry: UnsafeMutablePointer<Double>, _ label: UnsafeMutablePointer<CChar>) -> Int32 {
    let keys = KeyboardLayout.f75Max.keys
    guard keys.indices.contains(Int(index)) else { return 0 }
    let key = keys[Int(index)]
    geometry[0] = key.frame.minX; geometry[1] = key.frame.minY
    geometry[2] = key.frame.width; geometry[3] = key.frame.height
    geometry[4] = key.tone == .light ? 1 : 0; geometry[5] = Double(key.row)
    key.label.withCString { source in
        for i in 0..<min(key.label.utf8.count + 1, 32) { label[i] = source[i] }
    }
    return 1
}

private struct SavedLightingProfile: Codable {
    var id = UUID()
    var name: String
    var settings: LightingSettings
}

// Called exclusively on the GTK main thread. Storage is independent of the HID worker.
private enum Profiles {
    static var file: URL {
        let directory = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config").path
        return URL(fileURLWithPath: directory).appendingPathComponent("aula-f75-max-driver/lighting-profiles.json")
    }
    static func load() throws -> [SavedLightingProfile] {
        if !FileManager.default.fileExists(atPath: file.path) {
            let profiles = [
                SavedLightingProfile(name: L10n.text("Rainbow Wave"), settings: .init(mode: 11, brightness: 4, speed: 3, direction: 0, colorful: true, red: 0, green: 122, blue: 255)),
                SavedLightingProfile(name: L10n.text("Calm Breath"), settings: .init(mode: 7, brightness: 3, speed: 2, direction: 0, colorful: false, red: 0, green: 122, blue: 255)),
                SavedLightingProfile(name: L10n.text("Off"), settings: .init(mode: 0, brightness: 1, speed: 1, direction: 0, colorful: true, red: 0, green: 122, blue: 255))
            ]
            try save(profiles)
            return profiles
        }
        let data = try Data(contentsOf: file)
        return (try? JSONDecoder().decode([SavedLightingProfile].self, from: data)) ?? []
    }
    static func save(_ profiles: [SavedLightingProfile]) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(profiles).write(to: file, options: .atomic)
    }
}

// action: 0 read/count, 1 append, 2 update settings, 3 rename, 4 delete.
@_cdecl("aula_profiles")
func profilesBridge(_ action: Int32, _ index: Int32, _ name: UnsafePointer<CChar>?,
                    _ values: UnsafeMutablePointer<Int32>, _ output: UnsafeMutablePointer<CChar>, _ capacity: Int32) -> Int32 {
    do {
        var profiles = try Profiles.load()
        let i = Int(index)
        let settings = LightingSettings(mode: Int(values[0]), brightness: Int(values[1]), speed: Int(values[2]),
            direction: Int(values[3]), colorful: values[4] != 0, red: Int((values[5] >> 16) & 255),
            green: Int((values[5] >> 8) & 255), blue: Int(values[5] & 255))
        let title = name.map { String(cString: $0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        if action == 1 {
            guard !title.isEmpty else { throw NSError(domain: "AulaProfiles", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid profile name or selection."]) }
            profiles.append(.init(name: title, settings: settings))
        } else if action != 0 {
            guard profiles.indices.contains(i) else { throw NSError(domain: "AulaProfiles", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid profile name or selection."]) }
            if action == 2 { profiles[i].settings = settings }
            if action == 3 {
                guard !title.isEmpty else { throw NSError(domain: "AulaProfiles", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid profile name or selection."]) }
                profiles[i].name = title
            }
            if action == 4 { profiles.remove(at: i) }
        }
        if action != 0 { try Profiles.save(profiles) }
        if profiles.indices.contains(i) {
            let p = profiles[i]
            values[0] = Int32(p.settings.mode); values[1] = Int32(p.settings.brightness)
            values[2] = Int32(p.settings.speed); values[3] = Int32(p.settings.direction)
            values[4] = p.settings.colorful ? 1 : 0; values[5] = Int32(p.settings.rgbInteger)
            writeCString(p.name, to: output, capacity: capacity)
        }
        return Int32(profiles.count)
    } catch {
        writeCString(error.localizedDescription, to: output, capacity: capacity)
        return -1
    }
}
