import Foundation

/// Everything the keyboard needs to know to show one lighting look.
///
/// This one value type is shared by the live preview, saved profiles and the
/// view model, so "what the user picked", "what a profile stores" and "what
/// was last sent" can be compared with a plain `==`.
struct LightingSettings: Codable, Equatable, Sendable {
    /// Firmware effect id, 0...19 (see `WirelessAulaLabels.rgbModes`).
    var mode: Int
    /// 1 (dimmest) ... 5 (brightest).
    var brightness: Int
    /// 1 (slowest) ... 5 (fastest).
    var speed: Int
    /// 0 = right, 1 = down, 2 = left, 3 = up.
    var direction: Int
    /// true = rainbow colours, false = the single colour below.
    var colorful: Bool
    /// The single colour, sRGB 0...255 per channel.
    var red: Int
    var green: Int
    var blue: Int

    /// The colour packed as 0xRRGGBB, the format the keyboard command expects.
    var rgbInteger: Int {
        (red << 16) | (green << 8) | blue
    }
}

/// A colour with each channel in 0...1. Kept free of SwiftUI so the renderer
/// can be unit tested without a UI.
struct RGB: Equatable, Sendable {
    var r: Double
    var g: Double
    var b: Double

    static let black = RGB(r: 0, g: 0, b: 0)

    /// Perceived brightness (Rec. 709 weights).
    var luminance: Double {
        0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    func scaled(by factor: Double) -> RGB {
        RGB(r: r * factor, g: g * factor, b: b * factor).clamped()
    }

    func clamped() -> RGB {
        RGB(r: min(max(r, 0), 1), g: min(max(g, 0), 1), b: min(max(b, 0), 1))
    }
}
