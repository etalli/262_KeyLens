import SwiftUI

// MARK: - ComparisonTab

extension ChartsView {
    var comparisonTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ComparisonTabView(result: $comparisonResult)
                if let r = comparisonResult {
                    chartSection(L10n.shared.comparisonTabTitle, helpText: L10n.shared.helpComparison) {
                        ComparisonResultView(result: r)
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - ComparisonTabView

/// Date-range picker and preset controls for the Compare tab.
/// The result is surfaced via `result` binding so the parent can wrap it in `chartSection`.
struct ComparisonTabView: View {
    private let l = L10n.shared

    // Range A
    @State private var startA: Date = Calendar.current.date(byAdding: .day, value: -13, to: Date()) ?? Date()
    @State private var endA:   Date = Calendar.current.date(byAdding: .day, value: -7,  to: Date()) ?? Date()

    // Range B
    @State private var startB: Date = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
    @State private var endB:   Date = Date()

    @Binding var result: ComparisonResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            presetsRow
            pickerGrid
            compareButton
        }
    }

    // MARK: - Presets

    private var presetsRow: some View {
        HStack(spacing: 8) {
            presetButton(l.comparisonPresetLast7) {
                let today = Date()
                let cal   = Calendar.current
                startA = cal.date(byAdding: .day, value: -13, to: today) ?? today
                endA   = cal.date(byAdding: .day, value: -7,  to: today) ?? today
                startB = cal.date(byAdding: .day, value: -6,  to: today) ?? today
                endB   = today
                compute()
            }
            presetButton(l.comparisonPresetThisMonth) {
                let cal   = Calendar.current
                let now   = Date()
                let comps = cal.dateComponents([.year, .month], from: now)
                startB = cal.date(from: comps) ?? now
                endB   = now
                // Last month
                var lastComps = comps
                lastComps.month = (comps.month ?? 1) - 1
                if (lastComps.month ?? 1) < 1 {
                    lastComps.month = 12
                    lastComps.year  = (comps.year ?? 2026) - 1
                }
                startA = cal.date(from: lastComps) ?? now
                // Last day of last month = day before startB
                endA   = cal.date(byAdding: .day, value: -1, to: startB) ?? now
                compute()
            }
        }
    }

    private func presetButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(label, action: action)
            .buttonStyle(.bordered)
            .controlSize(.small)
    }

    // MARK: - Picker grid

    private var pickerGrid: some View {
        HStack(alignment: .top, spacing: 24) {
            rangeColumn(label: l.comparisonBefore, start: $startA, end: $endA)
            Divider().frame(height: 80)
            rangeColumn(label: l.comparisonAfter, start: $startB, end: $endB)
        }
        .padding(.vertical, 4)
    }

    private func rangeColumn(label: String, start: Binding<Date>, end: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.headline)
            HStack {
                Text(l.comparisonStart).foregroundColor(.secondary).frame(width: 36, alignment: .trailing)
                DatePicker("", selection: start, displayedComponents: .date)
                    .labelsHidden()
            }
            HStack {
                Text(l.comparisonEnd).foregroundColor(.secondary).frame(width: 36, alignment: .trailing)
                DatePicker("", selection: end, displayedComponents: .date)
                    .labelsHidden()
            }
        }
    }

    // MARK: - Compare button

    private var compareButton: some View {
        Button(l.comparisonCompareButton) { compute() }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
    }

    // MARK: - Computation

    private func compute() {
        result = ComparisonResult.compute(startA: startA, endA: endA, startB: startB, endB: endB)
    }
}

// MARK: - ComparisonResult

struct ComparisonResult {
    struct PeriodStats {
        let totalKeystrokes: Int
        let activeDays: Int
        let dailyAverage: Int
        let averageWPM: Double?
        let sameFingerRate: Double?
        let alternationRate: Double?
    }

    let a: PeriodStats
    let b: PeriodStats
    let startA: Date
    let endA:   Date
    let startB: Date
    let endB:   Date

    static func compute(startA: Date, endA: Date, startB: Date, endB: Date) -> ComparisonResult {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        func dateRange(_ start: Date, _ end: Date) -> Set<String> {
            var dates: Set<String> = []
            var current = start
            let cal = Calendar.current
            while current <= end {
                dates.insert(fmt.string(from: current))
                current = cal.date(byAdding: .day, value: 1, to: current) ?? current.addingTimeInterval(86400)
            }
            return dates
        }

        let store   = KeyCountStore.shared
        let allDays = store.dailyTotals()
        let allErg  = store.dailyErgonomicRates()

        func stats(start: Date, end: Date) -> PeriodStats {
            let dates   = dateRange(start, end)
            let dayData = allDays.filter { dates.contains($0.date) && $0.total > 0 }
            let total   = dayData.reduce(0) { $0 + $1.total }
            let active  = dayData.count
            let avg     = active > 0 ? total / active : 0

            let wpmVals = store.dailyWPM().filter { dates.contains($0.date) }.map(\.wpm)
            let avgWPM: Double? = wpmVals.isEmpty ? nil : wpmVals.reduce(0, +) / Double(wpmVals.count)

            let ergData = allErg.filter { dates.contains($0.date) }
            func avgRate(_ selector: (Double, Double, Double) -> Double) -> Double? {
                let vals = ergData.map { selector($0.sameFingerRate, $0.handAltRate, $0.highStrainRate) }
                return vals.isEmpty ? nil : vals.reduce(0, +) / Double(vals.count)
            }

            return PeriodStats(
                totalKeystrokes: total,
                activeDays:     active,
                dailyAverage:   avg,
                averageWPM:     avgWPM,
                sameFingerRate: avgRate { sf, _, _ in sf },
                alternationRate: avgRate { _, ha, _ in ha }
            )
        }

        return ComparisonResult(
            a: stats(start: startA, end: endA),
            b: stats(start: startB, end: endB),
            startA: startA, endA: endA,
            startB: startB, endB: endB
        )
    }
}

// MARK: - ComparisonResultView

struct ComparisonResultView: View {
    let result: ComparisonResult
    // Observing UserDefaults language key ensures SwiftUI re-renders this view
    // immediately when the user switches language, without requiring a new Compare press.
    @AppStorage("appLanguage") private var appLanguage: String = "system"
    private var l: L10n { L10n.shared }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func dateRangeStr(start: Date, end: Date) -> String {
        "\(Self.dateFmt.string(from: start)) – \(Self.dateFmt.string(from: end))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — labels resolved from L10n at render time so language changes apply instantly
            HStack {
                Text(l.comparisonMetricLabel).font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(l.comparisonBefore).font(.caption).bold()
                    Text(dateRangeStr(start: result.startA, end: result.endA))
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
                .frame(width: 120, alignment: .trailing)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(l.comparisonAfter).font(.caption).bold()
                    Text(dateRangeStr(start: result.startB, end: result.endB))
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
                .frame(width: 120, alignment: .trailing)
                Text("Δ").font(.caption).foregroundColor(.secondary).frame(width: 80, alignment: .trailing)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Keystroke rows
            intRow(
                label: l.comparisonMetricKeystrokes,
                a: result.a.totalKeystrokes,
                b: result.b.totalKeystrokes,
                lowerIsBetter: false,
                format: { $0.formatted() }
            )
            intRow(
                label: l.comparisonMetricDailyAvg,
                a: result.a.dailyAverage,
                b: result.b.dailyAverage,
                lowerIsBetter: false,
                format: { $0.formatted() }
            )
            intRow(
                label: l.comparisonMetricActiveDays,
                a: result.a.activeDays,
                b: result.b.activeDays,
                lowerIsBetter: false,
                format: { "\($0)" }
            )

            // WPM row (optional)
            if let wpmA = result.a.averageWPM, let wpmB = result.b.averageWPM {
                doubleRow(
                    label: l.comparisonMetricAvgWPM,
                    a: wpmA, b: wpmB,
                    lowerIsBetter: false,
                    format: { String(format: "%.1f wpm", $0) },
                    deltaFormat: { String(format: "%+.1f wpm", $0) }
                )
            }

            // Ergonomic rate rows (optional)
            if let sfA = result.a.sameFingerRate, let sfB = result.b.sameFingerRate {
                doubleRow(
                    label: l.comparisonMetricSameFinger,
                    a: sfA, b: sfB,
                    lowerIsBetter: true,
                    format: { String(format: "%.1f%%", $0 * 100) }
                )
            }
            if let haA = result.a.alternationRate, let haB = result.b.alternationRate {
                doubleRow(
                    label: l.comparisonMetricAlteration,
                    a: haA, b: haB,
                    lowerIsBetter: false,
                    format: { String(format: "%.1f%%", $0 * 100) }
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.1)))
    }

    // MARK: - Row builders

    private func intRow(label: String, a: Int, b: Int, lowerIsBetter: Bool, format: (Int) -> String) -> some View {
        let delta   = b - a
        let better  = lowerIsBetter ? delta < 0 : delta > 0
        let deltaStr = delta == 0 ? "—" : (delta > 0 ? "+\(format(delta))" : format(delta))
        return tableRow(
            label: label,
            aStr: format(a),
            bStr: format(b),
            deltaStr: deltaStr,
            deltaColor: delta == 0 ? .secondary : (better ? .green : .red)
        )
    }

    private func doubleRow(label: String, a: Double, b: Double, lowerIsBetter: Bool, format: (Double) -> String, deltaFormat: ((Double) -> String)? = nil) -> some View {
        let delta    = b - a
        let better   = lowerIsBetter ? delta < 0 : delta > 0
        let deltaStr: String
        if abs(delta) < 0.0001 {
            deltaStr = "—"
        } else if let deltaFormat {
            deltaStr = deltaFormat(delta)
        } else {
            let absDelta = abs(delta) * 100
            let sign     = delta >= 0 ? "+" : "-"
            deltaStr = "\(sign)\(String(format: "%.1f", absDelta))pp"
        }
        return tableRow(
            label: label,
            aStr: format(a),
            bStr: format(b),
            deltaStr: deltaStr,
            deltaColor: abs(delta) < 0.0001 ? .secondary : (better ? .green : .red)
        )
    }

    private func tableRow(label: String, aStr: String, bStr: String, deltaStr: String, deltaColor: Color) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
                Text(aStr).font(.system(size: 12, design: .monospaced)).frame(width: 120, alignment: .trailing)
                Text(bStr).font(.system(size: 12, design: .monospaced)).frame(width: 120, alignment: .trailing)
                Text(deltaStr)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(deltaColor)
                    .frame(width: 80, alignment: .trailing)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .background(Color(NSColor.windowBackgroundColor))
            Divider()
        }
    }
}
