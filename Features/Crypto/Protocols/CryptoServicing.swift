import Foundation

/// Contract for the Crypto feature's business logic. The ViewModel depends
/// only on this protocol, never on the concrete CryptoService.
protocol CryptoServicing {
    func encrypt(_ plainText: String, password: String) throws -> String
    func decrypt(_ encryptedText: String, password: String) throws -> String
}

enum CryptoError: Error, Equatable {
    case invalidInput
    case invalidPassword
    case corruptedData
}
