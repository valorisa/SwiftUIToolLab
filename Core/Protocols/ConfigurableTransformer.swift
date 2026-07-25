import Foundation

/// Transformation with parameters, but no secret. Exercised for the
/// first time in v2-E (LinearOperator feature) — no contract change
/// was needed. A conforming feature protocol resolves the associated
/// Configuration type via a same-type constraint in its own
/// declaration (see LinearOperatorServicing), not by modifying this
/// file.
/// Example: image resizing, filtering, linear operators.
protocol ConfigurableTransformer {
    associatedtype Configuration: Codable
    func transform(_ input: Payload, configuration: Configuration) throws -> Payload
    func inverse(_ input: Payload, configuration: Configuration) throws -> Payload
}
