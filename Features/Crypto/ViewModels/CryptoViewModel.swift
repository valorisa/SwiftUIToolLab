import Foundation
import Combine

@MainActor
final class CryptoViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var password: String = ""
    @Published var outputText: String = ""
    @Published var errorMessage: String?

    private let service: CryptoServicing
    private let workspace: Workspace
    private var cancellables: Set<AnyCancellable> = []

    init(
        service: CryptoServicing = ServiceLocator.shared.resolve(CryptoServicing.self) ?? CryptoService(),
        workspace: Workspace = ServiceLocator.shared.resolve(Workspace.self) ?? Workspace(),
        appState: AppState? = ServiceLocator.shared.resolve(AppState.self)
    ) {
        self.service = service
        self.workspace = workspace
        loadFromWorkspaceIfAvailable()
        subscribeToPurgeSignal(from: appState)
    }

    /// v2-B: password is purged after every call, success or failure —
    /// a deliberate UX trade-off for a COMPLETE threat model (D-v2-3).
    /// Targeted purge only: inputText/outputText are untouched here.
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

    /// v2-B-bis: wipes the remaining sensitive surface (input/output
    /// text). Triggered by RootView leaving the Crypto tab, via
    /// AppState.purgeSensitiveDataSignal. Deliberate UX trade-off
    /// (COMPLETE threat model): the user loses their text when
    /// switching tabs, and it does NOT come back automatically when
    /// they return — see loadFromWorkspaceIfAvailable() below.
    func clearSensitiveData() {
        inputText = ""
        outputText = ""
        password = ""
    }

    // MARK: - Workspace sync

    /// v2-B-bis: does NOT reload a payload whose last update was
    /// sensitive-and-unrecorded — reloading it here would make the
    /// clearSensitiveData() purge cosmetic (the text would just come
    /// back from the Workspace on the next tab visit). Non-sensitive
    /// payloads (e.g. a Base64-encoded value handed off from another
    /// tab) are still picked up exactly as before v2-B-bis.
    private func loadFromWorkspaceIfAvailable() {
        guard !workspace.lastUpdateWasSensitiveAndUnrecorded else { return }

        switch workspace.currentPayload {
        case .text(let text):
            inputText = text
        case .data(let data):
            inputText = data.base64EncodedString()
        default:
            break
        }
    }

    private func writeToWorkspace(_ payload: Payload, transformerName: String, isSensitive: Bool = false) {
        do {
            try workspace.updatePayload(payload, transformerName: transformerName, isSensitive: isSensitive)
        } catch {
            errorMessage = NSLocalizedString("workspace.sync_locked_error", comment: "Shown when Workspace.updatePayload throws because isProcessing is true")
        }
    }

    // MARK: - Purge signal subscription

    /// Subscribes to AppState.purgeSensitiveDataSignal so RootView can
    /// trigger a purge without holding a reference to this ViewModel
    /// (Question 4, Option B). [weak self] avoids a retain cycle
    /// through the Combine pipeline; storing the AnyCancellable in
    /// `cancellables` cancels the subscription automatically when this
    /// instance deallocates — no explicit deinit needed for that, but
    /// documented here since the brief calls it out explicitly.
    private func subscribeToPurgeSignal(from appState: AppState?) {
        appState?.purgeSensitiveDataSignal
            .sink { [weak self] in
                self?.clearSensitiveData()
            }
            .store(in: &cancellables)
    }
}
