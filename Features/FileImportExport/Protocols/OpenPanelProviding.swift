import AppKit

/// Minimal abstraction over NSOpenPanel, covering only the
/// members FileImportExportViewModel actually uses. Deliberately
/// does NOT mirror the full NSOpenPanel API (allowsMultipleSelection
/// is intentionally omitted — the VM always sets it to false and
/// never reads the plural `urls` property, so including it here
/// would be unused surface area).
protocol OpenPanelProviding {
    var canChooseFiles: Bool { get set }
    var canChooseDirectories: Bool { get set }
    var title: String { get set }
    var url: URL? { get }
    func runModal() -> NSApplication.ModalResponse
}
