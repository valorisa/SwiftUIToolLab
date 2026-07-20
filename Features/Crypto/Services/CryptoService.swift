import Foundation
import CryptoKit

/// AES-GCM authenticated encryption with a password-derived key (HKDF-SHA256).
/// Output is Base64(salt + AES.GCM.combined) so the whole roundtrip fits in
/// a single text field, mirroring Base64Service's UX.
///
/// Note: HKDF is used here for simplicity. A slow KDF (PBKDF2/Argon2) with a
/// configurable work factor would be preferable against low-entropy
/// passwords — tracked as a follow-up once CommonCrypto/Argon2 bridging is
/// wired into the SPM target.
final class CryptoService: CryptoServicing {
    private let saltLength = 16

    func encrypt(_ plainText: String, password: String) throws -> String {
        guard !password.isEmpty else { throw CryptoError.invalidPassword }
        guard !plainText.isEmpty else { throw CryptoError.invalidInput }

        let salt = Data((0..<saltLength).map { _ in UInt8.random(in: 0...255) })
        let key = Self.deriveKey(password: password, salt: salt)

        let sealedBox = try AES.GCM.seal(Data(plainText.utf8), using: key)
        guard let combined = sealedBox.combined else {
            throw CryptoError.corruptedData
        }

        return (salt + combined).base64EncodedString()
    }

    func decrypt(_ encryptedText: String, password: String) throws -> String {
        guard !password.isEmpty else { throw CryptoError.invalidPassword }
        guard let raw = Data(base64Encoded: encryptedText), raw.count > saltLength else {
            throw CryptoError.corruptedData
        }

        let salt = raw.prefix(saltLength)
        let combined = raw.suffix(from: raw.startIndex + saltLength)
        let key = Self.deriveKey(password: password, salt: salt)

        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.SealedBox(combined: combined)
        } catch {
            throw CryptoError.corruptedData
        }

        do {
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            guard let text = String(data: decryptedData, encoding: .utf8) else {
                throw CryptoError.corruptedData
            }
            return text
        } catch {
            // AES-GCM tag mismatch surfaces here — can mean wrong password
            // or tampered data; we report the more actionable case to the UI.
            throw CryptoError.invalidPassword
        }
    }

    private static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        let inputKeyMaterial = SymmetricKey(data: Data(password.utf8))
        return HKDF<SHA256>.deriveKey(inputKeyMaterial: inputKeyMaterial, salt: salt, outputByteCount: 32)
    }
}
