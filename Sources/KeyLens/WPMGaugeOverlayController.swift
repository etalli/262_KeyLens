import AppKit
import SwiftUI

// MARK: - WPMGaugeOverlayView

/// Compact floating speedometer — arc gauge + WPM number, scaled to fit a small panel.
private struct WPMGaugeOverlayView: View {
    var body: some View {
        SpeedometerView()
            .colorScheme(.dark)   // force white text so it's readable on the dark background
            .scaleEffect(0.62)
            // SpeedometerView is ~280 px tall total (canvas 200 + number ~50 + peak ~20 + spacing).
            // At 0.62 scale that is ~174 px; add 8 px padding margin.
            .frame(width: 162, height: 178)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.60))
            )
            .padding(4)
    }
}

// MARK: - WPMGaugePanel

/// Custom NSPanel subclass that shows a context menu on right-click.
private final class WPMGaugePanel: NSPanel {
    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()
        let item = NSMenuItem(
            title: L10n.shared.hideSpeedometer,
            action: #selector(WPMGaugeOverlayController.hideFromMenu),
            keyEquivalent: ""
        )
        item.target = WPMGaugeOverlayController.shared
        menu.addItem(item)
        NSMenu.popUpContextMenu(menu, with: event, for: contentView ?? self.contentView!)
    }
}

// MARK: - WPMGaugeOverlayController

final class WPMGaugeOverlayController: NSObject, NSWindowDelegate {
    static let shared = WPMGaugeOverlayController()
    static let enabledKey = "wpmGaugeOverlayEnabled"

    private let panel: WPMGaugePanel
    private let hostVC: NSHostingController<WPMGaugeOverlayView>

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Self.enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.enabledKey)
            if newValue {
                placePanel()
                panel.orderFront(nil)
            } else {
                panel.orderOut(nil)
            }
        }
    }

    private override init() {
        panel = WPMGaugePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        hostVC = NSHostingController(rootView: WPMGaugeOverlayView())
        super.init()

        panel.contentViewController = hostVC
        panel.delegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositionPanel),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        if isEnabled {
            placePanel()
            panel.orderFront(nil)
        }
    }

    // MARK: - Context Menu Actions

    @objc func hideFromMenu() {
        isEnabled = false
    }

    // MARK: - Positioning

    @objc private func repositionPanel() {
        guard panel.isVisible else { return }
        placePanel()
    }

    private func placePanel() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let f = screen.visibleFrame
        panel.contentView?.layoutSubtreeIfNeeded()
        let s = panel.contentView?.fittingSize ?? NSSize(width: 170, height: 186)
        let size = NSSize(width: max(s.width, 170), height: max(s.height, 186))

        // Restore saved drag position, or default to bottom-right corner.
        let defaults = UserDefaults.standard
        if let cx = defaults.object(forKey: "wpmGaugeOverlayX") as? Double,
           let cy = defaults.object(forKey: "wpmGaugeOverlayY") as? Double {
            panel.setFrame(NSRect(origin: NSPoint(x: cx, y: cy), size: size), display: true)
        } else {
            let margin: CGFloat = 20
            let origin = NSPoint(
                x: f.maxX - size.width - margin,
                y: f.minY + margin
            )
            panel.setFrame(NSRect(origin: origin, size: size), display: true)
        }
    }

    // NSWindowDelegate: persist position after drag.
    func windowDidMove(_ notification: Notification) {
        UserDefaults.standard.set(Double(panel.frame.origin.x), forKey: "wpmGaugeOverlayX")
        UserDefaults.standard.set(Double(panel.frame.origin.y), forKey: "wpmGaugeOverlayY")
    }
}
