import Foundation

/// A validated, self-describing image buffer. Pixels are stored
/// row-major (top-to-bottom, left-to-right), interleaved by channel
/// (e.g. R,G,B,A per pixel if channelsPerPixel == 4 and
/// hasAlphaChannel == true). The alpha channel, if present, is
/// assumed to be the LAST channel of each pixel.
///
/// Deliberately transported inside Payload.image(Data) as JSON-
/// encoded bytes, rather than adding a new Payload case — Payload
/// already has an .image(Data) case (confirmed by
/// FileImportExportService.swift's existing switch over Payload),
/// it simply never carried dimensions before. Adding a new Payload
/// case here would be exactly the premature Core generalization
/// v2-D's lesson warns against, when the existing case already
/// covers this need once given a self-describing payload.
struct RawImage: Equatable {
    let width: Int
    let height: Int
    let channelsPerPixel: Int
    let hasAlphaChannel: Bool
    let pixels: [UInt8]

    enum RawImageError: Error, Equatable {
        case invalidDimensions
        case pixelCountMismatch(expected: Int, actual: Int)
    }

    init(width: Int, height: Int, channelsPerPixel: Int, hasAlphaChannel: Bool, pixels: [UInt8]) throws {
        guard width > 0, height > 0, channelsPerPixel > 0 else {
            throw RawImageError.invalidDimensions
        }
        let expected = width * height * channelsPerPixel
        guard pixels.count == expected else {
            throw RawImageError.pixelCountMismatch(expected: expected, actual: pixels.count)
        }
        self.width = width
        self.height = height
        self.channelsPerPixel = channelsPerPixel
        self.hasAlphaChannel = hasAlphaChannel
        self.pixels = pixels
    }
}

// MARK: - Codable (manual, revalidates on decode — same pattern as Matrix)

extension RawImage: Codable {
    private enum CodingKeys: String, CodingKey {
        case width, height, channelsPerPixel, hasAlphaChannel, pixels
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let width = try container.decode(Int.self, forKey: .width)
        let height = try container.decode(Int.self, forKey: .height)
        let channelsPerPixel = try container.decode(Int.self, forKey: .channelsPerPixel)
        let hasAlphaChannel = try container.decode(Bool.self, forKey: .hasAlphaChannel)
        let pixels = try container.decode([UInt8].self, forKey: .pixels)
        try self.init(width: width, height: height, channelsPerPixel: channelsPerPixel, hasAlphaChannel: hasAlphaChannel, pixels: pixels)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(channelsPerPixel, forKey: .channelsPerPixel)
        try container.encode(hasAlphaChannel, forKey: .hasAlphaChannel)
        try container.encode(pixels, forKey: .pixels)
    }
}

// MARK: - ImageOperation

/// Only operations with a PROVABLE exact inverse, on integer pixel
/// data, no loss. No resize, no grayscale, no blur -- see
/// ImageTransformService for the proof of each inverse.
enum ImageOperation: String, Codable, Equatable {
    case rotate90
    case rotate180
    case rotate270
    case flipHorizontal
    case flipVertical
    case invertColors
}

// MARK: - ImageTransformConfiguration

/// The Configuration type ImageTransformServicing fixes
/// ConfigurableTransformer's associatedtype to -- the THIRD distinct
/// same-type constraint on ConfigurableTransformer in this
/// compilation unit (after MatrixAnalysisConfiguration in 🅰️ and
/// LinearEncoderConfiguration in 🅱️). No cross-field invariant to
/// protect here (unlike Matrix/LinearEncoderConfiguration), so the
/// synthesized Codable/Equatable conformances are used as-is rather
/// than a manual implementation.
struct ImageTransformConfiguration: Codable, Equatable {
    let operation: ImageOperation
}
