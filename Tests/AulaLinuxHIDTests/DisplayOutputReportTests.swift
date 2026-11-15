import AulaCore
@testable import AulaLinuxHID
import XCTest

final class DisplayOutputReportTests: XCTestCase {
    func testDisplayReportsPreserveHeaderAndPixelsAfterRemovingReportID() {
        // Exercise both a nonzero GIF frame count and zero/nonzero pixel bytes
        // at subsequent block boundaries.
        var stream = (0..<(AulaConstants.chunkLength * 3)).map { UInt8($0 % 251) }
        stream[0] = 42
        stream[AulaConstants.chunkLength] = 0
        stream[AulaConstants.chunkLength * 2] = 0xff
        var received: [UInt8] = []
        for offset in stride(from: 0, to: stream.count, by: AulaConstants.chunkLength) {
            let payload = Array(stream[offset..<(offset + AulaConstants.chunkLength)])
            let report = LinuxHIDBackend.displayOutputReport(payload)
            XCTAssertEqual(report.count, AulaConstants.chunkLength + 1)
            XCTAssertEqual(report.first, 0)
            received.append(contentsOf: report.dropFirst())
        }
        XCTAssertEqual(received, stream)
    }
}
