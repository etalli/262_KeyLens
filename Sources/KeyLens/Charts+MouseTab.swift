import SwiftUI
import Charts

extension ChartsView {

    var mouseTab: some View {
        let l = L10n.shared
        return ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection(l.chartTitleMouseDailyDistance, helpText: l.helpMouseDailyDistance) {
                    mouseDailyDistanceChart
                }
                chartSection(l.chartTitleMouseHourly, helpText: l.helpMouseHourly) {
                    mouseHourlyChart
                }
                chartSection(l.chartTitleMouseDirection, helpText: l.helpMouseDirection) {
                    mouseDirectionChart
                }
                chartSection(l.chartTitleMouseDailyDirection, helpText: l.helpMouseDailyDirection) {
                    mouseDailyDirectionTable
                }
            }
            .padding(24)
        }
    }

    // MARK: - Daily Distance Chart

    @ViewBuilder
    var mouseDailyDistanceChart: some View {
        if model.mouseDailyDistances.isEmpty {
            emptyState
        } else {
            Chart(model.mouseDailyDistances) { entry in
                BarMark(
                    x: .value("Date", entry.date),
                    y: .value("Distance (px)", entry.distancePts)
                )
                .foregroundStyle(theme.accentColor)
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(1, model.mouseDailyDistances.count / 6))) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month().day(), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatPts(v))
                                .font(.caption)
                        }
                    }
                }
            }
            .frame(height: 200)
        }
    }

    // MARK: - Hourly Activity Chart

    @ViewBuilder
    var mouseHourlyChart: some View {
        if model.mouseHourlyActivity.isEmpty {
            emptyState
        } else {
            Chart(model.mouseHourlyActivity) { entry in
                BarMark(
                    x: .value("Hour", entry.hourLabel),
                    y: .value("Distance (px)", entry.distancePts)
                )
                .foregroundStyle(theme.accentColor.opacity(0.85))
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: 1)) { value in
                    if let label = value.as(String.self),
                       label.hasPrefix("00") || label.hasPrefix("06") ||
                       label.hasPrefix("12") || label.hasPrefix("18") {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatPts(v))
                                .font(.caption)
                        }
                    }
                }
            }
            .frame(height: 180)
        }
    }

    // MARK: - Direction Breakdown Chart

    @ViewBuilder
    var mouseDirectionChart: some View {
        if model.mouseDirectionEntries.isEmpty {
            emptyState
        } else {
            Chart(model.mouseDirectionEntries) { entry in
                BarMark(
                    x: .value("Direction", entry.direction),
                    y: .value("Distance (px)", entry.distancePts)
                )
                .foregroundStyle(by: .value("Direction", entry.direction))
                .cornerRadius(4)
                .annotation(position: .top, spacing: 4) {
                    Text(formatPts(entry.distancePts))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                }
            }
            .chartLegend(.hidden)
            .frame(height: 180)
        }
    }

    // MARK: - Daily Direction Table

    @ViewBuilder
    var mouseDailyDirectionTable: some View {
        let l = L10n.shared
        if model.mouseDailyDirectionEntries.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Text(l.dateLabel)
                        .frame(width: 100, alignment: .leading)
                    Text(l.mouseColRight)
                        .frame(width: 80, alignment: .trailing)
                    Text(l.mouseColLeft)
                        .frame(width: 80, alignment: .trailing)
                    Text(l.mouseColDown)
                        .frame(width: 80, alignment: .trailing)
                    Text(l.mouseColUp)
                        .frame(width: 80, alignment: .trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)

                Divider()

                ForEach(Array(model.mouseDailyDirectionEntries.enumerated()), id: \.element.id) { idx, entry in
                    HStack(spacing: 0) {
                        Text(entry.date)
                            .frame(width: 100, alignment: .leading)
                        Text(formatPts(entry.right))
                            .frame(width: 80, alignment: .trailing)
                        Text(formatPts(entry.left))
                            .frame(width: 80, alignment: .trailing)
                        Text(formatPts(entry.down))
                            .frame(width: 80, alignment: .trailing)
                        Text(formatPts(entry.up))
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(idx % 2 == 0 ? Color.clear : Color.primary.opacity(0.04))
                }
            }
            .frame(maxWidth: 440, alignment: .leading)
        }
    }

    // MARK: - Mouse vs Keyboard Balance Chart

    @ViewBuilder
    var mouseKeyboardBalanceChart: some View {
        let l = L10n.shared
        if model.mouseKeyboardBalance.isEmpty {
            emptyState
        } else {
            let entries = model.mouseKeyboardBalance
            let maxDist = entries.map(\.distancePts).max() ?? 1
            let maxKeys = entries.map(\.keystrokes).max().map(Double.init) ?? 1
            Chart(entries) { entry in
                BarMark(
                    x: .value("Date", entry.date),
                    y: .value(l.mouseKeyboardBalanceMouseLabel, entry.distancePts / maxDist),
                    width: .ratio(0.4)
                )
                .offset(x: -4)
                .foregroundStyle(theme.accentColor)
                .cornerRadius(2)
                BarMark(
                    x: .value("Date", entry.date),
                    y: .value(l.mouseKeyboardBalanceKeysLabel, Double(entry.keystrokes) / maxKeys),
                    width: .ratio(0.4)
                )
                .offset(x: 4)
                .foregroundStyle(Color.orange)
                .cornerRadius(2)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartYAxis(.hidden)
            .chartForegroundStyleScale([
                l.mouseKeyboardBalanceMouseLabel: theme.accentColor,
                l.mouseKeyboardBalanceKeysLabel:  Color.orange,
            ])
            .frame(height: 200)
        }
    }

    // MARK: - Helpers

    private func formatPts(_ pts: Double) -> String {
        if pts >= 1_000_000 {
            return String(format: "%.1fM", pts / 1_000_000)
        } else if pts >= 1_000 {
            return String(format: "%.0fK", pts / 1_000)
        } else {
            return String(format: "%.0f", pts)
        }
    }
}
