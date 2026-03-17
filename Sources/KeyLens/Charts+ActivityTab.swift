import SwiftUI
import Charts
import KeyLensCore

extension ChartsView {

    var activityTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection(L10n.shared.chartTitleTypingSpeed, helpText: L10n.shared.helpTypingSpeed) { dailyWPMChart }
                chartSection(L10n.shared.chartTitleBackspaceRate, helpText: L10n.shared.helpBackspaceRate) { dailyAccuracyChart }
                chartSection(L10n.shared.chartTitleIKIHistogram, helpText: L10n.shared.helpIKIHistogram) { ikiHistogramChart }
                chartSection("Hourly Distribution", helpText: L10n.shared.helpHourlyDistribution) { hourlyDistributionChart }
                chartSection("Daily Totals", helpText: L10n.shared.helpDailyTotals) { dailyTotalsChart }
                chartSection("Monthly Totals", helpText: L10n.shared.helpMonthlyTotals) { monthlyTotalsChart }
                chartSection(L10n.shared.chartTitleSessions, helpText: L10n.shared.helpSessions) { sessionsChart }
            }
            .padding(24)
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
                            Text(String(d.dropFirst(5)))  // "yyyy-MM-dd" → "MM-dd"
                                .font(.footnote)
                        }
                    }
                }
            }
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
                            Text(String(d.dropFirst(5)))  // "yyyy-MM-dd" → "MM-dd"
                                .font(.footnote)
                        }
                    }
                }
            }
            .frame(height: 200)
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
            .frame(height: 180)
        }
    }

    // MARK: - Issue #60: Sessions chart

    @ViewBuilder
    var sessionsChart: some View {
        if model.sessionSummaries.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 16) {
                // Sessions per day (bar chart)
                Text(L10n.shared.sessionsPerDay)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Chart(model.sessionSummaries) { item in
                    BarMark(
                        x: .value("Date", item.date),
                        y: .value("Sessions", item.sessionCount)
                    )
                    .foregroundStyle(theme.accentColor)
                    .cornerRadius(3)
                }
                .frame(height: 140)

                // Longest session per day (bar chart)
                Text(L10n.shared.longestSessionLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Chart(model.sessionSummaries) { item in
                    BarMark(
                        x: .value("Date", item.date),
                        y: .value("Minutes", item.longestMinutes)
                    )
                    .foregroundStyle(theme.accentColor.opacity(0.7))
                    .cornerRadius(3)
                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Minutes", item.avgMinutes)
                    )
                    .foregroundStyle(theme.accentColor)
                    .symbolSize(30)
                }
                .frame(height: 140)
                Text("● \(L10n.shared.avgSessionLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
