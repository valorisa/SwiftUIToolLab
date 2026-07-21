import Foundation
import CryptoKit

/// Transformation with an authenticated secret.
/// Adopted by CryptoService since Phase 6a — no longer decorative.
/// Example: encryption, signing.

enum Secret {
    case password(String)
    case key(SymmetricKey)
    case keyDerivation(seed: Data, iterations: Int)
}

protocol SecuredTransformer {
    func transform(_ input: Payload, secret: Secret) throws -> Payload
    func inverse(_ input: Payload, secret: Secret) throws -> Payload
}
