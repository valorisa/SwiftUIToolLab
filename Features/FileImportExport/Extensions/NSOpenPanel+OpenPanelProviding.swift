import AppKit

/// NSOpenPanel already exposes every member OpenPanelProviding
/// requires with matching signatures — canChooseFiles/
/// canChooseDirectories are genuinely NSOpenPanel-only in AppKit (not
/// shared with NSSavePanel, despite NSOpenPanel inheriting from
/// NSSavePanel), and title/url/runModal() come from the NSWindow/
/// NSSavePanel hierarchy. No extra code needed beyond the conformance
/// declaration itself.
extension NSOpenPanel: OpenPanelProviding {}
