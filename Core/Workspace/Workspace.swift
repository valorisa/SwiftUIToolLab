import Foundation
import Combine

/// PURE data container. Holds no transformation logic (no encrypt(),
/// no base64Encode()) — only current state and a bounded undo/redo
/// history of applied transformations.
///
/// v2-B: updatePayload(_:transformerName:isSensitive:) lets a caller
/// mark a result as sensitive. Sensitive results still update
/// currentPayload (so the UI reflects them and the v1 cross-feature
/// handoff keeps working), but are deliberately never appended to
/// `history` — undo/redo can't resurrect a secret.
final class Workspace: ObservableObject {
    static let maxHistoryLength = 50

    @Published private(set) var currentPayload: Payload?
    @Published private(set) var history: [TransformationStep] = []
    @Published private(set) var historyIndex: Int = -1
    @Published var isProcessing: Bool = false

    /// True exactly when the LAST updatePayload call was sensitive and
    /// therefore not recorded in `history`. This is a derived fact
    /// about the last operation, NOT a durable property of whatever
    /// currentPayload happens to hold right now — renamed from v2-B's
    /// `currentPayloadIsUnrecordedSensitive` specifically to make that
    /// distinction unambiguous to future readers (v2-B-bis brief,
    /// Question 2). It flips back to false as soon as any subsequent
    /// update (sensitive or not) occurs, or after undo()/redo() moves
    /// currentPayload to an already-recorded (hence non-sensitive by
    /// construction) history entry.
    private(set) var lastUpdateWasSensitiveAndUnrecorded: Bool = false

    enum WorkspaceError: Error, Equatable {
        case writeLocked
    }

    /// Applies a new payload. Non-sensitive payloads are recorded in
    /// history and become the new undo/redo anchor, as before v2-B.
    /// Sensitive payloads update currentPayload only, bypassing history
    /// entirely. Throws if the Workspace is currently locked
    /// (isProcessing).
    func updatePayload(_ newPayload: Payload, transformerName: String = "unknown", isSensitive: Bool = false) throws {
        guard !isProcessing else { throw WorkspaceError.writeLocked }

        if isSensitive {
            currentPayload = newPayload
            lastUpdateWasSensitiveAndUnrecorded = true
            return
        }

        // Drop any "redo" branch beyond the current index before appending.
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
        lastUpdateWasSensitiveAndUnrecorded = false
    }

    func clearPayload() {
        currentPayload = nil
        history.removeAll()
        historyIndex = -1
        lastUpdateWasSensitiveAndUnrecorded = false
    }

    func undo() {
        if lastUpdateWasSensitiveAndUnrecorded {
            // Skip the sensitive detour: return to the last recorded
            // state instead of decrementing historyIndex, since no
            // index was ever pushed for the sensitive result.
            lastUpdateWasSensitiveAndUnrecorded = false
            currentPayload = historyIndex >= 0 ? history[historyIndex].payload : nil
            return
        }

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
        lastUpdateWasSensitiveAndUnrecorded = false
    }
}
