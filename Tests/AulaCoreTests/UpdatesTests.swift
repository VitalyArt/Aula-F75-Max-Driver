import XCTest
@testable import AulaCore

final class UpdatesTests: XCTestCase, @unchecked Sendable {
    func testChannelDefaultsAndSchedule() {
        XCTAssertEqual(UpdateChannel.initial(version: "0.2.0-rc1", stored: nil), .alpha)
        XCTAssertEqual(UpdateChannel.initial(version: "0.2.0", stored: nil), .stable)
        XCTAssertEqual(UpdateChannel.initial(version: "0.2.0-rc1", stored: "stable"), .stable)
        let now = Date(timeIntervalSince1970: 200000)
        XCTAssertTrue(UpdateTiming.isDue(automatic: true, checking: false, lastSuccess: nil, lastAttempt: nil, now: now))
        XCTAssertTrue(UpdateTiming.isDue(automatic: true, checking: false, lastSuccess: now.addingTimeInterval(-86400), lastAttempt: now.addingTimeInterval(-3600), now: now))
        XCTAssertEqual(UpdateTiming.isDue(automatic: true, checking: false, lastSuccess: now.addingTimeInterval(-86399), lastAttempt: nil, now: now), false)
        XCTAssertEqual(UpdateTiming.isDue(automatic: false, checking: false, lastSuccess: nil, lastAttempt: nil, now: now), false)
        XCTAssertEqual(UpdateTiming.isDue(automatic: true, checking: true, lastSuccess: nil, lastAttempt: nil, now: now), false)
        XCTAssertEqual(UpdateTiming.isDue(automatic: true, checking: false, lastSuccess: nil, lastAttempt: now, now: now), false)
    }
    func testInstallerRejectsMissingDigestBeforeDownload() async throws {
        let release = AppRelease(tag_name: "v0.2.0", html_url: "https://github.com/\(AppRelease.repository)/releases/tag/v0.2.0", draft: false, prerelease: false,
                                 assets: [.init(name: "AulaF75MaxDriver-v0.2.0_arm64.deb", browser_download_url: "https://github.com/\(AppRelease.repository)/releases/download/v0.2.0/app.deb")])
        do {
            _ = try await ReleaseDownload.deb(release: release, suffix: "_arm64.deb") { _ in }
            XCTFail("Installing without a digest must be rejected")
        } catch ReleaseDownloadError.invalidAsset {}
    }
    func testVersionOrdering() {
        let ordered = ["v0.2.0-alpha.1", "0.2.0-alpha.2", "0.2.0-beta.1", "0.2.0-rc2", "0.2.0-rc10", "0.2.0", "0.3.0"]
        let versions = ordered.map { ReleaseVersion($0)! }
        XCTAssertEqual(versions.sorted(), versions)
        XCTAssertEqual(ReleaseVersion("0.2.0-rc1"), ReleaseVersion("v0.2.0-rc.1"))
        XCTAssertEqual(ReleaseVersion("0.2.0+dev.sha"), ReleaseVersion("0.2.0"))
        for value in ["garbage", "v1.2", "1.2.3-alpha", "1.2.3-rc-1", "1.2.3-unknown1"] { XCTAssertNil(ReleaseVersion(value)) }
    }
    func testSelectionAndAssets() throws {
        func release(_ tag: String, preview: Bool = false, draft: Bool = false, suffix: String = ".dmg") -> AppRelease {
            AppRelease(tag_name: tag, html_url: "https://github.com/\(AppRelease.repository)/releases/tag/\(tag)", draft: draft, prerelease: preview,
                       assets: [.init(name: "AulaF75MaxDriver-\(tag)\(suffix)", browser_download_url: "https://github.com/\(AppRelease.repository)/releases/download/\(tag)/app\(suffix)")])
        }
        let releases = [release("v0.2.0"), release("v0.3.0-rc1", preview: true), release("v9.0.0", draft: true), release("v8.0.0", suffix: ".apk")]
        XCTAssertEqual(AppRelease.newest(releases, current: "0.1.0", channel: .stable, suffix: ".dmg")?.tag_name, "v0.2.0")
        XCTAssertEqual(AppRelease.newest(releases, current: "0.1.0", channel: .alpha, suffix: ".dmg")?.tag_name, "v0.3.0-rc1")
        XCTAssertNil(AppRelease.newest(releases, current: "0.3.0-rc1", channel: .stable, suffix: ".dmg"))
        XCTAssertNil(AppRelease.newest(releases, current: "0.3.0-rc1", channel: .alpha, suffix: ".dmg"))
        XCTAssertEqual(AppRelease.newest(releases, current: "0.2.0-rc1", channel: .stable, suffix: ".dmg")?.tag_name, "v0.2.0")
        XCTAssertNil(AppRelease.newest([release("v1.0.0", suffix: "_arm64.deb")], current: "0.1.0", channel: .stable, suffix: "_amd64.deb"))
    }
    func testTrustedURLsAndPagination() {
        XCTAssertNil(AppRelease.trustedURL("https://github.com/evil/repo/releases/tag/v1.0.0"))
        XCTAssertNil(AppRelease.trustedURL("http://github.com/\(AppRelease.repository)/releases/tag/v1.0.0"))
        XCTAssertNil(AppRelease.trustedURL("https://github.com@evil.com/\(AppRelease.repository)/releases/tag/v1.0.0"))
        XCTAssertEqual(GitHubUpdateClient.nextPage("<https://api.github.com/page=2>; rel=\"next\", <https://api.github.com/page=4>; rel=\"last\""), "https://api.github.com/page=2")
        XCTAssertNil(GitHubUpdateClient.nextPage(nil))
    }
}
