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
            errorMessage = NSLocalizedString("base64.decode_error", comment: "Shown when the Base64 input string cannot be decoded")
            outputText = ""
        }
    }

    // MARK: - Workspace sync

    private func loadFromWorkspaceIfAvailable() {
        if case .text(let text) = workspace.currentPayload {
            inputText = text
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
