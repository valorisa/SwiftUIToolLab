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
            errorMessage = "Mot de passe requis."
            outputText = ""
        } catch CryptoError.invalidInput {
            errorMessage = "Le texte à chiffrer est vide."
            outputText = ""
        } catch {
            errorMessage = "Erreur de chiffrement."
            outputText = ""
        }
    }

    func decrypt() {
        errorMessage = nil
        do {
            outputText = try service.decrypt(inputText, password: password)
            writeToWorkspace(.text(outputText), transformerName: "crypto.decrypt")
        } catch CryptoError.invalidPassword {
            errorMessage = "Mot de passe incorrect."
            outputText = ""
        } catch CryptoError.corruptedData {
            errorMessage = "Données chiffrées invalides ou corrompues."
            outputText = ""
        } catch {
            errorMessage = "Erreur de déchiffrement."
            outputText = ""
        }
    }

    // MARK: - Workspace sync

    /// Reads Workspace.currentPayload once at VM creation. .text
    /// payloads are used as-is (typical handoff after a Base64
    /// encode). .data payloads (e.g. a raw file import) are shown as
    /// their Base64 representation, matching what encrypt/decrypt
    /// expect as ciphertext input — a best-effort default, not a
    /// claim that arbitrary binary data is meaningful plaintext.
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

    /// Writes a successful transformation result back into the
    /// shared Workspace so other tabs can pick it up. isProcessing is
    /// never toggled anywhere in the app (Phase 6b scope), so
    /// writeLocked is unreachable today — handled defensively rather
    /// than silently ignored via try?.
    private func writeToWorkspace(_ payload: Payload, transformerName: String) {
        do {
            try workspace.updatePayload(payload, transformerName: transformerName)
        } catch {
            errorMessage = "Impossible de synchroniser avec le Workspace (verrouillé)."
        }
    }
}
