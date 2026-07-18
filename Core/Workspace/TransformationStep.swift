import Foundation

/// A single entry in the Workspace undo/redo history. Captures the payload
/// state *after* a transformation was applied, plus enough metadata to
/// describe what produced it.
struct TransformationStep: Identifiable {
    let id: UUID
    let payload: Payload
    let transformerName: String
    let appliedAt: Date

    init(payload: Payload, transformerName: String, appliedAt: Date = Date()) {
        self.id = UUID()
        self.payload = payload
        self.transformerName = transformerName
        self.appliedAt = appliedAt
    }
}
