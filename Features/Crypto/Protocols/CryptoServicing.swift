import Foundation

/// Contract for the Crypto feature's business logic.
///
/// CryptoServicing now inherits Core's SecuredTransformer: a
/// conforming type only needs to implement transform(_:secret:)/
/// inverse(_:secret:) on Payload+Secret. encrypt/decrypt below are
/// convenience wrappers over that same implementation, supplied once
/// here via a default extension — CryptoViewModel and
/// CryptoServiceTests keep using the original String+password API
/// completely unchanged.
///
/// Only Secret.password is currently supported by any conforming
/// implementation; other Secret cases surface as .invalidPassword
/// rather than adding new error cases for unimplemented paths.
protocol CryptoServicing: SecuredTransformer {
    func encrypt(_ plainText: String, password: String) throws -> String
    func decrypt(_ encryptedText: String, password: String) throws -> String
}

extension CryptoServicing {
    func encrypt(_ plainText: String, password: String) throws -> String {
        let result = try transform(.text(plainText), secret: .password(password))
        guard case .data(let combined) = result else {
            throw CryptoError.corruptedData
        }
        return combined.base64EncodedString()
    }

    func decrypt(_ encryptedText: String, password: String) throws -> String {
        guard !encryptedText.isEmpty, let raw = Data(base64Encoded: encryptedText) else {
            throw CryptoError.corruptedData
        }
        guard case .text(let plainText) = try inverse(.data(raw), secret: .password(password)) else {
            throw CryptoError.corruptedData
        }
        return plainText
    }
}

enum CryptoError: Error, Equatable {
    case invalidInput
    case invalidPassword
    case corruptedData
}
