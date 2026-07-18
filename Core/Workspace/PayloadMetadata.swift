import Foundation

/// Metadata attached to a Payload (origin, size, timestamps).
struct PayloadMetadata {
    let sourceFileName: String?
    let byteSize: Int
    let createdAt: Date

    init(sourceFileName: String? = nil, byteSize: Int, createdAt: Date = Date()) {
        self.sourceFileName = sourceFileName
        self.byteSize = byteSize
        self.createdAt = createdAt
    }
}
