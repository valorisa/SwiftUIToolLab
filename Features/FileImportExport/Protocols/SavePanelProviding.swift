import AppKit

/// Minimal abstraction over NSSavePanel, covering only the members
/// FileImportExportViewModel actually uses.
protocol SavePanelProviding {
    var canCreateDirectories: Bool { get set }
    var nameFieldStringValue: String { get set }
    var title: String { get set }
    var url: URL? { get }
    func runModal() -> NSApplication.ModalResponse
}
