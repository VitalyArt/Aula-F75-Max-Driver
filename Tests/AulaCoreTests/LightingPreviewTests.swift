import XCTest
@testable import AulaCore

final class LightingPreviewTests: XCTestCase {
    private func settings(mode: Int, brightness: Int = 5, direction: Int = 0, colorful: Bool = true) -> LightingSettings {
        .init(mode: mode, brightness: brightness, speed: 3, direction: direction,
              colorful: colorful, red: 80, green: 160, blue: 240)
    }

    func testAllEffectsProduceFiniteBoundedColors() {
        for mode in 0..<20 {
            for direction in 0..<4 {
                for time in [0.0, 0.5, 1.7, 12.0, 1000.0] {
                    for point in [CGPoint.zero, CGPoint(x: 0.5, y: 0.5), CGPoint(x: 1, y: 1)] {
                        let rgb = LightingEffectRenderer.color(for: settings(mode: mode, direction: direction), at: point, time: time)
                        for channel in [rgb.r, rgb.g, rgb.b] {
                            XCTAssertTrue(channel.isFinite && (0...1).contains(channel), "mode \(mode), time \(time)")
                        }
                    }
                }
            }
        }
    }

    func testOffAndSingleColorBrightness() {
        XCTAssertEqual(LightingEffectRenderer.color(for: settings(mode: 0), at: .zero, time: 5), .black)
        let rgb = LightingEffectRenderer.color(for: settings(mode: 1, brightness: 2, colorful: false), at: .zero, time: 5)
        XCTAssertEqual(rgb.r, 80.0 / 255 * 0.4, accuracy: 1e-9)
        XCTAssertEqual(rgb.g, 160.0 / 255 * 0.4, accuracy: 1e-9)
        XCTAssertEqual(rgb.b, 240.0 / 255 * 0.4, accuracy: 1e-9)
    }

    func testWaveDirectionAndTime() {
        let a = LightingEffectRenderer.color(for: settings(mode: 11), at: CGPoint(x: 0.25, y: 0.75), time: 1)
        let reversed = LightingEffectRenderer.color(for: settings(mode: 11, direction: 2), at: CGPoint(x: 0.75, y: 0.75), time: 1)
        XCTAssertEqual(a, reversed)
        XCTAssertNotEqual(a, LightingEffectRenderer.color(for: settings(mode: 11), at: CGPoint(x: 0.25, y: 0.75), time: 2))
    }

    func testSharedLayoutMatchesPhysicalKeyboard() {
        let layout = KeyboardLayout.f75Max
        XCTAssertEqual(layout.keys.count, 80)
        XCTAssertEqual(Set(layout.keys.map(\.id)).count, layout.keys.count)
        XCTAssertEqual(layout.keys.first { $0.id == "Space" }?.frame.width, 6.25)
        XCTAssertEqual(layout.screenFrame, CGRect(x: 13.95, y: 0.05, width: 1.1, height: 0.9))
        for key in layout.keys {
            XCTAssertGreaterThanOrEqual(key.frame.minX, 0)
            XCTAssertLessThanOrEqual(key.frame.maxX, layout.size.width)
            XCTAssertLessThanOrEqual(key.frame.maxY, layout.size.height)
        }
    }
}
