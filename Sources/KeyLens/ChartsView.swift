import SwiftUI
import Charts
import KeyLensCore

// MARK: - ChartsView

struct ChartsView: View {
    @ObservedObject var model: ChartDataModel
    @ObservedObject var theme = ThemeStore.shared

    @AppStorage(UDKeys.selectedChartTab) var selectedTab: ChartTab = .summary
    @AppStorage(UDKeys.frequentChartsSortDescending) var sortDescending: Bool = true
    @AppStorage(UDKeys.advancedMode) var advancedMode: Bool = false
    /// Active sub-tab within the Typing tab (#311).
    @State var typingSubTab: TypingSubTab = .live

    /// Title of the section whose clipboard copy just succeeded (cleared after 1.5 s).
    @State var copiedSection: String? = nil
    /// Key filter for the Slow Bigrams chart (Issue #99). Empty string = no filter.
    @State var slowBigramKeyFilter: String = ""
    /// Title of the section whose image save just succeeded (cleared after 1.5 s).
    @State var savedSection: String? = nil
    /// Stores each chart section's SwiftUI global frame and the Charts NSWindow reference.
    @State var snapperStore = SnapperStore()
    /// Active sub-tab within the Live tab (Issue #271).
    @State var liveSubTab: LiveSubTab = .monitor
    /// Active sub-tab within the Activity tab (Issue #272).
    @State var activitySubTab: ActivitySubTab = .speed
    /// Active sub-tab within the Keyboard tab (Issue #277).
    @State var keyboardSubTab: KeyboardSubTab = .heatmap
    /// Active sub-tab within the Training tab (Issue #276).
    @State var trainingSubTab: TrainingSubTab = .drill
    /// Active sub-tab within the Mouse tab (Issue #275).
    @AppStorage(UDKeys.selectedMouseSubTab) var mouseSubTab: MouseSubTab = .distance
    /// Active sub-tab within the Apps tab (Issue #274).
    @State var appsSubTab: AppsSubTab = .apps
    /// Active sub-tab within the Ergonomics tab (Issue #273).
    @State var ergoSubTab: ErgoSubTab = .bigrams
    /// Whether the thumb cluster config sheet is open (Issue #333).
    @State var showThumbClusterConfig: Bool = false
    /// State object for the Key Swap Optimizer (Issue #235).
    @StateObject var optimizerState = OptimizerSimulatorState()
    /// Saved drill presets stored as JSON (Issue #278).
    @AppStorage(UDKeys.drillPresets) var drillPresetsJSON: String = "[]"
    /// Selected finger filter for the Slow Bigrams chart. nil = All (Issue #153).
    @State var slowBigramFingerFilter: String? = nil
    /// Selected device filter for the Key Accumulation chart. nil = All Devices (Issue #349).
    @State var accumSelectedDevice: String? = nil
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
    @AppStorage(UDKeys.trainingSessionLength) var sessionLength: SessionLength = .normal
    /// IKI speed threshold for drill selection (ms). Bigrams slower than this are included.
    /// 0 = no filter (all ranked bigrams are used).
    @AppStorage(UDKeys.bigramDrillIKIThreshold) var drillIKIThreshold: Double = 0
    /// Changed each time the user taps "New Session" to force InteractivePracticeView to reset.
    @State var trainingResetToken = UUID()
    /// Controls the confirmation alert for clearing training history.
    @State var showClearHistoryAlert = false
    /// Holds the current comparison result so it can be wrapped in chartSection for save/copy.
    @State var comparisonResult: ComparisonResult? = nil
    /// Whether the thumb key optimization subsection is shown in Layout Comparison (Issue #208).
    /// 親指キー最適化サブセクションを Layout Comparison に表示するか（Issue #208）。
    @AppStorage(UDKeys.thumbOptimizationEnabled) var thumbOptimizationEnabled: Bool = false
    /// Set of section titles that are currently collapsed (Issue #251).
    /// 折りたたまれているセクションのタイトルセット。
    @State var collapsedSections: Set<String> = []

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
        VStack(spacing: 0) {
            // Custom tab bar — only the selected tab's view tree is built below.
            HStack(spacing: 0) {
                ForEach(ChartTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                            Text(tab.rawValue)
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedTab == tab
                                ? Color.accentColor.opacity(0.08)
                                : Color.clear
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Only the active tab's view tree is constructed on each switch.
            Group {
                if selectedTab == .summary    { summaryTab }
                if selectedTab == .typing     { typingTab }
                if selectedTab == .mouse      { mouseTab }
                if selectedTab == .ergonomics { ergonomicsTab }
            }
        }
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
        let isCollapsed = collapsedSections.contains(title)
        // ChartSnapper wraps the entire section (title + content) so the clipboard
        // image includes the section title. (Fix for Issue #156)
        return ZStack(alignment: .topLeading) {
            ChartSnapper(store: snapperStore, key: title)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    // Collapse/expand chevron (Issue #251)
                    Button {
                        if isCollapsed {
                            collapsedSections.remove(title)
                        } else {
                            collapsedSections.insert(title)
                        }
                    } label: {
                        Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                    .help(isCollapsed ? L10n.shared.sectionExpand : L10n.shared.sectionCollapse)

                    if let helpText {
                        SectionHeader(title: title, helpText: helpText)
                    } else {
                        Text(title).font(.headline)
                    }

                    Spacer()

                    if showSort && !isCollapsed {
                        Picker("", selection: $sortDescending) {
                            Image(systemName: "arrow.down.square").tag(true)
                                .help(L10n.shared.sortDescendingHelp)
                            Image(systemName: "arrow.up.square").tag(false)
                                .help(L10n.shared.sortAscendingHelp)
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
                    .help(isCopied ? L10n.shared.copiedConfirmation : L10n.shared.copyChartAsImageHelp)
                    .animation(.easeInOut(duration: 0.2), value: isCopied)
                }
                if !isCollapsed {
                    contentView
                }
            }
        }
    }

    /// Renders `snapper` and its siblings by capturing the window's content view into a bitmap,
    /// then crops to the snapper's region. Works with SwiftUI/CALayer content without requiring
    /// screen-recording permission.
    private func captureSnapperImage(_ snapper: NSView) -> NSImage? {
        guard let superview = snapper.superview,
              let window = superview.window,
              let contentView = window.contentView else { return nil }

        let scale = window.backingScaleFactor
        // Convert snapper bounds from snapper's own coordinate space into contentView coords.
        // Using snapper itself (not superview) avoids ScrollView document-view offset issues.
        let rectInContent = contentView.convert(snapper.bounds, from: snapper)

        // Render the full contentView into a bitmap (captures CALayer / SwiftUI content).
        guard let bitmapRep = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds)
        else { return nil }
        contentView.cacheDisplay(in: contentView.bounds, to: bitmapRep)

        // CGImage origin is top-left.
        // If contentView is flipped (SwiftUI hosting views always are), y is already top-down — no flip needed.
        // If not flipped, y is bottom-up → flip manually.
        let yPixel: CGFloat = contentView.isFlipped
            ? rectInContent.minY * scale
            : (contentView.bounds.height - rectInContent.maxY) * scale
        let pixelRect = CGRect(
            x:      rectInContent.minX * scale,
            y:      yPixel,
            width:  rectInContent.width  * scale,
            height: rectInContent.height * scale
        )
        guard let cgImage = bitmapRep.cgImage,
              let cropped = cgImage.cropping(to: pixelRect) else { return nil }
        return NSImage(cgImage: cropped,
                       size: NSSize(width: rectInContent.width, height: rectInContent.height))
    }

    /// Captures the section image and writes it to NSPasteboard.
    func snapshotToClipboard(title: String) {
        guard let snapper = snapperStore.views[title],
              let img = captureSnapperImage(snapper) else { return }
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
              let img = captureSnapperImage(snapper) else { return }

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
        Text(L10n.shared.noDataYet)
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
