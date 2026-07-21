import Foundation

// MARK: - PayloadMetadata

struct PayloadMetadata: Codable, Equatable {
    let createdAt: Date
    let sourceFileName: String?
    let toolVersion: String
}
