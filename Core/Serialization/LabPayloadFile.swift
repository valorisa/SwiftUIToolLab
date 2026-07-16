import Foundation

// MARK: - TODO
// Versioned JSON envelope written to disk as a single .cryptolab / .clab file.
// Bundles payload + encryption header + metadata so the user never manages
// keys, IVs, or metadata separately.

struct LabPayloadFile: Codable {
    let version: Int  // 1
    let encryption: EncryptionHeader?
    // MARK: - TODO: let payload: PayloadHeader
    // MARK: - TODO: let metadata: MetadataHeader
}

struct EncryptionHeader: Codable {
    let algorithm: String  // "AES-GCM-256" | "ChaChaPoly"
    let iv: Data
    let tag: Data
    let salt: Data?
    let iterations: Int?
}
