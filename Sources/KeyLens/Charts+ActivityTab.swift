import SwiftUI
import Charts
import KeyLensCore

// MARK: - Activity sub-tab enum (Issue #272)

enum ActivitySubTab: String, CaseIterable {
    case speed
    case patterns
    case volume
}

extension ChartsView {

    var activityTab: some View {
        VStack(spacing: 0) {
            SubTabPicker(selection: $activitySubTab) {
                Text(L10n.shared.activitySubTabSpeed).tag(ActivitySubTab.speed)
                Text(L10n.shared.activitySubTabPatterns).tag(ActivitySubTab.patterns)
                Text(L10n.shared.activitySubTabVolume).tag(ActivitySubTab.volume)
            }

            switch activitySubTab {
            case .speed:
                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        chartSection(L10n.shared.chartTitleTypingSpeed, helpText: L10n.shared.helpTypingSpeed) { dailyWPMChart }
                        chartSection(L10n.shared.chartTitleBackspaceRate, helpText: L10n.shared.helpBackspaceRate) { dailyAccuracyChart }
                        chartSection(L10n.shared.chartTitleIKIHistogram, helpText: L10n.shared.helpIKIHistogram) { ikiHistogramChart }
                    }
                    .padding(24)
                }

            case .patterns:
                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        chartSection(L10n.shared.chartTitleWeeklyHeatmap, helpText: L10n.shared.helpWeeklyHeatmap) { weeklyHeatmapChart }
                        chartSection(L10n.shared.chartTitleSessionRhythm, helpText: L10n.shared.helpSessionRhythm) {
                            SessionWeeklyHeatmapView(cells: model.sessionHeatmapCells)
                        }
                        chartSection(L10n.shared.chartTitleHourlyDistribution, helpText: L10n.shared.helpHourlyDistribution) { hourlyDistributionChart }
                    }
                    .padding(24)
                }

            case .volume:
                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        chartSection(L10n.shared.chartTitleDailyTotals, helpText: L10n.shared.helpDailyTotals) { dailyTotalsChart }
                        chartSection(L10n.shared.chartTitleMonthlyTotals, helpText: L10n.shared.helpMonthlyTotals) { monthlyTotalsChart }
                        chartSection(L10n.shared.chartTitleKeyAccumulation, helpText: L10n.shared.helpKeyAccumulation) { keyAccumulationChart }
                        chartSection(L10n.shared.chartTitleSessions, helpText: L10n.shared.helpSessions) { sessionsChart }
                    }
                    .padding(24)
                }
            }
        }
    }

    @ViewBuilder
    var dailyTotalsChart: some View {
        if model.dailyTotals.isEmpty {
            emptyState
        } else if model.dailyTotals.count == 1 {
            // 1点のみの場合は BarMark で代替
            Chart(model.dailyTotals) { item in
                BarMark(x: .value("Date", item.date), y: .value("Total", item.total))
                    .foregroundStyle(theme.accentColor)
                    .cornerRadius(4)
            }
            .frame(height: 180)
        } else {
            Chart(model.dailyTotals) { item in
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("Total", item.total)
                )
                .foregroundStyle(theme.accentColor.opacity(0.12))
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Total", item.total)
                )
                .foregroundStyle(theme.accentColor)
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Date", item.date),
                    y: .value("Total", item.total)
                )
                .foregroundStyle(theme.accentColor)
                .annotation(position: .top, spacing: 4) {
                    Text(item.total.formatted())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                let stride = max(2, model.dailyTotals.count / 5)
                AxisMarks(values: model.dailyTotals.enumerated()
                    .filter { $0.offset % stride == 0 }
                    .map { $0.element.date }
                ) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = value.as(String.self) {
                            Text(String(d.dropFirst(5)).replacingOccurrences(of: "-", with: "/"))  // "yyyy-MM-dd" → "MM/dd"
                                .font(.footnote)
                        }
                    }
                }
            }
            .chartYAxisLabel(L10n.shared.axisLabelKeys, alignment: .trailing)
            .frame(height: 200)
        }
    }

    @ViewBuilder
    var dailyWPMChart: some View {
        if model.dailyWPM.isEmpty {
            emptyState
        } else if model.dailyWPM.count == 1 {
            Chart(model.dailyWPM) { item in
                BarMark(x: .value("Date", item.date), y: .value("WPM", item.wpm))
                    .foregroundStyle(.orange)
                    .cornerRadius(4)
            }
            .frame(height: 180)
        } else {
            Chart(model.dailyWPM) { item in
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("WPM", item.wpm)
                )
                .foregroundStyle(.orange.opacity(0.12))
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("WPM", item.wpm)
                )
                .foregroundStyle(.orange)
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Date", item.date),
                    y: .value("WPM", item.wpm)
                )
                .foregroundStyle(.orange)
                .annotation(position: .top, spacing: 4) {
                    Text(String(format: "%.0f", item.wpm))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                let stride = max(2, model.dailyWPM.count / 5)
                AxisMarks(values: model.dailyWPM.enumerated()
                    .filter { $0.offset % stride == 0 }
                    .map { $0.element.date }
                ) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = value.as(String.self) {
                            Text(String(d.dropFirst(5)).replacingOccurrences(of: "-", with: "/"))  // "yyyy-MM-dd" → "MM/dd"
                                .font(.footnote)
                        }
                    }
                }
            }
            .chartYAxisLabel(L10n.shared.axisLabelWPM, alignment: .trailing)
            .frame(height: 200)
        }
    }

    @ViewBuilder
    var dailyAccuracyChart: some View {
        if model.dailyAccuracy.isEmpty {
            emptyState
        } else if model.dailyAccuracy.count == 1 {
            Chart(model.dailyAccuracy) { item in
                BarMark(x: .value("Date", item.date), y: .value("BS rate", item.rate))
                    .foregroundStyle(.red.opacity(0.7))
                    .cornerRadius(4)
            }
            .frame(height: 180)
        } else {
            Chart(model.dailyAccuracy) { item in
                AreaMark(
                    x: .value("Date", item.date),
                    y: .value("BS rate", item.rate)
                )
                .foregroundStyle(.red.opacity(0.10))
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("BS rate", item.rate)
                )
                .foregroundStyle(.red.opacity(0.8))
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value("Date", item.date),
                    y: .value("BS rate", item.rate)
                )
                .foregroundStyle(.red.opacity(0.8))
                .annotation(position: .top, spacing: 4) {
                    Text(String(format: "%.1f%%", item.rate))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                let stride = max(2, model.dailyAccuracy.count / 5)
                AxisMarks(values: model.dailyAccuracy.enumerated()
                    .filter { $0.offset % stride == 0 }
                    .map { $0.element.date }
                ) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = value.as(String.self) {
                            Text(String(d.dropFirst(5)).replacingOccurrences(of: "-", with: "/"))  // "yyyy-MM-dd" → "MM/dd"
                                .font(.footnote)
                        }
                    }
                }
            }
            .chartYAxisLabel(L10n.shared.axisLabelPercent, alignment: .trailing)
            .frame(height: 200)
        }
    }

    // MARK: - Issue #78: Weekly Activity Heatmap

    /// 7×24 grid heatmap: average keystrokes per (day-of-week, hour) cell.
    /// 曜日×時刻の週間ヒートマップ (Issue #78)。
    @ViewBuilder
    var weeklyHeatmapChart: some View {
        let cells = model.weeklyHeatmap
        if cells.isEmpty || cells.allSatisfy({ $0.avgCount == 0 }) {
            emptyState
        } else {
            WeeklyHeatmapView(cells: cells)
        }
    }

    /// 24-bar chart showing aggregate keystroke count by hour of day.
    /// 時刻 (0〜23時) 別の累積打鍵数棒グラフ。
    @ViewBuilder
    var hourlyDistributionChart: some View {
        let dist = model.hourlyDistribution
        if dist.isEmpty || dist.allSatisfy({ $0 == 0 }) {
            emptyState
        } else {
            let entries = dist.enumerated().map { HourEntry(hour: $0.offset, count: $0.element) }
            Chart(entries) { item in
                BarMark(
                    x: .value("Hour", item.hourLabel),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(item.isWorkHour ? Color.blue.opacity(0.75) : Color.blue.opacity(0.35))
                .cornerRadius(2)
            }
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23].map { String(format: "%02d:00", $0) }) { value in
                    AxisValueLabel { Text(value.as(String.self) ?? "") }
                    AxisGridLine()
                }
            }
            .chartYAxisLabel(L10n.shared.axisLabelKeys, alignment: .trailing)
            .frame(height: 160)
        }
    }

    /// Bar chart showing the distribution of inter-keystroke intervals (IKI) across all recorded keystrokes.
    /// 全打鍵データのIKI分布ヒストグラム (Issue #102)。
    @ViewBuilder
    var ikiHistogramChart: some View {
        let entries = model.ikiHistogram
        if entries.isEmpty || entries.allSatisfy({ $0.count == 0 }) {
            emptyState
        } else {
            Chart(entries) { item in
                BarMark(
                    x: .value("IKI", item.bucket),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(ikiHistogramColor(for: item.bucket))
                .cornerRadius(3)
                .annotation(position: .top, spacing: 3) {
                    if item.count > 0 {
                        Text(String(format: "%.0f%%", item.percentage))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let s = value.as(String.self) {
                            Text(s).font(.footnote)
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartYAxisLabel(L10n.shared.axisLabelKeys, alignment: .trailing)
            .frame(height: 180)
        }
    }

    private func ikiHistogramColor(for bucket: String) -> Color {
        switch bucket {
        case "0–50", "50–100":   return .green.opacity(0.8)
        case "100–150", "150–200": return .orange.opacity(0.75)
        default:                   return .red.opacity(0.7)
        }
    }

    /// Bar chart of total keystrokes per calendar month (last 12 months).
    /// 月別打鍵数合計の棒グラフ (直近12ヶ月)。
    @ViewBuilder
    var monthlyTotalsChart: some View {
        let entries = Array(model.monthlyTotals.suffix(12))
        if entries.isEmpty {
            emptyState
        } else {
            Chart(entries) { item in
                BarMark(
                    x: .value("Month", item.month),
                    y: .value("Total", item.total)
                )
                .foregroundStyle(.teal.opacity(0.75))
                .cornerRadius(4)
                .annotation(position: .top, spacing: 3) {
                    Text(item.total.formatted(.number.notation(.compactName)))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let s = value.as(String.self) {
                            // "yyyy-MM" → show "yy/MM" for compactness
                            // 表示例: "2024-03" → "24/03"
                            let parts = s.split(separator: "-")
                            let label = parts.count == 2
                                ? "\(String(parts[0]).suffix(2))/\(parts[1])"
                                : s
                            Text(label)
                                .font(.footnote)
                        }
                    }
                }
            }
            .chartYAxisLabel(L10n.shared.axisLabelKeys, alignment: .trailing)
            .frame(height: 180)
        }
    }

    // MARK: - Issue #347 / #349: Key Accumulation Chart with device filter

    @ViewBuilder
    var keyAccumulationChart: some View {
        let deviceNames = model.topDevices.map(\.device)
        let activeEntries: [AccumulationEntry] = {
            if let dev = accumSelectedDevice, let entries = model.keyAccumulationByDevice[dev] {
                return entries
            }
            return model.keyAccumulation
        }()

        if activeEntries.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if deviceNames.count > 1 {
                    Picker("", selection: $accumSelectedDevice) {
                        Text(L10n.shared.accumDeviceFilterAll).tag(String?.none)
                        ForEach(deviceNames, id: \.self) { name in
                            Text(name).tag(String?.some(name))
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 320)
                }

                accumChartContent(entries: activeEntries)
            }
        }
    }

    @ViewBuilder
    private func accumChartContent(entries: [AccumulationEntry]) -> some View {
        if entries.count == 1 {
            Chart(entries) { item in
                BarMark(x: .value("Date", item.date), y: .value("Total", item.cumulative))
                    .foregroundStyle(theme.accentColor)
                    .cornerRadius(4)
            }
            .frame(height: 180)
        } else {
            let milestone = entries.first(where: { $0.cumulative >= 1_000_000 })
            Chart {
                ForEach(entries) { item in
                    AreaMark(
                        x: .value("Date", item.date),
                        y: .value("Cumulative", item.cumulative)
                    )
                    .foregroundStyle(theme.accentColor.opacity(0.12))
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Cumulative", item.cumulative)
                    )
                    .foregroundStyle(theme.accentColor)
                    .interpolationMethod(.catmullRom)
                }
                if let m = milestone {
                    RuleMark(y: .value("1M", 1_000_000))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .annotation(position: .top, alignment: .leading) {
                            Text("1M")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    PointMark(
                        x: .value("Date", m.date),
                        y: .value("Cumulative", m.cumulative)
                    )
                    .foregroundStyle(.yellow)
                    .symbolSize(60)
                    .annotation(position: .top, spacing: 4) {
                        Text("🎉 1M")
                            .font(.caption2)
                    }
                }
            }
            .chartXAxis {
                let stride = max(2, entries.count / 5)
                AxisMarks(values: entries.enumerated()
                    .filter { $0.offset % stride == 0 }
                    .map { $0.element.date }
                ) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let d = value.as(String.self) {
                            Text(String(d.dropFirst(5)).replacingOccurrences(of: "-", with: "/"))
                                .font(.footnote)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text(v.formatted(.number.notation(.compactName)))
                                .font(.footnote)
                        }
                    }
                }
            }
            .chartYAxisLabel(L10n.shared.axisLabelKeys, alignment: .trailing)
            .frame(height: 200)
        }
    }

    // MARK: - Issue #291: Outlier threshold helper (mean + 1.5 × stddev)

    private func outlierThreshold(_ values: [Double]) -> Double {
        guard values.count > 1 else { return .infinity }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        return mean + 1.5 * variance.squareRoot()
    }

    // MARK: - Issue #60: Sessions chart

    @ViewBuilder
    var sessionsChart: some View {
        if model.sessionSummaries.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 16) {
                // Issue #290: consecutive active-day streak badge
                HStack(spacing: 8) {
                    Text(L10n.shared.sessionStreakDisplay(model.sessionStreakDays))
                        .font(.headline)
                    Spacer()
                    Text(L10n.shared.sessionStreakTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(theme.accentColor.opacity(0.10))
                .cornerRadius(8)

                // Sessions per day (bar chart)
                Text(L10n.shared.sessionsPerDay)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                let sessionCountThreshold = outlierThreshold(model.sessionSummaries.map { Double($0.sessionCount) })
                Chart(model.sessionSummaries) { item in
                    BarMark(
                        x: .value("Date", item.date),
                        y: .value("Sessions", item.sessionCount)
                    )
                    .foregroundStyle(theme.accentColor)
                    .cornerRadius(3)
                    .annotation(position: .top, spacing: 2) {
                        if Double(item.sessionCount) > sessionCountThreshold {
                            Text(L10n.shared.outlierLabel)
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .chartXAxis {
                    let stride = max(2, model.sessionSummaries.count / 5)
                    AxisMarks(values: model.sessionSummaries.enumerated()
                        .filter { $0.offset % stride == 0 }
                        .map { $0.element.date }
                    ) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let d = value.as(String.self) {
                                Text(String(d.dropFirst(5)).replacingOccurrences(of: "-", with: "/"))  // "yyyy-MM-dd" → "MM/dd"
                                    .font(.footnote)
                            }
                        }
                    }
                }
                .chartYAxisLabel(L10n.shared.axisLabelSessions, alignment: .trailing)
                .frame(height: 140)

                // Longest session per day (bar chart)
                Text(L10n.shared.longestSessionLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                let longestThreshold = outlierThreshold(model.sessionSummaries.map { $0.longestMinutes })
                Chart(model.sessionSummaries) { item in
                    BarMark(
                        x: .value("Date", item.date),
                        y: .value("Minutes", item.longestMinutes)
                    )
                    .foregroundStyle(theme.accentColor.opacity(0.7))
                    .cornerRadius(3)
                    .annotation(position: .top, spacing: 2) {
                        if item.longestMinutes > longestThreshold {
                            Text(L10n.shared.outlierLabel)
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .chartXAxis {
                    let stride = max(2, model.sessionSummaries.count / 5)
                    AxisMarks(values: model.sessionSummaries.enumerated()
                        .filter { $0.offset % stride == 0 }
                        .map { $0.element.date }
                    ) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let d = value.as(String.self) {
                                Text(String(d.dropFirst(5)).replacingOccurrences(of: "-", with: "/"))  // "yyyy-MM-dd" → "MM/dd"
                                    .font(.footnote)
                            }
                        }
                    }
                }
                .chartYAxisLabel(L10n.shared.axisLabelMinutes, alignment: .trailing)
                .frame(height: 140)

                // Average session per day (bar chart)
                Text(L10n.shared.avgSessionLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                let avgThreshold = outlierThreshold(model.sessionSummaries.map { $0.avgMinutes })
                Chart(model.sessionSummaries) { item in
                    BarMark(
                        x: .value("Date", item.date),
                        y: .value("Minutes", item.avgMinutes)
                    )
                    .foregroundStyle(theme.accentColor.opacity(0.5))
                    .cornerRadius(3)
                    .annotation(position: .top, spacing: 2) {
                        if item.avgMinutes > avgThreshold {
                            Text(L10n.shared.outlierLabel)
                                .font(.system(size: 9))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .chartXAxis {
                    let stride = max(2, model.sessionSummaries.count / 5)
                    AxisMarks(values: model.sessionSummaries.enumerated()
                        .filter { $0.offset % stride == 0 }
                        .map { $0.element.date }
                    ) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let d = value.as(String.self) {
                                Text(String(d.dropFirst(5)).replacingOccurrences(of: "-", with: "/"))  // "yyyy-MM-dd" → "MM/dd"
                                    .font(.footnote)
                            }
                        }
                    }
                }
                .chartYAxisLabel(L10n.shared.axisLabelMinutes, alignment: .trailing)
                .frame(height: 140)
            }
        }
    }
}

// MARK: - Issue #292: SessionWeeklyHeatmapView (7 rows × 24 cols, session count / avg duration)

/// Interactive 7-row (Mon–Sun) × 24-column (0–23h) heatmap for session rhythm.
/// Metric toggle: Session Count / Avg Duration.
struct SessionWeeklyHeatmapView: View {
    let cells: [SessionHeatmapCell]

    @State private var metric: SessionHeatmapMetric = .count
    @State private var hoveredCell: SessionHeatmapCell? = nil

    enum SessionHeatmapMetric { case count, duration }

    private let cellW:   CGFloat = 22
    private let cellH:   CGFloat = 18
    private let labelW:  CGFloat = 30
    private let headerH: CGFloat = 20

    private var lookup: [Int: SessionHeatmapCell] {
        Dictionary(uniqueKeysWithValues: cells.map { ($0.weekday * 24 + $0.hour, $0) })
    }

    private var maxValue: Double {
        switch metric {
        case .count:    return cells.map(\.avgCount).max().flatMap { $0 > 0 ? $0 : nil } ?? 1
        case .duration: return cells.map(\.avgDurationMinutes).max().flatMap { $0 > 0 ? $0 : nil } ?? 1
        }
    }

    var body: some View {
        if cells.isEmpty {
            Text(L10n.shared.noDataYet)
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Picker("", selection: $metric) {
                    Text(L10n.shared.sessionRhythmMetricCount).tag(SessionHeatmapMetric.count)
                    Text(L10n.shared.sessionRhythmMetricDuration).tag(SessionHeatmapMetric.duration)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)

                grid
                tooltipLine
                legend
            }
        }
    }

    private var weekdayDisplayOrder: [Int] { [1, 2, 3, 4, 5, 6, 0] }

    private var grid: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Spacer().frame(width: labelW)
                ForEach(0..<24, id: \.self) { h in
                    Text(h % 4 == 0 ? String(format: "%02d", h) : "")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .frame(width: cellW, height: headerH, alignment: .leading)
                }
            }
            ForEach(weekdayDisplayOrder, id: \.self) { wd in
                weekdayRow(wd: wd)
            }
        }
    }

    private func weekdayRow(wd: Int) -> some View {
        let abbrs = L10n.shared.weekdayAbbrs
        let label = wd < abbrs.count ? abbrs[wd] : ""
        return HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: labelW, height: cellH, alignment: .trailing)
                .padding(.trailing, 4)
            ForEach(0..<24, id: \.self) { h in
                let cell = lookup[wd * 24 + h]
                let value: Double = {
                    guard let c = cell else { return 0 }
                    switch metric {
                    case .count:    return c.avgCount
                    case .duration: return c.avgDurationMinutes
                    }
                }()
                let intensity = maxValue > 0 ? value / maxValue : 0
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.teal.opacity(0.06 + intensity * 0.88))
                    .frame(width: cellW - 2, height: cellH - 2)
                    .padding(1)
                    .onHover { isHovered in hoveredCell = isHovered ? cell : nil }
            }
        }
    }

    @ViewBuilder
    private var tooltipLine: some View {
        if let cell = hoveredCell {
            let abbrs   = L10n.shared.weekdayAbbrs
            let dayName = cell.weekday < abbrs.count ? abbrs[cell.weekday] : ""
            Text(L10n.shared.sessionRhythmTooltip(
                day: dayName,
                hour: cell.hour,
                count: Int(cell.avgCount.rounded()),
                durationMin: cell.avgDurationMinutes
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
            Text(" ").font(.caption)
        }
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text(L10n.shared.calendarLegendLow)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
            ForEach([0.1, 0.3, 0.5, 0.7, 1.0], id: \.self) { i in
                Rectangle()
                    .fill(Color.teal.opacity(0.06 + i * 0.88))
                    .frame(width: 10, height: 10)
                    .cornerRadius(2)
            }
            Text(L10n.shared.calendarLegendHigh)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Issue #239: WeeklyHeatmapView (GitHub-contribution style, 7 rows × 24 cols)

/// Interactive 7-row (Mon–Sun) × 24-column (0–23h) heatmap.
/// Supports a metric toggle: Keystrokes / WPM.
/// Hovering over a cell shows a tooltip with count + WPM.
struct WeeklyHeatmapView: View {
    let cells: [HeatmapCell]

    @State private var hoveredCell: HeatmapCell? = nil
    @State private var metric: HeatmapMetric = .keystrokes

    enum HeatmapMetric { case keystrokes, wpm }

    private let cellW:   CGFloat = 22
    private let cellH:   CGFloat = 18
    private let labelW:  CGFloat = 30
    private let headerH: CGFloat = 20

    private var lookup: [Int: HeatmapCell] {
        Dictionary(uniqueKeysWithValues: cells.map { ($0.weekday * 24 + $0.hour, $0) })
    }

    private var maxValue: Double {
        switch metric {
        case .keystrokes:
            return cells.map(\.avgCount).max().flatMap { $0 > 0 ? $0 : nil } ?? 1
        case .wpm:
            return cells.compactMap(\.avgWPM).max().flatMap { $0 > 0 ? $0 : nil } ?? 1
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Metric toggle
            Picker("", selection: $metric) {
                Text(L10n.shared.heatmapMetricKeys).tag(HeatmapMetric.keystrokes)
                Text(L10n.shared.heatmapMetricWPM).tag(HeatmapMetric.wpm)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)

            grid
            tooltipLine
            legend
        }
    }

    // 7 rows (weekday) × 24 columns (hour)
    private var grid: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hour header row
            HStack(spacing: 0) {
                Spacer().frame(width: labelW)
                ForEach(0..<24, id: \.self) { h in
                    Text(h % 4 == 0 ? String(format: "%02d", h) : "")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .frame(width: cellW, height: headerH, alignment: .leading)
                }
            }
            // One row per weekday (Sun=0 … Sat=6), reordered to Mon-first display
            ForEach(weekdayDisplayOrder, id: \.self) { wd in
                weekdayRow(wd: wd)
            }
        }
    }

    // Display Mon(1)…Sat(6), Sun(0) — Monday first
    private var weekdayDisplayOrder: [Int] { [1, 2, 3, 4, 5, 6, 0] }

    private func weekdayRow(wd: Int) -> some View {
        let abbrs = L10n.shared.weekdayAbbrs
        let label = wd < abbrs.count ? abbrs[wd] : ""
        return HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: labelW, height: cellH, alignment: .trailing)
                .padding(.trailing, 4)
            ForEach(0..<24, id: \.self) { h in
                cellView(wd: wd, hour: h)
            }
        }
    }

    private func cellView(wd: Int, hour: Int) -> some View {
        let cell  = lookup[wd * 24 + hour]
        let value: Double = {
            switch metric {
            case .keystrokes: return cell?.avgCount ?? 0
            case .wpm:        return cell?.avgWPM   ?? 0
            }
        }()
        let intensity = maxValue > 0 ? min(value / maxValue, 1.0) : 0
        let fill = Color.blue.opacity(0.06 + intensity * 0.88)
        let fullNames = L10n.shared.weekdayFullNames
        let dayName = wd < fullNames.count ? fullNames[wd] : ""
        let a11yLabel = L10n.shared.heatmapCellAccessibilityLabel(
            weekday: dayName,
            hour: hour,
            avgCount: cell?.avgCount ?? 0,
            avgWPM: cell?.avgWPM
        )
        return Rectangle()
            .fill(fill)
            .frame(width: cellW - 1, height: cellH - 1)
            .cornerRadius(2)
            .onHover { hovering in hoveredCell = hovering ? cell : nil }
            .accessibilityLabel(a11yLabel)
    }

    @ViewBuilder
    private var tooltipLine: some View {
        if let cell = hoveredCell {
            let fullNames = L10n.shared.weekdayFullNames
            let dayName   = cell.weekday < fullNames.count ? fullNames[cell.weekday] : ""
            let hourStr   = String(format: "%02d:00", cell.hour)
            let keysLabel = L10n.shared.heatmapAvgLabel(Int(cell.avgCount.rounded()))
            let wpmPart: String = {
                if let wpm = cell.avgWPM {
                    return "  ·  \(String(format: "%.0f", wpm)) WPM"
                }
                return ""
            }()
            Text("\(dayName) \(hourStr)  ·  \(keysLabel)\(wpmPart)")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text(" ").font(.caption)
        }
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text(L10n.shared.calendarLegendLow)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
            ForEach([0.1, 0.3, 0.5, 0.7, 1.0], id: \.self) { i in
                Rectangle()
                    .fill(Color.blue.opacity(0.06 + i * 0.88))
                    .frame(width: 10, height: 10)
                    .cornerRadius(2)
            }
            Text(L10n.shared.calendarLegendHigh)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }
}
