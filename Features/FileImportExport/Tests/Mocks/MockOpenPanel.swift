import AppKit
@testable import SwiftUIToolLab

/// Test double for OpenPanelProviding. A class (not a struct) so it
/// matches the reference semantics of a real NSOpenPanel: the
/// ViewModel receives the same instance it configures and later reads
/// `.url` from, exactly as it would with the real panel.
final class MockOpenPanel: OpenPanelProviding {
    var canChooseFiles: Bool = false
    var canChooseDirectories: Bool = false
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
