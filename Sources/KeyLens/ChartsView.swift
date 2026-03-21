import SwiftUI
import Charts
import KeyLensCore

// MARK: - ChartsView

struct ChartsView: View {
    @ObservedObject var model: ChartDataModel
    @ObservedObject var theme = ThemeStore.shared

    @AppStorage("selectedChartTab") var selectedTab: ChartTab = .summary
    @AppStorage("frequentChartsSortDescending") var sortDescending: Bool = true

    /// Title of the section whose clipboard copy just succeeded (cleared after 1.5 s).
    @State var copiedSection: String? = nil
    /// Key filter for the Slow Bigrams chart (Issue #99). Empty string = no filter.
    @State var slowBigramKeyFilter: String = ""
    /// Title of the section whose image save just succeeded (cleared after 1.5 s).
    @State var savedSection: String? = nil
    /// Stores each chart section's SwiftUI global frame and the Charts NSWindow reference.
    @State var snapperStore = SnapperStore()
    /// Timer that drives real-time refresh on the Live tab.
    @State var liveTimer: Timer? = nil
    /// Selected finger filter for the Slow Bigrams chart. nil = All (Issue #153).
    @State var slowBigramFingerFilter: String? = nil
    /// Whether a manual WPM session is active (Issue #150).
    @State var isMeasuringWPM: Bool = false
    /// Result of the last completed WPM session.
    @State var wpmResult: (wpm: Double, duration: TimeInterval, keystrokes: Int)? = nil
    /// Current hotkey display string (Issue #151).
    @State var wpmHotkeyDisplay: String = WPMHotkeyManager.shared.displayString
    /// Whether the app is waiting for the user to press a new hotkey.
    @State var isRecordingHotkey: Bool = false
    /// Target key for the Key Transition analysis section (Issue #98).
    @State var keyTransitionTarget: String = ""
    /// Selected training session length — persisted across launches.
    @AppStorage("trainingSessionLength") var sessionLength: SessionLength = .normal
    /// Changed each time the user taps "New Session" to force InteractivePracticeView to reset.
    @State var trainingResetToken = UUID()
    /// Controls the confirmation alert for clearing training history.
    @State var showClearHistoryAlert = false

    // MARK: - Issue #62: Period Comparison state
    /// Which preset is selected (0 = custom, 1 = this week vs last, 2 = this month vs last month)
    @State var comparisonPreset: Int = 1
    @State var comparisonAStart: Date = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State var comparisonAEnd: Date   = Date()
    @State var comparisonBStart: Date = Calendar.current.date(byAdding: .day, value: -13, to: Date()) ?? Date()
    @State var comparisonBEnd: Date   = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

    /// Fixed width keeps the live IKI snapshot compact when copying to the clipboard.
    /// 最新20打鍵グラフのコピーサイズを安定させるための固定幅。
    let recentIKIChartWidth: CGFloat = 560
    /// Slightly taller plot area leaves room for top annotations without making the snapshot too tall.
    /// 上端注釈が切れないように、コピー全体を伸ばしすぎず最小限だけ高さを増やす。
    let recentIKIPlotHeight: CGFloat = 200
    /// Extra Y-axis headroom prevents top annotations from being clipped at the 300ms ceiling.
    /// 300ms天井で上端注釈が切れないように、表示用のヘッドルームを少し確保する。
    let recentIKIChartMaxDisplay: Double = 340

    /// Set to true to show the actual key label above each IKI bar.
    /// WARNING: enabling this exposes keystrokes (including passwords) visually.
    /// Set to false (default) to hide key names for privacy.
    let ikichartShowKeyLabels = false

    var body: some View {
        TabView(selection: $selectedTab) {
            summaryTab
                .tabItem { Label(ChartTab.summary.rawValue, systemImage: ChartTab.summary.icon) }
                .tag(ChartTab.summary)

            liveTab
                .tabItem { Label(ChartTab.live.rawValue, systemImage: ChartTab.live.icon) }
                .tag(ChartTab.live)

            activityTab
                .tabItem { Label(ChartTab.activity.rawValue, systemImage: ChartTab.activity.icon) }
                .tag(ChartTab.activity)

            keyboardTab
                .tabItem { Label(ChartTab.keyboard.rawValue, systemImage: ChartTab.keyboard.icon) }
                .tag(ChartTab.keyboard)

            ergonomicsTab
                .tabItem { Label(ChartTab.ergonomics.rawValue, systemImage: ChartTab.ergonomics.icon) }
                .tag(ChartTab.ergonomics)

            shortcutsTab
                .tabItem { Label(ChartTab.shortcuts.rawValue, systemImage: ChartTab.shortcuts.icon) }
                .tag(ChartTab.shortcuts)

            appsTab
                .tabItem { Label(ChartTab.apps.rawValue, systemImage: ChartTab.apps.icon) }
                .tag(ChartTab.apps)

            mouseTab
                .tabItem { Label(ChartTab.mouse.rawValue, systemImage: ChartTab.mouse.icon) }
                .tag(ChartTab.mouse)

            trainingTab
                .tabItem { Label(ChartTab.training.rawValue, systemImage: ChartTab.training.icon) }
                .tag(ChartTab.training)

            comparisonTab
                .tabItem { Label(ChartTab.comparison.rawValue, systemImage: ChartTab.comparison.icon) }
                .tag(ChartTab.comparison)
        }
        .padding(.top, 8)
        .frame(minWidth: 680, minHeight: 480)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .topLeading) {
            // Grabs the NSWindow reference and silences the beep on plain typing.
            WindowGrabber(store: snapperStore).frame(width: 1, height: 1).opacity(0)
            KeySilencer().frame(width: 1, height: 1).opacity(0)
        }
    }

    // MARK: - Section wrapper

    func chartSection<C: View>(_ title: String, helpText: String? = nil, showSort: Bool = false, @ViewBuilder content: () -> C) -> some View {
        let contentView = AnyView(content())
        let isCopied = copiedSection == title
        // ChartSnapper wraps the entire section (title + content) so the clipboard
        // image includes the section title. (Fix for Issue #156)
        return ZStack(alignment: .topLeading) {
            ChartSnapper(store: snapperStore, key: title).allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if let helpText {
                        SectionHeader(title: title, helpText: helpText)
                    } else {
                        Text(title).font(.headline)
                    }

                    Spacer()

                    if showSort {
                        Picker("", selection: $sortDescending) {
                            Image(systemName: "arrow.down.square").tag(true)
                                .help("Descending (Most frequent first)")
                            Image(systemName: "arrow.up.square").tag(false)
                                .help("Ascending (Least frequent first)")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 80)
                    }

                    // Save image button
                    let isSaved = savedSection == title
                    Button {
                        saveImageToFile(title: title)
                    } label: {
                        Image(systemName: isSaved ? "checkmark" : "square.and.arrow.down")
                            .font(.body)
                            .foregroundStyle(isSaved ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isSaved ? L10n.shared.savedConfirmation : L10n.shared.saveChartAsImage)
                    .animation(.easeInOut(duration: 0.2), value: isSaved)

                    // Copy to clipboard button
                    Button {
                        snapshotToClipboard(title: title)
                    } label: {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.body)
                            .foregroundStyle(isCopied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isCopied ? L10n.shared.copiedConfirmation : "Copy chart as image")
                    .animation(.easeInOut(duration: 0.2), value: isCopied)
                }
                contentView
            }
        }
    }

    /// Captures the composited on-screen pixels for `title`'s section and writes to NSPasteboard.
    /// Uses GeometryReader (SwiftUI global frame) + CGWindowListCreateImage (Metal-compatible).
    func snapshotToClipboard(title: String) {
        guard let snapper = snapperStore.views[title],
              let superview = snapper.superview,
              let window = superview.window else { return }

        let scale = window.backingScaleFactor

        // Convert snapper.frame (superview coords) → window coords → screen coords.
        // snapper is a ZStack sibling of contentView, so its frame matches contentView exactly.
        let inWindow   = superview.convert(snapper.frame, to: nil)
        let onScreen   = window.convertToScreen(inWindow)
        let winOnScreen = window.frame

        guard let windowImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(window.windowNumber),
            [.bestResolution, .boundsIgnoreFraming]
        ) else { return }

        // Map screen rect → CGImage pixel rect (top-left origin).
        let cropRect = CGRect(
            x:      (onScreen.minX - winOnScreen.minX) * scale,
            y:      (winOnScreen.maxY - onScreen.maxY) * scale,
            width:  onScreen.width  * scale,
            height: onScreen.height * scale
        )
        guard let cropped = windowImage.cropping(to: cropRect) else { return }

        let img = NSImage(cgImage: cropped,
                          size: NSSize(width: onScreen.width, height: onScreen.height))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([img])
        copiedSection = title
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if copiedSection == title { copiedSection = nil }
        }
    }

    /// Captures the section image and saves it as a PNG file via NSSavePanel.
    func saveImageToFile(title: String) {
        guard let snapper = snapperStore.views[title],
              let superview = snapper.superview,
              let window = superview.window else { return }

        let scale = window.backingScaleFactor
        let inWindow   = superview.convert(snapper.frame, to: nil)
        let onScreen   = window.convertToScreen(inWindow)
        let winOnScreen = window.frame

        guard let windowImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(window.windowNumber),
            [.bestResolution, .boundsIgnoreFraming]
        ) else { return }

        let cropRect = CGRect(
            x:      (onScreen.minX - winOnScreen.minX) * scale,
            y:      (winOnScreen.maxY - onScreen.maxY) * scale,
            width:  onScreen.width  * scale,
            height: onScreen.height * scale
        )
        guard let cropped = windowImage.cropping(to: cropRect) else { return }

        let img = NSImage(cgImage: cropped,
                          size: NSSize(width: onScreen.width, height: onScreen.height))

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "\(title).png"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let tiffData = img.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: url)
            savedSection = title
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if savedSection == title { savedSection = nil }
            }
        }
    }

    // MARK: - Empty state

    var emptyState: some View {
        Text("(no data yet)")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
    }
}

// MARK: - NSView snapshot helpers

/// Reference-type store for chart NSViews and the Charts NSWindow.
/// Being a class means mutations don't trigger SwiftUI re-renders.
final class SnapperStore {
    var views: [String: NSView] = [:]
    weak var window: NSWindow?
}

/// Tiny invisible NSViewRepresentable whose only job is to supply the NSWindow reference.
private struct WindowGrabber: NSViewRepresentable {
    let store: SnapperStore
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {
        if store.window == nil {
            DispatchQueue.main.async { store.window = nsView.window }
        }
    }
}

/// Accepts first responder so plain typing into the Charts window is silently swallowed
/// instead of triggering the system beep. Cmd/Ctrl shortcuts are passed through normally.
private final class KeySilencerView: NSView {
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    override func keyDown(with event: NSEvent) {
        guard event.modifierFlags.intersection([.command, .control]).isEmpty else {
            super.keyDown(with: event); return
        }
        // Plain typing is captured by the CGEvent tap — just swallow it here.
    }
}

private struct KeySilencer: NSViewRepresentable {
    func makeNSView(context: Context) -> KeySilencerView { KeySilencerView() }
    func updateNSView(_ nsView: KeySilencerView, context: Context) {}
}

/// Transparent NSView subclass used as a position anchor inside each chart section.
private final class SnapperHost: NSView {}

/// Registers the chart section's NSView into SnapperStore for later screen capture.
private struct ChartSnapper: NSViewRepresentable {
    let store: SnapperStore
    let key: String
    func makeNSView(context: Context) -> SnapperHost { SnapperHost() }
    func updateNSView(_ nsView: SnapperHost, context: Context) {
        store.views[key] = nsView
    }
}
