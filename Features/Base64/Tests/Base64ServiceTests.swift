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

    // MARK: - Existing String-based API (unchanged since Phase 2)

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
        XCTAssertThrowsError(try sut.decode(""))
    }

    // MARK: - Core protocol conformance (ReversibleTransformer) — Phase 6a

    func testTransformInverseRoundtripOnPayload() throws {
        let original = "Grillé mais pas cramé 🔥"
        let transformed = try sut.transform(.text(original))
        let inverted = try sut.inverse(transformed)

        guard case .text(let result) = inverted else {
            XCTFail("Expected .text payload after inverse")
            return
        }
        XCTAssertEqual(result, original)
    }

    func testTransformOnNonTextPayloadThrows() {
        XCTAssertThrowsError(try sut.transform(.data(Data([0x01])))) { error in
            XCTAssertEqual(error as? Base64Error, .invalidInput)
        }
    }

    func testInverseOnInvalidPayloadThrows() {
        XCTAssertThrowsError(try sut.inverse(.text("not-valid-base64!!"))) { error in
            XCTAssertEqual(error as? Base64Error, .invalidInput)
        }
    }
}
