import Foundation
import CryptoKit

/// AES-GCM authenticated encryption with a password-derived key
/// (HKDF-SHA256).
///
/// Design decision (Phase 6a, salt placement): the salt now lives
/// concatenated with AES.GCM's combined output directly inside
/// Payload.data — "salt + combined" as raw bytes, no manual Base64
/// step at this layer. Rationale: when this Payload is later written
/// into a .clab file (LabPayloadFile.payloadData is Data), JSONEncoder
/// already Base64-encodes Data on its own; encoding it a second time
/// here (as the pre-6a String-based implementation did) was a
/// redundant encoding pass with no benefit once the transport type
/// became Payload instead of String. The String+password
/// encrypt/decrypt API (CryptoServicing.swift) still returns/accepts
/// Base64 text, for the benefit of any UI code or test expecting a
/// copy-pasteable string — that single encode/decode step now lives
/// only at the adapter boundary, not duplicated here.
///
/// Note: HKDF is used here for simplicity. A slow KDF (PBKDF2/Argon2)
/// with a configurable work factor would be preferable against
/// low-entropy passwords — tracked as a follow-up once
/// CommonCrypto/Argon2 bridging is wired into the SPM target.
final class CryptoService: CryptoServicing {
    private let saltLength = 16

    func transform(_ input: Payload, secret: Secret) throws -> Payload {
        guard case .password(let password) = secret else {
            throw CryptoError.invalidPassword
        }
        guard !password.isEmpty else { throw CryptoError.invalidPassword }
        guard case .text(let plainText) = input, !plainText.isEmpty else {
            throw CryptoError.invalidInput
        }

        let salt = Data((0..<saltLength).map { _ in UInt8.random(in: 0...255) })
        let key = Self.deriveKey(password: password, salt: salt)

        let sealedBox = try AES.GCM.seal(Data(plainText.utf8), using: key)
        guard let combined = sealedBox.combined else {
            throw CryptoError.corruptedData
        }

        return .data(salt + combined)
    }

    func inverse(_ input: Payload, secret: Secret) throws -> Payload {
        guard case .password(let password) = secret else {
            throw CryptoError.invalidPassword
        }
        guard !password.isEmpty else { throw CryptoError.invalidPassword }
        guard case .data(let raw) = input, raw.count > saltLength else {
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
            return .text(text)
        } catch {
            // AES-GCM tag mismatch surfaces here — can mean wrong
            // password or tampered data; we report the more
            // actionable case to the UI.
            throw CryptoError.invalidPassword
        }
    }

    private static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        let inputKeyMaterial = SymmetricKey(data: Data(password.utf8))
        return HKDF<SHA256>.deriveKey(inputKeyMaterial: inputKeyMaterial, salt: salt, outputByteCount: 32)
    }
}
