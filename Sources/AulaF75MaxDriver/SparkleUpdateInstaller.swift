import AppKit
import Sparkle
import AulaCore

/// GitHub determines the channel/version; Sparkle verifies, replaces and relaunches the app.
@MainActor
final class SparkleUpdateInstaller: NSObject, SPUUpdaterDelegate {
    private var controller: SPUStandardUpdaterController?
    private var feed: URL?
    private var preview = false
    private var canRelaunch: () -> Bool = { true }
    private var completion: ((String?) -> Void)?
    private var postponedRelaunch: Task<Void, Never>?

    func start(release: AppRelease, feed: URL, canRelaunch: @escaping () -> Bool, completion: @escaping (String?) -> Void) {
        guard controller?.updater.sessionInProgress != true else { return }
        guard (feed == release.pagesSparkleFeedURL || feed == release.legacySparkleFeedURL),
              Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String != nil else {
            completion(L10n.text("This release does not support in-app installation.")); return
        }
        self.feed = feed; preview = release.prerelease || (release.version?.stage ?? 3) < 3
        self.canRelaunch = canRelaunch; self.completion = completion
        if controller == nil {
            let controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
            self.controller = controller
            controller.updater.automaticallyChecksForUpdates = false
            controller.updater.automaticallyDownloadsUpdates = false
            controller.startUpdater()
        }
        controller?.checkForUpdates(nil)
    }
    func feedURLString(for updater: SPUUpdater) -> String? { feed?.absoluteString }
    func allowedChannels(for updater: SPUUpdater) -> Set<String> { preview ? ["alpha"] : [] }
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        let callback = completion; completion = nil
        callback?(error?.localizedDescription)
    }
    func updater(_ updater: SPUUpdater, shouldPostponeRelaunchForUpdate item: SUAppcastItem, untilInvokingBlock installHandler: @escaping () -> Void) -> Bool {
        guard !canRelaunch() else { return false }
        postponedRelaunch = Task { @MainActor in
            while !canRelaunch() {
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            }
            installHandler()
        }
        return true
    }
}
