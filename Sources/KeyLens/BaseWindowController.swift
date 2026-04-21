import AppKit

// MARK: - BaseWindowController

/// Shared base for all singleton NSWindowController subclasses.
/// Eliminates repeated `required init?(coder:)` and the center-on-first-show + activate pattern.
class BaseWindowController: NSWindowController {

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Centers the window on first appearance, then shows it and activates the app.
    func showAndActivate() {
        if !(window?.isVisible ?? false) { window?.center() }
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
