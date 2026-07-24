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
    private let workspace: Workspace
    private let openPanelFactory: () -> OpenPanelProviding
    private let savePanelFactory: () -> SavePanelProviding

    /// v2-C: panels are injected as factories rather than instantiated
    /// inline, closing v1's D5 debt. Defaults construct real panels
    /// via OpenPanelWrapper/SavePanelWrapper (wrappers needed because
    /// the Swift compiler cannot infer protocol conformance for ObjC
    /// classes via a trivial extension) — production behavior is
    /// unchanged; only tests substitute MockOpenPanel/MockSavePanel.
    init(
        service: FileImportExportServicing? = nil,
        workspace: Workspace? = nil,
        openPanelFactory: @escaping () -> OpenPanelProviding = { OpenPanelWrapper() },
        savePanelFactory: @escaping () -> SavePanelProviding = { SavePanelWrapper() }
    ) {
        self.service = service
            ?? ServiceLocator.shared.resolve(FileImportExportServicing.self)
            ?? FileImportExportService()
        self.workspace = workspace
            ?? ServiceLocator.shared.resolve(Workspace.self)
            ?? Workspace()
        self.openPanelFactory = openPanelFactory
        self.savePanelFactory = savePanelFactory
        loadFromWorkspaceIfAvailable()
    }

    // MARK: - Import

    func importFile() {
        isImporting = true
        defer { isImporting = false }

        var panel = openPanelFactory()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.title = NSLocalizedString("fileImportExport.import_file_panel_title", comment: "Title of the panel used to import a file")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let payload = try service.importFile(from: url)
            importedPayload = payload
            importedFileInfo = buildFileInfo(from: url, payload: payload)
            errorMessage = nil
            writeToWorkspace(payload, transformerName: "fileImportExport.import")
        } catch {
            presentError(error)
        }
    }

    func importLabFile() {
        isImporting = true
        defer { isImporting = false }

        var panel = openPanelFactory()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.title = NSLocalizedString("fileImportExport.import_lab_panel_title", comment: "Title of the panel used to import a .clab file")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let labFile = try service.importLabFile(from: url)
            let payload = Payload.data(labFile.payloadData ?? Data())
            importedPayload = payload
            errorMessage = nil
            writeToWorkspace(payload, transformerName: "fileImportExport.importLab")
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

        var panel = savePanelFactory()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(exportOptions.fileName).\(exportOptions.fileExtension)"
        panel.title = NSLocalizedString("fileImportExport.export_button", comment: "Title of the panel used to export a .clab file, shared with the export button label")

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

    // MARK: - Workspace sync

    private func loadFromWorkspaceIfAvailable() {
        guard let payload = workspace.currentPayload else { return }
        importedPayload = payload
    }

    private func writeToWorkspace(_ payload: Payload, transformerName: String) {
        do {
            try workspace.updatePayload(payload, transformerName: transformerName)
        } catch {
            errorMessage = NSLocalizedString("workspace.sync_locked_error", comment: "Shown when Workspace.updatePayload throws because isProcessing is true")
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
