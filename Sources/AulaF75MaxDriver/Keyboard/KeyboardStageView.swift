import SwiftUI

/// The Aula F75 Max drawn in code, with its RGB under-glow animated live.
///
/// Drawing happens in one `Canvas` (fast, no view per key) inside a
/// `TimelineView` that redraws 20 times a second. Each key's glow colour
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
    /// Lighting effects are slow, smooth gradients, so 20 redraws a second
    /// looks the same as 30 and costs a third less work.
    private static let framesPerSecond: Double = 20
    /// Room around the keys for the case, in key units.
    private let padding = CGSize(width: 0.55, height: 0.5)

    var body: some View {
        // Four stacked layers. Only the two that change with the lighting
        // effect redraw every frame; the case and the caps (with their 80 text
        // legends, the most expensive part to draw) are drawn once.
        ZStack {
            Canvas { context, size in
                let geometry = StageGeometry(size: size, caseSize: caseSize, padding: padding)
                drawCase(in: &context, origin: geometry.origin, unit: geometry.unit)
            }
            animatedLayer { context, geometry, glow in
                drawUnderGlow(in: &context, glow: glow, unit: geometry.unit, toCanvas: geometry.toCanvas)
            }
            // Redrawn once a minute so the clock on the little screen stays right.
            TimelineView(.everyMinute) { _ in
                Canvas { context, size in
                    let geometry = StageGeometry(size: size, caseSize: caseSize, padding: padding)
                    drawCaps(in: &context, unit: geometry.unit, toCanvas: geometry.toCanvas)
                    drawScreen(in: &context, unit: geometry.unit, toCanvas: geometry.toCanvas)
                    drawKnob(in: &context, unit: geometry.unit, toCanvas: geometry.toCanvas)
                }
            }
            animatedLayer { context, geometry, glow in
                drawCapRims(in: &context, glow: glow, unit: geometry.unit, toCanvas: geometry.toCanvas)
                drawAccents(in: &context, glow: glow, unit: geometry.unit, toCanvas: geometry.toCanvas)
            }
        }
        .aspectRatio(caseSize.width / caseSize.height, contentMode: .fit)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .trackingWindowVisibility($isWindowVisible)
        .accessibilityElement()
        .accessibilityLabel(L10n.text("Aula F75 Max keyboard preview"))
    }

    private var isPaused: Bool {
        !isAnimating || reduceMotion || !isVisible || !isWindowVisible
    }

    /// A canvas that redraws with the lighting animation and is handed the
    /// current colour of every key.
    private func animatedLayer(
        _ draw: @escaping (inout GraphicsContext, StageGeometry, [String: Color]) -> Void
    ) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / Self.framesPerSecond, paused: isPaused)) { timeline in
            Canvas { context, size in
                let geometry = StageGeometry(size: size, caseSize: caseSize, padding: padding)
                draw(&context, geometry, glowColors(time: timeline.date.timeIntervalSinceReferenceDate))
            }
            // Render this layer off-screen on the GPU (Metal) instead of
            // rasterising it on the CPU every frame.
            .drawingGroup()
        }
    }

    private var caseSize: CGSize {
        CGSize(width: layout.size.width + padding.width * 2, height: layout.size.height + padding.height * 2)
    }

    // MARK: - Drawing

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
        // Each key's glow is a pre-blurred white image (made once, see
        // `GlowSprites`) tinted with the key's colour. Blurring the whole
        // keyboard again on every frame was the main CPU cost of this view.
        var resolvedByWidth: [CGFloat: GraphicsContext.ResolvedImage] = [:]
        let margin = GlowSprites.marginUnits * unit

        for key in layout.keys {
            let width = key.frame.width
            if resolvedByWidth[width] == nil, let sprite = GlowSprites.image(forKeyWidth: width) {
                resolvedByWidth[width] = context.resolve(Image(decorative: sprite, scale: 1).renderingMode(.template))
            }
            guard var image = resolvedByWidth[width] else { continue }
            image.shading = .color(glow[key.id, default: .clear])
            context.draw(image, in: toCanvas(key.frame).insetBy(dx: -margin, dy: -margin))
        }
    }

    private func drawCaps(in context: inout GraphicsContext, unit: CGFloat, toCanvas: (CGRect) -> CGRect) {
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

            if showLegends, !key.label.isEmpty {
                let legend = Text(key.label)
                    .font(.system(size: unit * 0.2, weight: .medium))
                    .foregroundColor(key.tone == .light ? Color(white: 0.25) : Color(white: 0.62))
                context.draw(legend, at: CGPoint(x: top.minX + unit * 0.08, y: top.maxY - unit * 0.06), anchor: .bottomLeading)
            }
        }
    }

    /// Faint coloured rim where the under-glow catches each cap's edge.
    /// Drawn in an animated layer on top of the static caps.
    private func drawCapRims(in context: inout GraphicsContext, glow: [String: Color], unit: CGFloat, toCanvas: (CGRect) -> CGRect) {
        for key in layout.keys {
            let cap = toCanvas(key.frame).insetBy(dx: unit * 0.075, dy: unit * 0.075)
            let capShape = Path(roundedRect: cap, cornerRadius: unit * 0.13, style: .continuous)
            context.stroke(capShape, with: .color(glow[key.id, default: .clear].opacity(0.45)), lineWidth: max(0.5, unit * 0.03))
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
                faceTop: KeyboardKeycapPalette.faceTop, faceBottom: KeyboardKeycapPalette.faceBottom,
                skirtTop: KeyboardKeycapPalette.skirtTop, skirtBottom: KeyboardKeycapPalette.skirtBottom
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

/// Where the keyboard sits inside a canvas of a given size: the scale of one
/// key unit in points, and how to turn key-unit rectangles into points.
struct StageGeometry {
    let unit: CGFloat
    let origin: CGPoint
    let padding: CGSize

    init(size: CGSize, caseSize: CGSize, padding: CGSize) {
        unit = min(size.width / caseSize.width, size.height / caseSize.height)
        origin = CGPoint(
            x: (size.width - caseSize.width * unit) / 2,
            y: (size.height - caseSize.height * unit) / 2
        )
        self.padding = padding
    }

    func toCanvas(_ rect: CGRect) -> CGRect {
        CGRect(
            x: origin.x + (rect.minX + padding.width) * unit,
            y: origin.y + (rect.minY + padding.height) * unit,
            width: rect.width * unit,
            height: rect.height * unit
        )
    }
}

/// Soft white glow shapes, pre-blurred once per key width and reused on every
/// frame. Drawing them tinted is much cheaper than blurring live.
@MainActor
enum GlowSprites {
    /// Extra room around the key for the glow to spread into, in key units.
    static let marginUnits: CGFloat = 0.45
    /// Resolution the sprites are rendered at. The view scales them to fit,
    /// and a blur has no fine detail, so a modest size is enough.
    private static let pixelsPerUnit: CGFloat = 48
    private static var cache: [CGFloat: CGImage] = [:]

    static func image(forKeyWidth widthUnits: CGFloat) -> CGImage? {
        if let cached = cache[widthUnits] {
            return cached
        }
        let image = render(widthUnits: widthUnits)
        cache[widthUnits] = image
        return image
    }

    private static func render(widthUnits: CGFloat) -> CGImage? {
        let width = Int(((widthUnits + marginUnits * 2) * pixelsPerUnit).rounded())
        let height = Int(((1 + marginUnits * 2) * pixelsPerUnit).rounded())
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Classic trick for a blurred shape: draw the shape off the canvas and
        // let only its blurred shadow fall onto the canvas.
        let inset = 0.02 * pixelsPerUnit
        let keyRect = CGRect(
            x: marginUnits * pixelsPerUnit + inset,
            y: marginUnits * pixelsPerUnit + inset,
            width: widthUnits * pixelsPerUnit - inset * 2,
            height: pixelsPerUnit - inset * 2
        )
        let offscreen = keyRect.offsetBy(dx: CGFloat(width), dy: 0)
        context.setShadow(
            offset: CGSize(width: -CGFloat(width), height: 0),
            blur: 0.22 * pixelsPerUnit * 2,
            color: CGColor(gray: 1, alpha: 1)
        )
        context.addPath(CGPath(roundedRect: offscreen, cornerWidth: 0.18 * pixelsPerUnit, cornerHeight: 0.18 * pixelsPerUnit, transform: nil))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fillPath()
        return context.makeImage()
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
