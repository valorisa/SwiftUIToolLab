import Foundation

final class ImageTransformService: ImageTransformServicing {

    func encodeRawImage(_ image: RawImage) throws -> Data {
        try JSONEncoder().encode(image)
    }

    func decodeRawImage(from data: Data) throws -> RawImage {
        try JSONDecoder().decode(RawImage.self, from: data)
    }

    // MARK: - ConfigurableTransformer

    func transform(_ input: Payload, configuration: ImageTransformConfiguration) throws -> Payload {
        guard case .image(let data) = input else {
            throw ImageTransformError.invalidPayloadType
        }
        let image = try decodeRawImage(from: data)
        let result = Self.apply(configuration.operation, to: image)
        return .image(try encodeRawImage(result))
    }

    func inverse(_ input: Payload, configuration: ImageTransformConfiguration) throws -> Payload {
        guard case .image(let data) = input else {
            throw ImageTransformError.invalidPayloadType
        }
        let image = try decodeRawImage(from: data)
        let result = Self.apply(Self.inverseOperation(of: configuration.operation), to: image)
        return .image(try encodeRawImage(result))
    }

    /// rotate90 <-> rotate270; rotate180/flipHorizontal/flipVertical/
    /// invertColors are each their own exact inverse.
    static func inverseOperation(of operation: ImageOperation) -> ImageOperation {
        switch operation {
        case .rotate90: return .rotate270
        case .rotate270: return .rotate90
        case .rotate180, .flipHorizontal, .flipVertical, .invertColors:
            return operation
        }
    }

    static func apply(_ operation: ImageOperation, to image: RawImage) -> RawImage {
        switch operation {
        case .rotate90: return rotate90(image)
        // rotate180/270 are deliberately COMPOSED from the single
        // rotate90 primitive rather than re-derived by hand -- once
        // rotate90 is proven correct (see its doc comment), composing
        // it 2x/3x is correct by construction, not by a second,
        // independently-fallible derivation.
        case .rotate180: return rotate90(rotate90(image))
        case .rotate270: return rotate90(rotate90(rotate90(image)))
        case .flipHorizontal: return flipHorizontal(image)
        case .flipVertical: return flipVertical(image)
        case .invertColors: return invertColors(image)
        }
    }

    // MARK: - Pixel operations

    /// 90-degree clockwise rotation. new[newRow][newCol] =
    /// old[H-1-newCol][newRow], with new dimensions (newWidth,
    /// newHeight) = (oldHeight, oldWidth). Verified by hand against
    /// the canonical 3x3 example
    ///   0 1 2        6 3 0
    ///   3 4 5   ->   7 4 1
    ///   6 7 8        8 5 2
    /// (see ImageTransformServiceTests.testRotate90ProducesHandVerifiedGrid).
    static func rotate90(_ image: RawImage) -> RawImage {
        let w = image.width, h = image.height, ch = image.channelsPerPixel
        let newWidth = h
        let newHeight = w
        var newPixels = [UInt8](repeating: 0, count: newWidth * newHeight * ch)
        for newRow in 0..<newHeight {
            for newCol in 0..<newWidth {
                let oldRow = h - 1 - newCol
                let oldCol = newRow
                let oldIndex = (oldRow * w + oldCol) * ch
                let newIndex = (newRow * newWidth + newCol) * ch
                for k in 0..<ch {
                    newPixels[newIndex + k] = image.pixels[oldIndex + k]
                }
            }
        }
        return unchecked(width: newWidth, height: newHeight, channelsPerPixel: ch, hasAlphaChannel: image.hasAlphaChannel, pixels: newPixels)
    }

    static func flipHorizontal(_ image: RawImage) -> RawImage {
        let w = image.width, h = image.height, ch = image.channelsPerPixel
        var newPixels = [UInt8](repeating: 0, count: w * h * ch)
        for row in 0..<h {
            for col in 0..<w {
                let oldCol = w - 1 - col
                let oldIndex = (row * w + oldCol) * ch
                let newIndex = (row * w + col) * ch
                for k in 0..<ch { newPixels[newIndex + k] = image.pixels[oldIndex + k] }
            }
        }
        return unchecked(width: w, height: h, channelsPerPixel: ch, hasAlphaChannel: image.hasAlphaChannel, pixels: newPixels)
    }

    static func flipVertical(_ image: RawImage) -> RawImage {
        let w = image.width, h = image.height, ch = image.channelsPerPixel
        var newPixels = [UInt8](repeating: 0, count: w * h * ch)
        for row in 0..<h {
            let oldRow = h - 1 - row
            for col in 0..<w {
                let oldIndex = (oldRow * w + col) * ch
                let newIndex = (row * w + col) * ch
                for k in 0..<ch { newPixels[newIndex + k] = image.pixels[oldIndex + k] }
            }
        }
        return unchecked(width: w, height: h, channelsPerPixel: ch, hasAlphaChannel: image.hasAlphaChannel, pixels: newPixels)
    }

    /// Inverts ONLY the color channels (255 - value). If
    /// hasAlphaChannel is true, the LAST channel of each pixel is left
    /// untouched -- inverting alpha would turn transparent regions
    /// opaque, a semantically wrong result even though the roundtrip
    /// would still be bit-exact either way.
    static func invertColors(_ image: RawImage) -> RawImage {
        let ch = image.channelsPerPixel
        let colorChannelCount = image.hasAlphaChannel ? ch - 1 : ch
        var newPixels = image.pixels
        var index = 0
        while index < newPixels.count {
            for k in 0..<colorChannelCount {
                newPixels[index + k] = 255 - newPixels[index + k]
            }
            index += ch
        }
        return unchecked(width: image.width, height: image.height, channelsPerPixel: ch, hasAlphaChannel: image.hasAlphaChannel, pixels: newPixels)
    }

    /// Force-try is safe here: every call site supplies a pixel array
    /// whose count was just computed to exactly match
    /// width*height*channels -- a mismatch would mean a bug in this
    /// file's arithmetic, not bad external input. RawImage's public
    /// throwing initializer remains the only validated entry point for
    /// externally-provided data (see decodeRawImage).
    private static func unchecked(width: Int, height: Int, channelsPerPixel: Int, hasAlphaChannel: Bool, pixels: [UInt8]) -> RawImage {
        try! RawImage(width: width, height: height, channelsPerPixel: channelsPerPixel, hasAlphaChannel: hasAlphaChannel, pixels: pixels)
    }
}
