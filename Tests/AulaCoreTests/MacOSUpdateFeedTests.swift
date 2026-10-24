import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import AulaCore

final class MacOSUpdateFeedTests: XCTestCase, @unchecked Sendable {
    private func release(_ tag: String = "v1.7.0-rc2", legacy: Bool = false) -> AppRelease {
        var assets = [AppRelease.Asset(name: "AulaF75MaxDriver-\(tag).dmg", browser_download_url: "https://github.com/\(AppRelease.repository)/releases/download/\(tag)/app.dmg")]
        if legacy { assets.append(.init(name: "AulaF75MaxDriver-\(tag).appcast.xml", browser_download_url: "https://github.com/\(AppRelease.repository)/releases/download/\(tag)/feed.appcast.xml")) }
        return AppRelease(tag_name: tag, html_url: "https://github.com/\(AppRelease.repository)/releases/tag/\(tag)", draft: false, prerelease: true, assets: assets)
    }
    func testPagesURLAndLegacyCompatibility() async throws {
        let candidate = release()
        XCTAssertEqual(candidate.pagesSparkleFeedURL?.absoluteString, "https://vitalyart.github.io/Aula-F75-Max-Driver/updates/macos/v1.7.0-rc2.xml")
        XCTAssertNil(release("../evil").pagesSparkleFeedURL)
        XCTAssertNil(release("v1.7.0+dev.sha").pagesSparkleFeedURL)
        let client = MacOSUpdateFeedClient { _ in XCTFail("Legacy feed should not require Pages"); throw URLError(.notConnectedToInternet) }
        let legacy = release(legacy: true)
        let feed = try await client.feed(for: legacy)
        XCTAssertEqual(feed, legacy.legacySparkleFeedURL)
    }
    func testPagesAvailabilityAndMissingOldRelease() async throws {
        for status in [200, 404] {
            let client = MacOSUpdateFeedClient { request in
                XCTAssertEqual(request.httpMethod, "HEAD")
                return (Data(), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
            }
            let candidate = release()
            let feed = try await client.feed(for: candidate)
            XCTAssertEqual(feed, status == 200 ? candidate.pagesSparkleFeedURL : nil)
        }
    }
    func testNetworkErrorsAndUnexpectedRedirectsAreNotMissingFeeds() async throws {
        let clients = [
            MacOSUpdateFeedClient { _ in throw URLError(.notConnectedToInternet) },
            MacOSUpdateFeedClient { request in (Data(), HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!) },
            MacOSUpdateFeedClient { _ in (Data(), HTTPURLResponse(url: URL(string: "https://example.com/feed.xml")!, statusCode: 200, httpVersion: nil, headerFields: nil)!) }
        ]
        for client in clients {
            do { _ = try await client.feed(for: release()); XCTFail("Must report the error") } catch {}
        }
    }
}
