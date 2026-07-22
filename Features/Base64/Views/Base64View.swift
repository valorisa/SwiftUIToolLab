import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct Base64View: View {
    @StateObject private var viewModel = Base64ViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // "Base64" is a technical/algorithm name, not prose — left
            // as a literal, not localized (per brief risk list).
            Text("Base64").font(.title2).bold()

            Text("base64.input_label")
            TextEditor(text: $viewModel.inputText)
                .frame(minHeight: 100)
                .border(Color.gray.opacity(0.3))

            HStack {
                Button("base64.encode_button") { viewModel.encode() }
                Button("base64.decode_button") { viewModel.decode() }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }

            Text("base64.output_label")
            TextEditor(text: .constant(viewModel.outputText))
                .frame(minHeight: 100)
                .border(Color.gray.opacity(0.3))
                .disabled(true)

            Button("base64.copy_button") {
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
