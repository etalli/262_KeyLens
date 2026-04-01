// Charts+OptimizerTab.swift
// Key Swap Simulator — Issue #235
// Drag keys to simulate swaps and preview ergonomic score changes live.
// キーをドラッグしてスワップし、エルゴノミクススコアの変化をリアルタイムでプレビューする。

import SwiftUI
import KeyLensCore

// MARK: - OptimizerSimulatorState

/// Manages all mutable state for the Key Swap Simulator.
/// Runs score recomputation on a background queue after every swap.
/// キースワップシミュレータの可変状態を管理する。スワップごとにバックグラウンドでスコアを再計算。
final class OptimizerSimulatorState: ObservableObject {

    // MARK: Keyboard rows (swappable alpha/symbol keys only)
    // スワップ可能なアルファ/記号キーのみ（修飾キー・スペースを除く）
    static let keyRows: [[String]] = [
        ["`", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="],
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "[", "]", "\\"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l", ";", "'"],
        ["z", "x", "c", "v", "b", "n", "m", ",", ".", "/"]
    ]

    // MARK: Published state

    /// Accumulated key relocation map (label → physical slot).
    /// 蓄積されたリロケーションマップ (ラベル → 物理スロット)。
    @Published var relocationMap: [String: String] = [:]

    /// Physical slots the user has locked (cannot be swapped).
    /// ロック済み物理スロット（スワップ不可）。
    @Published var lockedSlots: Set<String> = []

    /// Currently selected slot awaiting a swap partner (click-to-swap mode).
    /// クリックスワップモードで次のパートナーを待っている選択済みスロット。
    @Published var selectedSlot: String? = nil

    /// Ergonomic snapshot before any swaps (loaded on first appear).
    /// スワップ前のエルゴノミクススナップショット（初回表示時にロード）。
    @Published var baseSnapshot: ErgonomicSnapshot? = nil

    /// Ergonomic snapshot after current relocation map is applied.
    /// 現在のリロケーションマップ適用後のスナップショット。
    @Published var currentSnapshot: ErgonomicSnapshot? = nil

    /// Ordered list of swaps the user has performed.
    /// ユーザーが実行したスワップの順序付きリスト。
    @Published var swapHistory: [(from: String, to: String)] = []

    /// File name of the last exported layout, shown briefly after export.
    /// 最後にエクスポートしたファイル名。エクスポート直後に表示。
    @Published var exportedFileName: String? = nil

    /// True while a background score recomputation is in progress.
    /// バックグラウンドでスコアを再計算中のとき true。
    @Published var isComputing: Bool = false

    // MARK: - Derived: display label at each physical slot

    /// Maps each physical slot to the key label currently displayed there.
    /// Inverts `relocationMap` (which maps label → slot) to get slot → label.
    /// 各物理スロットに表示されているキーラベルを返す。relocationMap の逆写像。
    var displayAt: [String: String] {
        // Invert: relocationMap[label] = slot → displayAt[slot] = label
        var d: [String: String] = [:]
        for (label, slot) in relocationMap {
            d[slot] = label
        }
        // Slots not targeted by any relocation show their original key.
        // どのリロケーションにも対応していないスロットは元のキーを表示。
        for row in Self.keyRows {
            for k in row where d[k] == nil {
                d[k] = k
            }
        }
        return d
    }

    // MARK: - Load

    /// Loads the baseline snapshot once. No-op if already loaded.
    /// ベースラインスナップショットを一度だけロードする。
    func loadIfNeeded() {
        guard baseSnapshot == nil, !isComputing else { return }
        isComputing = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let bc   = KeyCountStore.shared.allBigramCounts
            let kc   = KeyCountStore.shared.allKeyCounts
            let snap = ErgonomicSnapshot.capture(
                bigramCounts: bc,
                keyCounts:    kc,
                layout:       .shared
            )
            DispatchQueue.main.async {
                self?.baseSnapshot    = snap
                self?.currentSnapshot = snap
                self?.isComputing     = false
            }
        }
    }

    // MARK: - Interactions

    /// Handles a single tap on a physical slot:
    /// first tap selects; second tap on a different slot swaps; second tap on same slot deselects.
    /// 物理スロットへのシングルタップ処理。1回目は選択、2回目は別スロットでスワップ/同一スロットで選択解除。
    func tapSlot(_ physSlot: String) {
        guard !lockedSlots.contains(physSlot) else { return }
        if let sel = selectedSlot {
            if sel == physSlot {
                selectedSlot = nil
            } else {
                swapSlots(sel, physSlot)
                selectedSlot = nil
            }
        } else {
            selectedSlot = physSlot
        }
    }

    /// Toggles the lock state of a physical slot.
    /// 物理スロットのロック状態をトグルする。
    func toggleLock(_ physSlot: String) {
        if lockedSlots.contains(physSlot) {
            lockedSlots.remove(physSlot)
        } else {
            lockedSlots.insert(physSlot)
            if selectedSlot == physSlot { selectedSlot = nil }
        }
    }

    /// Swaps the keys at two physical slots.
    /// Guard: neither slot may be locked; no-op if labels are identical.
    /// 2つの物理スロットのキーをスワップする。ロック済みまたは同一ラベルは無視。
    func swapSlots(_ slot1: String, _ slot2: String) {
        guard !lockedSlots.contains(slot1), !lockedSlots.contains(slot2) else { return }
        let labels = displayAt
        let label1 = labels[slot1] ?? slot1
        let label2 = labels[slot2] ?? slot2
        guard label1 != label2 else { return }
        KeyRelocationSimulator.applySwap(key1: label1, key2: label2, to: &relocationMap)
        swapHistory.append((from: label1, to: label2))
        recompute()
    }

    /// Undoes the most recent swap by re-applying it (swap is self-inverse).
    /// 最後のスワップを再適用して元に戻す（スワップは自己逆写像）。
    func undoLastSwap() {
        guard let last = swapHistory.popLast() else { return }
        KeyRelocationSimulator.applySwap(key1: last.from, key2: last.to, to: &relocationMap)
        recompute()
    }

    /// Resets all swaps and locks, returning to the baseline state.
    /// すべてのスワップとロックをリセットしてベースライン状態に戻す。
    func reset() {
        relocationMap    = [:]
        swapHistory      = []
        selectedSlot     = nil
        lockedSlots      = []
        currentSnapshot  = baseSnapshot
        exportedFileName = nil
    }

    /// Exports the current relocation map as a JSON preset to ~/Documents.
    /// 現在のリロケーションマップを ~/Documents に JSON プリセットとしてエクスポートする。
    func exportLayout() {
        guard !relocationMap.isEmpty else { return }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let dateStr = df.string(from: Date())
        let fname   = "KeyLens-Layout-\(dateStr).json"
        let payload: [String: Any] = [
            "name":          "KeyLens Custom \(dateStr)",
            "relocationMap": relocationMap,
            "swaps":         swapHistory.map { ["from": $0.from, "to": $0.to] }
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents")
            .appendingPathComponent(fname)
        try? data.write(to: url)
        exportedFileName = fname
    }

    // MARK: - Private

    private func recompute() {
        let map = relocationMap
        isComputing = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let bc      = KeyCountStore.shared.allBigramCounts
            let kc      = KeyCountStore.shared.allKeyCounts
            let layout  = KeyRelocationSimulator.layout(applying: map, over: ANSILayout())
            let simReg  = LayoutRegistry.forSimulation(layout: layout)
            let snap    = ErgonomicSnapshot.capture(
                bigramCounts: bc,
                keyCounts:    kc,
                layout:       simReg
            )
            DispatchQueue.main.async {
                self?.currentSnapshot = snap
                self?.isComputing     = false
            }
        }
    }
}

// MARK: - ChartsView extension

extension ChartsView {

    // MARK: - Top-level optimizer tab

    @ViewBuilder
    var optimizerTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                optimizerScorePanel
                chartSection(
                    L10n.shared.optimizerTitle,
                    helpText: L10n.shared.optimizerHelpText
                ) {
                    optimizerKeyboardGrid
                }
                if !optimizerState.swapHistory.isEmpty {
                    optimizerSwapHistoryView
                }
            }
            .padding(24)
        }
        .onAppear { optimizerState.loadIfNeeded() }
    }

    // MARK: - Score panel

    @ViewBuilder
    private var optimizerScorePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Before / Delta / After score row
            HStack(spacing: 0) {
                optimizerScoreBlock(
                    label: L10n.shared.optimizerScoreBefore,
                    value: optimizerState.baseSnapshot?.ergonomicScore,
                    color: .secondary
                )

                Divider().frame(height: 60)

                if let before = optimizerState.baseSnapshot?.ergonomicScore,
                   let after  = optimizerState.currentSnapshot?.ergonomicScore {
                    let delta = after - before
                    let arrow: String = delta > 0.05 ? "↑" : (delta < -0.05 ? "↓" : "→")
                    let dColor: Color = delta > 0.05 ? .green : (delta < -0.05 ? .red : .secondary)
                    VStack(spacing: 2) {
                        Text("\(arrow) \(String(format: "%+.1f", delta))")
                            .font(.title3.monospacedDigit().bold())
                            .foregroundStyle(dColor)
                        Text(L10n.shared.ergoMetricErgoScore)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Spacer().frame(maxWidth: .infinity)
                }

                Divider().frame(height: 60)

                optimizerScoreBlock(
                    label: L10n.shared.optimizerScoreAfter,
                    value: optimizerState.currentSnapshot?.ergonomicScore,
                    color: {
                        guard let b = optimizerState.baseSnapshot?.ergonomicScore,
                              let a = optimizerState.currentSnapshot?.ergonomicScore
                        else { return .primary }
                        let d = a - b
                        return d > 0.05 ? .green : (d < -0.05 ? .red : .primary)
                    }()
                )
            }
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Per-metric breakdown — only shown once swaps are active
            // スワップが存在する場合のみ指標別の内訳を表示
            if let base = optimizerState.baseSnapshot,
               let curr = optimizerState.currentSnapshot,
               !optimizerState.swapHistory.isEmpty {
                optimizerBreakdown(base: base, curr: curr)
            }

            // Action bar
            HStack(spacing: 10) {
                if optimizerState.isComputing {
                    ProgressView().scaleEffect(0.7)
                }
                Text("\(optimizerState.swapHistory.count) \(L10n.shared.optimizerSwapCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(L10n.shared.optimizerUndoButton) {
                    optimizerState.undoLastSwap()
                }
                .disabled(optimizerState.swapHistory.isEmpty)

                Button(L10n.shared.optimizerResetButton) {
                    optimizerState.reset()
                }
                .disabled(optimizerState.swapHistory.isEmpty && optimizerState.lockedSlots.isEmpty)

                Button(L10n.shared.optimizerExportButton) {
                    optimizerState.exportLayout()
                }
                .disabled(optimizerState.relocationMap.isEmpty)

                if let fname = optimizerState.exportedFileName {
                    Text(L10n.shared.optimizerExported + fname)
                        .font(.caption)
                        .foregroundStyle(.green)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    @ViewBuilder
    private func optimizerScoreBlock(label: String, value: Double?, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let v = value {
                Text(String(format: "%.1f", v))
                    .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(color)
            } else {
                Text("—")
                    .font(.title.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Score breakdown table

    /// Compact grid showing per-metric before/after/delta for the current swap state.
    /// 現在のスワップ状態における指標別の変更前/後/差分をコンパクトなグリッドで表示する。
    @ViewBuilder
    private func optimizerBreakdown(
        base: ErgonomicSnapshot,
        curr: ErgonomicSnapshot
    ) -> some View {
        Grid(alignment: .trailing, horizontalSpacing: 16, verticalSpacing: 0) {
            // Header
            GridRow {
                Text(L10n.shared.tableHeaderMetric)
                    .font(.caption).bold().foregroundStyle(.secondary)
                    .gridColumnAlignment(.leading)
                Text(L10n.shared.optimizerScoreBefore)
                    .font(.caption).bold().foregroundStyle(.secondary)
                Text(L10n.shared.optimizerScoreAfter)
                    .font(.caption).bold().foregroundStyle(.secondary)
                Text(L10n.shared.tableHeaderChange)
                    .font(.caption).bold().foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)

            Divider().gridCellUnsizedAxes(.horizontal)

            // Same-finger rate — lower is better
            comparisonRow(
                metric:          L10n.shared.ergoMetricSameFingerRate,
                current:         pct(base.sameFingerRate),
                proposed:        pct(curr.sameFingerRate),
                delta:           -(curr.sameFingerRate - base.sameFingerRate),
                positiveIsBetter: true,
                format:          { pp(-$0) }
            )

            // High-strain rate — lower is better
            comparisonRow(
                metric:          L10n.shared.ergoMetricHighStrainRate,
                current:         pct(base.highStrainRate),
                proposed:        pct(curr.highStrainRate),
                delta:           -(curr.highStrainRate - base.highStrainRate),
                positiveIsBetter: true,
                format:          { pp(-$0) }
            )

            // Hand alternation — higher is better
            comparisonRow(
                metric:          L10n.shared.ergoMetricHandAlt,
                current:         pct(base.handAlternationRate),
                proposed:        pct(curr.handAlternationRate),
                delta:           curr.handAlternationRate - base.handAlternationRate,
                positiveIsBetter: true,
                format:          { pp($0) }
            )

            // Thumb imbalance — lower is better
            comparisonRow(
                metric:          L10n.shared.ergoMetricThumbImbalance,
                current:         String(format: "%.2f", base.thumbImbalanceRatio),
                proposed:        String(format: "%.2f", curr.thumbImbalanceRatio),
                delta:           -(curr.thumbImbalanceRatio - base.thumbImbalanceRatio),
                positiveIsBetter: true,
                format:          { String(format: "%+.2f", -$0) }
            )

            // Finger travel — lower is better
            comparisonRow(
                metric:          L10n.shared.ergoMetricFingerTravel,
                current:         String(format: "%.0f", base.estimatedTravelDistance),
                proposed:        String(format: "%.0f", curr.estimatedTravelDistance),
                delta:           -(curr.estimatedTravelDistance - base.estimatedTravelDistance),
                positiveIsBetter: true,
                format:          { String(format: "%+.0f", -$0) }
            )
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))

    }

    // MARK: - Keyboard grid

    @ViewBuilder
    private var optimizerKeyboardGrid: some View {
        if optimizerState.baseSnapshot == nil {
            if optimizerState.isComputing {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.75)
                    Text(L10n.shared.layoutComparisonCalculating)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                Text(L10n.shared.optimizerNoData)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.shared.optimizerInstruction)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(
                        Array(OptimizerSimulatorState.keyRows.enumerated()),
                        id: \.offset
                    ) { rowIdx, row in
                        HStack(spacing: 4) {
                            ForEach(row, id: \.self) { physSlot in
                                optimizerKeyButton(physSlot: physSlot)
                            }
                        }
                        // Stagger rows to mimic a real keyboard
                        // 実際のキーボードに似せて各行をずらす
                        .padding(.leading, CGFloat(rowIdx) * 10)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func optimizerKeyButton(physSlot: String) -> some View {
        let label     = optimizerState.displayAt[physSlot] ?? physSlot
        let isSelected = optimizerState.selectedSlot == physSlot
        let isLocked   = optimizerState.lockedSlots.contains(physSlot)
        let isChanged  = label != physSlot

        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    isSelected ? Color.accentColor :
                    isLocked   ? Color.secondary.opacity(0.12) :
                    isChanged  ? Color.green.opacity(0.18) :
                                 Color.secondary.opacity(0.1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(
                            isSelected  ? Color.accentColor :
                            isChanged   ? Color.green.opacity(0.5) :
                                         Color.secondary.opacity(0.25),
                            lineWidth: 1
                        )
                )

            VStack(spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(isSelected ? .white : isLocked ? Color.secondary : Color.primary)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 34, height: 30)
        // Double-click to toggle lock
        .onTapGesture(count: 2) {
            optimizerState.toggleLock(physSlot)
        }
        // Single-click to select / swap
        .onTapGesture {
            optimizerState.tapSlot(physSlot)
        }
        // Drag source: payload is the physical slot identifier
        // ドラッグソース：ペイロードは物理スロット識別子
        .draggable(physSlot) {
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(Color.accentColor)
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 30)
        }
        // Drop target: swap the dragged slot with this slot
        // ドロップターゲット：ドラッグされたスロットとこのスロットをスワップ
        .dropDestination(for: String.self) { items, _ in
            guard let sourceSlot = items.first, sourceSlot != physSlot else { return false }
            optimizerState.swapSlots(sourceSlot, physSlot)
            return true
        }
    }

    // MARK: - Swap history

    @ViewBuilder
    private var optimizerSwapHistoryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.shared.optimizerSwapHistoryTitle)
                .font(.footnote.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 90), spacing: 6)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(
                    Array(optimizerState.swapHistory.enumerated()),
                    id: \.offset
                ) { idx, swap in
                    HStack(spacing: 3) {
                        Text("\(idx + 1).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text("\(swap.from) ↔ \(swap.to)")
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
        }
    }
}
