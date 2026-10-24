import Foundation
import AulaCore

/// GTK polls immutable snapshots on its main loop; networking never touches widgets.
private final class LinuxUpdates: @unchecked Sendable {
    static let shared = LinuxUpdates()
    private let lock = NSLock()
    private let defaults = UserDefaults.standard
    private let client = GitHubUpdateClient()
    private var task: Task<Void, Never>?
    private var generation = 0
    private var busy = false
    private var release: AppRelease?
    private var failed = false
    private var installTask: Task<Void, Never>?
    private var installing = false
    private var installed = false
    private var downloadFraction: Double?
    private var installStatus: String?
    private var pendingInstaller: URL?
    private var installerFile: URL?
    private let executablePath = URL(fileURLWithPath: "/proc/self/exe").resolvingSymlinksInPath().path
    private var lastAttempt = Date.distantPast
    let version: String = {
        let url = URL(fileURLWithPath: "/proc/self/exe").standardizedFileURL.resolvingSymlinksInPath().deletingLastPathComponent().appendingPathComponent("version.txt")
        return (try? String(contentsOf: url, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)) ?? "0.1.0+dev"
    }()
    private init() {
        if let data = defaults.data(forKey: "updates.releases"), let cached = try? JSONDecoder().decode([AppRelease].self, from: data) {
            release = AppRelease.newest(cached, current: version, channel: channel, suffix: Self.suffix)
        }
    }
    private var channel: UpdateChannel {
        UpdateChannel.initial(version: version, stored: defaults.string(forKey: "updates.channel"))
    }
    private var automatic: Bool { defaults.object(forKey: "updates.automatic") as? Bool ?? true }
    private var lastCheck: Date? { defaults.object(forKey: "updates.lastCheck") as? Date }
    func command(_ action: Int32) {
        lock.lock(); defer { lock.unlock() }
        if action == 6 { beginDownload(); return }
        if action == 7 { pendingInstaller = nil; return }
        if action == 8 { installTask?.cancel(); installing = false; installStatus = nil; return }
        if installing && action != 4 { return }
        switch action {
        case 1, 2:
            defaults.set(action == 1 ? "stable" : "alpha", forKey: "updates.channel")
        case 3: defaults.set(!automatic, forKey: "updates.automatic"); return
        case 4: defaults.set(release?.tag_name, forKey: "updates.dismissed"); return
        default: break
        }
        if action == 0 && !UpdateTiming.isDue(automatic: automatic, checking: busy, lastSuccess: lastCheck, lastAttempt: lastAttempt) { return }
        if !installed { installStatus = nil }
        let previous = task
        previous?.cancel(); generation += 1
        let token = generation; let selected = channel
        busy = true; failed = false; release = nil; lastAttempt = Date()
        task = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            do {
                let items = try await client.releases()
                guard !Task.isCancelled else { return }
                self.finish(token, AppRelease.newest(items, current: version, channel: selected, suffix: Self.suffix), false)
            } catch {
                guard !Task.isCancelled else { return }
                self.finish(token, nil, true)
            }
        }
    }
    private func beginDownload() {
        guard !installing, !installed, let release else { return }
        installing = true; installed = false; downloadFraction = nil; installStatus = L10n.text("Downloading update…")
        installTask = Task {
            do {
                let file = try await ReleaseDownload.deb(release: release, suffix: Self.suffix) { fraction in self.downloadProgress(fraction) }
                guard !Task.isCancelled else { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()); return }
                self.downloadReady(file)
            } catch {
                guard !Task.isCancelled else { return }
                self.installFinished(false)
            }
        }
    }
    private func downloadProgress(_ fraction: Double?) {
        lock.lock(); defer { lock.unlock() }
        downloadFraction = fraction
        installStatus = L10n.text("Downloading update…") + (fraction.map { " \(Int($0 * 100))%" } ?? "")
    }
    private func downloadReady(_ file: URL) {
        lock.lock(); defer { lock.unlock() }
        installerFile = file; pendingInstaller = file
        installStatus = L10n.text("Waiting for the system installer…")
    }
    func installFinished(_ success: Bool, unavailable: Bool = false) {
        lock.lock(); defer { lock.unlock() }
        installing = false; installed = success; pendingInstaller = nil
        installStatus = L10n.text(success ? "Update installed. Restart the app." : unavailable ? "System installer unavailable. Install PackageKit and try again." : "Could not install the update. Please try again.")
        if let file = installerFile { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()); installerFile = nil }
    }
    private static var suffix: String {
        #if arch(arm64)
        "_arm64.deb"
        #else
        "_amd64.deb"
        #endif
    }
    private func finish(_ token: Int, _ result: AppRelease?, _ error: Bool) {
        lock.lock(); defer { lock.unlock() }
        guard token == generation else { return }
        release = result; failed = error; busy = false
        if !error { defaults.set(Date(), forKey: "updates.lastCheck") }
    }
    func snapshot(_ field: Int32) -> String {
        lock.lock(); defer { lock.unlock() }
        switch field {
        case 0: return version
        case 1: return channel.rawValue
        case 2: return automatic ? "1" : "0"
        case 3:
            if let installStatus { return installStatus }
            if busy { return L10n.text("Checking for updates…") }
            if failed { return L10n.text("Could not check for updates. Try again later.") }
            if let release { return "\(L10n.text("Update available")): \(release.tag_name)\((release.prerelease || (release.version?.stage ?? 3) < 3) ? " · " + L10n.text("Pre-release") : "")" }
            return lastCheck == nil ? "" : L10n.text("You’re up to date")
        case 4: return release?.downloadURL(suffix: Self.suffix)?.absoluteString ?? ""
        case 5: return release.flatMap { AppRelease.trustedURL($0.html_url)?.absoluteString } ?? ""
        case 6: return lastCheck.map { "\(L10n.text("Last checked")): \(DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .short))" } ?? ""
        case 7: return release != nil && release?.tag_name != defaults.string(forKey: "updates.dismissed") ? "1" : "0"
        case 8: return busy || installing ? "1" : "0"
        case 10: return pendingInstaller?.path ?? ""
        case 11: return installed ? "1" : "0"
        case 12: return executablePath
        case 13: return installing ? "1" : "0"
        case 14: return downloadFraction.map { String($0) } ?? "-1"
        default: return L10n.text(channel == .stable ? "Stable releases only." : "Stable and preview releases, including beta and RC. May be unstable.")
        }
    }
}

@_cdecl("aula_updates_command")
public func aulaUpdatesCommand(_ action: Int32) { LinuxUpdates.shared.command(action) }
@_cdecl("aula_updates_read")
public func aulaUpdatesRead(_ field: Int32, _ buffer: UnsafeMutablePointer<CChar>?, _ capacity: Int32) {
    guard let buffer, capacity > 0 else { return }
    let bytes = Array(LinuxUpdates.shared.snapshot(field).utf8.prefix(Int(capacity) - 1))
    for (i, byte) in bytes.enumerated() { buffer[i] = CChar(bitPattern: byte) }
    buffer[bytes.count] = 0
}

@_cdecl("aula_updates_install_finished")
public func aulaUpdatesInstallFinished(_ success: Int32) { LinuxUpdates.shared.installFinished(success == 1, unavailable: success == -1) }
