import Foundation

/// Purely synchronous — no Vision involved, so the async-isolation
/// question (relevant to SheetReader) does not apply here.
protocol ImageTransformServicing: ConfigurableTransformer where Configuration == ImageTransformConfiguration {
    func encodeRawImage(_ image: RawImage) throws -> Data
    func decodeRawImage(from data: Data) throws -> RawImage
}

enum ImageTransformError: Error, Equatable {
    case invalidPayloadType
}
