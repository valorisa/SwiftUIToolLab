import XCTest
@testable import SwiftUIToolLab

final class FileImportExportServiceTests: XCTestCase {

    private var service: FileImportExportService!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        service = FileImportExportService()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FIE_Tests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        service = nil
        super.tearDown()
    }

    func testImportTextFile_Success() throws {
        let content = "Hello, SwiftUIToolLab!"
        let url = tempDir.appendingPathComponent("test.txt")
        try content.write(to: url, atomically: true, encoding: .utf8)

        let payload = try service.importFile(from: url)

        guard case .text(let text) = payload else {
            XCTFail("Expected .text payload, got \(payload)")
            return
        }
        XCTAssertEqual(text, content)
    }

    func testImportBinaryFile_Success() throws {
        let bytes: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF]
        let data = Data(bytes)
        let url = tempDir.appendingPathComponent("image.png")
        try data.write(to: url)

        let payload = try service.importFile(from: url)

        guard case .data(let imported) = payload else {
            XCTFail("Expected .data payload, got \(payload)")
            return
        }
        XCTAssertEqual(imported, data)
    }

    func testImportFile_NotFound_Throws() {
        let url = tempDir.appendingPathComponent("nonexistent.txt")
        XCTAssertThrowsError(try service.importFile(from: url)) { error in
            XCTAssertEqual(error as? FileImportExportError, .fileNotFound(url))
        }
    }

    func testImportEmptyFile_Throws() throws {
        let url = tempDir.appendingPathComponent("empty.txt")
        try "".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try service.importFile(from: url)) { error in
            XCTAssertEqual(error as? FileImportExportError, .emptyFile(url))
        }
    }

    func testExportTextPayload_Success() throws {
        let payload = Payload.text("Export me!")
        let url = tempDir.appendingPathComponent("out.clab")

        try service.exportPayload(payload, to: url, metadata: nil)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(LabPayloadFile.self, from: data)
        XCTAssertEqual(decoded.version, 1)
        XCTAssertNil(decoded.encryption)
        XCTAssertEqual(String(data: decoded.payloadData ?? Data(), encoding: .utf8), "Export me!")
    }

    func testExportBinaryPayload_Success() throws {
        let bytes = Data([0x01, 0x02, 0x03, 0x04])
        let payload = Payload.data(bytes)
        let url = tempDir.appendingPathComponent("binary.clab")

        try service.exportPayload(payload, to: url, metadata: nil)

        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(LabPayloadFile.self, from: data)
        XCTAssertEqual(decoded.payloadData, bytes)
    }

    func testExportUnknownPayload_Throws() {
        let url = tempDir.appendingPathComponent("fail.clab")
        XCTAssertThrowsError(try service.exportPayload(.unknown, to: url, metadata: nil)) { error in
            guard case FileImportExportError.serializationFailed = error else {
                XCTFail("Expected serializationFailed, got \(error)")
                return
            }
        }
    }

    func testRoundtrip_Text() throws {
        let original = "Roundtrip: émojis 🚀 accents."
        let importURL = tempDir.appendingPathComponent("rt.txt")
        try original.write(to: importURL, atomically: true, encoding: .utf8)

        let payload = try service.importFile(from: importURL)
        let exportURL = tempDir.appendingPathComponent("rt.clab")
        try service.exportPayload(payload, to: exportURL, metadata: nil)

        let labFile = try service.importLabFile(from: exportURL)
        let recovered = String(data: labFile.payloadData ?? Data(), encoding: .utf8)
        XCTAssertEqual(recovered, original)
    }

    func testRoundtrip_Binary() throws {
        let original = Data((0...255).map { UInt8($0) })
        let importURL = tempDir.appendingPathComponent("rt.bin")
        try original.write(to: importURL)

        let payload = try service.importFile(from: importURL)
        let exportURL = tempDir.appendingPathComponent("rt_bin.clab")
        try service.exportPayload(payload, to: exportURL, metadata: nil)

        let labFile = try service.importLabFile(from: exportURL)
        XCTAssertEqual(labFile.payloadData, original)
    }

    func testImportLabFile_CorruptedJSON_Throws() throws {
        let url = tempDir.appendingPathComponent("corrupt.clab")
        try "not valid json {{{".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try service.importLabFile(from: url)) { error in
            guard case FileImportExportError.deserializationFailed = error else {
                XCTFail("Expected deserializationFailed, got \(error)")
                return
            }
        }
    }

    func testImportLabFile_ValidStructure() throws {
        let labFile = LabPayloadFile(
            version: 1,
            encryption: nil,
            payloadData: "test".data(using: .utf8),
            metadata: nil
        )
        let url = tempDir.appendingPathComponent("valid.clab")
        let data = try JSONEncoder().encode(labFile)
        try data.write(to: url)

        let imported = try service.importLabFile(from: url)
        XCTAssertEqual(imported.version, 1)
        XCTAssertEqual(String(data: imported.payloadData ?? Data(), encoding: .utf8), "test")
    }

    func testValidateFile_NonExistent_ReturnsFalse() {
        let url = tempDir.appendingPathComponent("ghost.txt")
        XCTAssertFalse(service.validateFile(at: url))
    }

    func testValidateFile_ValidFile_ReturnsTrue() throws {
        let url = tempDir.appendingPathComponent("valid.txt")
        try "content".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertTrue(service.validateFile(at: url))
    }
}
