import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension AppRelease {
    /// Fixed origin and strict tag syntax prevent release metadata from redirecting the updater.
    var pagesSparkleFeedURL: URL? {
        guard version != nil, !tag_name.contains("+"),
              Self.trustedURL(html_url) != nil, downloadURL(suffix: ".dmg") != nil else { return nil }
        return URL(string: "https://vitalyart.github.io/Aula-F75-Max-Driver/updates/macos/\(tag_name).xml")
    }

    var legacySparkleFeedURL: URL? {
        assets.first { $0.name.hasSuffix(".appcast.xml") && Self.trustedURL($0.browser_download_url, asset: true) != nil }
            .flatMap { Self.trustedURL($0.browser_download_url, asset: true) }
    }
}

/// Probe metadata availability, leaving signature verification and installation to Sparkle.
public actor MacOSUpdateFeedClient {
    private let transport: GitHubUpdateClient.Transport
    public init(transport: GitHubUpdateClient.Transport? = nil) {
        self.transport = transport ?? { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            return (data, response)
        }
    }

    public func feed(for release: AppRelease) async throws -> URL? {
        // Keep already-published releases usable without requiring a Pages migration.
        if let legacy = release.legacySparkleFeedURL { return legacy }
        guard let url = release.pagesSparkleFeedURL else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = "HEAD"
        let (_, response) = try await transport(request)
        try Task.checkCancellation()
        guard response.url == url else { throw URLError(.badServerResponse) }
        if response.statusCode == 404 { return nil }
        guard response.statusCode == 200 else { throw UpdateHTTPError(status: response.statusCode, retryAt: nil) }
        return url
    }
}
