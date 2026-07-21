import Foundation

// MARK: - FileImportExportService

final class FileImportExportService: FileImportExportServicing {

    static let maxFileSize: Int64 = 100 * 1024 * 1024

    private static let textExtensions: Set<String> = [
        "txt", "md", "json", "csv", "xml", "yaml", "yml",
        "swift", "py", "js", "ts", "html", "css", "log"
    ]

    private static let labExtensions: Set<String> = ["clab", "cryptolab"]

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func importFile(from url: URL) throws -> Payload {
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileImportExportError.fileNotFound(url)
        }

        let attrs = try? fileManager.attributesOfItem(atPath: url.path)
        let size = (attrs?[.size] as? Int64) ?? 0

        guard size > 0 else {
            throw FileImportExportError.emptyFile(url)
        }

        guard size <= Self.maxFileSize else {
            throw FileImportExportError.fileTooLarge(size: size, limit: Self.maxFileSize)
        }

        guard fileManager.isReadableFile(atPath: url.path) else {
            throw FileImportExportError.unreadableFile(url)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw FileImportExportError.unreadableFile(url)
        }

        let ext = url.pathExtension.lowercased()

        if Self.labExtensions.contains(ext) {
            return .data(data)
        }

        if Self.textExtensions.contains(ext) {
            if let text = String(data: data, encoding: .utf8) {
                return .text(text)
            }
            return .data(data)
        }

        return .data(data)
    }

    func exportPayload(_ payload: Payload, to url: URL, metadata: PayloadMetadata?) throws {
        let payloadData: Data

        switch payload {
        case .text(let string):
            guard let data = string.data(using: .utf8) else {
                throw FileImportExportError.serializationFailed("Cannot encode text as UTF-8")
            }
            payloadData = data
        case .data(let data):
            payloadData = data
        case .image(let data):
            payloadData = data
        case .unknown:
            throw FileImportExportError.serializationFailed("Cannot export unknown payload type")
        }

        let labFile = LabPayloadFile(version: 1, encryption: nil, payloadData: payloadData, metadata: metadata)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let fileData: Data
        do {
            fileData = try encoder.encode(labFile)
        } catch {
            throw FileImportExportError.serializationFailed(error.localizedDescription)
        }

        do {
            try fileData.write(to: url, options: .atomic)
        } catch {
            throw FileImportExportError.writeFailed(url)
        }
    }

    func importLabFile(from url: URL) throws -> LabPayloadFile {
        guard fileManager.fileExists(atPath: url.path) else {
            throw FileImportExportError.fileNotFound(url)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw FileImportExportError.unreadableFile(url)
        }

        guard !data.isEmpty else {
            throw FileImportExportError.emptyFile(url)
        }

        do {
            return try JSONDecoder().decode(LabPayloadFile.self, from: data)
        } catch {
            throw FileImportExportError.deserializationFailed(error.localizedDescription)
        }
    }

    func validateFile(at url: URL) -> Bool {
        guard fileManager.isReadableFile(atPath: url.path) else { return false }
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else { return false }
        return size > 0 && size <= Self.maxFileSize
    }
}
