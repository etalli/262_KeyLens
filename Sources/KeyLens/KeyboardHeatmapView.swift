import SwiftUI
import KeyLensCore

// MARK: - HeatmapMode

enum HeatmapMode: String, CaseIterable {
    case frequency = "Frequency"
    case strain    = "Strain"
    case speed     = "Speed"
}

// MARK: - HeatmapTemplate

enum HeatmapTemplate: String, CaseIterable {
    case auto        = "Auto"
    case ansi        = "ANSI"
    case pangaea     = "Pangaea"
    case ortholinear = "Ortho"
    case jis         = "JIS"
    case custom      = "Custom"

    // Pangaea is kept for internal .auto resolution but excluded from the layout picker.
    // Custom keyboards should use the Custom slot with an imported KLE JSON file.
    static var allCases: [HeatmapTemplate] {
        [.auto, .ansi, .ortholinear, .jis, .custom]
    }
}

private enum HeatmapTooltipStyle {
    case count
    case strain
}

// MARK: - KeyDef

struct KeyDef {
    let label: String       // 表示ラベル
    let keyName: String     // KeyCountStore の counts キー名
    let widthRatio: Double  // 標準キー(1.0) に対する相対幅

    init(_ label: String, _ keyName: String, _ widthRatio: Double) {
        self.label = label
        self.keyName = keyName
        self.widthRatio = widthRatio
    }
}

// MARK: - KeyboardHeatmapView

struct KeyboardHeatmapView: View {
    let counts: [String: Int]

    @StateObject private var vm = HeatmapViewModel()   // Issue #270: async score computation
    @State private var mode: HeatmapMode = .frequency
    @State private var selectedCellID: String?
    @State private var showModeHelp: Bool = false
    @State private var showStrainLegendHelp: Bool = false
    @State private var showKLEHelp: Bool = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    // Issue #284: toast when Auto resolves to a non-default layout
    @State private var toastMessage: String? = nil
    @State private var toastDismissTask: DispatchWorkItem? = nil
    // Tracks the last resolved template so the toast fires only on *changes*, not every poll tick
    @State private var lastResolvedTemplate: HeatmapTemplate? = nil
    @AppStorage("heatmapTemplate") private var template: HeatmapTemplate = .ansi
    @AppStorage("kleCustomLayoutJSON") private var kleCustomLayoutJSON: String = ""
    @AppStorage("kleCustomKeywords") private var kleCustomKeywords: String = ""
    @ObservedObject private var theme = ThemeStore.shared
    @Environment(\.colorScheme) private var colorScheme

    // Adapts to dark / light mode — dark: near-black, light: near-white
    private var emptyKeyColor: Color { colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.85) }

    // Returns a hue-based key fill color adjusted for the current color scheme.
    // Dark mode raises brightness and lowers saturation so vivid keys don't overpower the dark UI.
    private func heatColor(hue: Double) -> Color {
        colorScheme == .dark
            ? Color(hue: hue, saturation: 0.65, brightness: 0.92)
            : Color(hue: hue, saturation: 0.75, brightness: 0.82)
    }

    private let keyHeight: CGFloat = 40
    private let keySpacing: CGFloat = 4

    // US 配列レイアウト（各行の幅比合計 = 15U）
    static let ansiRows: [[KeyDef]] = [
        // Number row (15U)
        [
            .init("~\n`",  "`",      1.0),
            .init("1",     "1",      1.0), .init("2", "2", 1.0), .init("3", "3", 1.0),
            .init("4",     "4",      1.0), .init("5", "5", 1.0), .init("6", "6", 1.0),
            .init("7",     "7",      1.0), .init("8", "8", 1.0), .init("9", "9", 1.0),
            .init("0",     "0",      1.0), .init("-", "-", 1.0), .init("=", "=", 1.0),
            .init("⌫",     "Delete", 2.0),
        ],
        // QWERTY row (15U)
        [
            .init("⇥",     "Tab",    1.5),
            .init("Q",     "q",      1.0), .init("W", "w", 1.0), .init("E", "e", 1.0),
            .init("R",     "r",      1.0), .init("T", "t", 1.0), .init("Y", "y", 1.0),
            .init("U",     "u",      1.0), .init("I", "i", 1.0), .init("O", "o", 1.0),
            .init("P",     "p",      1.0), .init("[", "[", 1.0), .init("]", "]", 1.0),
            .init("\\",    "\\",     1.5),
        ],
        // Home row (15U)
        [
            .init("⇪",     "CapsLock", 1.75),
            .init("A",     "a",        1.0), .init("S", "s", 1.0), .init("D", "d", 1.0),
            .init("F",     "f",        1.0), .init("G", "g", 1.0), .init("H", "h", 1.0),
            .init("J",     "j",        1.0), .init("K", "k", 1.0), .init("L", "l", 1.0),
            .init(";",     ";",        1.0), .init("'", "'", 1.0),
            .init("↩",     "Return",   2.25),
        ],
        // Shift row (15U)
        [
            .init("⇧",     "⇧Shift",  2.25),
            .init("Z",     "z",        1.0), .init("X", "x", 1.0), .init("C", "c", 1.0),
            .init("V",     "v",        1.0), .init("B", "b", 1.0), .init("N", "n", 1.0),
            .init("M",     "m",        1.0), .init(",", ",", 1.0), .init(".", ".", 1.0),
            .init("/",     "/",        1.0),
            .init("⇧",     "⇧Shift",  2.75),
        ],
        // Bottom row (15U)
        [
            .init("⌃", "⌃Ctrl",   1.5),
            .init("⌥", "⌥Option", 1.5),
            .init("⌘", "⌘Cmd",    1.5),
            .init("Space", "Space", 7.5),
            .init("⌘", "⌘Cmd",    1.5),
            .init("⌥", "⌥Option", 1.5),
            .init("⌃", "⌃Ctrl",   1.5),
        ],
    ]

    // MARK: Pangaea split ergo layout (docs/Pangaea.json)
    // Each side has 4 alpha rows + 1 thumb row (6U per row).
    // "_spacer_" keyName renders as an invisible padding cell.
    // Pangaea スプリットエルゴノミクスレイアウト。各サイド 4 行 + サムロー（6U）。
    // "_spacer_" は不可視パディングセル。

    static let pangaeaLeftRows: [[KeyDef]] = [
        // Row 0: Number row (6U)
        [.init("~\nEsc", "Escape", 1), .init("1", "1", 1), .init("2", "2", 1),
         .init("3", "3", 1),           .init("4", "4", 1), .init("5", "5", 1)],
        // Row 1: QWERTY (6U)
        [.init("⇥", "Tab", 1), .init("Q", "q", 1), .init("W", "w", 1),
         .init("E", "e",   1), .init("R", "r", 1), .init("T", "t", 1)],
        // Row 2: Home row (6U)
        [.init("⌃", "⌃Ctrl", 1), .init("A", "a", 1), .init("S", "s", 1),
         .init("D", "d",     1), .init("F", "f", 1), .init("G", "g", 1)],
        // Row 3: Bottom row (6U)
        [.init("⇧", "⇧Shift", 1), .init("Z", "z", 1), .init("X", "x", 1),
         .init("C", "c",      1), .init("V", "v", 1), .init("B", "b", 1)],
        // Row 4: Thumb row (6U — left thumb: ⌘ Upper ⌫ DEL, padded with spacers)
        [.init("", "_spacer_", 1), .init("⌘", "⌘Cmd",   1), .init("↑", "Upper",  1),
         .init("⌫", "Delete", 1), .init("DEL", "Del",    1), .init("", "_spacer_", 1)],
    ]

    static let pangaeaRightRows: [[KeyDef]] = [
        // Row 0: Number row (6U)
        [.init("6", "6", 1), .init("7", "7", 1), .init("8", "8", 1),
         .init("9", "9", 1), .init("0", "0", 1), .init("-", "-", 1)],
        // Row 1: YUIOP (6U)
        [.init("Y", "y", 1), .init("U", "u", 1), .init("I", "i", 1),
         .init("O", "o", 1), .init("P", "p", 1), .init("=", "=", 1)],
        // Row 2: Home row (6U)
        [.init("H", "h", 1), .init("J", "j", 1), .init("K", "k", 1),
         .init("L", "l", 1), .init(";", ";", 1), .init("'", "'", 1)],
        // Row 3: Bottom row (6U)
        [.init("N", "n", 1), .init("M", "m", 1), .init(",", ",", 1),
         .init(".", ".", 1), .init("/", "/", 1), .init("⇧", "⇧Shift", 1)],
        // Row 4: Thumb row (6U — right thumb: ↩ SPC Lower, padded with spacers)
        [.init("", "_spacer_", 1), .init("↩", "Return",  1),
         .init("SPC", "Space", 1), .init("↓", "Lower",   1), .init("", "_spacer_", 2)],
    ]

    // MARK: Ortholinear layout (generic 60% grid — all keys 1U except Space 6U)
    // Row width = 12U. Keys missing from standard ANSI ([ ] \ ' - =) are omitted.
    // オーソリニア（60%グリッド）レイアウト。Space 以外はすべて 1U。
    static let ortholinearRows: [[KeyDef]] = [
        // Row 0: Number row (12U)
        [.init("~\n`", "`",      1), .init("1", "1", 1), .init("2", "2", 1),
         .init("3",    "3",      1), .init("4", "4", 1), .init("5", "5", 1),
         .init("6",    "6",      1), .init("7", "7", 1), .init("8", "8", 1),
         .init("9",    "9",      1), .init("0", "0", 1), .init("⌫", "Delete", 1)],
        // Row 1: QWERTY (12U)
        [.init("⇥", "Tab", 1), .init("Q", "q", 1), .init("W", "w", 1),
         .init("E",  "e",  1), .init("R", "r", 1), .init("T", "t", 1),
         .init("Y",  "y",  1), .init("U", "u", 1), .init("I", "i", 1),
         .init("O",  "o",  1), .init("P", "p", 1), .init("⌫", "Delete", 1)],
        // Row 2: Home row (12U)
        [.init("⇪", "CapsLock", 1), .init("A", "a", 1), .init("S", "s", 1),
         .init("D",  "d",       1), .init("F", "f", 1), .init("G", "g", 1),
         .init("H",  "h",       1), .init("J", "j", 1), .init("K", "k", 1),
         .init("L",  "l",       1), .init(";", ";", 1), .init("↩", "Return", 1)],
        // Row 3: Shift row (12U)
        [.init("⇧", "⇧Shift", 1), .init("Z", "z", 1), .init("X", "x", 1),
         .init("C",  "c",     1), .init("V", "v", 1), .init("B", "b", 1),
         .init("N",  "n",     1), .init("M", "m", 1), .init(",", ",", 1),
         .init(".",  ".",     1), .init("/", "/", 1), .init("⇧", "⇧Shift", 1)],
        // Row 4: Thumb / space row (12U — Space is 6U)
        [.init("⌃", "⌃Ctrl",   1), .init("⌥", "⌥Option", 1), .init("⌘", "⌘Cmd", 1),
         .init("Space", "Space", 6),
         .init("⌘", "⌘Cmd",    1), .init("⌥", "⌥Option", 1), .init("⌃", "⌃Ctrl", 1)],
    ]

    // MARK: JIS (Japanese Industrial Standard) layout
    // Differences from ANSI:
    //   Row 0: ^ and ¥ replace = and `, BS is 1U
    //   Row 1: @ and [ replace [ and ], L-shaped Return (top half: 1.5U)
    //   Row 2: : and ] added, L-shaped Return (bottom half: 1.25U)
    //   Row 3: ¥ added at right end, both Shifts are narrower
    //   Row 4: 英数 and かな flank Space
    // Note: JIS-specific key names (^, @, :, 英数, かな) may show 0 count if
    // the keyboard monitor does not yet track those keycodes.
    static let jisRows: [[KeyDef]] = [
        // Row 0: Number row (15U) — esc(1) + 13 × 1 + del(1)
        [
            .init("⎋",    "Escape",  1.0),
            .init("1",    "1",       1.0), .init("2", "2", 1.0), .init("3", "3", 1.0),
            .init("4",    "4",       1.0), .init("5", "5", 1.0), .init("6", "6", 1.0),
            .init("7",    "7",       1.0), .init("8", "8", 1.0), .init("9", "9", 1.0),
            .init("0",    "0",       1.0), .init("-", "-", 1.0), .init("^", "^", 1.0),
            .init("¥",    "\\",      1.0), .init("⌫", "Delete", 1.0),
        ],
        // Row 1: QWERTY row (15U) — tab(1.5) + 10 alpha + @(1) + [(1) + ret(1.5)
        [
            .init("⇥",    "Tab",     1.5),
            .init("Q",    "q",       1.0), .init("W", "w", 1.0), .init("E", "e", 1.0),
            .init("R",    "r",       1.0), .init("T", "t", 1.0), .init("Y", "y", 1.0),
            .init("U",    "u",       1.0), .init("I", "i", 1.0), .init("O", "o", 1.0),
            .init("P",    "p",       1.0), .init("@", "@", 1.0), .init("[", "[", 1.0),
            .init("↩",    "Return",  1.5),
        ],
        // Row 2: Home row (15U) — caps(1.75) + 11 alpha + :(1) + ](1) + ret(1.25)
        [
            .init("⇪",    "CapsLock", 1.75),
            .init("A",    "a",        1.0), .init("S", "s", 1.0), .init("D", "d", 1.0),
            .init("F",    "f",        1.0), .init("G", "g", 1.0), .init("H", "h", 1.0),
            .init("J",    "j",        1.0), .init("K", "k", 1.0), .init("L", "l", 1.0),
            .init(";",    ";",        1.0), .init(":", ":", 1.0), .init("]", "]", 1.0),
            .init("↩",    "Return",   1.25),
        ],
        // Row 3: Shift row (15U) — lshift(2) + 10 alpha + ¥(1) + /(1) + rshift(2)
        [
            .init("⇧",    "⇧Shift",  2.0),
            .init("Z",    "z",        1.0), .init("X", "x", 1.0), .init("C", "c", 1.0),
            .init("V",    "v",        1.0), .init("B", "b", 1.0), .init("N", "n", 1.0),
            .init("M",    "m",        1.0), .init(",", ",", 1.0), .init(".", ".", 1.0),
            .init("/",    "/",        1.0), .init("\\","\\",      1.0),
            .init("⇧",    "⇧Shift",  2.0),
        ],
        // Row 4: Bottom row (15U) — ctrl(1.5) + 英数(1.5) + opt(1) + spc(6) + opt(1) + かな(1.5) + ctrl(1.5)
        [
            .init("⌃",    "⌃Ctrl",   1.5),
            .init("英数",  "英数",    1.5),
            .init("⌥",    "⌥Option", 1.0),
            .init("Space", "Space",   6.0),
            .init("⌥",    "⌥Option", 1.0),
            .init("かな",  "かな",    1.5),
            .init("⌃",    "⌃Ctrl",   1.5),
        ],
    ]

    // Decodes the persisted KLE JSON string into absolute keys.
    // Returns [] when nothing has been imported yet.
    private var customKeys: [KLEAbsoluteKey] {
        guard !kleCustomLayoutJSON.isEmpty,
              let data = kleCustomLayoutJSON.data(using: .utf8),
              let keys = try? JSONDecoder().decode([KLEAbsoluteKey].self, from: data)
        else { return [] }
        return keys
    }

    // キーボードキー名をテンプレートに応じて動的に計算する（instance computed property）
    // Template-aware keyboard key names; computed per-render from effective template.
    private var keyboardKeyNames: Set<String> {
        let defs: [KeyDef]
        switch effectiveTemplate {
        case .auto:        defs = Self.ansiRows.flatMap { $0 }           // unreachable; fallback
        case .ansi:        defs = Self.ansiRows.flatMap { $0 }
        case .pangaea:     defs = (Self.pangaeaLeftRows + Self.pangaeaRightRows).flatMap { $0 }
        case .ortholinear: defs = Self.ortholinearRows.flatMap { $0 }
        case .jis:         defs = Self.jisRows.flatMap { $0 }
        case .custom:      return Set(customKeys.map(\.keyName)).subtracting(["_spacer_", ""])
        }
        return Set(defs.map(\.keyName)).subtracting(["_spacer_"])
    }

    // Issue #284: refreshed on appear so layout changes are detected across window reopen
    @State private var deviceNames: [String] = KeyboardDeviceInfo.connectedNames()

    // Resolves a list of device names to a concrete layout.
    // Priority: Custom keywords → KLE import + split device → split/ergo (Pangaea) → JIS → ANSI
    //
    // If a KLE layout has been imported, connecting any split/ergo keyboard (e.g. Pangaea)
    // automatically resolves to .custom — no keyword configuration required.
    // Custom keywords can still override this for keyboards that should NOT use the KLE layout.
    private func resolveTemplate(from names: [String]) -> HeatmapTemplate {
        let lower = names.map { $0.lowercased() }
        let splitKeywords = ["split", "ergo", "moonlander", "advantage", "corne", "reviung", "pangaea"]
        let jisKeywords   = ["jis", "japanese"]
        let isSplitDevice = lower.contains(where: { n in splitKeywords.contains { n.contains($0) } })

        if !kleCustomLayoutJSON.isEmpty {
            let customKWs = kleCustomKeywords
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }
            if !customKWs.isEmpty && lower.contains(where: { n in customKWs.contains { n.contains($0) } }) {
                return .custom
            }
            // KLE imported + split/ergo device detected → use the imported layout (Issue #288)
            if isSplitDevice { return .custom }
        }

        if isSplitDevice { return .pangaea }
        if lower.contains(where: { n in jisKeywords.contains { n.contains($0) } }) { return .jis }
        return .ansi
    }

    // Resolves the `auto` template to a concrete layout based on connected keyboard names.
    private var effectiveTemplate: HeatmapTemplate {
        guard template == .auto else { return template }
        return resolveTemplate(from: deviceNames)
    }

    // Returns the matched device name when `.auto` resolves to Custom via keyword match.
    private var autoMatchedCustomName: String? {
        guard template == .auto, !kleCustomLayoutJSON.isEmpty else { return nil }
        let customKWs = kleCustomKeywords
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        guard !customKWs.isEmpty else { return nil }
        return deviceNames.first { n in customKWs.contains { n.lowercased().contains($0) } }
    }

    private var maxKeyCount: Int {
        counts.filter { keyboardKeyNames.contains($0.key) }.values.max() ?? 1
    }

    private var maxMouseCount: Int {
        counts.filter { $0.key.hasPrefix("🖱") }.values.max() ?? 1
    }

    // Strain score per key: sum of high-strain bigram counts in which the key participates.
    // キーごとの高負荷スコア：そのキーが関係する高負荷ビグラムのカウント合計。
    // strainScores and speedScores are now published by HeatmapViewModel (Issue #270).
    // Accessed as vm.strainScores / vm.speedScores — computed once async, not per-render.

    // Returns (count, max) for a key based on the current display mode.
    // 現在の表示モードに応じてキーの（カウント, 最大値）ペアを返す。
    private func keyDisplayValues(for keyName: String) -> (Int, Int) {
        switch mode {
        case .frequency: return (counts[keyName] ?? 0, maxKeyCount)
        case .strain:    return (vm.strainScores[keyName] ?? 0, vm.strainScores.values.max() ?? 1)
        case .speed:
            let ms = vm.speedScores[keyName] ?? 0
            let maxMs = vm.speedScores.values.max() ?? 1.0
            return (Int(ms * 100), Int(maxMs * 100))
        }
    }

    // マウスボタン一覧（データ準備を View から分離）
    private var mouseButtons: [KeyDef] {
        let fixed: [KeyDef] = [
            .init("🖱 Left",   "🖱Left",   1.0),
            .init("🖱 Middle", "🖱Middle", 1.0),
            .init("🖱 Right",  "🖱Right",  1.0),
        ]
        let knownKeys: Set<String> = ["🖱Left", "🖱Right", "🖱Middle"]
        let extra = counts.keys
            .filter { $0.hasPrefix("🖱") && !knownKeys.contains($0) }
            .sorted()
            .map { KeyDef($0, $0, 1.0) }
        return fixed + extra
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Template + mode controls
            VStack(alignment: .leading, spacing: 6) {
                // Layout template selector
                HStack {
                    Picker(L10n.shared.heatmapLayoutLabel, selection: $template) {
                        ForEach(HeatmapTemplate.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()

                    if template == .custom {
                        Button(L10n.shared.importKLEButton, action: importKLELayout)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        Image(systemName: "info.circle")
                            .font(.body)
                            .foregroundStyle(showKLEHelp ? .primary : .secondary)
                            .onHover { showKLEHelp = $0 }
                            .popover(isPresented: $showKLEHelp, arrowEdge: .bottom) {
                                Text(L10n.shared.helpKLECustom)
                                    .font(.callout)
                                    .padding(10)
                                    .frame(width: 320)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                    }

                    Spacer()
                }
                .alert(L10n.shared.kleParseErrorTitle, isPresented: $showImportError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(importErrorMessage)
                }
                // Device keywords field (only when Custom layout is selected)
                if template == .custom {
                    HStack(spacing: 6) {
                        Text(L10n.shared.kleKeywordsLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField(L10n.shared.kleKeywordsPlaceholder, text: $kleCustomKeywords)
                            .font(.caption)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 220)
                    }
                }
                // Auto-match info (only when .auto resolved to Custom via keyword)
                if let matchedName = autoMatchedCustomName {
                    Text(L10n.shared.autoMatchedCustom(matchedName))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                // Mode toggle + connected keyboard names
                HStack {
                    Picker("", selection: $mode) {
                        ForEach(HeatmapMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)

                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(showModeHelp ? .primary : .secondary)
                        .onHover { showModeHelp = $0 }
                        .popover(isPresented: $showModeHelp, arrowEdge: .bottom) {
                            Text(mode == .strain
                                ? L10n.shared.helpHeatmapStrain
                                : mode == .speed
                                    ? L10n.shared.helpHeatmapSpeed
                                    : L10n.shared.helpHeatmapFrequency
                            )
                            .font(.callout)
                            .padding(10)
                            .frame(width: 280)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                    Spacer()

                    // Only show device names when Auto is active — avoids showing
                    // dormant receivers (e.g. wireless dongle) for manual template picks.
                    if template == .auto, !deviceNames.isEmpty {
                        Text(deviceNames.joined(separator: "  /  "))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }  // end mode HStack
            }  // end controls VStack

            HeatmapExportView(
                counts: counts,
                mode: mode,
                template: effectiveTemplate,
                keyboardKeyNames: keyboardKeyNames,
                strainScores: vm.strainScores,
                speedScores: vm.speedScores,
                selectedCellID: $selectedCellID,
                customKeys: customKeys
            )
        }
        .overlay(alignment: .bottom) {
            if let msg = toastMessage {
                Text(msg)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 4)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture { dismissToast() }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: toastMessage)
        .onAppear {
            vm.reload()
            // Set initial lastResolvedTemplate and show toast if auto already resolved to non-ANSI
            let initial = resolveTemplate(from: deviceNames)
            lastResolvedTemplate = initial
            if initial != .ansi {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showToast(L10n.shared.heatmapAutoSwitched(layout: initial.rawValue, device: deviceNames.first ?? ""))
                }
            }
        }
        .task {
            // Poll for hot-plug events every 2 s as a safety net.
            // The primary path is onReceive(.keyboardDevicesChanged) which fires immediately
            // from AppDelegate's IOKit callback. The poll catches any events that arrive
            // before the view is mounted, or edge cases where the notification is missed.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let fresh = KeyboardDeviceInfo.connectedNames()
                if fresh != deviceNames { deviceNames = fresh }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .keyboardDevicesChanged)) { _ in
            // IOKit fired a connect/remove callback — refresh device list immediately.
            // A 300 ms delay lets the IORegistry settle before querying (removal callbacks
            // can fire slightly before the device disappears from IOHIDManagerCopyDevices).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let fresh = KeyboardDeviceInfo.connectedNames()
                if fresh != deviceNames { deviceNames = fresh }
            }
        }
        .onChange(of: deviceNames) { newNames in
            guard template == .auto else { return }
            let resolved = resolveTemplate(from: newNames)
            guard resolved != lastResolvedTemplate else { return }
            lastResolvedTemplate = resolved
            if resolved == .ansi {
                showToast(L10n.shared.heatmapAutoSwitchedToANSI)
            } else {
                let triggerName = newNames.first { name in
                    let n = name.lowercased()
                    switch resolved {
                    case .jis:     return n.contains("jis") || n.contains("japanese")
                    case .pangaea: return ["split","ergo","moonlander","advantage","corne","reviung","pangaea"].contains { n.contains($0) }
                    case .custom:  return true
                    default:       return false
                    }
                } ?? newNames.first
                showToast(L10n.shared.heatmapAutoSwitched(layout: resolved.rawValue, device: triggerName ?? ""))
            }
        }
        .onChange(of: counts) { _ in vm.reload() }
    }

    // MARK: - Toast helpers (Issue #284)

    private func showToast(_ message: String) {
        toastDismissTask?.cancel()
        withAnimation { toastMessage = message }
        let task = DispatchWorkItem { dismissToast() }
        toastDismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: task)
    }

    private func dismissToast() {
        withAnimation { toastMessage = nil }
    }

    @MainActor
    private func importKLELayout() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.title = L10n.shared.importKLEButton
        panel.message = L10n.shared.importKLEButton
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let rows = try KLEParser.parse(data)
            let encoded = try JSONEncoder().encode(rows)
            kleCustomLayoutJSON = String(data: encoded, encoding: .utf8) ?? ""
        } catch {
            importErrorMessage = error.localizedDescription
            showImportError = true
        }
    }

}

// MARK: - HeatmapExportView

struct HeatmapExportView: View {
    let counts: [String: Int]
    let mode: HeatmapMode
    let template: HeatmapTemplate
    let keyboardKeyNames: Set<String>
    let strainScores: [String: Int]
    var speedScores: [String: Double] = [:]
    var selectedCellID: Binding<String?>? = nil
    var customKeys: [KLEAbsoluteKey] = []

    @Environment(\.colorScheme) private var colorScheme

    private var emptyKeyColor: Color { colorScheme == .dark ? Color(white: 0.25) : Color(white: 0.85) }

    private func heatColor(hue: Double) -> Color {
        colorScheme == .dark
            ? Color(hue: hue, saturation: 0.65, brightness: 0.92)
            : Color(hue: hue, saturation: 0.75, brightness: 0.82)
    }

    private let keyHeight: CGFloat = 40
    private let keySpacing: CGFloat = 4

    private var maxKeyCount: Int {
        counts.filter { keyboardKeyNames.contains($0.key) }.values.max() ?? 1
    }

    private var maxMouseCount: Int {
        counts.filter { $0.key.hasPrefix("🖱") }.values.max() ?? 1
    }

    private var maxStrainScore: Int { strainScores.values.max() ?? 1 }
    private var maxSpeedScore: Double { speedScores.values.max() ?? 1.0 }

    // HeatmapExportView always receives an already-resolved template from the parent.
    // This alias exists so the internal switches read identically to KeyboardHeatmapView.
    private var effectiveTemplate: HeatmapTemplate { template }

    private var keyboardFrameHeight: CGFloat {
        let rowH = keyHeight + keySpacing
        switch template {
        case .auto:        return CGFloat(KeyboardHeatmapView.ansiRows.count) * rowH - keySpacing + 16
        case .ansi:        return CGFloat(KeyboardHeatmapView.ansiRows.count) * rowH - keySpacing + 16
        case .pangaea:     return CGFloat(KeyboardHeatmapView.pangaeaLeftRows.count) * rowH - keySpacing + 16
        case .ortholinear: return CGFloat(KeyboardHeatmapView.ortholinearRows.count) * rowH - keySpacing + 16
        case .jis:         return CGFloat(KeyboardHeatmapView.jisRows.count) * rowH - keySpacing + 16
        case .custom:
            let refMaxX = customKeys.map { $0.cx + $0.w / 2 }.max() ?? 1
            let refUnitW = 800.0 / CGFloat(refMaxX)   // estimate at reference 800px width
            let maxY = customKeys.map(\.cy).max() ?? 2
            return CGFloat(maxY) * refUnitW + refUnitW + keySpacing + 16
        }
    }

    private func keyDisplayValues(for keyName: String) -> (Int, Int) {
        switch mode {
        case .frequency: return (counts[keyName] ?? 0, maxKeyCount)
        case .strain:    return (strainScores[keyName] ?? 0, maxStrainScore)
        case .speed:
            let ms = speedScores[keyName] ?? 0
            return (Int(ms * 100), Int(maxSpeedScore * 100))
        }
    }

    // Returns the raw ms IKI value for speed tooltip, or nil if not in speed mode.
    private func speedTooltipText(for keyName: String) -> String? {
        guard mode == .speed, let ms = speedScores[keyName] else { return nil }
        return L10n.shared.heatmapSpeedTooltip(ms)
    }

    // Returns the row definitions for the current template.
    // .auto falls back to ANSI (HeatmapExportView always receives a resolved template).
    private var rowsForTemplate: [[KeyDef]] {
        switch template {
        case .ortholinear: return KeyboardHeatmapView.ortholinearRows
        case .jis:         return KeyboardHeatmapView.jisRows
        default:           return KeyboardHeatmapView.ansiRows
        }
    }

    private var mouseButtons: [KeyDef] {
        let fixed: [KeyDef] = [
            .init("🖱 Left",   "🖱Left",   1.0),
            .init("🖱 Middle", "🖱Middle", 1.0),
            .init("🖱 Right",  "🖱Right",  1.0),
        ]
        let knownKeys: Set<String> = ["🖱Left", "🖱Right", "🖱Middle"]
        let extra = counts.keys
            .filter { $0.hasPrefix("🖱") && !knownKeys.contains($0) }
            .sorted()
            .map { KeyDef($0, $0, 1.0) }
        return fixed + extra
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geo in
                let availableWidth = geo.size.width - 16
                VStack(alignment: .leading, spacing: keySpacing) {
                    switch template {
                    case .auto, .ansi, .ortholinear, .jis:
                        ForEach(Array(rowsForTemplate.enumerated()), id: \.offset) { rowIndex, row in
                            rowView(row, rowID: "row-\(rowIndex)", availableWidth: availableWidth)
                        }
                    case .pangaea:
                        let splitGap: CGFloat = 20
                        let halfWidth = (availableWidth - splitGap) / 2
                        ForEach(KeyboardHeatmapView.pangaeaLeftRows.indices, id: \.self) { i in
                            HStack(spacing: splitGap) {
                                rowView(KeyboardHeatmapView.pangaeaLeftRows[i], rowID: "left-\(i)", availableWidth: halfWidth)
                                rowView(KeyboardHeatmapView.pangaeaRightRows[i], rowID: "right-\(i)", availableWidth: halfWidth)
                            }
                        }
                    case .custom:
                        if customKeys.isEmpty {
                            Text(L10n.shared.kleCustomNoData)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 20)
                        } else {
                            let maxX  = customKeys.map { $0.cx + $0.w / 2 }.max() ?? 1
                            let maxY  = customKeys.map(\.cy).max() ?? 0
                            let unitW = availableWidth / CGFloat(maxX)
                            // KLE uses square units (1u = same size in both axes)
                            let unitH = unitW
                            let frameH = CGFloat(maxY) * unitH + unitH + keySpacing
                            ZStack(alignment: .topLeading) {
                                Color.clear.frame(width: availableWidth, height: frameH)
                                ForEach(Array(customKeys.enumerated()), id: \.offset) { idx, key in
                                    let cellW = max(4, CGFloat(key.w) * unitW - keySpacing)
                                    let cellH = max(20, CGFloat(key.h) * unitW - keySpacing)
                                    let (displayCount, displayMax) = keyDisplayValues(for: key.keyName)
                                    kleHeatCell(
                                        cellID: "custom-\(idx)-\(key.keyName)",
                                        label: key.label,
                                        slots: key.legendSlots,
                                        count: displayCount,
                                        max: displayMax,
                                        width: cellW,
                                        height: cellH,
                                        tooltipStyle: mode == .strain ? .strain : .count,
                                        tooltipOverride: speedTooltipText(for: key.keyName)
                                    )
                                    .rotationEffect(.degrees(key.r))
                                    .offset(x: CGFloat(key.cx) * unitW - cellW / 2,
                                            y: CGFloat(key.cy) * unitH - cellH / 2)
                                }
                            }
                        }
                    }
                }
                .padding(8)
            }
            .frame(height: keyboardFrameHeight)

            legend
        }
        .padding(10)
    }

    @ViewBuilder
    private func rowView(_ row: [KeyDef], rowID: String, availableWidth: CGFloat) -> some View {
        let totalRatio = row.map(\.widthRatio).reduce(0, +)
        let gaps = CGFloat(row.count - 1) * keySpacing
        let unitWidth = (availableWidth - gaps) / CGFloat(totalRatio)

        HStack(spacing: keySpacing) {
            ForEach(Array(row.enumerated()), id: \.offset) { idx, key in
                if key.keyName == "_spacer_" {
                    Color.clear.frame(width: unitWidth * CGFloat(key.widthRatio), height: keyHeight)
                } else {
                    let (displayCount, displayMax) = keyDisplayValues(for: key.keyName)
                    heatCell(
                        cellID: "\(rowID)-\(idx)-\(key.keyName)",
                        label: key.label,
                        count: displayCount,
                        max: displayMax,
                        width: unitWidth * CGFloat(key.widthRatio),
                        tooltipStyle: mode == .strain ? .strain : .count,
                        tooltipOverride: speedTooltipText(for: key.keyName)
                    )
                }
            }
        }
    }

    private var mouseSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.shared.heatmapMouse)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: keySpacing) {
                ForEach(Array(mouseButtons.enumerated()), id: \.offset) { idx, key in
                    heatCell(
                        cellID: "mouse-\(idx)-\(key.keyName)",
                        label: key.label,
                        count: counts[key.keyName] ?? 0,
                        max: maxMouseCount,
                        width: 80,
                        tooltipStyle: .count
                    )
                }
            }
        }
    }

    private func heatCell(
        cellID: String,
        label: String,
        count: Int,
        max: Int,
        width: CGFloat,
        height: CGFloat? = nil,
        tooltipStyle: HeatmapTooltipStyle,
        tooltipOverride: String? = nil
    ) -> some View {
        let t = max > 0 && count > 0 ? Double(count) / Double(max) : 0
        let baseHue = ThemeStore.shared.current.heatmapBaseHue
        let hue = (1.0 - t) * baseHue
        let bgColor = count > 0 ? heatColor(hue: hue) : emptyKeyColor
        let fgColor: Color = count > 0 ? .white : .secondary

        let accessibilityValue = tooltipOverride ?? tooltipText(for: count, style: tooltipStyle)
        let cell = ZStack {
            RoundedRectangle(cornerRadius: 5).fill(bgColor)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(fgColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 2)
        }
        .frame(width: width, height: height ?? keyHeight)
        .accessibilityLabel(label.isEmpty ? "Unknown key" : "\(label) key")
        .accessibilityValue(accessibilityValue)

        guard let selectedCellID else { return AnyView(cell) }

        let isPresented = Binding(
            get: { selectedCellID.wrappedValue == cellID },
            set: { if !$0 { selectedCellID.wrappedValue = nil } }
        )

        return AnyView(
            cell
                .contentShape(RoundedRectangle(cornerRadius: 5))
                .onTapGesture {
                    selectedCellID.wrappedValue = cellID
                }
                .popover(isPresented: isPresented, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(tooltipOverride ?? tooltipText(for: count, style: tooltipStyle))
                            .font(.callout.monospacedDigit())
                    }
                    .padding(10)
                }
        )
    }

    // Renders a KLE custom key with all legend slots positioned in a 3×3 grid:
    //   Top row:    TL(0)  TC(8)  TR(2)
    //   Center row: CL(6)  C(9)   CR(7)
    //   Bottom row: BL(1)  BC(10) BR(3)
    // Front legends (4,5,11) are omitted (not visible in top-down 2D view).
    private func kleHeatCell(
        cellID: String,
        label: String,
        slots: [String],
        count: Int,
        max: Int,
        width: CGFloat,
        height: CGFloat? = nil,
        tooltipStyle: HeatmapTooltipStyle,
        tooltipOverride: String? = nil
    ) -> some View {
        let t = max > 0 && count > 0 ? Double(count) / Double(max) : 0
        let baseHue = ThemeStore.shared.current.heatmapBaseHue
        let hue = (1.0 - t) * baseHue
        let bgColor = count > 0 ? heatColor(hue: hue) : emptyKeyColor
        let fgColor: Color = count > 0 ? .white : .secondary

        func s(_ i: Int) -> String { i < slots.count ? slots[i] : "" }

        // Each slot is overlaid at its keycap position using ZStack alignment.
        // Using independent frames (not split columns) so each text gets full
        // key width to work with and can render at a readable size.
        let cell = ZStack {
            RoundedRectangle(cornerRadius: 5).fill(bgColor)
            Group {
                if !s(0).isEmpty  { Text(s(0)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) }
                if !s(8).isEmpty  { Text(s(8)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) }
                if !s(2).isEmpty  { Text(s(2)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing) }
                if !s(6).isEmpty  { Text(s(6)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading) }
                if !s(9).isEmpty  { Text(s(9)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center) }
                if !s(7).isEmpty  { Text(s(7)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing) }
                if !s(1).isEmpty  { Text(s(1)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading) }
                if !s(10).isEmpty { Text(s(10)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom) }
                if !s(3).isEmpty  { Text(s(3)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing) }
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(fgColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(2)
        }
        .frame(width: width, height: height ?? keyHeight)
        .accessibilityLabel(label.isEmpty ? "Unknown key" : "\(label) key")
        .accessibilityValue(tooltipOverride ?? tooltipText(for: count, style: tooltipStyle))

        guard let selectedCellID else { return AnyView(cell) }

        let isPresented = Binding(
            get: { selectedCellID.wrappedValue == cellID },
            set: { if !$0 { selectedCellID.wrappedValue = nil } }
        )

        return AnyView(
            cell
                .contentShape(RoundedRectangle(cornerRadius: 5))
                .onTapGesture {
                    selectedCellID.wrappedValue = cellID
                }
                .popover(isPresented: isPresented, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(tooltipOverride ?? tooltipText(for: count, style: tooltipStyle))
                            .font(.callout.monospacedDigit())
                    }
                    .padding(10)
                }
        )
    }

    private func tooltipText(for value: Int, style: HeatmapTooltipStyle) -> String {
        switch style {
        case .count:
            return L10n.shared.heatmapCountTooltip(value)
        case .strain:
            return L10n.shared.heatmapStrainTooltip(value)
        }
    }

    private var legend: some View {
        let l = L10n.shared
        let lowLabel  = mode == .strain ? "Low strain"  : mode == .speed ? l.heatmapSpeedLow  : l.heatmapLow
        let highLabel = mode == .strain ? "High strain" : mode == .speed ? l.heatmapSpeedHigh : l.heatmapHigh
        return HStack(spacing: 6) {
            Text(lowLabel).font(.caption2).foregroundStyle(.secondary)
            LinearGradient(
                stops: {
                    let h = ThemeStore.shared.current.heatmapBaseHue
                    return [
                        .init(color: emptyKeyColor,             location: 0.00),
                        .init(color: heatColor(hue: h),         location: 0.15),
                        .init(color: heatColor(hue: h * 0.60),  location: 0.45),
                        .init(color: heatColor(hue: h * 0.22),  location: 0.75),
                        .init(color: heatColor(hue: 0.00),      location: 1.00),
                    ]
                }(),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 120, height: 10)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(highLabel).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
