import Foundation

/// Foundation-based Base64 encoder/decoder. Stateless, thread-safe.
final class Base64Service: Base64Servicing {
    func encode(_ input: String) -> String {
        Data(input.utf8).base64EncodedString()
    }

    func decode(_ input: String) throws -> String {
        guard !input.isEmpty,
              let data = Data(base64Encoded: input),
              let decoded = String(data: data, encoding: .utf8) else {
            throw Base64Error.invalidInput
        }
        return decoded
    }
}
