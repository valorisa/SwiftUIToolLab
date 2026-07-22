import Foundation

@MainActor
final class CryptoViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var password: String = ""
    @Published var outputText: String = ""
    @Published var errorMessage: String?

    private let service: CryptoServicing
    private let workspace: Workspace

    init(
        service: CryptoServicing = ServiceLocator.shared.resolve(CryptoServicing.self) ?? CryptoService(),
        workspace: Workspace = ServiceLocator.shared.resolve(Workspace.self) ?? Workspace()
    ) {
        self.service = service
        self.workspace = workspace
        loadFromWorkspaceIfAvailable()
    }

    func encrypt() {
        errorMessage = nil
        do {
            outputText = try service.encrypt(inputText, password: password)
            writeToWorkspace(.text(outputText), transformerName: "crypto.encrypt")
        } catch CryptoError.invalidPassword {
            errorMessage = NSLocalizedString("crypto.password_required_error", comment: "Shown when the password field is empty during encryption")
            outputText = ""
        } catch CryptoError.invalidInput {
            errorMessage = NSLocalizedString("crypto.empty_input_error", comment: "Shown when the plaintext field is empty during encryption")
            outputText = ""
        } catch {
            errorMessage = NSLocalizedString("crypto.encrypt_generic_error", comment: "Fallback shown for unexpected encryption failures")
            outputText = ""
        }
    }

    func decrypt() {
        errorMessage = nil
        do {
            outputText = try service.decrypt(inputText, password: password)
            writeToWorkspace(.text(outputText), transformerName: "crypto.decrypt")
        } catch CryptoError.invalidPassword {
            errorMessage = NSLocalizedString("crypto.wrong_password_error", comment: "Shown when decryption fails due to a wrong password")
            outputText = ""
        } catch CryptoError.corruptedData {
            errorMessage = NSLocalizedString("crypto.corrupted_data_error", comment: "Shown when the ciphertext is malformed or tampered with")
            outputText = ""
        } catch {
            errorMessage = NSLocalizedString("crypto.decrypt_generic_error", comment: "Fallback shown for unexpected decryption failures")
            outputText = ""
        }
    }

    // MARK: - Workspace sync

    private func loadFromWorkspaceIfAvailable() {
        switch workspace.currentPayload {
        case .text(let text):
            inputText = text
        case .data(let data):
            inputText = data.base64EncodedString()
        default:
            break
        }
    }

    private func writeToWorkspace(_ payload: Payload, transformerName: String) {
        do {
            try workspace.updatePayload(payload, transformerName: transformerName)
        } catch {
            errorMessage = NSLocalizedString("workspace.sync_locked_error", comment: "Shown when Workspace.updatePayload throws because isProcessing is true")
        }
    }
}
