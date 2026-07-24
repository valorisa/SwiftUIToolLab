import Foundation

/// A single entry in the Workspace undo/redo history. Captures the payload
/// state *after* a transformation was applied, plus enough metadata to
/// describe what produced it.
///
/// isSensitive (v2-B): currently always false in practice. Workspace
/// deliberately never constructs a TransformationStep for a payload
/// marked sensitive at updatePayload(_:transformerName:isSensitive:) —
/// such payloads bypass history entirely (see Workspace.swift). The
/// field is kept here as forward-compatible plumbing for a possible
/// future design (e.g. a "sensitive but visible with a warning" history
/// mode), not because anything sets it true today.
struct TransformationStep: Identifiable {
    let id: UUID
    let payload: Payload
    let transformerName: String
    let appliedAt: Date
    let isSensitive: Bool

    init(payload: Payload, transformerName: String, appliedAt: Date = Date(), isSensitive: Bool = false) {
        self.id = UUID()
        self.payload = payload
        self.transformerName = transformerName
        self.appliedAt = appliedAt
        self.isSensitive = isSensitive
    }
}
