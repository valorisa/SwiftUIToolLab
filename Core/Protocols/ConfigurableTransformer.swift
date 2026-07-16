import Foundation

// MARK: - TODO
// Transformation with parameters, but no secret.
// Example: image resizing, filtering.

protocol ConfigurableTransformer {
    associatedtype Configuration: Codable
    func transform(_ input: Payload, configuration: Configuration) throws -> Payload
    func inverse(_ input: Payload, configuration: Configuration) throws -> Payload
}
