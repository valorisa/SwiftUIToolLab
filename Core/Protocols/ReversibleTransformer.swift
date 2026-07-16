import Foundation

// MARK: - TODO
// Transformation without parameters, strictly reversible 1:1.
// Example: Base64, ROT13.

protocol ReversibleTransformer {
    func transform(_ input: Payload) throws -> Payload
    func inverse(_ input: Payload) throws -> Payload
}
