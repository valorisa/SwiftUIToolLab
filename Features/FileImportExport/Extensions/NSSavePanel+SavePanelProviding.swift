import AppKit

/// Wrapper around NSSavePanel conforming to SavePanelProviding.
/// See OpenPanelWrapper's doc comment for why a trivial extension
/// does not compile (ObjC class vs pure Swift protocol).
struct SavePanelWrapper: SavePanelProviding {
    private let panel: NSSavePanel

    init() {
        self.panel = NSSavePanel()
    }

    var canCreateDirectories: Bool {
        get { panel.canCreateDirectories }
        nonmutating set { panel.canCreateDirectories = newValue }
    }

    var nameFieldStringValue: String {
        get { panel.nameFieldStringValue }
        nonmutating set { panel.nameFieldStringValue = newValue }
    }

    var title: String {
        get { panel.title }
        nonmutating set { panel.title = newValue }
    }

    var url: URL? { panel.url }

    func runModal() -> NSApplication.ModalResponse {
        panel.runModal()
    }
}
