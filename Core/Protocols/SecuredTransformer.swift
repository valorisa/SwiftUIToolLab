import Foundation
import CryptoKit

// MARK: - TODO
// Transformation with an authenticated secret.
// Example: encryption, signing.

enum Secret {
    case password(String)
    case key(SymmetricKey)
    case keyDerivation(seed: Data, iterations: Int)
}

protocol SecuredTransformer {
    func transform(_ input: Payload, secret: Secret) throws -> Payload
    func inverse(_ input: Payload, secret: Secret) throws -> Payload
}
