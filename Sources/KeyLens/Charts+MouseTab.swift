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
            .chartLegend(.hidden)
            .frame(height: 180)
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
