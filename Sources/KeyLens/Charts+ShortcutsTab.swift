import SwiftUI
import Charts
import KeyLensCore

extension ChartsView {

    var shortcutsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection(L10n.shared.modifierFingerTitle, helpText: L10n.shared.modifierFingerHelp) { modifierFingerChart }
                chartSection(L10n.shared.chartTitleCmdShortcuts, helpText: L10n.shared.helpShortcuts, showSort: true) { shortcutsChart }
                chartSection(L10n.shared.chartTitleAllCombos, helpText: L10n.shared.helpAllCombos, showSort: true) { allCombosChart }
                chartSection(L10n.shared.shortcutStrainTitle, helpText: L10n.shared.shortcutStrainHelp) { shortcutStrainChart }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    var shortcutsChart: some View {
        if model.shortcuts.isEmpty {
            emptyState
        } else {
            let keyOrder = model.shortcuts.map(\.key)
            let domain = sortDescending ? Array(keyOrder.reversed()) : keyOrder

            Chart(model.shortcuts) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Shortcut", item.key)
                )
                .foregroundStyle(shortcutColor(item.key))
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: domain)
            .chartLegend(.hidden)
            .chartXAxisLabel(L10n.shared.axisLabelKeys, alignment: .trailing)
            .frame(height: CGFloat(model.shortcuts.count * 26 + 24))
        }
    }

    func shortcutColor(_ key: String) -> Color {
        switch key {
        case "⌘c": return .green
        case "⌘v": return .blue
        case "⌘x": return .orange
        case "⌘z": return .purple
        default:    return .teal
        }
    }

    @ViewBuilder
    var allCombosChart: some View {
        if model.allCombos.isEmpty {
            emptyState
        } else {
            let keyOrder = model.allCombos.map(\.key)
            let domain = sortDescending ? Array(keyOrder.reversed()) : keyOrder

            VStack(alignment: .leading, spacing: 6) {
                Chart(model.allCombos) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Combo", item.key)
                    )
                    .foregroundStyle(comboColor(item.key))
                    .cornerRadius(3)
                    .annotation(position: .trailing, spacing: 4) {
                        Text(item.count.formatted())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYScale(domain: domain)
                .chartLegend(.hidden)
                .chartXAxisLabel(L10n.shared.axisLabelKeys, alignment: .trailing)
                .frame(height: CGFloat(model.allCombos.count * 26 + 24))

                // 凡例
                HStack(spacing: 14) {
                    ForEach([("⌘", Color.teal), ("⌃", Color.orange), ("⌥", Color.purple), ("⇧", Color.green), ("Multi", Color.pink)], id: \.0) { label, color in
                        HStack(spacing: 4) {
                            Circle().fill(color).frame(width: 8, height: 8)
                            Text(label).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    func comboColor(_ key: String) -> Color {
        let modifiers = ["⌘", "⌃", "⌥", "⇧"]
        let found = modifiers.filter { key.hasPrefix($0) || key.contains($0) }
        if found.count > 1 { return .pink }
        switch found.first {
        case "⌘": return .teal
        case "⌃": return .orange
        case "⌥": return .purple
        case "⇧": return .green
        default:   return .gray
        }
    }

    // MARK: - Modifier Keys by Finger (Issue #334)

    @ViewBuilder
    var modifierFingerChart: some View {
        let l = L10n.shared
        let data = model.modifierFingerData

        if data.allSatisfy({ $0.count == 0 }) {
            Text(l.modifierFingerNoData)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                // Bar chart: one bar per modifier key, colored by finger
                Chart(data) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Key", item.displayLabel)
                    )
                    .foregroundStyle(modifierFingerColor(item))
                    .cornerRadius(3)
                    .annotation(position: .trailing, spacing: 4) {
                        if item.count > 0 {
                            Text(item.count.formatted())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text(label).font(.system(size: 13, weight: .semibold))
                                    Text(fingerLabel(for: label, in: data))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .frame(height: CGFloat(data.count * 36 + 24))

                // Summary line: thumb % vs pinky %
                let total     = data.map(\.count).reduce(0, +)
                let thumbSum  = data.filter(\.isThumb).map(\.count).reduce(0, +)
                let pinkySum  = data.filter { !$0.isThumb }.map(\.count).reduce(0, +)
                if total > 0 {
                    let thumbPct = Int((Double(thumbSum) / Double(total) * 100).rounded())
                    let pinkyPct = Int((Double(pinkySum) / Double(total) * 100).rounded())
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Circle().fill(Color.blue).frame(width: 8, height: 8)
                            Text("Thumb").font(.caption).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 6) {
                            Circle().fill(Color.red).frame(width: 8, height: 8)
                            Text("Pinky").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(l.modifierFingerSummary(thumbPct: thumbPct, pinkyPct: pinkyPct))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func modifierFingerColor(_ entry: ModifierFingerEntry) -> Color {
        entry.isThumb ? .blue : .red
    }

    private func fingerLabel(for displayLabel: String, in data: [ModifierFingerEntry]) -> String {
        data.first(where: { $0.displayLabel == displayLabel })?.fingerLabel ?? ""
    }

    // MARK: - Shortcut Strain (Issue #335)

    @ViewBuilder
    var shortcutStrainChart: some View {
        let l        = L10n.shared
        let entries  = model.shortcutStrainEntries
        let total    = model.shortcutStrainTotalPresses

        if total == 0 {
            Text(l.shortcutStrainNoData)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if entries.isEmpty {
            let pct = 0
            let same = 0
            VStack(alignment: .leading, spacing: 6) {
                Text(l.shortcutStrainRate(pct: pct, sameCount: same, totalCount: total))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(l.shortcutStrainNoData)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } else {
            let samePressesl = entries.map(\.count).reduce(0, +)
            let pct = Int((Double(samePressesl) / Double(total) * 100).rounded())
            let display = Array(entries.prefix(20))

            VStack(alignment: .leading, spacing: 8) {
                Text(l.shortcutStrainRate(pct: pct, sameCount: samePressesl, totalCount: total))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                let keyOrder = display.map(\.combo)
                Chart(display) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Combo", item.combo)
                    )
                    .foregroundStyle(Color.red.opacity(0.75))
                    .cornerRadius(3)
                    .annotation(position: .trailing, spacing: 4) {
                        Text(item.count.formatted())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYScale(domain: keyOrder)
                .chartLegend(.hidden)
                .chartXAxisLabel(L10n.shared.axisLabelKeys, alignment: .trailing)
                .frame(height: CGFloat(display.count * 26 + 24))
            }
        }
    }
}
