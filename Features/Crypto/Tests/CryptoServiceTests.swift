import XCTest
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
}
