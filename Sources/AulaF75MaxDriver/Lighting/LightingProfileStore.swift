import Foundation

/// A named lighting look the user saved, like a G Hub preset.
struct LightingProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var settings: LightingSettings
}

/// Keeps the user's saved lighting profiles on this Mac.
///
/// Profiles live in `UserDefaults` as one JSON array, not on the keyboard
/// (the keyboard protocol the app knows has no profile slots). The store is an
/// `ObservableObject`, so any view showing the list redraws when it changes.
@MainActor
final class LightingProfileStore: ObservableObject {
    @Published private(set) var profiles: [LightingProfile] = []
    @Published var selectedID: UUID?

    private let defaults: UserDefaults
    private let storageKey: String

    /// - Parameters:
    ///   - defaults: injectable so tests can use an isolated suite.
    ///   - storageKey: the `UserDefaults` key holding the JSON array.
    init(defaults: UserDefaults = .standard, storageKey: String = "lighting.profiles.v1") {
        self.defaults = defaults
        self.storageKey = storageKey
        load()
    }

    var selectedProfile: LightingProfile? {
        profiles.first { $0.id == selectedID }
    }

    @discardableResult
    func add(name: String, settings: LightingSettings) -> LightingProfile {
        let profile = LightingProfile(id: UUID(), name: name, settings: settings)
        profiles.append(profile)
        save()
        return profile
    }

    func update(_ id: UUID, settings: LightingSettings) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].settings = settings
        save()
    }

    func rename(_ id: UUID, to name: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].name = name
        save()
    }

    func delete(_ id: UUID) {
        profiles.removeAll { $0.id == id }
        if selectedID == id {
            selectedID = nil
        }
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard defaults.object(forKey: storageKey) != nil else {
            // Nothing stored yet: this is the first launch, so add starters.
            profiles = Self.starterProfiles()
            save()
            return
        }

        // Unreadable data (wrong type or bad JSON) starts empty rather than
        // crashing, and does not bring back starters the user may have deleted.
        guard let data = defaults.data(forKey: storageKey) else {
            profiles = []
            return
        }
        profiles = (try? JSONDecoder().decode([LightingProfile].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func starterProfiles() -> [LightingProfile] {
        [
            LightingProfile(
                id: UUID(),
                name: L10n.text("Rainbow Wave"),
                settings: LightingSettings(mode: 11, brightness: 4, speed: 3, direction: 0, colorful: true, red: 0, green: 122, blue: 255)
            ),
            LightingProfile(
                id: UUID(),
                name: L10n.text("Calm Breath"),
                settings: LightingSettings(mode: 7, brightness: 3, speed: 2, direction: 0, colorful: false, red: 0, green: 122, blue: 255)
            ),
            LightingProfile(
                id: UUID(),
                name: L10n.text("Off"),
                settings: LightingSettings(mode: 0, brightness: 1, speed: 1, direction: 0, colorful: true, red: 0, green: 122, blue: 255)
            )
        ]
    }
}
