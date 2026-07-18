import XCTest
@testable import SwiftUIToolLab

final class WorkspaceTests: XCTestCase {
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
}
