import XCTest
@testable import SwiftUIToolLab

final class WorkspaceTests: XCTestCase {

    // MARK: - Existing tests (Phase 1, unchanged)

    func testUpdatePayloadSetsCurrentAndHistory() throws {
        let workspace = Workspace()
        try workspace.updatePayload(.text("hello"), transformerName: "raw")

        XCTAssertEqual(workspace.history.count, 1)
        if case .text(let value) = workspace.currentPayload {
            XCTAssertEqual(value, "hello")
        } else {
            XCTFail("Expected .text payload")
        }
    }

    func testUndoRedoRoundtrip() throws {
        let workspace = Workspace()
        try workspace.updatePayload(.text("first"), transformerName: "raw")
        try workspace.updatePayload(.text("second"), transformerName: "raw")

        workspace.undo()
        if case .text(let value) = workspace.currentPayload {
            XCTAssertEqual(value, "first")
        } else {
            XCTFail("Expected .text payload after undo")
        }

        workspace.redo()
        if case .text(let value) = workspace.currentPayload {
            XCTAssertEqual(value, "second")
        } else {
            XCTFail("Expected .text payload after redo")
        }
    }

    func testHistoryIsCappedAtFiftySteps() throws {
        let workspace = Workspace()
        for index in 0..<60 {
            try workspace.updatePayload(.text("\(index)"), transformerName: "raw")
        }
        XCTAssertEqual(workspace.history.count, Workspace.maxHistoryLength)
    }

    // MARK: - New: Workspace driven by a real feature (Phase 6b)

    /// Proves the Workspace isn't just synthetically exercised with
    /// bare .text values — a real feature service (Base64Service)
    /// drives it end to end, and undo/redo behave correctly across
    /// those feature-produced payloads. This is the automated
    /// evidence behind the "Workspace used by at least one feature"
    /// success criterion, independent of any ViewModel/panel wiring
    /// that can't be exercised in CI (D5).
    func testUndoRedoAcrossBase64FeatureTransformations() throws {
        let workspace = Workspace()
        let base64Service = Base64Service()

        let original = "Feature-driven workspace check"
        let encoded = try base64Service.transform(.text(original))
        try workspace.updatePayload(encoded, transformerName: "base64.encode")

        guard case .text(let encodedText) = workspace.currentPayload else {
            XCTFail("Expected text payload after Base64 encode")
            return
        }

        let decoded = try base64Service.inverse(.text(encodedText))
        try workspace.updatePayload(decoded, transformerName: "base64.decode")

        workspace.undo()
        guard case .text(let afterUndo) = workspace.currentPayload else {
            XCTFail("Expected text payload after undo")
            return
        }
        XCTAssertEqual(afterUndo, encodedText)

        workspace.redo()
        guard case .text(let afterRedo) = workspace.currentPayload,
              case .text(let expected) = decoded else {
            XCTFail("Expected text payloads after redo")
            return
        }
        XCTAssertEqual(afterRedo, expected)
    }
}
