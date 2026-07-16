import Foundation
import Combine

// MARK: - TODO
// PURE data container. NO transformation methods here (no encrypt(),
// no base64Encode()). Only state + undo/redo history management.

final class Workspace: ObservableObject {
    @Published var currentPayload: Payload?
    @Published var history: [TransformationStep] = []   // MARK: - TODO: cap at 50 steps
    @Published var historyIndex: Int = 0
    @Published var isProcessing: Bool = false

    // MARK: - TODO: func updatePayload(_ newPayload: Payload) throws
    // MARK: - TODO: func clearPayload()
    // MARK: - TODO: func undo()
    // MARK: - TODO: func redo()
}
