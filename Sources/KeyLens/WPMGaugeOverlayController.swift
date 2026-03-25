import AppKit
import SwiftUI

// MARK: - WPMNumberViewModel

/// Spring-damper WPM model — mirrors SpeedometerViewModel but is internal so the overlay can own it.
private final class WPMNumberViewModel: ObservableObject {
    @Published var displayWPM: Double = 0

    private var targetWPM:  Double = 0
    private var velocity:   Double = 0
    private var lastKeystrokeDate: Date = .distantPast

    private var decayTimer:  Timer?
    private var springTimer: Timer?
    private var observer:    NSObjectProtocol?

    private static let springK:     Double = 12.0
    private static let damping:     Double = 4.5
    private static let springDt:    Double = 1.0 / 60.0
    private static let decayFactor: Double = 0.65

    init() {
        decayTimer = Timer.scheduledTimer(withTimeInterval: AppConfiguration.liveRefreshIntervalSecs, repeats: true) { [weak self] _ in
            self?.tick()
        }
        springTimer = Timer.scheduledTimer(withTimeInterval: Self.springDt, repeats: true) { [weak self] _ in
            self?.springTick()
        }
        observer = NotificationCenter.default.addObserver(
            forName: .keystrokeInput, object: nil, queue: .main
        ) { [weak self] _ in
            self?.lastKeystrokeDate = Date()
            self?.targetWPM = KeyCountStore.shared.rollingWPM()
        }
    }

    deinit {
        decayTimer?.invalidate()
        springTimer?.invalidate()
        if let obs = observer { NotificationCenter.default.removeObserver(obs) }
    }

    private func tick() {
        guard Date().timeIntervalSince(lastKeystrokeDate) > AppConfiguration.speedometerKeystrokeCooldownSecs else { return }
        targetWPM = max(0, targetWPM * Self.decayFactor)
    }

    private func springTick() {
        let dt = Self.springDt
        velocity   += (targetWPM - displayWPM) * Self.springK * dt - velocity * Self.damping * dt
        displayWPM  = max(0, displayWPM + velocity * dt)
    }
}

// MARK: - WPMGaugeOverlayView

/// Compact floating WPM number display — shows the live spring-smoothed WPM in a dark pill.
private struct WPMGaugeOverlayView: View {
    @StateObject private var vm = WPMNumberViewModel()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(verbatim: "\(Int(vm.displayWPM))")
                .font(.system(size: 42, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(L10n.shared.speedometerWPMLabel)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
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
        let s = panel.contentView?.fittingSize ?? NSSize(width: 140, height: 70)
        let size = NSSize(width: max(s.width, 100), height: max(s.height, 50))

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
