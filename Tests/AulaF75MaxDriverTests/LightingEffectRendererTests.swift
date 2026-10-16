import CoreGraphics
import XCTest
@testable import AulaF75MaxDriver

final class LightingEffectRendererTests: XCTestCase {
    private func settings(
        mode: Int,
        brightness: Int = 5,
        direction: Int = 0,
        colorful: Bool = false,
        red: Int = 255,
        green: Int = 255,
        blue: Int = 255
    ) -> LightingSettings {
        LightingSettings(
            mode: mode,
            brightness: brightness,
            speed: 3,
            direction: direction,
            colorful: colorful,
            red: red,
            green: green,
            blue: blue
        )
    }

    func testLedOffIsBlack() {
        let color = LightingEffectRenderer.color(for: settings(mode: 0), at: CGPoint(x: 0.4, y: 0.6), time: 2.5)
        XCTAssertEqual(color, RGB(r: 0, g: 0, b: 0))
    }

    func testStaticUsesChosenColour() {
        let color = LightingEffectRenderer.color(
            for: settings(mode: 1, red: 255, green: 0, blue: 0),
            at: CGPoint(x: 0.5, y: 0.5),
            time: 0
        )
        XCTAssertEqual(color.r, 1, accuracy: 0.01)
        XCTAssertEqual(color.g, 0, accuracy: 0.01)
        XCTAssertEqual(color.b, 0, accuracy: 0.01)
    }

    func testBrightnessScales() {
        let point = CGPoint(x: 0.5, y: 0.5)
        let dim = LightingEffectRenderer.color(for: settings(mode: 1, brightness: 1), at: point, time: 0)
        let bright = LightingEffectRenderer.color(for: settings(mode: 1, brightness: 5), at: point, time: 0)
        XCTAssertLessThan(dim.luminance, bright.luminance)
        XCTAssertEqual(dim.luminance / bright.luminance, 0.2, accuracy: 0.01)
    }

    func testDeterministic() {
        let input = settings(mode: 4, colorful: true)
        let point = CGPoint(x: 0.21, y: 0.77)
        XCTAssertEqual(
            LightingEffectRenderer.color(for: input, at: point, time: 3.3),
            LightingEffectRenderer.color(for: input, at: point, time: 3.3)
        )
    }

    func testDirectionChangesPhase() {
        let point = CGPoint(x: 0.3, y: 0.5)
        let right = LightingEffectRenderer.color(for: settings(mode: 11, direction: 0, colorful: true), at: point, time: 1.0)
        let left = LightingEffectRenderer.color(for: settings(mode: 11, direction: 2, colorful: true), at: point, time: 1.0)
        XCTAssertNotEqual(right, left)
    }

    func testAllModesProduceValidColours() {
        for mode in 0...19 {
            for colorful in [true, false] {
                let color = LightingEffectRenderer.color(
                    for: settings(mode: mode, colorful: colorful, red: 30, green: 200, blue: 90),
                    at: CGPoint(x: 0.65, y: 0.35),
                    time: 4.2
                )
                for component in [color.r, color.g, color.b] {
                    XCTAssertGreaterThanOrEqual(component, 0, "mode \(mode)")
                    XCTAssertLessThanOrEqual(component, 1, "mode \(mode)")
                }
            }
        }
    }

    func testRGBIntegerPacksComponents() {
        XCTAssertEqual(settings(mode: 1, red: 0x12, green: 0x34, blue: 0x56).rgbInteger, 0x123456)
    }
}
