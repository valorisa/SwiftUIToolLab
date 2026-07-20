import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

struct CryptoView: View {
    @StateObject private var viewModel = CryptoViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Crypto").font(.title2).bold()

            Text("Entrée")
            TextEditor(text: $viewModel.inputText)
                .frame(minHeight: 100)
                .border(Color.gray.opacity(0.3))

            SecureField("Mot de passe", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Chiffrer") { viewModel.encrypt() }
                Button("Déchiffrer") { viewModel.decrypt() }
            }
            .disabled(viewModel.password.isEmpty)

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
    CryptoView()
}
