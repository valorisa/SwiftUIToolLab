import Foundation

@MainActor
final class Base64ViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var outputText: String = ""
    @Published var errorMessage: String?

    private let service: Base64Servicing
    private let workspace: Workspace

    init(
        service: Base64Servicing = ServiceLocator.shared.resolve(Base64Servicing.self) ?? Base64Service(),
        workspace: Workspace = ServiceLocator.shared.resolve(Workspace.self) ?? Workspace()
    ) {
        self.service = service
        self.workspace = workspace
        loadFromWorkspaceIfAvailable()
    }

    func encode() {
        errorMessage = nil
        outputText = service.encode(inputText)
        writeToWorkspace(.text(outputText), transformerName: "base64.encode")
    }

    func decode() {
        errorMessage = nil
        do {
            outputText = try service.decode(inputText)
            writeToWorkspace(.text(outputText), transformerName: "base64.decode")
        } catch {
            errorMessage = "Entrée Base64 invalide."
            outputText = ""
        }
    }

    // MARK: - Workspace sync

    /// Reads Workspace.currentPayload once at VM creation, if a
    /// compatible (.text) payload is already there — e.g. handed off
    /// from another tab. Non-text payloads (binary file imports) are
    /// left untouched; Base64 only knows how to operate on text.
    private func loadFromWorkspaceIfAvailable() {
        if case .text(let text) = workspace.currentPayload {
            inputText = text
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
