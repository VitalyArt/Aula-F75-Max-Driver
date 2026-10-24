import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import AulaCore

private actor UpdateHTTPFixture {
    struct Reply: Sendable { let status: Int; let headers: [String: String]; let body: String }
    var replies: [Reply] = []
    private(set) var requests: [URLRequest] = []
    func reset(_ replies: [Reply]) { self.replies = replies; requests = [] }
    func respond(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        guard !replies.isEmpty else { throw URLError(.notConnectedToInternet) }
        let reply = replies.removeFirst()
        return (Data(reply.body.utf8), HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: reply.headers)!)
    }
}

final class UpdateHTTPTests: XCTestCase, @unchecked Sendable {
    private func client(_ suite: String, _ fixture: UpdateHTTPFixture) -> GitHubUpdateClient {
        GitHubUpdateClient(suiteName: suite, transport: { try await fixture.respond($0) })
    }
    func testPaginationAndPersistent304Cache() async throws {
        let suite = "updates.tests.\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let fixture = UpdateHTTPFixture()
        let next = "https://api.github.com/repos/\(AppRelease.repository)/releases?page=2"
        await fixture.reset([
            .init(status: 200, headers: ["ETag": "first", "Link": "<\(next)>; rel=\"next\""], body: "[]"),
            .init(status: 200, headers: ["ETag": "second"], body: "[]")
        ])
        let first = try await client(suite, fixture).releases()
        XCTAssertTrue(first.isEmpty)
        let initialRequests = await fixture.requests
        XCTAssertEqual(initialRequests.count, 2)
        XCTAssertNotNil(UserDefaults(suiteName: suite)?.data(forKey: "updates.releases"))
        await fixture.reset([.init(status: 304, headers: [:], body: ""), .init(status: 304, headers: [:], body: "")])
        let cached = try await client(suite, fixture).releases()
        XCTAssertTrue(cached.isEmpty)
        let requests = await fixture.requests
        XCTAssertEqual(requests.map { $0.value(forHTTPHeaderField: "If-None-Match") }, ["first", "second"])
    }
    func testErrorsAndRateLimitBackoff() async throws {
        let suite = "updates.tests.\(UUID())"
        defer { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        let fixture = UpdateHTTPFixture()
        let api = client(suite, fixture)
        do { _ = try await api.releases(); XCTFail("Offline request must fail") } catch {}
        await fixture.reset([.init(status: 429, headers: ["Retry-After": "120"], body: "{}")])
        do { _ = try await api.releases(); XCTFail("Rate limit must fail") }
        catch let error as UpdateHTTPError { XCTAssertEqual(error.status, 429); XCTAssertNotNil(error.retryAt) }
        do { _ = try await api.releases(); XCTFail("Backoff must fail without another request") } catch {}
        let requests = await fixture.requests
        XCTAssertEqual(requests.count, 1)
    }
}
