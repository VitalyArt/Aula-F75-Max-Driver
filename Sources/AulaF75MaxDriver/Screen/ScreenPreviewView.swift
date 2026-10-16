import SwiftUI

/// Works out which frame of an animation is showing at a given moment.
/// Pure so it can be tested; frames loop forever like on the keyboard.
enum ScreenPreviewPlayback {
    static func frameIndex(durations: [TimeInterval], at time: TimeInterval) -> Int {
        let total = durations.reduce(0, +)
        guard total > 0 else { return 0 }

        var remaining = time.truncatingRemainder(dividingBy: total)
        for (index, duration) in durations.enumerated() {
            if remaining < duration {
                return index
            }
            remaining -= duration
        }
        return durations.count - 1
    }
}

/// The keyboard screen shown large and pixel-sharp: each of the 128 × 128
/// pixels is drawn as a crisp square with a faint grid between them, so the
/// user sees exactly what the tiny display will show.
struct ScreenPreviewView: View {
    let image: CGImage?
    var side: CGFloat = 288

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black)

            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: side, height: side)
                PixelGrid(pixels: AulaConstants.displayWidth)
                    .frame(width: side, height: side)
                    .allowsHitTesting(false)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 34, weight: .light))
                    Text(L10n.text("Drop a GIF or image here"))
                        .font(.callout)
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(width: side + 16, height: side + 16)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(white: 0.25), lineWidth: 6)
        )
        .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
        .accessibilityElement()
        .accessibilityLabel(L10n.text("Keyboard screen preview"))
    }
}

/// Thin dark lines between display pixels, like looking closely at an LCD.
private struct PixelGrid: View {
    let pixels: Int

    var body: some View {
        Canvas { context, size in
            let step = size.width / CGFloat(pixels)
            guard step >= 2 else { return }
            var path = Path()
            for index in 1..<pixels {
                let offset = CGFloat(index) * step
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset, y: size.height))
                path.move(to: CGPoint(x: 0, y: offset))
                path.addLine(to: CGPoint(x: size.width, y: offset))
            }
            context.stroke(path, with: .color(.black.opacity(0.28)), lineWidth: 0.5)
        }
    }
}

/// A row of small frame thumbnails under the preview, highlighting the
/// frame that is showing now.
struct ScreenFrameStrip: View {
    let frames: [ScreenPreviewFrame]
    let currentIndex: Int

    private let maxThumbnails = 14

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(sampledIndices.enumerated()), id: \.offset) { _, index in
                Image(decorative: frames[index].image, scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(index == currentIndex ? Color.accentColor : .white.opacity(0.12), lineWidth: index == currentIndex ? 2 : 1)
                    )
            }
            Text(L10n.format("%d frames", frames.count))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.leading, 6)
        }
    }

    /// Evenly spread frame numbers when there are more frames than fit.
    private var sampledIndices: [Int] {
        guard frames.count > maxThumbnails else { return Array(frames.indices) }
        return (0..<maxThumbnails).map { $0 * (frames.count - 1) / (maxThumbnails - 1) }
    }
}
