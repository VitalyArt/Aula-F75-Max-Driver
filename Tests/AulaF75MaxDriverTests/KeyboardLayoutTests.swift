import XCTest
@testable import AulaF75MaxDriver

final class KeyboardLayoutTests: XCTestCase {
    private let layout = KeyboardLayout.f75Max

    func testF75KeyCount() {
        // Rows from the reference photo: 13 + 15 + 15 + 14 + 14 + 9.
        XCTAssertEqual(layout.keys.count, 80)
    }

    func testKeyIDsAreUnique() {
        XCTAssertEqual(Set(layout.keys.map(\.id)).count, layout.keys.count)
    }

    func testNoKeysOverlap() {
        let frames = layout.keys.map(\.frame)
        for first in 0..<frames.count {
            for second in (first + 1)..<frames.count {
                let overlap = frames[first].intersection(frames[second])
                XCTAssertTrue(
                    overlap.isNull || overlap.width < 0.001 || overlap.height < 0.001,
                    "\(layout.keys[first].id) overlaps \(layout.keys[second].id)"
                )
            }
        }
    }

    func testScreenAndKnobRightOfF12() throws {
        let f12 = try XCTUnwrap(layout.keys.first { $0.id == "F12" })
        XCTAssertGreaterThan(layout.screenFrame.minX, f12.frame.maxX)
        XCTAssertGreaterThan(layout.knobCenter.x, layout.screenFrame.maxX)
    }

    func testEverythingFitsInsideTheLayoutSize() {
        let bounds = CGRect(origin: .zero, size: layout.size)
        for key in layout.keys {
            XCTAssertTrue(bounds.contains(key.frame), key.id)
        }
        XCTAssertTrue(bounds.contains(layout.screenFrame))
    }

    func testTopRowsAreLightAndBottomRowsDark() throws {
        let q = try XCTUnwrap(layout.keys.first { $0.id == "Q" })
        let z = try XCTUnwrap(layout.keys.first { $0.id == "Z" })
        XCTAssertEqual(q.tone, .light)
        XCTAssertEqual(z.tone, .dark)
    }
}
