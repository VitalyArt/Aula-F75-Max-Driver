import Foundation

/// Everything the keyboard needs to know to show one lighting look.
///
/// This one value type is shared by the live preview, saved profiles and the
/// view model, so "what the user picked", "what a profile stores" and "what
/// was last sent" can be compared with a plain `==`.
public struct LightingSettings: Codable, Equatable, Sendable {
    /// Firmware effect id, 0...19 (see `WirelessAulaLabels.rgbModes`).
    public var mode: Int
    /// 1 (dimmest) ... 5 (brightest).
    public var brightness: Int
    /// 1 (slowest) ... 5 (fastest).
    public var speed: Int
    /// 0 = right, 1 = down, 2 = left, 3 = up.
    public var direction: Int
    /// true = rainbow colours, false = the single colour below.
    public var colorful: Bool
    /// The single colour, sRGB 0...255 per channel.
    public var red: Int
    public var green: Int
    public var blue: Int

    public init(mode: Int, brightness: Int, speed: Int, direction: Int, colorful: Bool, red: Int, green: Int, blue: Int) {
        self.mode = mode; self.brightness = brightness; self.speed = speed
        self.direction = direction; self.colorful = colorful
        self.red = red; self.green = green; self.blue = blue
    }

    /// The colour packed as 0xRRGGBB, the format the keyboard command expects.
    public var rgbInteger: Int {
        (red << 16) | (green << 8) | blue
    }
}

/// A colour with each channel in 0...1. Kept free of SwiftUI so the renderer
/// can be unit tested without a UI.
public struct RGB: Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }

    public static let black = RGB(r: 0, g: 0, b: 0)

    /// Perceived brightness (Rec. 709 weights).
    public var luminance: Double {
        0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    public func scaled(by factor: Double) -> RGB {
        RGB(r: r * factor, g: g * factor, b: b * factor).clamped()
    }

    public func clamped() -> RGB {
        RGB(r: min(max(r, 0), 1), g: min(max(g, 0), 1), b: min(max(b, 0), 1))
    }
}
