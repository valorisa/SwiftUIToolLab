import XCTest
@testable import SwiftUIToolLab

// MARK: - CorruptionTests

/// Validates graceful, typed error handling when a .clab file is
/// truncated, tampered with, empty, missing, or carries an
/// unsupported/future version number.
final class CorruptionTests: XCTestCase {

    private var service: FileImportExportService!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        service = FileImportExportService()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Corruption_Tests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        service = nil
        super.tearDown()
    }

    func testTruncatedLabFile_ThrowsDeserializationFailed() throws {
        let labFile = LabPayloadFile(
            version: 1,
            encryption: nil,
            payloadData: Data(repeating: 0x42, count: 2000),
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

    func testInvalidJSON_ThrowsDeserializationFailed() throws {
        let url = tempDir.appendingPathComponent("invalid.clab")
        try "not valid json {{{".write(to: url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try service.importLabFile(from: url)) { error in
            guard case FileImportExportError.deserializationFailed = error else {
                XCTFail("Expected deserializationFailed, got \(error)")
                return
            }
        }
    }

    func testFutureVersion_ParsesSuccessfully() throws {
        // LabPayloadFile.version is a plain Int with no validation —
        // a "future" version is expected to parse, not throw. This
        // documents current behavior rather than asserting a
        // versioning policy that doesn't exist yet.
        let json = """
        {"version":99,"encryption":null,"payloadData":"dGVzdA==","metadata":null}
        """
        let url = tempDir.appendingPathComponent("future_version.clab")
        try json.write(to: url, atomically: true, encoding: .utf8)

        let imported = try service.importLabFile(from: url)
        XCTAssertEqual(imported.version, 99)
        XCTAssertEqual(String(data: imported.payloadData ?? Data(), encoding: .utf8), "test")
    }

    func testEmptyFile_ThrowsEmptyFile() throws {
        let url = tempDir.appendingPathComponent("empty.clab")
        try Data().write(to: url)

        XCTAssertThrowsError(try service.importLabFile(from: url)) { error in
            XCTAssertEqual(error as? FileImportExportError, .emptyFile(url))
        }
    }

    func testNonExistentFile_ThrowsFileNotFound() {
        let url = tempDir.appendingPathComponent("does-not-exist.clab")

        XCTAssertThrowsError(try service.importLabFile(from: url)) { error in
            XCTAssertEqual(error as? FileImportExportError, .fileNotFound(url))
        }
    }
}
