import SwiftUI
import Charts

// MARK: - Chart data types

struct TopKeyEntry: Identifiable {
    let id: String
    let key: String
    let count: Int
    init(_ t: (key: String, count: Int)) { id = t.key; key = t.key; count = t.count }
}

struct DailyTotalEntry: Identifiable {
    let id: String
    let date: String
    let total: Int
    init(_ t: (date: String, total: Int)) { id = t.date; date = t.date; total = t.total }
}

struct CategoryEntry: Identifiable {
    var id: String { type.rawValue }
    let type: KeyType
    let count: Int
    init(_ t: (type: KeyType, count: Int)) { type = t.type; count = t.count }
}

struct DailyKeyEntry: Identifiable {
    let id = UUID()
    let date: String
    let key: String
    let count: Int
    init(_ t: (date: String, key: String, count: Int)) { date = t.date; key = t.key; count = t.count }
}

struct ShortcutEntry: Identifiable {
    let id: String
    let key: String
    let count: Int
    init(_ t: (key: String, count: Int)) { id = t.key; key = t.key; count = t.count }
}

struct BigramEntry: Identifiable {
    let id: String
    let pair: String
    let count: Int
    init(_ t: (pair: String, count: Int)) { id = t.pair; pair = t.pair; count = t.count }
}

// MARK: - Phase 3 data types

/// One data point in the Learning Curve chart: a rate value for a given date and metric series.
/// 学習曲線チャートの1点：指定日・指標系列の比率値。
struct DailyErgonomicEntry: Identifiable {
    let id = UUID()
    let date: String
    let series: String   // "Same-finger" | "Alternation" | "High-strain"
    let rate: Double
}

/// One row in the Weekly Delta table: a metric compared across two consecutive 7-day windows.
/// 週次デルタ表の1行：連続する2つの7日間ウィンドウで比較した指標。
struct WeeklyDeltaRow: Identifiable {
    let id = UUID()
    let metric: String
    let thisWeek: Double
    let lastWeek: Double
    let lowerIsBetter: Bool
    var delta: Double { thisWeek - lastWeek }
}

// MARK: - SectionHeader

/// Section title with an optional hover-triggered help popover.
/// セクションタイトル + ホバーで表示されるヘルプポップオーバー（任意）。
private struct SectionHeader: View {
    let title: String
    let helpText: String
    @State private var showHelp = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.headline)
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(showHelp ? .primary : .secondary)
                .onHover { showHelp = $0 }
                .popover(isPresented: $showHelp, arrowEdge: .bottom) {
                    Text(helpText)
                        .font(.callout)
                        .padding(10)
                        .frame(width: 280)
                        .fixedSize(horizontal: false, vertical: true)
                }
        }
    }
}

// MARK: - ChartsView

struct ChartsView: View {
    @ObservedObject var model: ChartDataModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection("Keyboard Heatmap") { KeyboardHeatmapView(counts: model.keyCounts) }
                chartSection("Top 20 Keys — All Time") { topKeysChart }
                chartSection("Top 20 Bigrams", helpText: L10n.shared.helpBigrams) { bigramChart }
                chartSection("Daily Totals") { dailyTotalsChart }
                chartSection("Ergonomic Learning Curve", helpText: L10n.shared.helpLearningCurve) { learningCurveChart }
                chartSection("Weekly Report") { weeklyDeltaSection }
                chartSection("Key Categories") { categoryChart }
                chartSection("Top 10 Keys per Day") { perDayChart }
                chartSection("⌘ Keyboard Shortcuts") { shortcutsChart }
                chartSection("All Keyboard Combos") { allCombosChart }
            }
            .padding(24)
        }
        .frame(minWidth: 640, minHeight: 420)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Section wrapper

    @ViewBuilder
    private func chartSection<C: View>(_ title: String, helpText: String? = nil, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let helpText {
                SectionHeader(title: title, helpText: helpText)
            } else {
                Text(title).font(.headline)
            }
            content()
        }
    }

    // MARK: - Chart 1: Top 20 Keys (horizontal bar, color-coded)

    @ViewBuilder
    private var topKeysChart: some View {
        if model.topKeys.isEmpty {
            emptyState
        } else {
            let keyOrder = model.topKeys.map(\.key)
            VStack(alignment: .leading, spacing: 6) {
                Chart(model.topKeys) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Key", item.key)
                    )
                    .foregroundStyle(KeyType.classify(item.key).color)
                    .cornerRadius(3)
                }
                .chartYScale(domain: keyOrder.reversed())
                .chartLegend(.hidden)
                .frame(height: CGFloat(model.topKeys.count * 26 + 24))

                // カラーレジェンド
                let presentTypes = Set(model.topKeys.map { KeyType.classify($0.key) })
                HStack(spacing: 14) {
                    ForEach(KeyType.allCases, id: \.self) { type in
                        if presentTypes.contains(type) {
                            HStack(spacing: 4) {
                                Circle().fill(type.color).frame(width: 8, height: 8)
                                Text(type.label).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Chart 2: Top 20 Bigrams (horizontal bar + ergonomic summary)

    @ViewBuilder
    private var bigramChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.topBigrams.isEmpty {
                emptyState
            } else {
                let pairOrder = model.topBigrams.map(\.pair)
                Chart(model.topBigrams) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Bigram", item.pair)
                    )
                    .foregroundStyle(Color.teal.opacity(0.8))
                    .cornerRadius(3)
                }
                .chartYScale(domain: pairOrder.reversed())
                .chartLegend(.hidden)
                .frame(height: CGFloat(model.topBigrams.count * 26 + 24))
            }

            // Ergonomic metrics summary (Phase 0 data — previously computed but not shown)
            HStack(spacing: 24) {
                ergonomicMetricPair(
                    label: "Same-finger rate",
                    allTime: model.sameFingerRate,
                    today: model.todaySameFingerRate
                )
                ergonomicMetricPair(
                    label: "Hand alternation rate",
                    allTime: model.handAlternationRate,
                    today: model.todayHandAltRate
                )
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func ergonomicMetricPair(label: String, allTime: Double?, today: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                if let v = allTime {
                    Text("All-time: \(Int(v * 100))%").font(.caption.monospacedDigit())
                }
                if let v = today {
                    Text("Today: \(Int(v * 100))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                if allTime == nil && today == nil {
                    Text("—").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Chart 3: Daily Totals (line chart)

    @ViewBuilder
    private var dailyTotalsChart: some View {
        if model.dailyTotals.isEmpty {
            emptyState
        } else if model.dailyTotals.count == 1 {
            // 1点のみの場合は BarMark で代替
            Chart(model.dailyTotals) { item in
                BarMark(x: .value("Date", item.date), y: .value("Total", item.total))
                    .foregroundStyle(.blue)
                    .cornerRadius(4)
            }
            .frame(height: 180)
        } else {
            Chart(model.dailyTotals) { item in
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Total", item.total)
                )
                .foregroundStyle(.blue.opacity(0.12))
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Total", item.total)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Date", item.date),
                    y: .value("Total", item.total)
                )
                .foregroundStyle(.blue)
                .annotation(position: .top, spacing: 4) {
                    Text(item.total.formatted())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 200)
        }
    }

    // MARK: - Chart 3: Key Categories (doughnut / stacked bar)

    @ViewBuilder
    private var categoryChart: some View {
        if model.categories.isEmpty {
            emptyState
        } else if #available(macOS 14.0, *) {
            donutChart
        } else {
            stackedBarCategories
        }
    }

    @available(macOS 14.0, *)
    private var donutChart: some View {
        HStack(alignment: .center, spacing: 28) {
            Chart(model.categories) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.52),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(item.type.color)
            }
            .chartLegend(.hidden)
            .frame(width: 180, height: 180)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.categories) { item in
                    HStack(spacing: 8) {
                        Circle().fill(item.type.color).frame(width: 10, height: 10)
                        Text(item.type.label).font(.callout)
                        Spacer()
                        Text(item.count.formatted())
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 160)
                }
            }
        }
    }

    // macOS 13 フォールバック: 横積みバー + レジェンド
    private var stackedBarCategories: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart(model.categories) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Category", "")
                )
                .foregroundStyle(item.type.color)
            }
            .chartYAxis(.hidden)
            .chartXAxis(.hidden)
            .frame(height: 40)

            HStack(spacing: 14) {
                ForEach(model.categories) { item in
                    HStack(spacing: 4) {
                        Circle().fill(item.type.color).frame(width: 8, height: 8)
                        Text("\(item.type.label) \(item.count.formatted())")
                            .font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Chart 4: Top 10 keys per day (grouped bar)

    @ViewBuilder
    private var perDayChart: some View {
        if model.perDayKeys.isEmpty {
            emptyState
        } else {
            let keyOrder = model.perDayKeys
                .reduce(into: [String: Int]()) { $0[$1.key, default: 0] += $1.count }
                .sorted { $0.value > $1.value }
                .map(\.key)

            Chart(model.perDayKeys) { item in
                BarMark(
                    x: .value("Key", item.key),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(by: .value("Date", item.date))
                .position(by: .value("Date", item.date))
                .cornerRadius(3)
            }
            .chartXScale(domain: keyOrder)
            .chartLegend(position: .top, alignment: .leading)
            .frame(height: 220)
        }
    }

    // MARK: - Chart 5: ⌘ Keyboard Shortcuts (horizontal bar)

    @ViewBuilder
    private var shortcutsChart: some View {
        if model.shortcuts.isEmpty {
            emptyState
        } else {
            let keyOrder = model.shortcuts.map(\.key)
            Chart(model.shortcuts) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Shortcut", item.key)
                )
                .foregroundStyle(shortcutColor(item.key))
                .cornerRadius(3)
                .annotation(position: .trailing, spacing: 4) {
                    Text(item.count.formatted())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: keyOrder.reversed())
            .chartLegend(.hidden)
            .frame(height: CGFloat(model.shortcuts.count * 26 + 24))
        }
    }

    private func shortcutColor(_ key: String) -> Color {
        switch key {
        case "⌘c": return .green
        case "⌘v": return .blue
        case "⌘x": return .orange
        case "⌘z": return .purple
        default:    return .teal
        }
    }

    // MARK: - Chart 6: All Keyboard Combos (horizontal bar, modifier-color-coded)

    @ViewBuilder
    private var allCombosChart: some View {
        if model.allCombos.isEmpty {
            emptyState
        } else {
            let keyOrder = model.allCombos.map(\.key)
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
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYScale(domain: keyOrder.reversed())
                .chartLegend(.hidden)
                .frame(height: CGFloat(model.allCombos.count * 26 + 24))

                // 凡例
                HStack(spacing: 14) {
                    ForEach([("⌘", Color.teal), ("⌃", Color.orange), ("⌥", Color.purple), ("⇧", Color.green), ("Multi", Color.pink)], id: \.0) { label, color in
                        HStack(spacing: 4) {
                            Circle().fill(color).frame(width: 8, height: 8)
                            Text(label).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func comboColor(_ key: String) -> Color {
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

    // MARK: - Phase 3: Learning Curve (daily ergonomic trend)

    @ViewBuilder
    private var learningCurveChart: some View {
        if model.dailyErgonomics.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Chart(model.dailyErgonomics) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Rate", item.rate)
                    )
                    .foregroundStyle(by: .value("Metric", item.series))
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Rate", item.rate)
                    )
                    .foregroundStyle(by: .value("Metric", item.series))
                }
                .chartForegroundStyleScale([
                    "Same-finger": Color.orange,
                    "Alternation": Color.teal,
                    "High-strain": Color.red
                ])
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v * 100))%")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 200)

                // Legend
                HStack(spacing: 16) {
                    ForEach([("Same-finger", Color.orange), ("Alternation", Color.teal), ("High-strain", Color.red)], id: \.0) { label, color in
                        HStack(spacing: 4) {
                            Circle().fill(color).frame(width: 8, height: 8)
                            Text(label).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Phase 3: Weekly Delta Report

    @ViewBuilder
    private var weeklyDeltaSection: some View {
        if model.weeklyDeltas.isEmpty {
            Text("Need at least two weeks of data")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                Grid(alignment: .trailing, horizontalSpacing: 20, verticalSpacing: 0) {
                    GridRow {
                        Text("Metric")
                            .font(.caption).bold().foregroundStyle(.secondary)
                            .gridColumnAlignment(.leading)
                        Text("This week")
                            .font(.caption).bold().foregroundStyle(.secondary)
                        Text("Last week")
                            .font(.caption).bold().foregroundStyle(.secondary)
                        Text("Δ")
                            .font(.caption).bold().foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 6)

                    Divider()
                        .gridCellUnsizedAxes(.horizontal)

                    ForEach(model.weeklyDeltas) { row in
                        GridRow {
                            Text(row.metric)
                                .font(.callout)
                                .gridColumnAlignment(.leading)
                            Text(weeklyFormat(row.thisWeek, metric: row.metric))
                                .font(.callout.monospacedDigit())
                            Text(weeklyFormat(row.lastWeek, metric: row.metric))
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                            deltaLabel(row)
                        }
                        .padding(.vertical, 5)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func weeklyFormat(_ value: Double, metric: String) -> String {
        if metric == "Keystrokes" {
            return Int(value).formatted()
        } else {
            return "\(Int(value * 100))%"
        }
    }

    @ViewBuilder
    private func deltaLabel(_ row: WeeklyDeltaRow) -> some View {
        let threshold = row.metric == "Keystrokes" ? 0.01 : 0.005
        let isImprovement = row.lowerIsBetter ? row.delta < -threshold : row.delta > threshold
        let isRegression  = row.lowerIsBetter ? row.delta > threshold  : row.delta < -threshold
        let color: Color  = isImprovement ? .green : (isRegression ? .red : .secondary)

        let absStr: String = {
            if row.metric == "Keystrokes" {
                return abs(Int(row.delta)).formatted()
            } else {
                return "\(Int(abs(row.delta) * 100))pp"
            }
        }()
        let arrow = row.delta > threshold ? "↑" : (row.delta < -threshold ? "↓" : "→")

        Text("\(arrow) \(absStr)")
            .font(.callout.monospacedDigit())
            .foregroundStyle(color)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        Text("(no data yet)")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
    }
}
