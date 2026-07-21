import Foundation

/// Transformation without parameters, strictly reversible 1:1.
/// Adopted by Base64Service since Phase 6a — no longer decorative.
/// Example: Base64, ROT13.
protocol ReversibleTransformer {
    func transform(_ input: Payload) throws -> Payload
    func inverse(_ input: Payload) throws -> Payload
}
