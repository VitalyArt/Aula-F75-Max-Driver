import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct ReleaseVersion: Comparable, Sendable {
    public let numbers: [Int]
    public let stage: Int
    public let sequence: Int
    public init?(_ value: String) {
        let pattern = #"^v?([0-9]+)\.([0-9]+)\.([0-9]+)(?:-(alpha|beta|rc)\.?([0-9]+))?(?:\+[0-9A-Za-z.-]+)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)) else { return nil }
        func part(_ i: Int) -> String { Range(match.range(at: i), in: value).map { String(value[$0]) } ?? "" }
        guard let major = Int(part(1)), let minor = Int(part(2)), let patch = Int(part(3)) else { return nil }
        numbers = [major, minor, patch]
        stage = ["alpha": 0, "beta": 1, "rc": 2][part(4)] ?? 3
        guard part(5).isEmpty || Int(part(5)) != nil else { return nil }
        sequence = Int(part(5)) ?? 0
    }
    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.numbers + [lhs.stage, lhs.sequence]).lexicographicallyPrecedes(rhs.numbers + [rhs.stage, rhs.sequence])
    }
}

public enum UpdateChannel: String, Sendable, CaseIterable {
    case stable, alpha
    public static func initial(version: String, stored: String?) -> Self {
        stored.flatMap(Self.init(rawValue:)) ?? ((ReleaseVersion(version)?.stage ?? 3) < 3 ? .alpha : .stable)
    }
}

public enum UpdateTiming {
    public static func isDue(automatic: Bool, checking: Bool, lastSuccess: Date?, lastAttempt: Date?, now: Date = Date()) -> Bool {
        automatic && !checking && now.timeIntervalSince(lastSuccess ?? .distantPast) >= 86400
            && now.timeIntervalSince(lastAttempt ?? .distantPast) >= 3600
    }
}
public struct AppRelease: Codable, Sendable {
    public struct Asset: Codable, Sendable {
        public let name: String
        public var digest: String? = nil
        public var size: Int64? = nil
        public let browser_download_url: String
    }
    public let tag_name: String
    public let html_url: String
    public let draft: Bool
    public let prerelease: Bool
    public let assets: [Asset]
    public var version: ReleaseVersion? { ReleaseVersion(tag_name) }
    public static let repository = "VitalyArt/Aula-F75-Max-Driver"
    public static func trustedURL(_ value: String, asset: Bool = false) -> URL? {
        guard let url = URL(string: value), url.scheme == "https", url.host == "github.com",
              url.user == nil, url.password == nil, url.port == nil,
              url.path.hasPrefix("/\(repository)/releases/\(asset ? "download/" : "tag/")") else { return nil }
        return url
    }
    public func downloadURL(suffix: String) -> URL? {
        assets.first { $0.name.hasPrefix("AulaF75MaxDriver-v") && $0.name.hasSuffix(suffix) && Self.trustedURL($0.browser_download_url, asset: true) != nil }
            .flatMap { Self.trustedURL($0.browser_download_url, asset: true) }
    }
    public static func newest(_ releases: [Self], current: String, channel: UpdateChannel, suffix: String) -> Self? {
        guard let installed = ReleaseVersion(current) else { return nil }
        return releases.filter {
            guard !$0.draft, let version = $0.version, version > installed,
                  trustedURL($0.html_url) != nil, $0.downloadURL(suffix: suffix) != nil else { return false }
            return channel == .alpha || (!$0.prerelease && version.stage == 3)
        }.max { $0.version! < $1.version! }
    }
}

public struct UpdateHTTPError: LocalizedError, Sendable {
    public let status: Int
    public let retryAt: Date?
    public var errorDescription: String? { "GitHub HTTP \(status)" }
}

/// Persistent per-page cache retains Link alongside ETag, including on a 304 response.
public actor GitHubUpdateClient {
    private struct Page: Codable { let data: Data; let etag: String?; let next: String? }
    private let defaults: UserDefaults
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    private let transport: Transport
    public init(suiteName: String? = nil, session: URLSession? = nil, transport: Transport? = nil) {
        defaults = suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        self.transport = transport ?? { request in
            let (data, response) = try await (session ?? .shared).data(for: request)
            guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            return (data, response)
        }
    }
    public static func nextPage(_ link: String?) -> String? {
        link?.components(separatedBy: ",").first { $0.contains("rel=\"next\"") }
            .flatMap { $0.split(separator: ">").first }.map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "<", with: "") }
    }
    public func releases() async throws -> [AppRelease] {
        let retry = defaults.double(forKey: "updates.retryAt")
        if retry > Date().timeIntervalSince1970 { throw UpdateHTTPError(status: 429, retryAt: Date(timeIntervalSince1970: retry)) }
        var next: String? = "https://api.github.com/repos/\(AppRelease.repository)/releases?per_page=100"
        var visited = Set<String>()
        var result: [AppRelease] = []
        while let address = next {
            try Task.checkCancellation()
            guard visited.insert(address).inserted, let url = URL(string: address), url.scheme == "https", url.host == "api.github.com", url.path == "/repos/\(AppRelease.repository)/releases" else { throw URLError(.badServerResponse) }
            let key = "updates.page.\(address)"
            let cached = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Page.self, from: $0) }
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("AulaF75MaxDriver", forHTTPHeaderField: "User-Agent")
            request.setValue(cached?.etag, forHTTPHeaderField: "If-None-Match")
            let (data, response) = try await transport(request)
            try Task.checkCancellation()
            let page: Page
            if response.statusCode == 304, let cached { page = cached }
            else if response.statusCode == 200 {
                page = Page(data: data, etag: response.value(forHTTPHeaderField: "ETag"), next: Self.nextPage(response.value(forHTTPHeaderField: "Link")))
            } else {
                var retryAt: Date?
                if response.statusCode == 403 || response.statusCode == 429 {
                    let reset = Double(response.value(forHTTPHeaderField: "X-RateLimit-Reset") ?? "") ?? 0
                    let retryHeader = response.value(forHTTPHeaderField: "Retry-After") ?? ""
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)
                    formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
                    let seconds = Double(retryHeader) ?? formatter.date(from: retryHeader)?.timeIntervalSinceNow ?? 60
                    retryAt = Date(timeIntervalSince1970: max(reset, Date().timeIntervalSince1970 + seconds))
                    defaults.set(retryAt!.timeIntervalSince1970, forKey: "updates.retryAt")
                }
                throw UpdateHTTPError(status: response.statusCode, retryAt: retryAt)
            }
            result += try JSONDecoder().decode([AppRelease].self, from: page.data)
            defaults.set(try JSONEncoder().encode(page), forKey: key)
            next = page.next
        }
        defaults.set(try JSONEncoder().encode(result), forKey: "updates.releases")
        return result
    }
}
