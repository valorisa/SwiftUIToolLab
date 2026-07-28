import SwiftUI

struct ImageTransformView: View {
    @StateObject private var viewModel = ImageTransformViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transformation d'image").font(.title2).fontWeight(.semibold)

            Button(action: { viewModel.importImage() }) {
                Label("Importer une image", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isImporting)

            Picker("Opération", selection: $viewModel.selectedOperationRawValue) {
                ForEach(ImageTransformViewModel.availableOperations, id: \.self) { rawValue in
                    Text(ImageOperation(rawValue: rawValue)?.displayName ?? rawValue).tag(rawValue)
                }
            }
            .pickerStyle(.menu)
            .disabled(!viewModel.hasImportedImage)

            Button(action: { viewModel.applyTransformation() }) {
                Label("Appliquer", systemImage: "wand.and.stars")
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.hasImportedImage)

            Button(action: { viewModel.exportImage() }) {
                Label("Exporter en PNG", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.hasTransformedImage || viewModel.isExporting)

            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage).font(.caption).foregroundStyle(.green)
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 420, minHeight: 320)
        .alert("Erreur", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Erreur inconnue")
        }
    }
}

#Preview {
    ImageTransformView()
}
