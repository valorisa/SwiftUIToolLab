import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ImageIOBridgeError: Error, Equatable {
    case decodingFailed
    case unsupportedPixelFormat(bitsPerComponent: Int, bitsPerPixel: Int)
    case unsupportedAlphaLayout
    case jpegOutputNotSupported
    case pngEncodingFailed
    case cgImageCreationFailed
}

/// Bridges RawImage (this feature's in-memory pixel representation) to
/// and from real image files (PNG, JPEG-in). NOT a ConfigurableTransformer
/// conformance -- this is I/O, not a reversible data transform, so it
/// deliberately does NOT add a 4th same-type-constraint tier.
///
/// SCOPE, STATED PLAINLY: bit-exact roundtrip is claimed ONLY through
/// this bridge's OWN PNG encode/decode pair, and only via the "exact"
/// decode path below (8 bits/component, 32 bits/pixel, straight --
/// not premultiplied -- alpha as the last channel, matching RawImage's
/// own documented layout). Any input that doesn't match that exact
/// layout (typically a JPEG, which carries no alpha channel at all)
/// falls through to a "normalized" decode path that redraws through a
/// CGBitmapContext (premultiplied alpha -- the only alpha layout
/// CGContext creation reliably supports) -- well-formed, but NOT
/// claimed bit-exact, since premultiplication can round color values
/// wherever alpha < 255.
///
/// Whether real ImageIO round-trips our own PNG through the exact
/// path in practice (rather than silently normalizing it too) has not
/// been verified by running this code -- no compiler was available
/// while writing it. If CI disagrees, that surfaces as a loud,
/// explicit test failure here, not a silently wrong pixel.
enum ImageIOBridge {

    // MARK: - Encoding (RawImage -> file bytes)

    /// The ONLY supported output format. Requires a 4-channel RGBA
    /// RawImage (hasAlphaChannel == true) -- a bounded scope decision,
    /// not a general-purpose encoder: supporting a tight 3-channel RGB
    /// buffer would require CGImageAlphaInfo.none, which CGImage
    /// creation permits in principle but whose interaction with PNG
    /// encoding hasn't been established here; rejecting it explicitly
    /// (unsupportedAlphaLayout) is preferred over an unverified guess.
    static func encodePNG(_ image: RawImage) throws -> Data {
        guard image.hasAlphaChannel, image.channelsPerPixel == 4 else {
            throw ImageIOBridgeError.unsupportedAlphaLayout
        }

        let cgImage = try makeStraightAlphaCGImage(from: image)

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw ImageIOBridgeError.pngEncodingFailed
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageIOBridgeError.pngEncodingFailed
        }
        return data as Data
    }

    /// Deliberately unimplemented as a real encoder -- exists only to
    /// make the rejection explicit and testable. JPEG is lossy;
    /// silently producing it (or silently falling back to PNG under a
    /// JPEG label) would be exactly the kind of silent contournement
    /// this project's reversibility guarantee exists to rule out.
    static func encodeJPEG(_ image: RawImage) throws -> Data {
        throw ImageIOBridgeError.jpegOutputNotSupported
    }

    /// Straight (non-premultiplied) alpha, last channel -- matches
    /// RawImage's own documented layout exactly, so no pixel value is
    /// altered on the way into the CGImage. CGImage CREATION (unlike
    /// CGContext creation) permits this alpha layout.
    private static func makeStraightAlphaCGImage(from image: RawImage) throws -> CGImage {
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
        return cgImage
    }

    // MARK: - Decoding (file bytes -> RawImage)

    static func decodeRawImage(from data: Data) throws -> RawImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageIOBridgeError.decodingFailed
        }
        return try rawImage(from: cgImage)
    }

    static func decodeRawImage(fromFileAt url: URL) throws -> RawImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageIOBridgeError.decodingFailed
        }
        return try rawImage(from: cgImage)
    }

    private static func rawImage(from cgImage: CGImage) throws -> RawImage {
        if let exact = try? exactRawImage(from: cgImage) {
            return exact
        }
        return try normalizedRawImage(from: cgImage)
    }

    /// FAST PATH: succeeds only when the CGImage's raw buffer already
    /// matches RawImage's layout exactly -- guarantees no value is
    /// altered. This is the path our own PNG encode/decode pair is
    /// expected to hit, which is what makes the self-roundtrip
    /// bit-exact claim testable in the first place.
    private static func exactRawImage(from cgImage: CGImage) throws -> RawImage {
        guard cgImage.bitsPerComponent == 8, cgImage.bitsPerPixel == 32 else {
            throw ImageIOBridgeError.unsupportedPixelFormat(bitsPerComponent: cgImage.bitsPerComponent, bitsPerPixel: cgImage.bitsPerPixel)
        }
        guard let alphaInfo = CGImageAlphaInfo(rawValue: cgImage.bitmapInfo.rawValue & CGBitmapInfo.alphaInfoMask.rawValue),
              alphaInfo == .last else {
            throw ImageIOBridgeError.unsupportedAlphaLayout
        }
        let width = cgImage.width
        let height = cgImage.height
        let expectedBytesPerRow = width * 4
        guard cgImage.bytesPerRow == expectedBytesPerRow else {
            throw ImageIOBridgeError.unsupportedPixelFormat(bitsPerComponent: cgImage.bitsPerComponent, bitsPerPixel: cgImage.bitsPerPixel)
        }
        guard let dataProvider = cgImage.dataProvider, let cfData = dataProvider.data else {
            throw ImageIOBridgeError.decodingFailed
        }
        let byteCount = width * height * 4
        guard CFDataGetLength(cfData) >= byteCount, let pointer = CFDataGetBytePtr(cfData) else {
            throw ImageIOBridgeError.decodingFailed
        }
        let pixels = Array(UnsafeBufferPointer(start: pointer, count: byteCount))
        return try RawImage(width: width, height: height, channelsPerPixel: 4, hasAlphaChannel: true, pixels: pixels)
    }

    /// NORMALIZATION PATH: redraws through a fixed RGBA premultiplied
    /// context -- the only alpha layout CGBitmapContext creation
    /// reliably supports. Used for inputs that don't already match
    /// RawImage's exact layout (typically JPEG, which has no alpha
    /// channel at all -- CoreGraphics fills it with 255/opaque here).
    /// NOT claimed bit-exact: only well-formedness (correct width/
    /// height/channel count) is guaranteed.
    private static func normalizedRawImage(from cgImage: CGImage) throws -> RawImage {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        let byteCount = height * bytesPerRow

        let buffer = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: 1)
        defer { buffer.deallocate() }
        buffer.initializeMemory(as: UInt8.self, repeating: 0, count: byteCount)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ImageIOBridgeError.cgImageCreationFailed
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let typedBuffer = buffer.bindMemory(to: UInt8.self, capacity: byteCount)
        let pixels = Array(UnsafeBufferPointer(start: typedBuffer, count: byteCount))

        return try RawImage(width: width, height: height, channelsPerPixel: 4, hasAlphaChannel: true, pixels: pixels)
    }
}
