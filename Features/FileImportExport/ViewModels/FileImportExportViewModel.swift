import Foundation
import SwiftUI
import AppKit

// MARK: - FileImportExportViewModel

@MainActor
final class FileImportExportViewModel: ObservableObject {

    @Published var importedPayload: Payload = .unknown
    @Published var importedFileInfo: ImportedFileInfo?
    @Published var exportOptions = ExportOptions()
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var isImporting: Bool = false
    @Published var isExporting: Bool = false
    @Published var lastExportURL: URL?

    private let service: FileImportExportServicing

    init(service: FileImportExportServicing? = nil) {
        self.service = service
            ?? ServiceLocator.shared.resolve(FileImportExportServicing.self)
            ?? FileImportExportService()
    }

    // MARK: - Import

    func importFile() {
        isImporting = true
        defer { isImporting = false }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Import a file"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let payload = try service.importFile(from: url)
            importedPayload = payload
            importedFileInfo = buildFileInfo(from: url, payload: payload)
            errorMessage = nil
        } catch {
            presentError(error)
        }
    }

    func importLabFile() {
        isImporting = true
        defer { isImporting = false }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Import a .clab file"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let labFile = try service.importLabFile(from: url)
            importedPayload = .data(labFile.payloadData ?? Data())
            errorMessage = nil
        } catch {
            presentError(error)
        }
    }

    // MARK: - Export

    func exportPayload() {
        guard case .unknown = importedPayload else {
            performExport(importedPayload)
            return
        }
        presentError(FileImportExportError.serializationFailed("No payload to export"))
    }

    private func performExport(_ payload: Payload) {
        isExporting = true
        defer { isExporting = false }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(exportOptions.fileName).\(exportOptions.fileExtension)"
        panel.title = "Export as .clab"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let metadata: PayloadMetadata? = exportOptions.includeMetadata
                ? PayloadMetadata(
                    createdAt: Date(),
                    sourceFileName: importedFileInfo?.fileName,
                    toolVersion: "1.0.0"
                )
                : nil

            try service.exportPayload(payload, to: url, metadata: metadata)
            lastExportURL = url
            errorMessage = nil
        } catch {
            presentError(error)
        }
    }

    // MARK: - Private

    private func buildFileInfo(from url: URL, payload: Payload) -> ImportedFileInfo {
        let ext = url.pathExtension.lowercased()
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0

        let payloadType: ImportedFileInfo.PayloadType
        if ["clab", "cryptolab"].contains(ext) {
            payloadType = .labFile
        } else if case .text = payload {
            payloadType = .text
        } else {
            payloadType = .binary
        }

        return ImportedFileInfo(
            id: UUID(),
            fileName: url.lastPathComponent,
            fileExtension: ext,
            sizeInBytes: size,
            importedAt: Date(),
            payloadType: payloadType
        )
    }

    private func presentError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
}
