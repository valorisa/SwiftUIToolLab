import Foundation

/// Contract for the Base64 feature's business logic. The ViewModel depends
/// only on this protocol, never on the concrete Base64Service.
protocol Base64Servicing {
    func encode(_ input: String) -> String
    func decode(_ input: String) throws -> String
}

enum Base64Error: Error, Equatable {
    case invalidInput
}
