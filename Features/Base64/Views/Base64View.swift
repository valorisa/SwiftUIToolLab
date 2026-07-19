import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct Base64View: View {
    @StateObject private var viewModel = Base64ViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Base64").font(.title2).bold()

            Text("Entrée")
            TextEditor(text: $viewModel.inputText)
                .frame(minHeight: 100)
                .border(Color.gray.opacity(0.3))

            HStack {
                Button("Encoder") { viewModel.encode() }
                Button("Décoder") { viewModel.decode() }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }

            Text("Sortie")
            TextEditor(text: .constant(viewModel.outputText))
                .frame(minHeight: 100)
                .border(Color.gray.opacity(0.3))
                .disabled(true)

            Button("Copier dans le presse-papiers") {
                #if canImport(AppKit)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(viewModel.outputText, forType: .string)
                #endif
            }
            .disabled(viewModel.outputText.isEmpty)
        }
        .padding()
    }
}

#Preview {
    Base64View()
}
