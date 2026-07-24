import Foundation
import Combine

/// PURE data container. Holds no transformation logic (no encrypt(),
/// no base64Encode()) — only current state and a bounded undo/redo
/// history of applied transformations.
///
/// v2-B: updatePayload(_:transformerName:isSensitive:) lets a caller
/// mark a result as sensitive. Sensitive results still update
/// currentPayload (so the UI reflects them), but are deliberately never
/// appended to `history` — undo/redo can't resurrect a secret. Deciding
/// *what counts as sensitive* is the caller's job (e.g.
/// CryptoViewModel), not the Workspace's: this stays plumbing, not
/// business logic, consistent with "Workspace = pure container" since
/// Phase 1.
final class Workspace: ObservableObject {
    static let maxHistoryLength = 50

    @Published private(set) var currentPayload: Payload?
    @Published private(set) var history: [TransformationStep] = []
    @Published private(set) var historyIndex: Int = -1
    @Published var isProcessing: Bool = false

    /// True when currentPayload was produced by a sensitive update that
    /// was intentionally NOT recorded in `history`. Lets undo() know it
    /// must jump back to history[historyIndex] (the last *recorded*
    /// state) instead of decrementing historyIndex again — no new index
    /// was ever pushed for the sensitive result in the first place.
    private var currentPayloadIsUnrecordedSensitive: Bool = false

    enum WorkspaceError: Error, Equatable {
        case writeLocked
    }

    /// Applies a new payload. Non-sensitive payloads are recorded in
    /// history and become the new undo/redo anchor, as before v2-B.
    /// Sensitive payloads update currentPayload only, bypassing history
    /// entirely — see the type-level doc comment above.
    /// Throws if the Workspace is currently locked (isProcessing).
    func updatePayload(_ newPayload: Payload, transformerName: String = "unknown", isSensitive: Bool = false) throws {
        guard !isProcessing else { throw WorkspaceError.writeLocked }

        if isSensitive {
            currentPayload = newPayload
            currentPayloadIsUnrecordedSensitive = true
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
        currentPayloadIsUnrecordedSensitive = false
    }

    func clearPayload() {
        currentPayload = nil
        history.removeAll()
        historyIndex = -1
        currentPayloadIsUnrecordedSensitive = false
    }

    func undo() {
        if currentPayloadIsUnrecordedSensitive {
            // Skip the sensitive detour: return to the last recorded
            // state instead of decrementing historyIndex, since no
            // index was ever pushed for the sensitive result.
            currentPayloadIsUnrecordedSensitive = false
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
        currentPayloadIsUnrecordedSensitive = false
    }
}
