import Foundation

/// Contract for the Base64 feature's business logic.
///
/// Base64Servicing now inherits Core's ReversibleTransformer: a
/// conforming type only needs to implement transform(_:)/inverse(_:)
/// on Payload. encode/decode below are convenience wrappers over that
/// same implementation, supplied once here via a default extension —
/// Base64ViewModel and Base64ServiceTests keep using the original
/// String-based API completely unchanged.
protocol Base64Servicing: ReversibleTransformer {
    func encode(_ input: String) -> String
    func decode(_ input: String) throws -> String
}

extension Base64Servicing {
    func encode(_ input: String) -> String {
        guard let result = try? transform(.text(input)),
              case .text(let output) = result else {
            return ""
        }
        return output
    }

    func decode(_ input: String) throws -> String {
        guard case .text(let output) = try inverse(.text(input)) else {
            throw Base64Error.invalidInput
        }
        return output
    }
}

enum Base64Error: Error, Equatable {
    case invalidInput
}
