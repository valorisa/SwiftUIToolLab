import XCTest
import Combine
@testable import SwiftUIToolLab

// MARK: - SensitiveTextPurgeTests

/// Validates v2-B-bis's global (non-cosmetic) purge of sensitive text:
///   1. CryptoViewModel.clearSensitiveData() wipes inputText/outputText.
///   2. After a sensitive Crypto operation, a freshly created
///      CryptoViewModel does NOT reload the sensitive text from
///      Workspace.currentPayload — the core anti-cosmetic-purge check.
///   3. The cross-feature flow (Workspace → FileImportExportService
///      export) still works for a sensitive payload — the security
///      hardening doesn't break the v1 Workspace handoff.
///   4. That export window is not indefinite: the next Workspace update
///      (sensitive or not) naturally closes it.
///   5. AppState.purgeSensitiveDataSignal actually drives
///      CryptoViewModel.clearSensitiveData() through the subscription
///      wired in init — tested by sending the signal directly, without
///      going through RootView/.onChange(of:), which isn't testable
///      without ViewInspector (documented as an accepted test gap).
///
/// All @MainActor since CryptoViewModel/AppState are @MainActor types.
@MainActor
final class SensitiveTextPurgeTests: XCTestCase {

    // MARK: - clearSensitiveData()

    func testClearSensitiveDataPurgesCryptoViewModel() {
        let viewModel = CryptoViewModel(service: CryptoService(), workspace: Workspace())
        viewModel.inputText = "some ciphertext"
        viewModel.outputText = "some decrypted secret"
        viewModel.password = "leftover-password"

        viewModel.clearSensitiveData()

        XCTAssertEqual(viewModel.inputText, "")
        XCTAssertEqual(viewModel.outputText, "")
        XCTAssertEqual(viewModel.password, "")
    }

    // MARK: - Non-cosmetic purge: no reload from Workspace after a sensitive op

    func testFreshCryptoViewModelDoesNotReloadAfterSensitiveOperation() throws {
        let workspace = Workspace()
        try workspace.updatePayload(.text("decrypted secret"), transformerName: "crypto.decrypt", isSensitive: true)

        XCTAssertTrue(workspace.lastUpdateWasSensitiveAndUnrecorded, "Sanity check on the Workspace flag this test depends on.")

        let freshViewModel = CryptoViewModel(service: CryptoService(), workspace: workspace)

        XCTAssertEqual(freshViewModel.inputText, "", "A fresh CryptoViewModel must NOT reload a sensitive, unrecorded payload — that would make the purge cosmetic.")
    }

    func testFreshCryptoViewModelStillReloadsNonSensitivePayload() throws {
        // Non-regression: only sensitive+unrecorded payloads are
        // withheld. A normal handoff between tabs (e.g. after a Base64
        // encode) must keep working exactly as in Phase 6b.
        let workspace = Workspace()
        try workspace.updatePayload(.text("aGVsbG8="), transformerName: "base64.encode", isSensitive: false)

        let freshViewModel = CryptoViewModel(service: CryptoService(), workspace: workspace)

        XCTAssertEqual(freshViewModel.inputText, "aGVsbG8=", "Non-sensitive payloads must still be picked up by a fresh ViewModel, as before v2-B-bis.")
    }

    // MARK: - Cross-feature flow still works for sensitive payloads

    func testSensitivePayloadStillExportableViaFileImportExportService() throws {
        let workspace = Workspace()
        try workspace.updatePayload(.text("decrypted secret to export"), transformerName: "crypto.decrypt", isSensitive: true)

        guard case .text = workspace.currentPayload else {
            XCTFail("Expected currentPayload to reflect the sensitive result for cross-feature handoff")
            return
        }

        let fileService = FileImportExportService()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SensitivePurge_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let exportURL = tempDir.appendingPathComponent("sensitive_export.clab")
        try fileService.exportPayload(workspace.currentPayload!, to: exportURL, metadata: nil)

        let labFile = try fileService.importLabFile(from: exportURL)
        XCTAssertEqual(String(data: labFile.payloadData ?? Data(), encoding: .utf8), "decrypted secret to export")
    }

    func testExportWindowClosesAfterNextOperation() throws {
        let workspace = Workspace()
        try workspace.updatePayload(.text("first secret"), transformerName: "crypto.decrypt", isSensitive: true)
        XCTAssertTrue(workspace.lastUpdateWasSensitiveAndUnrecorded)

        // Any subsequent update — sensitive or not — naturally closes
        // the previous sensitive window: currentPayload moves on.
        try workspace.updatePayload(.text("unrelated text"), transformerName: "base64.encode", isSensitive: false)

        guard case .text(let current) = workspace.currentPayload else {
            XCTFail("Expected .text currentPayload")
            return
        }
        XCTAssertEqual(current, "unrelated text", "The sensitive payload must no longer be the exportable currentPayload once superseded.")
        XCTAssertFalse(workspace.lastUpdateWasSensitiveAndUnrecorded)
    }

    // MARK: - Signal-driven purge (AppState.purgeSensitiveDataSignal)

    func testPurgeSignalTriggersClearSensitiveDataOnSubscribedViewModel() {
        ServiceLocator.shared.reset()
        let appState = AppState()
        ServiceLocator.shared.register(AppState.self, instance: appState)

        let viewModel = CryptoViewModel(service: CryptoService(), workspace: Workspace())
        viewModel.inputText = "leftover ciphertext"
        viewModel.outputText = "leftover plaintext"

        appState.purgeSensitiveDataSignal.send()

        XCTAssertEqual(viewModel.inputText, "", "Sending the signal must trigger clearSensitiveData() on any subscribed CryptoViewModel, mirroring what RootView.onChange(of:) does when leaving the Crypto tab.")
        XCTAssertEqual(viewModel.outputText, "")

        ServiceLocator.shared.reset()
    }
}
