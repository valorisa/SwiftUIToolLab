import XCTest
@testable import SwiftUIToolLab

// MARK: - Test double for a failing service

/// Minimal FileImportExportServicing double whose importFile(from:)
/// always throws a caller-supplied error. The other three methods are
/// never exercised by the tests that use this double, so they simply
/// fail loudly if ever called by mistake — that's a signal the test
/// setup is wrong, not a silently-passing gap.
private final class ThrowingFileImportExportService: FileImportExportServicing {
    private let errorToThrow: FileImportExportError

    init(errorToThrow: FileImportExportError) {
        self.errorToThrow = errorToThrow
    }

    func importFile(from url: URL) throws -> Payload {
        throw errorToThrow
    }

    func exportPayload(_ payload: Payload, to url: URL, metadata: PayloadMetadata?) throws {
        XCTFail("exportPayload should not be called in this test")
    }

    func importLabFile(from url: URL) throws -> LabPayloadFile {
        XCTFail("importLabFile should not be called in this test")
        throw FileImportExportError.emptyFile(url)
    }

    func validateFile(at url: URL) -> Bool {
        XCTFail("validateFile should not be called in this test")
        return false
    }
}

// MARK: - FileImportExportViewModelTests

@MainActor
final class FileImportExportViewModelTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FIE_VM_Tests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    // MARK: - importFile()

    func testImportFile_Success_UpdatesPayloadAndFileInfoAndWorkspace() throws {
        let content = "Hello from a mocked NSOpenPanel"
        let fileURL = tempDir.appendingPathComponent("mocked_import.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let workspace = Workspace()
        let viewModel = FileImportExportViewModel(
            service: FileImportExportService(),
            workspace: workspace,
            openPanelFactory: { MockOpenPanel(urlToReturn: fileURL, modalResponse: .OK) },
            savePanelFactory: { MockSavePanel(urlToReturn: nil) }
        )

        viewModel.importFile()

        guard case .text(let text) = viewModel.importedPayload else {
            XCTFail("Expected .text payload, got \(viewModel.importedPayload)")
            return
        }
        XCTAssertEqual(text, content)
        XCTAssertEqual(viewModel.importedFileInfo?.fileName, "mocked_import.txt")
        XCTAssertNil(viewModel.errorMessage)

        XCTAssertEqual(workspace.history.count, 1, "A successful import must be recorded in Workspace history.")
        guard case .text(let workspaceText) = workspace.currentPayload else {
            XCTFail("Expected Workspace.currentPayload to reflect the imported text")
            return
        }
        XCTAssertEqual(workspaceText, content)
    }

    func testImportFile_PanelCancelled_LeavesStateUntouched() {
        let workspace = Workspace()
        let viewModel = FileImportExportViewModel(
            service: FileImportExportService(),
            workspace: workspace,
            openPanelFactory: { MockOpenPanel(urlToReturn: nil, modalResponse: .cancel) },
            savePanelFactory: { MockSavePanel(urlToReturn: nil) }
        )

        viewModel.importFile()

        if case .unknown = viewModel.importedPayload {
            // expected: nothing changed
        } else {
            XCTFail("Expected importedPayload to remain .unknown after a cancelled panel")
        }
        XCTAssertNil(viewModel.importedFileInfo)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(workspace.history.count, 0, "A cancelled import must not touch the Workspace.")
    }

    func testImportFile_ServiceThrows_SetsErrorMessage() {
        let workspace = Workspace()
        let missingURL = tempDir.appendingPathComponent("does-not-exist.txt")
        let viewModel = FileImportExportViewModel(
            service: ThrowingFileImportExportService(errorToThrow: .fileNotFound(missingURL)),
            workspace: workspace,
            openPanelFactory: { MockOpenPanel(urlToReturn: missingURL, modalResponse: .OK) },
            savePanelFactory: { MockSavePanel(urlToReturn: nil) }
        )

        viewModel.importFile()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.showError)
        XCTAssertEqual(workspace.history.count, 0, "A failed import must not touch the Workspace.")
    }

    // MARK: - importLabFile()

    func testImportLabFile_Success_UpdatesPayloadAndWorkspace() throws {
        let labFile = LabPayloadFile(
            version: 1,
            encryption: nil,
            payloadData: "lab file content".data(using: .utf8),
            metadata: nil
        )
        let fileURL = tempDir.appendingPathComponent("mocked_import.clab")
        let data = try JSONEncoder().encode(labFile)
        try data.write(to: fileURL)

        let workspace = Workspace()
        let viewModel = FileImportExportViewModel(
            service: FileImportExportService(),
            workspace: workspace,
            openPanelFactory: { MockOpenPanel(urlToReturn: fileURL, modalResponse: .OK) },
            savePanelFactory: { MockSavePanel(urlToReturn: nil) }
        )

        viewModel.importLabFile()

        guard case .data(let importedData) = viewModel.importedPayload else {
            XCTFail("Expected .data payload, got \(viewModel.importedPayload)")
            return
        }
        XCTAssertEqual(String(data: importedData, encoding: .utf8), "lab file content")
        XCTAssertEqual(workspace.history.count, 1)
    }

    // MARK: - exportPayload()

    func testExportPayload_Success_SetsLastExportURL() throws {
        let content = "Ready to export"
        let sourceURL = tempDir.appendingPathComponent("source.txt")
        try content.write(to: sourceURL, atomically: true, encoding: .utf8)

        let workspace = Workspace()
        let viewModel = FileImportExportViewModel(
            service: FileImportExportService(),
            workspace: workspace,
            openPanelFactory: { MockOpenPanel(urlToReturn: sourceURL, modalResponse: .OK) },
            savePanelFactory: { [tempDir] in
                MockSavePanel(urlToReturn: tempDir!.appendingPathComponent("exported.clab"), modalResponse: .OK)
            }
        )

        viewModel.importFile() // populates importedPayload from the mocked open panel
        viewModel.exportPayload()

        XCTAssertEqual(viewModel.lastExportURL?.lastPathComponent, "exported.clab")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.appendingPathComponent("exported.clab").path))
    }

    func testExportPayload_NoPayloadImported_SetsError() {
        let viewModel = FileImportExportViewModel(
            service: FileImportExportService(),
            workspace: Workspace(),
            openPanelFactory: { MockOpenPanel(urlToReturn: nil) },
            savePanelFactory: { MockSavePanel(urlToReturn: nil) }
        )

        viewModel.exportPayload()

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.showError)
        XCTAssertNil(viewModel.lastExportURL)
    }

    func testExportPayload_PanelCancelled_LeavesLastExportURLNil() throws {
        let content = "Ready to export"
        let sourceURL = tempDir.appendingPathComponent("source.txt")
        try content.write(to: sourceURL, atomically: true, encoding: .utf8)

        let viewModel = FileImportExportViewModel(
            service: FileImportExportService(),
            workspace: Workspace(),
            openPanelFactory: { MockOpenPanel(urlToReturn: sourceURL, modalResponse: .OK) },
            savePanelFactory: { MockSavePanel(urlToReturn: nil, modalResponse: .cancel) }
        )

        viewModel.importFile()
        viewModel.exportPayload()

        XCTAssertNil(viewModel.lastExportURL)
        XCTAssertNil(viewModel.errorMessage, "A cancelled save panel is not an error condition.")
    }
}
