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

    /// v2-B: password is purged after every call, success or failure —
    /// a deliberate UX trade-off for a COMPLETE threat model (D-v2-3):
    /// a typo means retyping the password, but it never lingers in
    /// memory after use. Targeted purge only: inputText/outputText are
    /// untouched here (Chantier 3, deferred to v2-B-bis).
    func encrypt() {
        errorMessage = nil
        defer { password = "" }

        do {
            outputText = try service.encrypt(inputText, password: password)
            writeToWorkspace(.text(outputText), transformerName: "crypto.encrypt", isSensitive: true)
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

    /// See encrypt() doc comment — same targeted, always-purge policy.
    func decrypt() {
        errorMessage = nil
        defer { password = "" }

        do {
            outputText = try service.decrypt(inputText, password: password)
            writeToWorkspace(.text(outputText), transformerName: "crypto.decrypt", isSensitive: true)
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

    /// isSensitive defaults to false so any future non-crypto caller of
    /// this helper doesn't need to opt in explicitly; encrypt()/decrypt()
    /// above always pass true.
    private func writeToWorkspace(_ payload: Payload, transformerName: String, isSensitive: Bool = false) {
        do {
            try workspace.updatePayload(payload, transformerName: transformerName, isSensitive: isSensitive)
        } catch {
            errorMessage = NSLocalizedString("workspace.sync_locked_error", comment: "Shown when Workspace.updatePayload throws because isProcessing is true")
        }
    }
}
