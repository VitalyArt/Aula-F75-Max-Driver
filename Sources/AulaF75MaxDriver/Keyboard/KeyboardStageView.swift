import SwiftUI

/// The Aula F75 Max drawn in code, with its RGB under-glow animated live.
///
/// Drawing happens in one `Canvas` (fast, no view per key) inside a
/// `TimelineView` that redraws about 30 times a second. Each key's glow colour
/// comes from `LightingEffectRenderer`, so the preview follows whatever
/// settings it is given — before anything is sent to the keyboard.
///
/// The animation pauses when the view is off screen, when `isAnimating` is
/// false, or when the user has turned on Reduce Motion.
struct KeyboardStageView: View {
    let settings: LightingSettings
    var screenImage: CGImage? = nil
    var isAnimating: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @State private var isWindowVisible = true

    private let layout = KeyboardLayout.f75Max
    /// Room around the keys for the case, in key units.
    private let padding = CGSize(width: 0.55, height: 0.5)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isAnimating || reduceMotion || !isVisible || !isWindowVisible)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                draw(in: &context, size: size, time: time)
            }
        }
        .aspectRatio(caseSize.width / caseSize.height, contentMode: .fit)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .trackingWindowVisibility($isWindowVisible)
        .accessibilityElement()
        .accessibilityLabel(L10n.text("Aula F75 Max keyboard preview"))
    }

    private var caseSize: CGSize {
        CGSize(width: layout.size.width + padding.width * 2, height: layout.size.height + padding.height * 2)
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let unit = min(size.width / caseSize.width, size.height / caseSize.height)
        let origin = CGPoint(
            x: (size.width - caseSize.width * unit) / 2,
            y: (size.height - caseSize.height * unit) / 2
        )
        /// Converts a rectangle in key units to points in the canvas.
        func toCanvas(_ rect: CGRect) -> CGRect {
            CGRect(
                x: origin.x + (rect.minX + padding.width) * unit,
                y: origin.y + (rect.minY + padding.height) * unit,
                width: rect.width * unit,
                height: rect.height * unit
            )
        }

        let glow = glowColors(time: time)
        drawCase(in: &context, origin: origin, unit: unit)
        drawUnderGlow(in: &context, glow: glow, unit: unit, toCanvas: toCanvas)
        drawCaps(in: &context, glow: glow, unit: unit, toCanvas: toCanvas)
        drawScreen(in: &context, unit: unit, toCanvas: toCanvas)
        drawKnob(in: &context, unit: unit, toCanvas: toCanvas)
        drawAccents(in: &context, glow: glow, unit: unit, toCanvas: toCanvas)
    }

    /// One colour per key id, from the effect renderer.
    private func glowColors(time: TimeInterval) -> [String: Color] {
        var colors: [String: Color] = [:]
        for key in layout.keys {
            let centre = CGPoint(
                x: key.frame.midX / layout.size.width,
                y: key.frame.midY / layout.size.height
            )
            let rgb = LightingEffectRenderer.color(for: settings, at: centre, time: time)
            colors[key.id] = Color(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b)
        }
        return colors
    }

    private func drawCase(in context: inout GraphicsContext, origin: CGPoint, unit: CGFloat) {
        let caseRect = CGRect(origin: origin, size: CGSize(width: caseSize.width * unit, height: caseSize.height * unit))
        let shape = Path(roundedRect: caseRect, cornerRadius: unit * 0.45, style: .continuous)

        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.6), radius: unit * 0.6, x: 0, y: unit * 0.35))
            layer.fill(shape, with: .linearGradient(
                Gradient(colors: [Color(white: 0.16), Color(white: 0.07)]),
                startPoint: caseRect.origin,
                endPoint: CGPoint(x: caseRect.minX, y: caseRect.maxY)
            ))
        }
        context.stroke(shape, with: .color(.white.opacity(0.12)), lineWidth: max(1, unit * 0.04))

        let plate = Path(
            roundedRect: caseRect.insetBy(dx: unit * 0.22, dy: unit * 0.22),
            cornerRadius: unit * 0.28,
            style: .continuous
        )
        context.fill(plate, with: .color(Color(white: 0.035)))
    }

    /// The RGB light: coloured shapes under each key, blurred so the colour
    /// bleeds onto the plate around the caps like the real keyboard.
    private func drawUnderGlow(in context: inout GraphicsContext, glow: [String: Color], unit: CGFloat, toCanvas: (CGRect) -> CGRect) {
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: unit * 0.22))
            for key in layout.keys {
                let rect = toCanvas(key.frame).insetBy(dx: unit * 0.02, dy: unit * 0.02)
                layer.fill(Path(roundedRect: rect, cornerRadius: unit * 0.18), with: .color(glow[key.id, default: .clear]))
            }
        }
    }

    private func drawCaps(in context: inout GraphicsContext, glow: [String: Color], unit: CGFloat, toCanvas: (CGRect) -> CGRect) {
        let showLegends = unit >= 24

        for key in layout.keys {
            let cell = toCanvas(key.frame)
            let cap = cell.insetBy(dx: unit * 0.075, dy: unit * 0.075)
            let palette = capPalette(for: key)
            let capShape = Path(roundedRect: cap, cornerRadius: unit * 0.13, style: .continuous)

            // Cap skirt, darker at the bottom like a sculpted keycap.
            context.fill(capShape, with: .linearGradient(
                Gradient(colors: [palette.skirtTop, palette.skirtBottom]),
                startPoint: CGPoint(x: cap.midX, y: cap.minY),
                endPoint: CGPoint(x: cap.midX, y: cap.maxY)
            ))

            // Top face, slightly smaller and lighter, offset upward.
            let top = CGRect(
                x: cap.minX + unit * 0.09,
                y: cap.minY + unit * 0.05,
                width: cap.width - unit * 0.18,
                height: cap.height - unit * 0.2
            )
            context.fill(
                Path(roundedRect: top, cornerRadius: unit * 0.1, style: .continuous),
                with: .linearGradient(
                    Gradient(colors: [palette.faceTop, palette.faceBottom]),
                    startPoint: CGPoint(x: top.midX, y: top.minY),
                    endPoint: CGPoint(x: top.midX, y: top.maxY)
                )
            )

            // Faint coloured rim where the under-glow catches the cap edge.
            context.stroke(capShape, with: .color(glow[key.id, default: .clear].opacity(0.45)), lineWidth: max(0.5, unit * 0.03))

            if showLegends, !key.label.isEmpty {
                let legend = Text(key.label)
                    .font(.system(size: unit * 0.2, weight: .medium))
                    .foregroundColor(key.tone == .light ? Color(white: 0.25) : glow[key.id, default: .white].opacity(0.85))
                context.draw(legend, at: CGPoint(x: top.minX + unit * 0.08, y: top.maxY - unit * 0.06), anchor: .bottomLeading)
            }
        }
    }

    private struct CapPalette {
        let faceTop: Color
        let faceBottom: Color
        let skirtTop: Color
        let skirtBottom: Color
    }

    /// Light grey caps on the upper rows fading to near-black at the bottom,
    /// matching the F75 Max's two-tone keycap set.
    private func capPalette(for key: KeyboardKey) -> CapPalette {
        if key.tone == .light {
            return CapPalette(
                faceTop: Color(white: 0.86), faceBottom: Color(white: 0.74),
                skirtTop: Color(white: 0.66), skirtBottom: Color(white: 0.5)
            )
        }
        // Dark caps get a little lighter on row 3 so the fade looks gradual.
        let lift = key.row == 3 ? 0.08 : 0.0
        return CapPalette(
            faceTop: Color(white: 0.24 + lift), faceBottom: Color(white: 0.17 + lift),
            skirtTop: Color(white: 0.13 + lift), skirtBottom: Color(white: 0.07 + lift)
        )
    }

    private func drawScreen(in context: inout GraphicsContext, unit: CGFloat, toCanvas: (CGRect) -> CGRect) {
        let bezel = toCanvas(layout.screenFrame)
        context.fill(Path(roundedRect: bezel, cornerRadius: unit * 0.08), with: .color(Color(white: 0.02)))
        context.stroke(Path(roundedRect: bezel, cornerRadius: unit * 0.08), with: .color(.white.opacity(0.15)), lineWidth: max(0.5, unit * 0.025))

        let display = bezel.insetBy(dx: unit * 0.06, dy: unit * 0.06)
        if let screenImage {
            var imageContext = context
            imageContext.clip(to: Path(roundedRect: display, cornerRadius: unit * 0.04))
            let image = Image(decorative: screenImage, scale: 1).interpolation(.none)
            imageContext.draw(image, in: display)
        } else {
            context.fill(
                Path(roundedRect: display, cornerRadius: unit * 0.04),
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.05, green: 0.08, blue: 0.16), Color(red: 0.02, green: 0.02, blue: 0.05)]),
                    startPoint: CGPoint(x: display.minX, y: display.minY),
                    endPoint: CGPoint(x: display.maxX, y: display.maxY)
                )
            )
            if unit >= 14 {
                let clock = Text(Date.now, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute())
                    .font(.system(size: unit * 0.24, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                context.draw(clock, at: CGPoint(x: display.midX, y: display.midY))
            }
        }
    }

    private func drawKnob(in context: inout GraphicsContext, unit: CGFloat, toCanvas: (CGRect) -> CGRect) {
        let centreRect = toCanvas(CGRect(origin: layout.knobCenter, size: .zero))
        let centre = centreRect.origin
        let radius = layout.knobRadius * unit
        let knob = Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))

        context.drawLayer { layer in
            layer.addFilter(.shadow(color: .black.opacity(0.7), radius: unit * 0.12, x: 0, y: unit * 0.06))
            layer.fill(knob, with: .radialGradient(
                Gradient(colors: [Color(white: 0.42), Color(white: 0.12)]),
                center: CGPoint(x: centre.x - radius * 0.35, y: centre.y - radius * 0.4),
                startRadius: 0,
                endRadius: radius * 1.4
            ))
        }

        // Knurled edge: short ticks around the rim.
        var ticks = Path()
        for index in 0..<36 {
            let angle = Double(index) / 36 * 2 * .pi
            let outer = CGPoint(x: centre.x + cos(angle) * radius * 0.97, y: centre.y + sin(angle) * radius * 0.97)
            let inner = CGPoint(x: centre.x + cos(angle) * radius * 0.84, y: centre.y + sin(angle) * radius * 0.84)
            ticks.move(to: inner)
            ticks.addLine(to: outer)
        }
        context.stroke(ticks, with: .color(.black.opacity(0.35)), lineWidth: max(0.5, unit * 0.015))
        context.stroke(knob, with: .color(.white.opacity(0.18)), lineWidth: max(0.5, unit * 0.02))
    }

    /// The light bar on the space bar and the status dot beside Caps Lock.
    private func drawAccents(in context: inout GraphicsContext, glow: [String: Color], unit: CGFloat, toCanvas: (CGRect) -> CGRect) {
        if let space = layout.keys.first(where: { $0.id == "Space" }) {
            let cell = toCanvas(space.frame)
            let bar = CGRect(x: cell.midX - unit * 0.45, y: cell.maxY - unit * 0.24, width: unit * 0.9, height: max(1, unit * 0.05))
            context.fill(Path(roundedRect: bar, cornerRadius: bar.height / 2), with: .color(glow["Space", default: .white].opacity(0.95)))
        }
        if let caps = layout.keys.first(where: { $0.id == "Caps" }) {
            let cell = toCanvas(caps.frame)
            let radius = unit * 0.06
            let dot = CGRect(x: cell.minX - unit * 0.3 - radius, y: cell.midY - radius, width: radius * 2, height: radius * 2)
            context.fill(Path(ellipseIn: dot), with: .color(glow["Caps", default: .blue]))
        }
    }
}

/// The dark "stage" backdrop the keyboard sits on: a deep rounded panel with a
/// soft spotlight, used on Home, Lighting and Screen.
struct StageBackdrop<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.16), Color(white: 0.05)],
                            center: .init(x: 0.5, y: 0.35),
                            startRadius: 10,
                            endRadius: 520
                        )
                    )
            }
            .environment(\.colorScheme, .dark)
    }
}
