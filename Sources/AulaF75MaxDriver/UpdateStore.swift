import SwiftUI
import AppKit
import AulaCore

@MainActor
final class UpdateStore: ObservableObject {
    static let shared = UpdateStore()
    let version = Bundle.main.object(forInfoDictionaryKey: "AulaReleaseVersion") as? String ?? "0.1.0+dev"
    @Published var channel: UpdateChannel {
        didSet { UserDefaults.standard.set(channel.rawValue, forKey: "updates.channel"); check() }
    }
    @Published var automatic: Bool {
        didSet { UserDefaults.standard.set(automatic, forKey: "updates.automatic"); if automatic { checkIfDue() } }
    }
    @Published private(set) var installing = false
    private let installer = SparkleUpdateInstaller()
    private let feedClient = MacOSUpdateFeedClient()
    @Published private var resolvedFeed: URL?
    @Published private(set) var checking = false
    @Published private(set) var release: AppRelease?
    @Published private(set) var error: String?
    @Published private(set) var lastCheck: Date?
    @Published private var dismissed: String?
    private let client = GitHubUpdateClient()
    private var task: Task<Void, Never>?
    private var lastAttempt = Date.distantPast
    private init() {
        let defaults = UserDefaults.standard
        channel = UpdateChannel.initial(version: version, stored: defaults.string(forKey: "updates.channel"))
        automatic = defaults.object(forKey: "updates.automatic") as? Bool ?? true
        lastCheck = defaults.object(forKey: "updates.lastCheck") as? Date
        dismissed = defaults.string(forKey: "updates.dismissed")
        if let data = defaults.data(forKey: "updates.releases"), let cached = try? JSONDecoder().decode([AppRelease].self, from: data) {
            release = AppRelease.newest(cached, current: version, channel: channel, suffix: ".dmg")
            resolvedFeed = release?.legacySparkleFeedURL
            if let release, defaults.string(forKey: "updates.feedTag") == release.tag_name,
               let address = defaults.string(forKey: "updates.feedURL"), address == release.pagesSparkleFeedURL?.absoluteString {
                resolvedFeed = release.pagesSparkleFeedURL
            }
        }
    }
    var showBanner: Bool { release != nil && release?.tag_name != dismissed }
    var supportsInstallation: Bool {
        resolvedFeed != nil
    }
    var actionTitle: String { L10n.text(supportsInstallation ? "Update…" : "Download") }
    func dismiss() { dismissed = release?.tag_name; UserDefaults.standard.set(dismissed, forKey: "updates.dismissed") }
    func install(canRelaunch: @escaping () -> Bool) {
        guard !installing, !checking, let release else { return }
        // Releases published before Sparkle integration can only be installed manually.
        guard let feed = resolvedFeed else {
            error = nil
            if let asset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }),
               let url = AppRelease.trustedURL(asset.browser_download_url, asset: true),
               NSWorkspace.shared.open(url) {
                return
            }
            error = L10n.text("Could not check for updates. Try again later.")
            return
        }
        installing = true; error = nil
        installer.start(release: release, feed: feed, canRelaunch: canRelaunch) { [weak self] error in
            self?.installing = false; self?.error = error
        }
    }

    func checkIfDue() { if !installing && UpdateTiming.isDue(automatic: automatic, checking: checking, lastSuccess: lastCheck, lastAttempt: lastAttempt) { check() } }
    func check() {
        guard !installing else { return }
        let previous = task
        previous?.cancel()
        lastAttempt = Date()
        let selected = channel
        checking = true; error = nil; release = nil; resolvedFeed = nil
        task = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            do {
                let releases = try await client.releases()
                guard !Task.isCancelled, channel == selected else { return }
                let candidate = AppRelease.newest(releases, current: version, channel: selected, suffix: ".dmg")
                let feed: URL?
                if let candidate { feed = try await feedClient.feed(for: candidate) }
                else { feed = nil }
                guard !Task.isCancelled, channel == selected else { return }
                release = candidate; resolvedFeed = feed
                UserDefaults.standard.set(candidate?.tag_name, forKey: "updates.feedTag")
                UserDefaults.standard.set(feed?.absoluteString, forKey: "updates.feedURL")
                lastCheck = Date(); UserDefaults.standard.set(lastCheck, forKey: "updates.lastCheck")
            } catch {
                guard !Task.isCancelled, channel == selected else { return }
                self.error = L10n.text("Could not check for updates. Try again later.")
            }
            checking = false
        }
    }
}

struct UpdatesCard: View {
    @EnvironmentObject private var model: AppViewModel
    @ObservedObject private var updates = UpdateStore.shared
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(L10n.text("Current version")): \(updates.version)").font(.callout).foregroundStyle(.secondary)
                Picker(L10n.text("Update channel"), selection: $updates.channel) {
                    Text("Stable").tag(UpdateChannel.stable)
                    Text("Alpha").tag(UpdateChannel.alpha)
                }.pickerStyle(.segmented).disabled(updates.installing)
                Text(L10n.text(updates.channel == .stable ? "Stable releases only." : "Stable and preview releases, including beta and RC. May be unstable.")).font(.caption).foregroundStyle(.secondary)
                Toggle(L10n.text("Automatically check for updates"), isOn: $updates.automatic)
                Divider()
                if updates.checking { ProgressView(L10n.text("Checking for updates…")) }
                if let error = updates.error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                if let release = updates.release {
                    Label(release.tag_name, systemImage: "arrow.down.circle.fill").font(.headline)
                    if release.prerelease || (release.version?.stage ?? 3) < 3 { Text(L10n.text("Pre-release")).font(.caption).foregroundStyle(.orange) }
                    HStack {
                        Button(updates.actionTitle) { updates.install { !model.isWorking } }.buttonStyle(.borderedProminent).disabled(model.isWorking || updates.installing || updates.checking)
                        if let url = AppRelease.trustedURL(release.html_url) { Link(L10n.text("What’s new"), destination: url) }
                    }
                    if !updates.supportsInstallation { Text(L10n.text("This release does not support in-app installation.")).font(.caption).foregroundStyle(.secondary) }
                    if updates.installing { ProgressView(L10n.text("Downloading update…")) }
                } else if updates.lastCheck != nil && updates.error == nil && !updates.checking { Label(L10n.text("You’re up to date"), systemImage: "checkmark.circle") }
                if let date = updates.lastCheck { Text("\(L10n.text("Last checked")): \(date.formatted())").font(.caption).foregroundStyle(.secondary) }
                Button(L10n.text("Check now")) { updates.check() }.disabled(updates.checking || updates.installing)
            }.frame(maxWidth: .infinity, alignment: .leading)
        } label: { Label(L10n.text("Updates"), systemImage: "arrow.triangle.2.circlepath") }
    }
}

struct UpdateBanner: View {
    @EnvironmentObject private var model: AppViewModel
    @ObservedObject private var updates = UpdateStore.shared
    var body: some View {
        if updates.showBanner, let release = updates.release {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("\(L10n.text("Update available")): \(release.tag_name)", systemImage: "arrow.down.circle")
                    Spacer()
                    if updates.installing { ProgressView().controlSize(.small) }
                    Button(updates.actionTitle) { updates.install { !model.isWorking } }.disabled(model.isWorking || updates.installing || updates.checking)
                    Button { updates.dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel(L10n.text("Dismiss"))
                }
                if let error = updates.error { Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled) }
                else if !updates.supportsInstallation { Text(L10n.text("This release does not support in-app installation.")).font(.caption).foregroundStyle(.secondary) }
            }.padding(12).background(.tint.opacity(0.1))
        }
    }
}
