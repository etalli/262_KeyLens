import AppKit
import SwiftUI

// MARK: - SpeedometerSize

enum SpeedometerSize: String, CaseIterable {
    case small
    case medium
    case large

    static let defaultsKey = UDKeys.speedometerSize

    /// Scale factor applied to SpeedometerView (native ~280 px tall).
    var scale: CGFloat {
        switch self {
        case .small:  return 0.62
        case .medium: return 0.85
        case .large:  return 1.10
        }
    }

    /// Frame size for the overlay panel at this scale.
    var frameSize: CGSize {
        let base = CGSize(width: 162, height: 178)
        let ratio = scale / 0.62
        return CGSize(width: (base.width * ratio).rounded(), height: (base.height * ratio).rounded())
    }

    var displayName: String {
        let l = L10n.shared
        switch self {
        case .small:  return l.speedometerSizeSmall
        case .medium: return l.speedometerSizeMedium
        case .large:  return l.speedometerSizeLarge
        }
    }
}

// MARK: - WPMGaugeOverlayView

/// Compact floating speedometer — arc gauge + WPM number, scaled to fit a small panel.
private struct WPMGaugeOverlayView: View {
    @ObservedObject private var themeStore = ThemeStore.shared
    @AppStorage(SpeedometerSize.defaultsKey) private var sizeRaw: String = SpeedometerSize.small.rawValue

    private var size: SpeedometerSize { SpeedometerSize(rawValue: sizeRaw) ?? .small }

    /// Resolve the effective color scheme, honoring the user's app appearance setting.
    private var resolvedScheme: ColorScheme {
        switch themeStore.appearance {
        case .dark:  return .dark
        case .light: return .light
        case .system:
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? .dark : .light
        }
    }

    var body: some View {
        let fs = size.frameSize
        SpeedometerView()
            .colorScheme(resolvedScheme)
            .scaleEffect(size.scale)
            // SpeedometerView is ~280 px tall total (canvas 200 + number ~50 + peak ~20 + spacing).
            // Frame is scaled proportionally from the small baseline (162 × 178).
            .frame(width: fs.width, height: fs.height)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(resolvedScheme == .dark
                          ? Color.black.opacity(0.60)
                          : Color.white.opacity(0.80))
            )
            .padding(4)
    }
}

// MARK: - WPMGaugePanel

/// Custom NSPanel subclass that shows a context menu on right-click.
private final class WPMGaugePanel: NSPanel {
    override func rightMouseDown(with event: NSEvent) {
        let l = L10n.shared
        let menu = NSMenu()

        // Size submenu
        let currentSize = SpeedometerSize(rawValue: UserDefaults.standard.string(forKey: SpeedometerSize.defaultsKey) ?? "") ?? .small
        let sizeSubmenu = NSMenu()
        for option in SpeedometerSize.allCases {
            let sizeItem = NSMenuItem(title: option.displayName, action: #selector(WPMGaugeOverlayController.setSizeFromMenu(_:)), keyEquivalent: "")
            sizeItem.target = WPMGaugeOverlayController.shared
            sizeItem.representedObject = option.rawValue
            sizeItem.state = option == currentSize ? .on : .off
            sizeSubmenu.addItem(sizeItem)
        }
        let sizeMenuItem = NSMenuItem(title: l.speedometerSizeMenuTitle, action: nil, keyEquivalent: "")
        sizeMenuItem.submenu = sizeSubmenu
        menu.addItem(sizeMenuItem)

        menu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: l.hideSpeedometer,
            action: #selector(WPMGaugeOverlayController.hideFromMenu),
            keyEquivalent: ""
        )
        hideItem.target = WPMGaugeOverlayController.shared
        menu.addItem(hideItem)

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

    @objc func setSizeFromMenu(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String else { return }
        UserDefaults.standard.set(raw, forKey: SpeedometerSize.defaultsKey)
        // Resize the panel to match the new size.
        let size = SpeedometerSize(rawValue: raw) ?? .small
        let fs = size.frameSize
        let panelSize = NSSize(width: fs.width + 8, height: fs.height + 8)
        var frame = panel.frame
        frame.size = panelSize
        panel.setFrame(frame, display: true)
    }

    // MARK: - Positioning

    @objc private func repositionPanel() {
        guard panel.isVisible else { return }
        placePanel()
    }

    private func placePanel() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let f = screen.visibleFrame
        let sizeOption = SpeedometerSize(rawValue: UserDefaults.standard.string(forKey: SpeedometerSize.defaultsKey) ?? "") ?? .small
        let fs = sizeOption.frameSize
        let size = NSSize(width: fs.width + 8, height: fs.height + 8)

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
        UserDefaults.standard.set(Double(panel.frame.origin.x), forKey: UDKeys.wpmGaugeOverlayX)
        UserDefaults.standard.set(Double(panel.frame.origin.y), forKey: UDKeys.wpmGaugeOverlayY)
    }
}
