import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct CryptoView: View {
    @StateObject private var viewModel = CryptoViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // "Crypto" is a technical feature name, not prose — left
            // as a literal, not localized (per brief risk list).
            Text("Crypto").font(.title2).bold()

            Text("crypto.input_label")
            TextEditor(text: $viewModel.inputText)
                .frame(minHeight: 100)
                .border(Color.gray.opacity(0.3))

            SecureField("crypto.password_placeholder", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("crypto.encrypt_button") { viewModel.encrypt() }
                Button("crypto.decrypt_button") { viewModel.decrypt() }
            }
            .disabled(viewModel.password.isEmpty)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }

            Text("crypto.output_label")
            TextEditor(text: .constant(viewModel.outputText))
                .frame(minHeight: 100)
                .border(Color.gray.opacity(0.3))
                .disabled(true)

            Button("crypto.copy_button") {
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
    CryptoView()
}
