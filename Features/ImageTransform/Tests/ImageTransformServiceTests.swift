import XCTest
@testable import SwiftUIToolLab

// MARK: - ImageTransformServiceTests

final class ImageTransformServiceTests: XCTestCase {

    private var service: ImageTransformService!

    override func setUp() {
        super.setUp()
        service = ImageTransformService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    private func payload(for image: RawImage) throws -> Payload {
        .image(try service.encodeRawImage(image))
    }

    private func image(from payload: Payload) throws -> RawImage {
        guard case .image(let data) = payload else {
            XCTFail("Expected .image payload")
            throw ImageTransformError.invalidPayloadType
        }
        return try service.decodeRawImage(from: data)
    }

    // MARK: - Hand-verified rotate90 (3x3 grayscale, no alpha)

    func testRotate90ProducesHandVerifiedGrid() throws {
        let original = try RawImage(width: 3, height: 3, channelsPerPixel: 1, hasAlphaChannel: false, pixels: [0, 1, 2, 3, 4, 5, 6, 7, 8])
        let config = ImageTransformConfiguration(operation: .rotate90)

        let transformed = try service.transform(try payload(for: original), configuration: config)
        let result = try image(from: transformed)

        XCTAssertEqual(result.width, 3)
        XCTAssertEqual(result.height, 3)
        XCTAssertEqual(result.pixels, [6, 3, 0, 7, 4, 1, 8, 5, 2])
    }

    // MARK: - rotate90 swaps dimensions; rotate270 restores original

    func testRotate90SwapsDimensionsAndRotate270RestoresOriginal() throws {
        let original = try RawImage(width: 3, height: 2, channelsPerPixel: 1, hasAlphaChannel: false, pixels: [0, 1, 2, 3, 4, 5])
        let config = ImageTransformConfiguration(operation: .rotate90)

        let transformed = try service.transform(try payload(for: original), configuration: config)
        let transformedImage = try image(from: transformed)

        XCTAssertEqual(transformedImage.width, 2, "rotate90 must swap width/height: new width = old height")
        XCTAssertEqual(transformedImage.height, 3, "rotate90 must swap width/height: new height = old width")

        let inverted = try service.inverse(transformed, configuration: config)
        let invertedImage = try image(from: inverted)

        XCTAssertEqual(invertedImage, original, "rotate270 (the declared inverse of rotate90) must restore the exact original, dimensions included, bit-exact")
    }

    // MARK: - rotate180 is its own inverse

    func testRotate180IsOwnInverse() throws {
        let original = try RawImage(width: 3, height: 3, channelsPerPixel: 1, hasAlphaChannel: false, pixels: [0, 1, 2, 3, 4, 5, 6, 7, 8])
        let config = ImageTransformConfiguration(operation: .rotate180)

        let transformed = try service.transform(try payload(for: original), configuration: config)
        let transformedImage = try image(from: transformed)

        XCTAssertEqual(transformedImage.pixels, [8, 7, 6, 5, 4, 3, 2, 1, 0], "rotate180 must reverse the full pixel order for this asymmetric grid")
        XCTAssertNotEqual(transformedImage.pixels, original.pixels, "Sanity check: rotate180 must actually change an asymmetric image")

        let inverted = try service.inverse(transformed, configuration: config)
        let invertedImage = try image(from: inverted)
        XCTAssertEqual(invertedImage, original)
    }

    // MARK: - flipHorizontal / flipVertical are their own inverse

    func testFlipHorizontalIsOwnInverse() throws {
        let original = try RawImage(width: 3, height: 3, channelsPerPixel: 1, hasAlphaChannel: false, pixels: [0, 1, 2, 3, 4, 5, 6, 7, 8])
        let config = ImageTransformConfiguration(operation: .flipHorizontal)

        let transformed = try service.transform(try payload(for: original), configuration: config)
        let transformedImage = try image(from: transformed)
        XCTAssertEqual(transformedImage.pixels, [2, 1, 0, 5, 4, 3, 8, 7, 6])

        let inverted = try service.inverse(transformed, configuration: config)
        XCTAssertEqual(try image(from: inverted), original)
    }

    func testFlipVerticalIsOwnInverse() throws {
        let original = try RawImage(width: 3, height: 3, channelsPerPixel: 1, hasAlphaChannel: false, pixels: [0, 1, 2, 3, 4, 5, 6, 7, 8])
        let config = ImageTransformConfiguration(operation: .flipVertical)

        let transformed = try service.transform(try payload(for: original), configuration: config)
        let transformedImage = try image(from: transformed)
        XCTAssertEqual(transformedImage.pixels, [6, 7, 8, 3, 4, 5, 0, 1, 2])

        let inverted = try service.inverse(transformed, configuration: config)
        XCTAssertEqual(try image(from: inverted), original)
    }

    // MARK: - invertColors: RGB inverted exactly, alpha preserved exactly

    func testInvertColorsInvertsRGBExactlyAndPreservesAlpha() throws {
        // 1x2 RGBA image: two pixels, distinct RGBA values, alpha != 255
        // and != 0 so an accidental alpha inversion is unambiguously
        // detectable.
        let original = try RawImage(
            width: 2, height: 1, channelsPerPixel: 4, hasAlphaChannel: true,
            pixels: [10, 20, 30, 111, 200, 150, 5, 222]
        )
        let config = ImageTransformConfiguration(operation: .invertColors)

        let transformed = try service.transform(try payload(for: original), configuration: config)
        let result = try image(from: transformed)

        XCTAssertEqual(result.pixels, [245, 235, 225, 111, 55, 105, 250, 222], "RGB channels must be exactly 255-original; alpha (111, 222) must be untouched")

        let inverted = try service.inverse(transformed, configuration: config)
        let restored = try image(from: inverted)
        XCTAssertEqual(restored, original, "invertColors must be its own exact inverse")
    }

    // MARK: - Anti-no-op: composing two non-inverse operations must not equal the original

    func testComposingRotate90ThenFlipHorizontalDoesNotMatchOriginal() throws {
        let original = try RawImage(width: 3, height: 3, channelsPerPixel: 1, hasAlphaChannel: false, pixels: [0, 1, 2, 3, 4, 5, 6, 7, 8])

        let afterRotate = try service.transform(try payload(for: original), configuration: ImageTransformConfiguration(operation: .rotate90))
        let afterBoth = try service.transform(afterRotate, configuration: ImageTransformConfiguration(operation: .flipHorizontal))
        let result = try image(from: afterBoth)

        // Hand-verified: rotate90(original) = [6,3,0,7,4,1,8,5,2],
        // then flipHorizontal of THAT (reverse each row of a 3x3 grid)
        // = [0,3,6,1,4,7,2,5,8].
        XCTAssertEqual(result.pixels, [0, 3, 6, 1, 4, 7, 2, 5, 8])
        XCTAssertNotEqual(result.pixels, original.pixels, "Composing two non-inverse operations must not silently return the original -- this would be the signature of a no-op implementation.")

        let rotateOnlyResult = try image(from: afterRotate)
        XCTAssertNotEqual(result.pixels, rotateOnlyResult.pixels, "The composed result must also differ from either single step alone -- proves both steps actually executed, not just one.")
    }

    // MARK: - Payload type guard

    func testTransformRejectsNonImagePayload() {
        let config = ImageTransformConfiguration(operation: .rotate90)
        XCTAssertThrowsError(try service.transform(.text("not an image"), configuration: config)) { error in
            XCTAssertEqual(error as? ImageTransformError, .invalidPayloadType)
        }
    }

    // MARK: - RawImage validation

    func testRawImageRejectsPixelCountMismatch() {
        XCTAssertThrowsError(try RawImage(width: 2, height: 2, channelsPerPixel: 1, hasAlphaChannel: false, pixels: [1, 2, 3])) { error in
            XCTAssertEqual(error as? RawImage.RawImageError, .pixelCountMismatch(expected: 4, actual: 3))
        }
    }

    func testRawImageCodableRevalidatesOnDecode() {
        let tamperedJSON = """
        {"width":2,"height":2,"channelsPerPixel":1,"hasAlphaChannel":false,"pixels":[1,2,3]}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(RawImage.self, from: tamperedJSON))
    }

    // MARK: - Chantier 4: third tier of the SE-0309 same-type-constraint question

    /// Exercises THREE distinct ConfigurableTransformer conformances
    /// (MatrixAnalysisConfiguration, LinearEncoderConfiguration,
    /// ImageTransformConfiguration), each fixing the associatedtype via
    /// its own same-type constraint, coexisting in the same
    /// compilation unit. Confirmed (or not) only by this file's CI run
    /// actually compiling and passing -- the theory says it should
    /// generalize past the two-conformance case already confirmed in
    /// 🅱️, but per the established discipline, the CI decides, not the
    /// theory.
    func testTriplePolymorphicCoexistenceOfConfigurableTransformerConformances() throws {
        let operatorService = LinearOperatorService()
        let matrix = try Matrix(values: [[2, 0], [0, 2]])
        _ = try operatorService.transform(.text("1,1"), configuration: MatrixAnalysisConfiguration(matrix: matrix))

        let encoderService = LinearEncoderService()
        let encoderConfig = try encoderService.generateConfiguration(size: 4, seed: 99, operationCount: 10)
        _ = try encoderService.transform(.text("hi"), configuration: encoderConfig)

        let imageService = ImageTransformService()
        let image = try RawImage(width: 2, height: 2, channelsPerPixel: 1, hasAlphaChannel: false, pixels: [1, 2, 3, 4])
        let imagePayload = Payload.image(try imageService.encodeRawImage(image))
        _ = try imageService.transform(imagePayload, configuration: ImageTransformConfiguration(operation: .rotate180))
    }
}
