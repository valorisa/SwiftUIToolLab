import SwiftUI
import AppKit

// MARK: - FileImportExportView

struct FileImportExportView: View {
    @StateObject private var viewModel = FileImportExportViewModel()

    var body: some View {
        VStack(spacing: 20) {
            headerSection
            importSection
            payloadPreviewSection
            exportSection
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 400)
        .alert("fileImportExport.error_alert_title", isPresented: $viewModel.showError) {
            Button("fileImportExport.ok_button", role: .cancel) {}
        } message: {
            Text(errorMessageText)
        }
    }

    private var headerSection: some View {
        Text("fileImportExport.title")
            .font(.title2)
            .fontWeight(.semibold)
    }

    private var importSection: some View {
        HStack(spacing: 16) {
            Button(action: { viewModel.importFile() }) {
                Label("fileImportExport.import_file_button", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isImporting)

            Button(action: { viewModel.importLabFile() }) {
                Label("fileImportExport.import_lab_button", systemImage: "doc.badge.gearshape")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isImporting)
        }
    }

    @ViewBuilder
    private var payloadPreviewSection: some View {
        if let info = viewModel.importedFileInfo {
            VStack(alignment: .leading, spacing: 8) {
                Divider()
                // Interpolated content: computed as a plain String below
                // (importedLabelText), so Text(_:) uses the verbatim
                // String overload rather than re-treating it as a
                // LocalizedStringKey — see importedLabelText doc.
                Text(importedLabelText(for: info))
                    .font(.headline)
                HStack {
                    // info.payloadType.rawValue ("text"/"binary"/"labFile")
                    // is an internal type identifier, not UI prose — left
                    // as-is, not localized (per brief risk list).
                    Label(info.payloadType.rawValue, systemImage: "doc")
                    Spacer()
                    Text(formattedSize(info.sizeInBytes))
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        } else {
            Text("fileImportExport.no_file_imported")
                .foregroundStyle(.secondary)
                .italic()
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            HStack {
                TextField("fileImportExport.filename_placeholder", text: $viewModel.exportOptions.fileName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                Text(".\(viewModel.exportOptions.fileExtension)")
                    .foregroundStyle(.secondary)

                Spacer()

                Toggle("fileImportExport.include_metadata_toggle", isOn: $viewModel.exportOptions.includeMetadata)
                    .toggleStyle(.checkbox)
            }

            Button("fileImportExport.export_button") { viewModel.exportPayload() }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isExporting)

            if let url = viewModel.lastExportURL {
                Text(exportedToText(for: url))
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Localized interpolated strings

    /// Text(String) uses the verbatim (non-localizing) overload, so it's
    /// safe to hand it an already-fully-resolved localized string built
    /// here via NSLocalizedString + String(format:) — same pattern used
    /// in FileImportExportViewModel for errorMessage.
    private func importedLabelText(for info: ImportedFileInfo) -> String {
        String(format: NSLocalizedString("fileImportExport.imported_file_label", comment: "Shows the name of the just-imported file"), info.fileName)
    }

    private func exportedToText(for url: URL) -> String {
        String(format: NSLocalizedString("fileImportExport.exported_to_label", comment: "Shows the file name just exported to"), url.lastPathComponent)
    }

    private var errorMessageText: String {
        viewModel.errorMessage ?? NSLocalizedString("fileImportExport.unknown_error_fallback", comment: "Fallback when no specific error message is available")
    }

    // MARK: - Helpers

    private func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    FileImportExportView()
}
