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

enum FileImportExportError: Error, Equatable {
    case fileNotFound(URL)
    case fileTooLarge(size: Int64, limit: Int64)
    case unreadableFile(URL)
    case unsupportedFormat(String)
    case serializationFailed(String)
    case deserializationFailed(String)
    case writeFailed(URL)
    case emptyFile(URL)
}

// MARK: - LocalizedError conformance (v2-A)

/// Adds localized user-facing messages on top of the plain Equatable
/// enum above. Kept as a separate extension rather than inlined into
/// the enum declaration so the case list (used for pattern matching
/// and equality in tests) stays visually decoupled from the
/// presentation-layer strings — a test asserting `.fileNotFound(url)`
/// doesn't need to know or care that this extension exists.
extension FileImportExportError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return String(
                format: NSLocalizedString("fileImportExport.error.file_not_found", comment: "Shown when the file to import does not exist"),
                url.lastPathComponent
            )
        case .fileTooLarge(let size, let limit):
            return String(
                format: NSLocalizedString("fileImportExport.error.file_too_large", comment: "Shown when the file to import exceeds the size limit"),
                size, limit
            )
        case .unreadableFile(let url):
            return String(
                format: NSLocalizedString("fileImportExport.error.unreadable_file", comment: "Shown when the file cannot be read due to permissions or I/O failure"),
                url.lastPathComponent
            )
        case .unsupportedFormat(let ext):
            return String(
                format: NSLocalizedString("fileImportExport.error.unsupported_format", comment: "Shown when the file extension is not supported"),
                ext
            )
        case .serializationFailed(let detail):
            return String(
                format: NSLocalizedString("fileImportExport.error.serialization_failed", comment: "Shown when a .clab file cannot be created/written"),
                detail
            )
        case .deserializationFailed(let detail):
            return String(
                format: NSLocalizedString("fileImportExport.error.deserialization_failed", comment: "Shown when a .clab file cannot be read/parsed"),
                detail
            )
        case .writeFailed(let url):
            return String(
                format: NSLocalizedString("fileImportExport.error.write_failed", comment: "Shown when writing to disk fails"),
                url.lastPathComponent
            )
        case .emptyFile(let url):
            return String(
                format: NSLocalizedString("fileImportExport.error.empty_file", comment: "Shown when the file to import is empty"),
                url.lastPathComponent
            )
        }
    }
}
