import XCTest
import CryptoKit
@testable import SwiftUIToolLab

final class CryptoServiceTests: XCTestCase {
    private var sut: CryptoServicing!

    override func setUp() {
        super.setUp()
        sut = CryptoService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Existing String+password API (unchanged since Phase 4)

    func testEncryptDecryptRoundtrip() throws {
        let original = "Grillé mais pas cramé 🔥"
        let encrypted = try sut.encrypt(original, password: "correct-horse-battery-staple")
        let decrypted = try sut.decrypt(encrypted, password: "correct-horse-battery-staple")
        XCTAssertEqual(decrypted, original)
    }

    func testEncryptProducesDifferentOutputEachTime() throws {
        let first = try sut.encrypt("same input", password: "pw")
        let second = try sut.encrypt("same input", password: "pw")
        XCTAssertNotEqual(first, second, "Random salt/nonce must prevent identical ciphertexts")
    }

    func testDecryptWithWrongPasswordThrowsInvalidPassword() throws {
        let encrypted = try sut.encrypt("secret", password: "right-password")
        XCTAssertThrowsError(try sut.decrypt(encrypted, password: "wrong-password")) { error in
            XCTAssertEqual(error as? CryptoError, .invalidPassword)
        }
    }

    func testDecryptCorruptedDataThrowsCorruptedData() {
        XCTAssertThrowsError(try sut.decrypt("not-valid-base64-ciphertext", password: "pw")) { error in
            XCTAssertEqual(error as? CryptoError, .corruptedData)
        }
    }

    func testEncryptEmptyPasswordThrowsInvalidPassword() {
        XCTAssertThrowsError(try sut.encrypt("text", password: "")) { error in
            XCTAssertEqual(error as? CryptoError, .invalidPassword)
        }
    }

    func testEncryptEmptyInputThrowsInvalidInput() {
        XCTAssertThrowsError(try sut.encrypt("", password: "pw")) { error in
            XCTAssertEqual(error as? CryptoError, .invalidInput)
        }
    }

    // MARK: - Core protocol conformance (SecuredTransformer) — Phase 6a

    func testTransformInverseRoundtripOnPayloadWithSecret() throws {
        let secret = Secret.password("correct-horse-battery-staple")
        let original = "Grillé mais pas cramé 🔥"

        let transformed = try sut.transform(.text(original), secret: secret)
        guard case .data = transformed else {
            XCTFail("Expected .data payload from transform (salt + combined)")
            return
        }

        let inverted = try sut.inverse(transformed, secret: secret)
        guard case .text(let result) = inverted else {
            XCTFail("Expected .text payload from inverse")
            return
        }
        XCTAssertEqual(result, original)
    }

    func testTransformWithUnsupportedSecretTypeThrows() {
        let unsupported = Secret.key(SymmetricKey(size: .bits256))
        XCTAssertThrowsError(try sut.transform(.text("secret"), secret: unsupported)) { error in
            XCTAssertEqual(error as? CryptoError, .invalidPassword)
        }
    }

    func testInverseOnNonDataPayloadThrows() {
        XCTAssertThrowsError(
            try sut.inverse(.text("not-a-data-payload"), secret: .password("pw"))
        ) { error in
            XCTAssertEqual(error as? CryptoError, .corruptedData)
        }
    }
}
