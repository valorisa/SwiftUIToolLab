import XCTest
@testable import SwiftUIToolLab

// MARK: - SecurityRetentionTests

/// Validates v2-B's two hardening measures:
///   1. CryptoViewModel.password is purged after every encrypt/decrypt
///      call, whether it succeeded or failed.
///   2. Workspace never retains a sensitive payload in `history`
///      (undo/redo), while still reflecting it in `currentPayload` for
///      the UI. undo() after a sensitive operation intentionally skips
///      straight back to the last recorded (non-sensitive) state.
///
/// CryptoViewModel is @MainActor, so this whole test class runs on the
/// main actor to instantiate and call it synchronously.
@MainActor
final class SecurityRetentionTests: XCTestCase {

    // MARK: - Chantier 1: password purge

    func testPasswordPurgedAfterSuccessfulEncrypt() throws {
        let viewModel = CryptoViewModel(service: CryptoService(), workspace: Workspace())
        viewModel.inputText = "a secret message"
        viewModel.password = "correct-horse-battery-staple"

        viewModel.encrypt()

        XCTAssertEqual(viewModel.password, "", "Password must be purged after a successful encrypt().")
        XCTAssertFalse(viewModel.outputText.isEmpty, "Sanity check: encrypt() should still have produced output.")
    }

    func testPasswordPurgedAfterFailedDecryptWrongPassword() throws {
        let service = CryptoService()
        let workspace = Workspace()
        let encryptVM = CryptoViewModel(service: service, workspace: workspace)
        encryptVM.inputText = "a secret message"
        encryptVM.password = "right-password"
        encryptVM.encrypt()
        let ciphertext = encryptVM.outputText

        let decryptVM = CryptoViewModel(service: service, workspace: Workspace())
        decryptVM.inputText = ciphertext
        decryptVM.password = "wrong-password"

        decryptVM.decrypt()

        XCTAssertEqual(decryptVM.password, "", "Password must be purged even after a failed decrypt().")
        XCTAssertNotNil(decryptVM.errorMessage, "Sanity check: decrypt() should have failed with the wrong password.")
    }

    func testPasswordPurgeDoesNotClearInputOrOutputText() throws {
        // Targeted purge only: password = "" must NOT wipe inputText/
        // outputText (that's Chantier 3, deferred to v2-B-bis).
        let viewModel = CryptoViewModel(service: CryptoService(), workspace: Workspace())
        viewModel.inputText = "a secret message"
        viewModel.password = "correct-horse-battery-staple"

        viewModel.encrypt()

        XCTAssertEqual(viewModel.inputText, "a secret message", "inputText must survive the password purge.")
        XCTAssertFalse(viewModel.outputText.isEmpty, "outputText must survive the password purge.")
    }

    // MARK: - Chantier 2: sensitive payloads not retained in history

    func testSensitivePayloadNotRetainedInHistoryButReflectedInCurrentPayload() throws {
        let workspace = Workspace()
        try workspace.updatePayload(.text("first"), transformerName: "raw")
        try workspace.updatePayload(.text("decrypted secret"), transformerName: "crypto.decrypt", isSensitive: true)

        XCTAssertEqual(workspace.history.count, 1, "The sensitive step must not be appended to history.")

        guard case .text(let current) = workspace.currentPayload else {
            XCTFail("Expected .text currentPayload")
            return
        }
        XCTAssertEqual(current, "decrypted secret", "currentPayload must still reflect the sensitive result for the UI.")
    }

    func testUndoSkipsSensitiveOperationAndReturnsToLastRecordedStep() throws {
        let workspace = Workspace()
        try workspace.updatePayload(.text("first"), transformerName: "raw")
        try workspace.updatePayload(.text("decrypted secret"), transformerName: "crypto.decrypt", isSensitive: true)

        workspace.undo()

        guard case .text(let afterUndo) = workspace.currentPayload else {
            XCTFail("Expected .text currentPayload after undo")
            return
        }
        XCTAssertEqual(afterUndo, "first", "undo() after a sensitive operation must jump back to the last recorded state, not decrement historyIndex further.")
        XCTAssertEqual(workspace.history.count, 1, "History itself must remain untouched by the sensitive detour.")
    }

    func testMultipleUpdatesAfterSensitiveOperationResumeNormalHistory() throws {
        // Non-regression: a sensitive detour must not corrupt history
        // bookkeeping for subsequent normal (non-sensitive) updates.
        let workspace = Workspace()
        try workspace.updatePayload(.text("first"), transformerName: "raw")
        try workspace.updatePayload(.text("decrypted secret"), transformerName: "crypto.decrypt", isSensitive: true)
        try workspace.updatePayload(.text("second"), transformerName: "raw")

        XCTAssertEqual(workspace.history.count, 2, "Only the two non-sensitive steps should be recorded.")

        workspace.undo()
        guard case .text(let afterUndo) = workspace.currentPayload else {
            XCTFail("Expected .text currentPayload")
            return
        }
        XCTAssertEqual(afterUndo, "first")
    }
}
