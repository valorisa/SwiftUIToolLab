import AppKit

/// Wrapper around NSOpenPanel conforming to OpenPanelProviding.
/// A trivial extension (extension NSOpenPanel: OpenPanelProviding {})
/// does NOT compile: the Swift compiler cannot automatically infer
/// conformance to a pure Swift protocol for an Objective-C class
/// (NSOpenPanel is AppKit/ObjC). This struct bridges the gap,
/// forwarding each protocol member to the wrapped panel.
/// `nonmutating set` because the setters mutate the wrapped panel
/// (a reference type), not the wrapper struct itself.
struct OpenPanelWrapper: OpenPanelProviding {
    private let panel: NSOpenPanel

    init() {
        self.panel = NSOpenPanel()
    }

    var canChooseFiles: Bool {
        get { panel.canChooseFiles }
        nonmutating set { panel.canChooseFiles = newValue }
    }

    var canChooseDirectories: Bool {
        get { panel.canChooseDirectories }
        nonmutating set { panel.canChooseDirectories = newValue }
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
