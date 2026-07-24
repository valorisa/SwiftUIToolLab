import AppKit
@testable import SwiftUIToolLab

/// Test double for SavePanelProviding. See MockOpenPanel's doc comment
/// for why this is a class rather than a struct.
final class MockSavePanel: SavePanelProviding {
    var canCreateDirectories: Bool = false
    var nameFieldStringValue: String = ""
    var title: String = ""
    let url: URL?

    private let modalResponseToReturn: NSApplication.ModalResponse
    private(set) var runModalCallCount = 0

    init(urlToReturn: URL?, modalResponse: NSApplication.ModalResponse = .OK) {
        self.url = urlToReturn
        self.modalResponseToReturn = modalResponse
    }

    func runModal() -> NSApplication.ModalResponse {
        runModalCallCount += 1
        return modalResponseToReturn
    }
}
