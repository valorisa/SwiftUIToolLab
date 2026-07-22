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

    init(
        service: FileImportExportServicing? = nil,
        workspace: Workspace? = nil
    ) {
        self.service = service
            ?? ServiceLocator.shared.resolve(FileImportExportServicing.self)
            ?? FileImportExportService()
        self.workspace = workspace
            ?? ServiceLocator.shared.resolve(Workspace.self)
            ?? Workspace()
        loadFromWorkspaceIfAvailable()
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
            writeToWorkspace(payload, transformerName: "fileImportExport.import")
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
            let payload = Payload.data(labFile.payloadData ?? Data())
            importedPayload = payload
            errorMessage = nil
            writeToWorkspace(payload, transformerName: "fileImportExport.importLab")
        } catch {
            presentError(error)
        }
    }

    // MARK: - Export

    /// Exports the most relevant payload: the shared Workspace first
    /// (carries the latest state of the cross-tab flow — e.g. a file
    /// imported here, then Base64-encoded, then encrypted in other
    /// tabs), falling back to the locally imported payload if the
    /// Workspace is empty. This is the level-1 cross-feature flow
    /// (D2 = (b)): no Pipeline, the Workspace is the shared clipboard.
    /// Reading the Workspace at call time (not just at VM init) is
    /// essential: the VM is a long-lived @StateObject, so a payload
    /// produced in another tab AFTER this VM was created would
    /// otherwise be invisible to export.
    func exportPayload() {
        if let workspacePayload = workspace.currentPayload {
            performExport(workspacePayload)
            return
        }
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

    // MARK: - Workspace sync

    /// Reads Workspace.currentPayload once at VM creation, so a
    /// payload produced in another tab (Base64 encode, Crypto
    /// encrypt) is available for export here. importedFileInfo stays
    /// nil in that case (the Workspace carries no file metadata) —
    /// acceptable: the UI shows "No file imported yet" for file
    /// info, but the payload is exportable.
    private func loadFromWorkspaceIfAvailable() {
        guard let payload = workspace.currentPayload else { return }
        importedPayload = payload
    }

    /// Writes a freshly imported payload back into the shared
    /// Workspace so other tabs can pick it up. isProcessing is never
    /// toggled anywhere in the app (Phase 6b scope), so writeLocked is
    /// unreachable today — handled defensively rather than silently
    /// ignored via try?.
    private func writeToWorkspace(_ payload: Payload, transformerName: String) {
        do {
            try workspace.updatePayload(payload, transformerName: transformerName)
        } catch {
            errorMessage = "Impossible de synchroniser avec le Workspace (verrouillé)."
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
