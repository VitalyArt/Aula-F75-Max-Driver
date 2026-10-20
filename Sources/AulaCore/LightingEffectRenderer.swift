import Foundation

/// Approximates each firmware lighting effect so the app can preview it.
///
/// It is a pure function: the same settings, key position and time always give
/// the same colour. That makes it easy to test and lets every key of the
/// keyboard model be coloured independently, many times per second.
///
/// These are approximations of what the keyboard draws; the app cannot read the
/// firmware's real animation.
public enum LightingEffectRenderer {
    /// - Parameters:
    ///   - position: the key's centre, normalised to 0...1 across the keyboard
    ///     (x left→right, y top→bottom).
    ///   - time: seconds since any fixed starting point.
    public static func color(for settings: LightingSettings, at position: CGPoint, time: TimeInterval) -> RGB {
        let x = Double(position.x)
        let y = Double(position.y)
        let rate = 0.15 + Double(clamp(settings.speed, 1, 5)) * 0.15
        let brightness = Double(clamp(settings.brightness, 1, 5)) / 5.0
        // Distance travelled along the chosen direction, 0...1.
        let along = alongDirection(x: x, y: y, direction: settings.direction)
        let phase = time * rate

        let color: RGB
        switch settings.mode {
        case 0: // LED Off
            return .black
        case 1: // Static
            color = base(settings, hue: x * 0.85)
        case 2: // SingleOn: keys light up as if pressed, then fade
            color = base(settings, hue: x).scaled(by: pressFlash(x: x, y: y, time: time, rate: rate))
        case 3: // SingleOff: lit board, pressed keys go dark briefly
            color = base(settings, hue: x).scaled(by: 1 - pressFlash(x: x, y: y, time: time, rate: rate))
        case 4: // Glittering
            color = base(settings, hue: hash(x, y, floor(time * rate * 6))).scaled(by: sparkle(x: x, y: y, time: time, rate: rate))
        case 5: // Falling: streaks running down each column
            let streak = pow(fract(y - phase * 1.5 + hash(floor(x * 16), 0, 0)), 4)
            color = base(settings, hue: x).scaled(by: streak)
        case 6: // Colourful: a still rainbow across the board
            color = base(settings, hue: x)
        case 7: // Breath
            color = base(settings, hue: floor(phase * 0.5) * 0.17).scaled(by: breath(phase))
        case 8: // Spectrum: the whole board cycles through colours
            color = base(settings, hue: phase * 0.25)
        case 9: // Outward: rings moving out from the centre
            color = base(settings, hue: centreDistance(x, y) - phase).scaled(by: ring(centreDistance(x, y) * 2 - phase * 2))
        case 10: // Scrolling: a band of light moving along the direction
            color = base(settings, hue: along - phase).scaled(by: ring(along * 1.5 - phase * 1.5))
        case 11: // Rolling: a rainbow wave along the direction
            color = base(settings, hue: along - phase)
        case 12: // Rotating: colours sweep around the centre
            let angle = atan2(y - 0.5, x - 0.5) / (2 * .pi)
            color = base(settings, hue: angle + phase * 0.5)
        case 13: // Explode: periodic bursts from the centre
            let burst = fract(phase * 0.5)
            let distance = abs(centreDistance(x, y) - burst * 0.9)
            color = base(settings, hue: burst).scaled(by: max(0, 1 - distance * 8) * (1 - burst * 0.6))
        case 14: // Launch: streaks rising up each column
            let streak = pow(fract((1 - y) - phase * 1.5 + hash(floor(x * 16), 1, 0)), 4)
            color = base(settings, hue: x).scaled(by: streak)
        case 15: // Ripples: rings from a few moving drop points
            color = ripples(settings, x: x, y: y, phase: phase)
        case 16: // Flowing: a diagonal rainbow flow
            color = base(settings, hue: (along + (settings.direction % 2 == 0 ? y : x) * 0.5) * 0.7 - phase)
        case 17: // Pulsating: whole-board pulses, new colour each pulse
            color = base(settings, hue: floor(phase) * 0.23).scaled(by: pow(1 - fract(phase), 2))
        case 18: // Tilt: a gradient that rocks back and forth
            let tilt = sin(phase * 2 * .pi * 0.5) * 0.5
            color = base(settings, hue: along * 0.6 + y * tilt)
        case 19: // Shuttle: a bar sliding back and forth
            let position = 0.5 - 0.5 * cos(phase * .pi)
            color = base(settings, hue: position).scaled(by: max(0, 1 - abs(along - position) * 6))
        default: // Unknown effect: a slow rainbow so something sensible shows
            color = base(settings, hue: x - time * 0.1)
        }

        return color.scaled(by: brightness)
    }

    // MARK: - Building blocks

    /// The colour a key would have at full intensity: a rainbow hue when the
    /// effect is colourful, otherwise the user's single colour.
    private static func base(_ settings: LightingSettings, hue: Double) -> RGB {
        if settings.colorful {
            return hsv(hue: fract(hue), saturation: 1, value: 1)
        }
        return RGB(
            r: Double(clamp(settings.red, 0, 255)) / 255,
            g: Double(clamp(settings.green, 0, 255)) / 255,
            b: Double(clamp(settings.blue, 0, 255)) / 255
        )
    }

    private static func alongDirection(x: Double, y: Double, direction: Int) -> Double {
        switch direction {
        case 1: return y
        case 2: return 1 - x
        case 3: return 1 - y
        default: return x
        }
    }

    private static func breath(_ phase: Double) -> Double {
        0.5 - 0.5 * cos(phase * 2 * .pi * 0.5)
    }

    /// 1 on the crest of a repeating wave, falling to 0 between crests.
    private static func ring(_ value: Double) -> Double {
        pow(0.5 + 0.5 * cos(fract(value) * 2 * .pi), 3)
    }

    private static func centreDistance(_ x: Double, _ y: Double) -> Double {
        let dx = x - 0.5
        let dy = (y - 0.5) * 0.4 // the board is about 2.5x wider than tall
        return (dx * dx + dy * dy).squareRoot()
    }

    /// A key "pressed" at a random moment every cycle, glowing then fading.
    private static func pressFlash(x: Double, y: Double, time: TimeInterval, rate: Double) -> Double {
        let cycle = time * rate * 1.5 + hash(x, y, 7) * 8
        let age = fract(cycle)
        let pressedThisCycle = hash(x, y, floor(cycle)) > 0.82
        return pressedThisCycle ? pow(1 - age, 2) : 0
    }

    private static func sparkle(x: Double, y: Double, time: TimeInterval, rate: Double) -> Double {
        let cycle = time * rate * 3 + hash(x, y, 3) * 5
        let visible = hash(x, y, floor(cycle)) > 0.55
        return visible ? 1 - fract(cycle) * 0.7 : 0.08
    }

    private static func ripples(_ settings: LightingSettings, x: Double, y: Double, phase: Double) -> RGB {
        var intensity = 0.0
        var hue = 0.0
        for drop in 0..<3 {
            let cycle = phase * 0.6 + Double(drop) / 3
            let index = floor(cycle)
            let centreX = hash(index, Double(drop), 11)
            let centreY = hash(index, Double(drop), 13)
            let dx = x - centreX
            let dy = (y - centreY) * 0.4
            let distance = (dx * dx + dy * dy).squareRoot()
            let radius = fract(cycle) * 0.6
            let strength = max(0, 1 - abs(distance - radius) * 14) * (1 - fract(cycle))
            if strength > intensity {
                intensity = strength
                hue = hash(index, Double(drop), 17)
            }
        }
        return base(settings, hue: hue).scaled(by: intensity)
    }

    // MARK: - Maths helpers

    private static func fract(_ value: Double) -> Double {
        value - floor(value)
    }

    private static func clamp(_ value: Int, _ low: Int, _ high: Int) -> Int {
        min(max(value, low), high)
    }

    /// A repeatable pseudo-random number in 0..<1 for the given inputs.
    private static func hash(_ a: Double, _ b: Double, _ c: Double) -> Double {
        fract(sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453)
    }

    private static func hsv(hue: Double, saturation: Double, value: Double) -> RGB {
        let sector = hue * 6
        let index = Int(floor(sector)) % 6
        let f = sector - floor(sector)
        let p = value * (1 - saturation)
        let q = value * (1 - saturation * f)
        let t = value * (1 - saturation * (1 - f))
        switch index {
        case 0: return RGB(r: value, g: t, b: p)
        case 1: return RGB(r: q, g: value, b: p)
        case 2: return RGB(r: p, g: value, b: t)
        case 3: return RGB(r: p, g: q, b: value)
        case 4: return RGB(r: t, g: p, b: value)
        default: return RGB(r: value, g: p, b: q)
        }
    }
}
