import Foundation

// MARK: - LabPayloadFile

struct LabPayloadFile: Codable, Equatable {
    let version: Int
    let encryption: EncryptionHeader?
    let payloadData: Data?
    let metadata: PayloadMetadata?
}

// MARK: - EncryptionHeader

struct EncryptionHeader: Codable, Equatable {
    let algorithm: String
    let iv: Data
    let tag: Data
    let salt: Data?
    let iterations: Int?
}
