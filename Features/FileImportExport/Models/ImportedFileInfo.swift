import Foundation

// MARK: - ImportedFileInfo

struct ImportedFileInfo: Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let fileExtension: String
    let sizeInBytes: Int64
    let importedAt: Date
    let payloadType: PayloadType

    enum PayloadType: String, Equatable {
        case text
        case binary
        case labFile
    }
}

// MARK: - ExportOptions

struct ExportOptions: Equatable {
    var fileName: String = "export"
    var fileExtension: String = "clab"
    var includeMetadata: Bool = true
    var overwriteExisting: Bool = false
}
