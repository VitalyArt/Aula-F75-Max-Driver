import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ReleaseDownloadError: Error { case invalidAsset, invalidResponse, checksumMismatch, incompatiblePackage }

/// Stream data ourselves: FoundationNetworking download tasks can duplicate bytes
/// when a task delegate and the async download API are combined on Linux.
private final class ReleaseTransfer: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private let file: FileHandle
    private let expectedSize: Int64?
    private let progress: @Sendable (Double?) -> Void
    private var continuation: CheckedContinuation<Void, Error>?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var cancelled = false
    // The following fields are accessed only on the session's serial delegate queue.
    private var received: Int64 = 0
    private var responseSize: Int64 = -1
    private var failure: Error?
    private let limit: Int64 = 512 * 1024 * 1024

    init(destination: URL, expectedSize: Int64?, progress: @escaping @Sendable (Double?) -> Void) throws {
        guard FileManager.default.createFile(atPath: destination.path, contents: nil, attributes: [.posixPermissions: 0o600]) else { throw ReleaseDownloadError.invalidResponse }
        file = try FileHandle(forWritingTo: destination)
        self.expectedSize = expectedSize
        self.progress = progress
    }
    deinit { try? file.close() }
    func run(_ request: URLRequest) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                lock.lock()
                if cancelled {
                    lock.unlock(); continuation.resume(throwing: CancellationError()); return
                }
                self.continuation = continuation
                let session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
                self.session = session
                let task = session.dataTask(with: request)
                self.task = task
                lock.unlock()
                task.resume()
            }
        } onCancel: { self.cancel() }
    }
    private func cancel() {
        lock.lock(); cancelled = true; let task = task; lock.unlock()
        task?.cancel()
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        responseSize = response.expectedContentLength
        guard (response as? HTTPURLResponse)?.statusCode == 200, responseSize <= limit, (expectedSize ?? 0) <= limit else {
            failure = ReleaseDownloadError.invalidResponse
            completionHandler(.cancel); return
        }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard failure == nil else { return }
        received += Int64(data.count)
        guard received <= limit else { failure = ReleaseDownloadError.invalidResponse; dataTask.cancel(); return }
        do { try file.write(contentsOf: data) }
        catch { failure = error; dataTask.cancel(); return }
        let total = responseSize > 0 ? responseSize : expectedSize ?? -1
        progress(total > 0 ? min(1, Double(received) / Double(total)) : nil)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        var resultError = failure ?? error
        if resultError == nil && (received == 0 || (responseSize > 0 && received != responseSize) || (expectedSize != nil && received != expectedSize)) {
            resultError = ReleaseDownloadError.invalidResponse
        }
        do { try file.close() } catch { resultError = resultError ?? error }
        lock.lock()
        let continuation = continuation
        self.continuation = nil; self.task = nil; self.session = nil
        let cancelled = cancelled
        lock.unlock()
        session.finishTasksAndInvalidate()
        if cancelled { continuation?.resume(throwing: CancellationError()) }
        else if let error = resultError { continuation?.resume(throwing: error) }
        else { continuation?.resume() }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        let allowed = request.url.map { $0.scheme == "https" && ["github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com"].contains($0.host ?? "") } ?? false
        completionHandler(allowed ? request : nil)
    }
}

public enum ReleaseDownload {
    /// A private, unique directory prevents another local process from replacing the installer.
    public static func deb(release: AppRelease, suffix: String, progress: @escaping @Sendable (Double?) -> Void) async throws -> URL {
        guard let asset = release.assets.first(where: { $0.name.hasPrefix("AulaF75MaxDriver-v") && $0.name.hasSuffix(suffix) }),
              let url = AppRelease.trustedURL(asset.browser_download_url, asset: true),
              let digest = asset.digest, digest.hasPrefix("sha256:"), digest.count == 71 else { throw ReleaseDownloadError.invalidAsset }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("aula-update-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let destination = directory.appendingPathComponent("update.deb")
        do {
            let transfer = try ReleaseTransfer(destination: destination, expectedSize: asset.size, progress: progress)
            try await transfer.run(URLRequest(url: url, timeoutInterval: 60))
            try Task.checkCancellation()
            let size = (try FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? NSNumber)?.int64Value ?? 0
            guard size > 0, size <= 512 * 1024 * 1024, asset.size == nil || size == asset.size else { throw ReleaseDownloadError.invalidResponse }
            let checksum = try output("/usr/bin/sha256sum", [destination.path]).split(separator: " ").first.map(String.init)
            guard checksum?.lowercased() == String(digest.dropFirst(7)).lowercased() else { throw ReleaseDownloadError.checksumMismatch }
            let package = try output("/usr/bin/dpkg-deb", ["-f", destination.path, "Package"])
            let version = try output("/usr/bin/dpkg-deb", ["-f", destination.path, "Version"])
            let architecture = try output("/usr/bin/dpkg-deb", ["-f", destination.path, "Architecture"])
            let expectedVersion = release.tag_name.hasPrefix("v") ? String(release.tag_name.dropFirst()) : release.tag_name
            guard package == "aula-f75-max-driver", version == expectedVersion.replacingOccurrences(of: "-", with: "~"), suffix == "_\(architecture).deb" else { throw ReleaseDownloadError.incompatiblePackage }
            try Task.checkCancellation()
            return destination
        } catch { try? FileManager.default.removeItem(at: directory); throw error }
    }
    private static func output(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process(); let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ReleaseDownloadError.incompatiblePackage }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
