import XCTest
@testable import SwiftUIToolLab

// MARK: - PipelineServiceTests

/// Validates PipelineService.run(_:through:) — a thin, deliberately
/// trivial fold over closures, not a new abstraction. No mocks: real
/// Base64Service/CryptoService instances, exactly as RoundtripTests
/// already does since Phase 6b. Base64Service.transform is passed
/// directly (its signature already matches (Payload) throws ->
/// Payload); CryptoService.transform(_:secret:) is partially applied
/// into a closure to carry the password.
final class PipelineServiceTests: XCTestCase {

    // MARK: - Empty pipeline

    func testPipelineEmpty_ReturnsInputUnchanged() throws {
        let pipeline = PipelineService()
        let input = Payload.text("unchanged")

        let result = try pipeline.run(input, through: [])

        guard case .text(let value) = result else {
            XCTFail("Expected .text payload")
            return
        }
        XCTAssertEqual(value, "unchanged")
    }

    // MARK: - Single transform

    func testPipelineSingleTransform_AppliesTransform() throws {
        let pipeline = PipelineService()
        let base64Service = Base64Service()
        let input = Payload.text("hello")

        let result = try pipeline.run(input, through: [base64Service.transform])

        guard case .text(let value) = result else {
            XCTFail("Expected .text payload")
            return
        }
        XCTAssertEqual(value, "aGVsbG8=")
    }

    // MARK: - Multiple transforms, order preserved

    func testPipelineMultipleTransforms_AppliesInOrder() throws {
        let pipeline = PipelineService()
        let base64Service = Base64Service()
        let cryptoService = CryptoService()
        let secret = Secret.password("pipeline-order-test")

        let steps: [(Payload) throws -> Payload] = [
            base64Service.transform,
            { try cryptoService.transform($0, secret: secret) }
        ]

        let result = try pipeline.run(.text("order matters"), through: steps)

        guard case .data = result else {
            XCTFail("Expected .data payload after Base64 -> Crypto (Crypto always outputs .data)")
            return
        }

        // Reverse order proves the sequence is honored, not just that
        // "a" transform ran: decrypting a payload that was
        // encode-then-encrypt requires decrypt-then-decode, in that
        // exact reverse order.
        let decrypted = try cryptoService.inverse(result, secret: secret)
        let decoded = try base64Service.inverse(decrypted)

        guard case .text(let value) = decoded else {
            XCTFail("Expected .text payload after full reversal")
            return
        }
        XCTAssertEqual(value, "order matters")
    }

    func testPipelineOrderIsNotInterchangeable() throws {
        // Encode-then-encrypt and encrypt-then-encode must NOT produce
        // an equivalent ciphertext shape — proves reduce isn't silently
        // reordering or short-circuiting steps.
        let pipeline = PipelineService()
        let base64Service = Base64Service()
        let cryptoService = CryptoService()
        let secret = Secret.password("order-distinctness-test")

        let encodeThenEncrypt: [(Payload) throws -> Payload] = [
            base64Service.transform,
            { try cryptoService.transform($0, secret: secret) }
        ]

        // Base64.transform requires a .text input, so encrypt-then-encode
        // is only meaningful the other way: encrypt (text -> data) then
        // attempt to feed that into Base64.transform, which requires
        // .text and must therefore fail — demonstrating the pipeline
        // genuinely executes steps in the given order rather than
        // reordering them into whatever would happen to compile.
        let encryptThenEncode: [(Payload) throws -> Payload] = [
            { try cryptoService.transform($0, secret: secret) },
            base64Service.transform
        ]

        let firstResult = try pipeline.run(.text("distinct order"), through: encodeThenEncrypt)
        guard case .data = firstResult else {
            XCTFail("Expected .data payload from encode-then-encrypt")
            return
        }

        XCTAssertThrowsError(try pipeline.run(.text("distinct order"), through: encryptThenEncode)) { error in
            XCTAssertEqual(error as? Base64Error, .invalidInput, "encrypt-then-encode must fail at the Base64 step, since Crypto output is .data, not .text")
        }
    }

    // MARK: - Error propagation

    func testPipelineTransformThrows_PropagatesError() throws {
        let pipeline = PipelineService()
        let cryptoService = CryptoService()

        let encrypted = try cryptoService.transform(.text("secret"), secret: .password("right-password"))

        let steps: [(Payload) throws -> Payload] = [
            { try cryptoService.inverse($0, secret: .password("wrong-password")) }
        ]

        XCTAssertThrowsError(try pipeline.run(encrypted, through: steps)) { error in
            XCTAssertEqual(error as? CryptoError, .invalidPassword)
        }
    }

    func testPipelineStopsAtFirstThrowingStep() throws {
        // A second step must never run once an earlier one throws —
        // reduce's short-circuit behavior on `try`, made explicit.
        let pipeline = PipelineService()
        let base64Service = Base64Service()
        var secondStepCalled = false

        let steps: [(Payload) throws -> Payload] = [
            { _ in throw Base64Error.invalidInput },
            { payload in
                secondStepCalled = true
                return try base64Service.transform(payload)
            }
        ]

        XCTAssertThrowsError(try pipeline.run(.text("never reached"), through: steps))
        XCTAssertFalse(secondStepCalled, "A step after a throwing step must never execute.")
    }

    // MARK: - Equivalence with the Phase 6b manual chain (RoundtripTests)

    func testPipelineEquivalenceWithManualChaining() throws {
        let original = "Pipeline vs manual chain: accents éà, emoji 🔧."
        let base64Service = Base64Service()
        let cryptoService = CryptoService()
        let secret = Secret.password("equivalence-test")

        // Manual chain, exactly as RoundtripTests.
        // testCompleteRoundtrip_ImportBase64EncryptExportImportDecryptDecode
        // performs it step by step since Phase 6b.
        let manualEncoded = try base64Service.transform(.text(original))
        let manualEncrypted = try cryptoService.transform(manualEncoded, secret: secret)

        // Same sequence via PipelineService.
        let pipeline = PipelineService()
        let pipelineEncrypted = try pipeline.run(.text(original), through: [
            base64Service.transform,
            { try cryptoService.transform($0, secret: secret) }
        ])

        guard case .data(let manualBytes) = manualEncrypted,
              case .data(let pipelineBytes) = pipelineEncrypted else {
            XCTFail("Expected .data payloads from both chains")
            return
        }

        // Ciphertext bytes themselves will differ (random salt/nonce per
        // AES-GCM call, confirmed non-deterministic since
        // CryptoServiceTests.testEncryptProducesDifferentOutputEachTime,
        // Phase 4) — so equivalence is proven by reversibility to the
        // same plaintext, not by byte-for-byte ciphertext equality.
        XCTAssertNotEqual(manualBytes, pipelineBytes, "Sanity check: AES-GCM must use a fresh salt per call, so identical plaintext must not yield identical ciphertext.")

        let manualDecrypted = try cryptoService.inverse(manualEncrypted, secret: secret)
        let manualDecoded = try base64Service.inverse(manualDecrypted)

        let pipelineDecrypted = try cryptoService.inverse(pipelineEncrypted, secret: secret)
        let pipelineDecoded = try base64Service.inverse(pipelineDecrypted)

        guard case .text(let manualResult) = manualDecoded,
              case .text(let pipelineResult) = pipelineDecoded else {
            XCTFail("Expected .text payloads after full reversal")
            return
        }

        XCTAssertEqual(manualResult, original)
        XCTAssertEqual(pipelineResult, original)
        XCTAssertEqual(manualResult, pipelineResult, "Manual chaining and PipelineService must be behaviorally equivalent.")
    }
}
