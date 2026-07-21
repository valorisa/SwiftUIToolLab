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
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }

    private var headerSection: some View {
        Text("File Import / Export")
            .font(.title2)
            .fontWeight(.semibold)
    }

    private var importSection: some View {
        HStack(spacing: 16) {
            Button(action: { viewModel.importFile() }) {
                Label("Import File", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isImporting)

            Button(action: { viewModel.importLabFile() }) {
                Label("Import .clab", systemImage: "doc.badge.gearshape")
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
                Text("Imported: \(info.fileName)")
                    .font(.headline)
                HStack {
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
            Text("No file imported yet.")
                .foregroundStyle(.secondary)
                .italic()
        }
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            HStack {
                TextField("File name", text: $viewModel.exportOptions.fileName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                Text(".\(viewModel.exportOptions.fileExtension)")
                    .foregroundStyle(.secondary)

                Spacer()

                Toggle("Include metadata", isOn: $viewModel.exportOptions.includeMetadata)
                    .toggleStyle(.checkbox)
            }

            Button(action: { viewModel.exportPayload() }) {
                Label("Export as .clab", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isExporting)

            if let url = viewModel.lastExportURL {
                Text("Exported to: \(url.lastPathComponent)")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }

    private func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    FileImportExportView()
}
