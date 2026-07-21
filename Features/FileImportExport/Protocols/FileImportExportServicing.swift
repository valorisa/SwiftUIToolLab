import Foundation

// MARK: - FileImportExportServicing

/// Protocol defining file import/export capabilities.
/// Views and ViewModels depend only on this abstraction.
protocol FileImportExportServicing {
    func importFile(from url: URL) throws -> Payload
    func exportPayload(_ payload: Payload, to url: URL, metadata: PayloadMetadata?) throws
    func importLabFile(from url: URL) throws -> LabPayloadFile
    func validateFile(at url: URL) -> Bool
}

// MARK: - FileImportExportError

enum FileImportExportError: LocalizedError, Equatable {
    case fileNotFound(URL)
    case fileTooLarge(size: Int64, limit: Int64)
    case unreadableFile(URL)
    case unsupportedFormat(String)
    case serializationFailed(String)
    case deserializationFailed(String)
    case writeFailed(URL)
    case emptyFile(URL)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .fileTooLarge(let size, let limit):
            return "File too large: \(size) bytes (limit: \(limit) bytes)"
        case .unreadableFile(let url):
            return "Cannot read file: \(url.lastPathComponent)"
        case .unsupportedFormat(let ext):
            return "Unsupported file format: .\(ext)"
        case .serializationFailed(let reason):
            return "Serialization failed: \(reason)"
        case .deserializationFailed(let reason):
            return "Deserialization failed: \(reason)"
        case .writeFailed(let url):
            return "Cannot write to: \(url.lastPathComponent)"
        case .emptyFile(let url):
            return "File is empty: \(url.lastPathComponent)"
        }
    }
}
