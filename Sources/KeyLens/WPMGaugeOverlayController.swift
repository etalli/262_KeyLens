import AppKit
import SwiftUI

// MARK: - WPMGaugeOverlayView

/// Compact floating speedometer — wraps SpeedometerView in a dark translucent pill.
private struct WPMGaugeOverlayView: View {
    var body: some View {
        SpeedometerView()
            .scaleEffect(0.62)
            // Fix the frame to the scaled content so the panel sizes correctly.
            // SpeedometerView is ~280px tall; at 0.62 scale that is ~174px.
            .frame(width: 162, height: 178)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.60))
            )
            .padding(4)
    }
}

// MARK: - WPMGaugeOverlayController

final class WPMGaugeOverlayController: NSObject, NSWindowDelegate {
    static let shared = WPMGaugeOverlayController()
    static let enabledKey = "wpmGaugeOverlayEnabled"

    private let panel: NSPanel
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
        panel = NSPanel(
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
