import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import AulaF75MaxDriver

final class ScreenPreviewDecoderTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testRoundTripTwoFrameGif() throws {
        let url = try writeImage(
            named: "two.gif",
            type: .gif,
            frames: [(255, 0, 0, 0.1), (0, 0, 255, 0.2)]
        )
        let stream = try DisplayEncoder.encodeImage(at: url, fitMode: .stretch)
        let frames = ScreenPreviewDecoder.frames(from: stream)

        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0].duration, 0.1, accuracy: 0.002)
        XCTAssertEqual(frames[1].duration, 0.2, accuracy: 0.002)

        let first = try centrePixel(of: frames[0].image)
        XCTAssertGreaterThanOrEqual(first.r, 248)
        XCTAssertLessThanOrEqual(first.g, 4)
        XCTAssertLessThanOrEqual(first.b, 4)

        let second = try centrePixel(of: frames[1].image)
        XCTAssertGreaterThanOrEqual(second.b, 248)
        XCTAssertLessThanOrEqual(second.r, 4)
    }

    func testFrameCountMatchesStreamHeader() throws {
        let url = try writeImage(
            named: "three.gif",
            type: .gif,
            frames: [(10, 20, 30, 0.05), (40, 50, 60, 0.05), (70, 80, 90, 0.05)]
        )
        let stream = try DisplayEncoder.encodeImage(at: url, fitMode: .contain)
        let frames = ScreenPreviewDecoder.frames(from: stream)
        XCTAssertEqual(frames.count, stream.frameCount)
        XCTAssertEqual(frames.count, Int(stream.data[0]))
    }

    func testStaticPngGivesOneFrame() throws {
        let url = try writeImage(named: "one.png", type: .png, frames: [(0, 255, 0, 0)])
        let stream = try DisplayEncoder.encodeImage(at: url, fitMode: .cover)
        let frames = ScreenPreviewDecoder.frames(from: stream)
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0].image.width, 128)
        XCTAssertEqual(frames[0].image.height, 128)
    }

    // MARK: - Helpers

    /// Writes solid-colour frames (r, g, b, delay seconds) to an image file.
    private func writeImage(named name: String, type: UTType, frames: [(Int, Int, Int, Double)]) throws -> URL {
        let url = tempDirectory.appendingPathComponent(name)
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, frames.count, nil))
        for (red, green, blue, delay) in frames {
            let image = try solidImage(red: red, green: green, blue: blue)
            let properties: [CFString: Any] = [
                kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]
            ]
            CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    private func solidImage(red: Int, green: Int, blue: Int) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        return try XCTUnwrap(context.makeImage())
    }

    private func centrePixel(of image: CGImage) throws -> (r: Int, g: Int, b: Int) {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: -64, y: -64, width: 128, height: 128))
        return (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]))
    }
}

final class ScreenPreviewPlaybackTests: XCTestCase {
    func testFrameIndexFollowsDurationsAndLoops() {
        let durations: [TimeInterval] = [0.1, 0.2]
        XCTAssertEqual(ScreenPreviewPlayback.frameIndex(durations: durations, at: 0.05), 0)
        XCTAssertEqual(ScreenPreviewPlayback.frameIndex(durations: durations, at: 0.15), 1)
        XCTAssertEqual(ScreenPreviewPlayback.frameIndex(durations: durations, at: 0.35), 0)
    }

    func testEmptyAndZeroDurationsAreSafe() {
        XCTAssertEqual(ScreenPreviewPlayback.frameIndex(durations: [], at: 3), 0)
        XCTAssertEqual(ScreenPreviewPlayback.frameIndex(durations: [0, 0], at: 3), 0)
    }
}
