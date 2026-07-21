import XCTest
@testable import SwiftUIToolLab

// MARK: - FileImportExportTests

final class FileImportExportTests: XCTestCase {

    private var service: FileImportExportService!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        service = FileImportExportService()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FIE_Integ_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        service = nil
        super.tearDown()
    }

    // MARK: - Cross-feature: Import -> Base64 -> Export

    func testImportText_Base64Encode_Export_Roundtrip() throws {
        let original = "Integration: Base64 + FileIO"
        let importURL = tempDir.appendingPathComponent("input.txt")
        try original.write(to: importURL, atomically: true, encoding: .utf8)

        let payload = try service.importFile(from: importURL)
        guard case .text(let importedText) = payload else {
            XCTFail("Expected text payload")
            return
        }

        let base64Service = Base64Service()
        let encodedText = base64Service.encode(importedText)

        let exportURL = tempDir.appendingPathComponent("encoded.clab")
        try service.exportPayload(.text(encodedText), to: exportURL, metadata: nil)

        let labFile = try service.importLabFile(from: exportURL)
        let recoveredEncodedText = String(data: labFile.payloadData ?? Data(), encoding: .utf8) ?? ""
        let decoded = try base64Service.decode(recoveredEncodedText)

        XCTAssertEqual(decoded, original)
    }

    // MARK: - Corruption robustness

    func testImportTruncatedLabFile_ThrowsGracefully() throws {
        let labFile = LabPayloadFile(
            version: 1,
            encryption: nil,
            payloadData: Data(repeating: 0x42, count: 1000),
            metadata: nil
        )
        let fullData = try JSONEncoder().encode(labFile)
        let truncated = fullData.prefix(fullData.count / 3)
        let url = tempDir.appendingPathComponent("truncated.clab")
        try truncated.write(to: url)

        XCTAssertThrowsError(try service.importLabFile(from: url)) { error in
            guard case FileImportExportError.deserializationFailed = error else {
                XCTFail("Expected deserializationFailed, got \(error)")
                return
            }
        }
    }

    func testImportLabFile_WrongVersion_Parses() throws {
        let json = """
        {"version":99,"encryption":null,"payloadData":"dGVzdA==","metadata":null}
        """
        let url = tempDir.appendingPathComponent("future.clab")
        try json.write(to: url, atomically: true, encoding: .utf8)

        let imported = try service.importLabFile(from: url)
        XCTAssertEqual(imported.version, 99)
    }

    // MARK: - Multiple exports

    func testMultipleExports_NoConflict() throws {
        let payload = Payload.text("sequential")
        let url1 = tempDir.appendingPathComponent("seq1.clab")
        let url2 = tempDir.appendingPathComponent("seq2.clab")

        try service.exportPayload(payload, to: url1, metadata: nil)
        try service.exportPayload(payload, to: url2, metadata: nil)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url1.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: url2.path))

        let f1 = try service.importLabFile(from: url1)
        let f2 = try service.importLabFile(from: url2)
        XCTAssertEqual(f1.payloadData, f2.payloadData)
    }
}
