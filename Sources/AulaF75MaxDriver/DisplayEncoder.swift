import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ScreenFitMode: String, CaseIterable, Identifiable {
    case contain
    case cover
    case stretch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .contain: return L10n.text("Fit")
        case .cover: return L10n.text("Fill")
        case .stretch: return L10n.text("Stretch")
        }
    }
}

struct EncodedDisplayStream {
    let data: Data
    let frameCount: Int
    let chunkCount: Int
}

enum DisplayEncoder {
    static func encodeImage(at url: URL, fitMode: ScreenFitMode) throws -> EncodedDisplayStream {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw AulaError.imageLoadFailed(url.lastPathComponent)
        }

        let sourceFrameCount = max(CGImageSourceGetCount(source), 1)
        let frameCount = min(sourceFrameCount, AulaConstants.maxFrames)
        let payloadLength = AulaConstants.headerLength + frameCount * AulaConstants.frameBytes
        let chunkCount = (payloadLength + AulaConstants.chunkLength - 1) / AulaConstants.chunkLength
        var stream = Data(repeating: 0, count: chunkCount * AulaConstants.chunkLength)

        stream[0] = UInt8(frameCount)
        for index in 0..<frameCount {
            stream[1 + index] = delayByte(source: source, index: index)
        }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw AulaError.imageLoadFailed("sRGB color space is unavailable")
        }

        let canvasBytesPerRow = AulaConstants.displayWidth * 4
        var canvas = [UInt8](
            repeating: 0,
            count: AulaConstants.displayHeight * canvasBytesPerRow
        )

        for frameIndex in 0..<frameCount {
            guard let image = CGImageSourceCreateImageAtIndex(source, frameIndex, nil) else {
                throw AulaError.imageLoadFailed("frame \(frameIndex + 1)")
            }

            canvas.withUnsafeMutableBytes { rawBuffer in
                guard let base = rawBuffer.baseAddress else { return }
                guard let context = CGContext(
                    data: base,
                    width: AulaConstants.displayWidth,
                    height: AulaConstants.displayHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: canvasBytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else {
                    return
                }

                context.interpolationQuality = .high
                context.setBlendMode(.copy)
                if frameIndex == 0 {
                    context.setFillColor(NSColor.black.cgColor)
                    context.fill(CGRect(x: 0, y: 0, width: AulaConstants.displayWidth, height: AulaConstants.displayHeight))
                }

                context.setBlendMode(.normal)
                context.draw(image, in: drawRect(for: image, fitMode: fitMode))
            }

            let streamOffset = AulaConstants.headerLength + frameIndex * AulaConstants.frameBytes
            encodeRGB565(canvas: canvas, into: &stream, at: streamOffset)
        }

        return EncodedDisplayStream(data: stream, frameCount: frameCount, chunkCount: chunkCount)
    }

    private static func delayByte(source: CGImageSource, index: Int) -> UInt8 {
        let fallback = 0.1
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else {
            return secondsToDeviceDelay(fallback)
        }

        let unclamped = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? NSNumber
        let clamped = gifProperties[kCGImagePropertyGIFDelayTime] as? NSNumber
        let seconds = unclamped?.doubleValue ?? clamped?.doubleValue ?? fallback
        return secondsToDeviceDelay(seconds)
    }

    private static func secondsToDeviceDelay(_ seconds: Double) -> UInt8 {
        let normalized = seconds <= 0 ? 0.01 : seconds
        let value = Int((normalized * 500.0).rounded())
        return UInt8(max(1, min(255, value)))
    }

    private static func drawRect(for image: CGImage, fitMode: ScreenFitMode) -> CGRect {
        let target = CGSize(width: AulaConstants.displayWidth, height: AulaConstants.displayHeight)
        let source = CGSize(width: image.width, height: image.height)

        switch fitMode {
        case .stretch:
            return CGRect(origin: .zero, size: target)
        case .contain, .cover:
            let scaleX = target.width / source.width
            let scaleY = target.height / source.height
            let scale = fitMode == .contain ? min(scaleX, scaleY) : max(scaleX, scaleY)
            let width = source.width * scale
            let height = source.height * scale
            return CGRect(
                x: (target.width - width) / 2.0,
                y: (target.height - height) / 2.0,
                width: width,
                height: height
            )
        }
    }

    private static func encodeRGB565(canvas: [UInt8], into stream: inout Data, at offset: Int) {
        for pixelIndex in 0..<(AulaConstants.displayWidth * AulaConstants.displayHeight) {
            let base = pixelIndex * 4
            let red = UInt16(canvas[base]) >> 3
            let green = UInt16(canvas[base + 1]) >> 2
            let blue = UInt16(canvas[base + 2]) >> 3
            let pixel = (red << 11) | (green << 5) | blue
            stream[offset + pixelIndex * 2] = UInt8(pixel & 0xff)
            stream[offset + pixelIndex * 2 + 1] = UInt8(pixel >> 8)
        }
    }
}
