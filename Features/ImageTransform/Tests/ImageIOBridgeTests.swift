import XCTest
import CoreGraphics
import UniformTypeIdentifiers
@testable import SwiftUIToolLab

// MARK: - ImageIOBridgeTests

final class ImageIOBridgeTests: XCTestCase {

    // MARK: - Own PNG roundtrip: the bit-exact claim

    func testEncodePNGThenDecodeReturnsBitExactRawImage() throws {
        // Alpha values include 255, 0, and mid-range on purpose --
        // this is exactly the case that would silently break under
        // premultiplication if the "exact" fast path weren't actually
        // hit for our own PNG output.
        let original = try RawImage(
            width: 2, height: 2, channelsPerPixel: 4, hasAlphaChannel: true,
            pixels: [
                10, 20, 30, 255,
                40, 50, 60, 128,
                70, 80, 90, 0,
                100, 110, 120, 200
            ]
        )

        let pngData = try ImageIOBridge.encodePNG(original)
        let decoded = try ImageIOBridge.decodeRawImage(from: pngData)

        XCTAssertEqual(decoded, original, "Round-tripping through this bridge's own PNG encode/decode pair must be bit-exact -- the first real test of this claim, unverified until this CI run.")
    }

    func testEncodePNGRejectsImageWithoutAlphaChannel() throws {
        let image = try RawImage(width: 1, height: 1, channelsPerPixel: 3, hasAlphaChannel: false, pixels: [1, 2, 3])
        XCTAssertThrowsError(try ImageIOBridge.encodePNG(image)) { error in
            XCTAssertEqual(error as? ImageIOBridgeError, .unsupportedAlphaLayout)
        }
    }

    // MARK: - JPEG output: explicit rejection

    func testEncodeJPEGThrowsExplicitly() throws {
        let image = try RawImage(width: 1, height: 1, channelsPerPixel: 4, hasAlphaChannel: true, pixels: [1, 2, 3, 255])
        XCTAssertThrowsError(try ImageIOBridge.encodeJPEG(image)) { error in
            XCTAssertEqual(error as? ImageIOBridgeError, .jpegOutputNotSupported)
        }
    }

    // MARK: - JPEG input: well-formed, not claimed bit-exact

    func testDecodeJPEGProducesWellFormedRawImage_NotClaimedBitExact() throws {
        let original = try RawImage(
            width: 4, height: 3, channelsPerPixel: 4, hasAlphaChannel: true,
            pixels: (0..<48).map { UInt8(($0 * 5) % 256) }
        )
        let jpegData = try Self.makeJPEGDataForTesting(from: original)

        let decoded = try ImageIOBridge.decodeRawImage(from: jpegData)

        XCTAssertEqual(decoded.width, 4)
        XCTAssertEqual(decoded.height, 3)
        XCTAssertEqual(decoded.channelsPerPixel, 4)
        XCTAssertTrue(decoded.hasAlphaChannel)
        // Deliberately NOT asserting pixel equality: JPEG is lossy and
        // carries no alpha channel at all, so exact values are never
        // expected to match -- only structural well-formedness is
        // claimed for this input path.
    }

    func testDecodeMalformedDataThrows() {
        let garbage = Data([0x00, 0x01, 0x02, 0x03])
        XCTAssertThrowsError(try ImageIOBridge.decodeRawImage(from: garbage)) { error in
            XCTAssertEqual(error as? ImageIOBridgeError, .decodingFailed)
        }
    }

    // MARK: - Full pipeline: real PNG bytes -> ImageTransform -> real PNG bytes

    func testPipeline_DecodeTransformInverseEncodeRoundtrip() throws {
        let original = try RawImage(
            width: 3, height: 2, channelsPerPixel: 4, hasAlphaChannel: true,
            pixels: (0..<24).map { UInt8(($0 * 7) % 256) }
        )
        let pngData = try ImageIOBridge.encodePNG(original)
        let decoded = try ImageIOBridge.decodeRawImage(from: pngData)

        let transformService = ImageTransformService()
        let payload = Payload.image(try transformService.encodeRawImage(decoded))
        let config = ImageTransformConfiguration(operation: .rotate90)

        let transformed = try transformService.transform(payload, configuration: config)
        let inverted = try transformService.inverse(transformed, configuration: config)

        guard case .image(let invertedData) = inverted else {
            XCTFail("Expected .image payload")
            return
        }
        let finalImage = try transformService.decodeRawImage(from: invertedData)
        XCTAssertEqual(finalImage, decoded, "rotate90 then its declared inverse (rotate270) must restore the ImageIOBridge-decoded image bit-exact, closing the loop between real PNG I/O and ImageTransformService.")

        let finalPNG = try ImageIOBridge.encodePNG(finalImage)
        let reDecoded = try ImageIOBridge.decodeRawImage(from: finalPNG)
        XCTAssertEqual(reDecoded, original, "The full loop -- decode real PNG, transform, inverse, re-encode real PNG, decode again -- must land back on the original bytes.")
    }

    // MARK: - Test-only JPEG fixture generator

    /// Uses raw ImageIO/CGImageDestination DIRECTLY, deliberately
    /// bypassing ImageIOBridge.encodeJPEG (which always throws --
    /// see testEncodeJPEGThrowsExplicitly). This is test scaffolding to
    /// fabricate a JPEG blob for the decode-input test above; it is
    /// NOT evidence this feature's public API supports JPEG output.
    private static func makeJPEGDataForTesting(from image: RawImage) throws -> Data {
        let bytesPerRow = image.width * image.channelsPerPixel
        guard let provider = CGDataProvider(data: Data(image.pixels) as CFData) else {
            throw ImageIOBridgeError.cgImageCreationFailed
        }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
        guard let cgImage = CGImage(
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else {
            throw ImageIOBridgeError.cgImageCreationFailed
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ImageIOBridgeError.pngEncodingFailed
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageIOBridgeError.pngEncodingFailed
        }
        return data as Data
    }
}
