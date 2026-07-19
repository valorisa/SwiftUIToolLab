import XCTest
@testable import SwiftUIToolLab

final class Base64ServiceTests: XCTestCase {
    private var sut: Base64Servicing!

    override func setUp() {
        super.setUp()
        sut = Base64Service()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testEncodeDecodeRoundtrip() throws {
        let original = "Grillé mais pas cramé 🔥"
        let encoded = sut.encode(original)
        let decoded = try sut.decode(encoded)
        XCTAssertEqual(decoded, original)
    }

    func testEncodeKnownValue() {
        XCTAssertEqual(sut.encode("hello"), "aGVsbG8=")
    }

    func testDecodeKnownValue() throws {
        XCTAssertEqual(try sut.decode("aGVsbG8="), "hello")
    }

    func testDecodeInvalidInputThrows() {
        XCTAssertThrowsError(try sut.decode("not-valid-base64!!")) { error in
            XCTAssertEqual(error as? Base64Error, .invalidInput)
        }
    }

    func testDecodeEmptyStringThrows() {
        // An empty round-trip target is treated as invalid input rather
        // than silently succeeding with an empty result.
        XCTAssertThrowsError(try sut.decode(""))
    }
}
