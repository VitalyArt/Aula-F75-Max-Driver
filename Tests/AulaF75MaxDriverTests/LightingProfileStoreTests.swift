import XCTest
@testable import AulaF75MaxDriver

@MainActor
final class LightingProfileStoreTests: XCTestCase {
    private let key = "lighting.profiles.test"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: UUID().uuidString)
    }

    private let sample = LightingSettings(mode: 8, brightness: 3, speed: 2, direction: 1, colorful: false, red: 10, green: 20, blue: 30)

    func testFirstLaunchSeedsThreeStarters() {
        let store = LightingProfileStore(defaults: defaults, storageKey: key)
        XCTAssertEqual(store.profiles.count, 3)
        XCTAssertEqual(store.profiles.map(\.settings.mode), [11, 7, 0])
    }

    func testSecondLaunchDoesNotReseed() {
        let first = LightingProfileStore(defaults: defaults, storageKey: key)
        for profile in first.profiles { first.delete(profile.id) }
        let second = LightingProfileStore(defaults: defaults, storageKey: key)
        XCTAssertTrue(second.profiles.isEmpty)
    }

    func testAddRenameUpdateDeletePersist() {
        let store = LightingProfileStore(defaults: defaults, storageKey: key)
        let added = store.add(name: "Desk", settings: sample)
        XCTAssertEqual(LightingProfileStore(defaults: defaults, storageKey: key).profiles.last, added)

        store.rename(added.id, to: "Night")
        XCTAssertEqual(LightingProfileStore(defaults: defaults, storageKey: key).profiles.last?.name, "Night")

        var changed = sample
        changed.brightness = 5
        store.update(added.id, settings: changed)
        XCTAssertEqual(LightingProfileStore(defaults: defaults, storageKey: key).profiles.last?.settings.brightness, 5)

        store.delete(added.id)
        XCTAssertFalse(LightingProfileStore(defaults: defaults, storageKey: key).profiles.contains { $0.id == added.id })
    }

    func testDeletingSelectedProfileClearsSelection() {
        let store = LightingProfileStore(defaults: defaults, storageKey: key)
        let added = store.add(name: "Desk", settings: sample)
        let other = store.profiles[0]
        store.selectedID = added.id
        store.delete(added.id)
        XCTAssertNil(store.selectedID)
        XCTAssertTrue(store.profiles.contains(other))
    }

    func testCorruptDataLoadsEmptyWithoutReseeding() {
        defaults.set(Data("not json".utf8), forKey: key)
        let store = LightingProfileStore(defaults: defaults, storageKey: key)
        XCTAssertTrue(store.profiles.isEmpty)
    }

    func testSelectedProfileFollowsSelectedID() {
        let store = LightingProfileStore(defaults: defaults, storageKey: key)
        let added = store.add(name: "Desk", settings: sample)
        store.selectedID = added.id
        XCTAssertEqual(store.selectedProfile, added)
    }
}

@MainActor
final class LightingProfileReviewFixTests: XCTestCase {
    func testWrongTypeStoredValueLoadsEmptyWithoutReseeding() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        defaults.set("garbage", forKey: "key")
        let store = LightingProfileStore(defaults: defaults, storageKey: "key")
        XCTAssertTrue(store.profiles.isEmpty)
    }

    func testEditingBeforeAnyApplyCountsAsUnsaved() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = LightingProfileStore(defaults: defaults, storageKey: "key")
        let model = AppViewModel()
        XCTAssertFalse(ProfileActions.hasUnsavedEdits(model: model, store: store))
        model.rgbBrightness = model.rgbBrightness == 1 ? 2 : 1
        XCTAssertTrue(ProfileActions.hasUnsavedEdits(model: model, store: store))
    }
}
