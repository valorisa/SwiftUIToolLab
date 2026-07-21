import Foundation

/// Foundation-based Base64 encoder/decoder. Stateless, thread-safe.
///
/// Conforms directly only to ReversibleTransformer's Payload-based
/// API. The String-based encode/decode consumed by Base64ViewModel and
/// by the existing test suite are supplied for free by the default
/// extension in Base64Servicing.swift — this type's public surface
/// changed shape (transform/inverse instead of encode/decode) without
/// any caller needing to change.
final class Base64Service: Base64Servicing {
    func transform(_ input: Payload) throws -> Payload {
        guard case .text(let string) = input else {
            throw Base64Error.invalidInput
        }
        return .text(Data(string.utf8).base64EncodedString())
    }

    func inverse(_ input: Payload) throws -> Payload {
        guard case .text(let string) = input,
              !string.isEmpty,
              let data = Data(base64Encoded: string),
              let decoded = String(data: data, encoding: .utf8) else {
            throw Base64Error.invalidInput
        }
        return .text(decoded)
    }
}
