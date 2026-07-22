import XCTest
@testable import SwiftUIToolLab

// MARK: - RoundtripTests

/// Cross-feature roundtrip tests, exercising services directly (no
/// ViewModel, no NSOpenPanel/NSSavePanel — those stay untested per
/// D5, backlog v2). No Core/Pipeline orchestrator is used here either
/// (D2): each step is called explicitly, mirroring what a user would
/// do by switching tabs with the Workspace carrying the payload.
final class RoundtripTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Roundtrip_Tests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Base64 alone

    func testBase64Roundtrip_TransformInverse() throws {
        let service = Base64Service()
        let original = "Roundtrip Base64 seul : accents éà, emoji 🔤."

        let transformed = try service.transform(.text(original))
        let inverted = try service.inverse(transformed)

        guard case .text(let result) = inverted else {
            XCTFail("Expected .text payload")
            return
        }
        XCTAssertEqual(result, original)
    }

    // MARK: - Crypto alone

    func testCryptoRoundtrip_TransformInverseWithSecret() throws {
        let service = CryptoService()
        let secret = Secret.password("roundtrip-crypto-only")
        let original = "Roundtrip Crypto seul : accents éà, emoji 🔐."

        let transformed = try service.transform(.text(original), secret: secret)
        let inverted = try service.inverse(transformed, secret: secret)

        guard case .text(let result) = inverted else {
            XCTFail("Expected .text payload")
            return
        }
        XCTAssertEqual(result, original)
    }

    // MARK: - Export/Import alone

    func testExportImportRoundtrip_TextPayload() throws {
        let service = FileImportExportService()
        let original = "Roundtrip export/import seul."
        let url = tempDir.appendingPathComponent("export_import_only.clab")

        try service.exportPayload(.text(original), to: url, metadata: nil)
        let labFile = try service.importLabFile(from: url)

        let recovered = String(data: labFile.payloadData ?? Data(), encoding: .utf8)
        XCTAssertEqual(recovered, original)
    }

    // MARK: - Complete chain

    func testCompleteRoundtrip_ImportBase64EncryptExportImportDecryptDecode() throws {
        let original = "Roundtrip complet : accents éà, émojis 🔐🚀, symboles !@#."
        let importURL = tempDir.appendingPathComponent("complete_input.txt")
        try original.write(to: importURL, atomically: true, encoding: .utf8)

        let fileService = FileImportExportService()
        let base64Service = Base64Service()
        let cryptoService = CryptoService()
        let secret = Secret.password("phase6b-complete-roundtrip")

        // 1. Import
        let importedPayload = try fileService.importFile(from: importURL)
        guard case .text = importedPayload else {
            XCTFail("Expected text payload from import")
            return
        }

        // 2. Base64 transform
        let encoded = try base64Service.transform(importedPayload)

        // 3. Crypto transform
        let encrypted = try cryptoService.transform(encoded, secret: secret)
        guard case .data = encrypted else {
            XCTFail("Expected data payload from crypto transform (salt + combined)")
            return
        }

        // 4. Export .clab
        let exportURL = tempDir.appendingPathComponent("complete_output.clab")
        try fileService.exportPayload(encrypted, to: exportURL, metadata: nil)

        // 5. Import .clab
        let labFile = try fileService.importLabFile(from: exportURL)
        let reimported = Payload.data(labFile.payloadData ?? Data())

        // 6. Crypto inverse
        let decrypted = try cryptoService.inverse(reimported, secret: secret)

        // 7. Base64 inverse
        let decoded = try base64Service.inverse(decrypted)

        guard case .text(let result) = decoded else {
            XCTFail("Expected text payload after full roundtrip")
            return
        }
        XCTAssertEqual(result, original)
    }

    func testCompleteRoundtrip_WrongPasswordFailsAtDecrypt() throws {
        let original = "Should not decrypt with the wrong password."
        let importURL = tempDir.appendingPathComponent("complete_wrong_pw.txt")
        try original.write(to: importURL, atomically: true, encoding: .utf8)

        let fileService = FileImportExportService()
        let base64Service = Base64Service()
        let cryptoService = CryptoService()

        let importedPayload = try fileService.importFile(from: importURL)
        let encoded = try base64Service.transform(importedPayload)
        let encrypted = try cryptoService.transform(encoded, secret: .password("right-password"))

        let exportURL = tempDir.appendingPathComponent("complete_wrong_pw.clab")
        try fileService.exportPayload(encrypted, to: exportURL, metadata: nil)

        let labFile = try fileService.importLabFile(from: exportURL)
        let reimported = Payload.data(labFile.payloadData ?? Data())

        XCTAssertThrowsError(
            try cryptoService.inverse(reimported, secret: .password("wrong-password"))
        ) { error in
            XCTAssertEqual(error as? CryptoError, .invalidPassword)
        }
    }
}
