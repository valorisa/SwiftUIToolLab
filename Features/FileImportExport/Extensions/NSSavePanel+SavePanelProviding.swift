import AppKit

/// NSSavePanel already exposes every member SavePanelProviding
/// requires with matching signatures. No extra code needed beyond the
/// conformance declaration itself.
extension NSSavePanel: SavePanelProviding {}
