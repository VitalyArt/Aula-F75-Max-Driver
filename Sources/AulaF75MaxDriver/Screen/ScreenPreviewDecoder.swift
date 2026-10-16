import CoreGraphics
import Foundation

/// One frame of the keyboard-screen preview and how long it stays on screen.
/// `CGImage` is immutable, so sharing frames across threads is safe.
struct ScreenPreviewFrame: @unchecked Sendable {
    let image: CGImage
    let duration: TimeInterval
}

/// Turns the exact bytes the app uploads to the keyboard back into images.
///
/// Because the preview is decoded from the same `EncodedDisplayStream` that
/// gets sent, it shows precisely what the 128 × 128 display will show —
/// including the colour loss of the keyboard's 16-bit (RGB565) format.
///
/// Stream layout (see `DisplayEncoder`):
/// - byte 0: number of frames
/// - bytes 1...count: per-frame delay, in units of 1/500 s
/// - from `AulaConstants.headerLength`: frames of 128 × 128 pixels, each pixel
///   2 bytes, little-endian RGB565, rows from the top.
enum ScreenPreviewDecoder {
    static func frames(from stream: EncodedDisplayStream) -> [ScreenPreviewFrame] {
        let data = [UInt8](stream.data)
        guard !data.isEmpty else { return [] }

        let width = AulaConstants.displayWidth
        let height = AulaConstants.displayHeight
        let frameCount = Int(data[0])
        var frames: [ScreenPreviewFrame] = []
        frames.reserveCapacity(frameCount)

        for frameIndex in 0..<frameCount {
            let start = AulaConstants.headerLength + frameIndex * AulaConstants.frameBytes
            guard start + AulaConstants.frameBytes <= data.count else { break }

            var rgba = [UInt8](repeating: 255, count: width * height * 4)
            for pixelIndex in 0..<(width * height) {
                let low = UInt16(data[start + pixelIndex * 2])
                let high = UInt16(data[start + pixelIndex * 2 + 1])
                let pixel = (high << 8) | low

                let red5 = (pixel >> 11) & 0x1f
                let green6 = (pixel >> 5) & 0x3f
                let blue5 = pixel & 0x1f

                // Stretch 5- and 6-bit channels back to 8 bits so full
                // intensity stays 255 rather than 248.
                rgba[pixelIndex * 4] = UInt8((red5 << 3) | (red5 >> 2))
                rgba[pixelIndex * 4 + 1] = UInt8((green6 << 2) | (green6 >> 4))
                rgba[pixelIndex * 4 + 2] = UInt8((blue5 << 3) | (blue5 >> 2))
            }

            guard let image = makeImage(rgba: rgba, width: width, height: height) else { continue }
            let delayByte = 1 + frameIndex < data.count ? data[1 + frameIndex] : 1
            frames.append(ScreenPreviewFrame(image: image, duration: Double(delayByte) / 500.0))
        }

        return frames
    }

    private static func makeImage(rgba: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(rgba) as CFData) else {
            return nil
        }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
