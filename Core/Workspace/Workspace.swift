import Foundation
import Combine

/// PURE data container. Holds no transformation logic (no encrypt(),
/// no base64Encode()) — only current state and a bounded undo/redo
/// history of applied transformations.
final class Workspace: ObservableObject {
    static let maxHistoryLength = 50

    @Published private(set) var currentPayload: Payload?
    @Published private(set) var history: [TransformationStep] = []
    @Published private(set) var historyIndex: Int = -1
    @Published var isProcessing: Bool = false

    enum WorkspaceError: Error, Equatable {
        case writeLocked
    }

    /// Applies a new payload and records it in history.
    /// Throws if the Workspace is currently locked (isProcessing).
    func updatePayload(_ newPayload: Payload, transformerName: String = "unknown") throws {
        guard !isProcessing else { throw WorkspaceError.writeLocked }

        if historyIndex < history.count - 1 {
            history.removeSubrange((historyIndex + 1)...)
        }

        let step = TransformationStep(payload: newPayload, transformerName: transformerName)
        history.append(step)

        if history.count > Self.maxHistoryLength {
            history.removeFirst(history.count - Self.maxHistoryLength)
        }

        historyIndex = history.count - 1
        currentPayload = newPayload
    }

    func clearPayload() {
        currentPayload = nil
        history.removeAll()
        historyIndex = -1
    }

    func undo() {
        guard historyIndex >= 0 else { return }
        if historyIndex == 0 {
            historyIndex = -1
            currentPayload = nil
            return
        }
        historyIndex -= 1
        currentPayload = history[historyIndex].payload
    }

    func redo() {
        guard historyIndex < history.count - 1 else { return }
        historyIndex += 1
        currentPayload = history[historyIndex].payload
    }
}
