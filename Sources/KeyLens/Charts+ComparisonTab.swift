import SwiftUI
import Charts
import KeyLensCore

// MARK: - Period Comparison Tab (Issue #62)

extension ChartsView {

    var comparisonTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection(
                    L10n.shared.chartTitlePeriodComparison,
                    helpText: L10n.shared.helpPeriodComparison
                ) {
                    comparisonControls
                }

                chartSection(L10n.shared.chartTitlePeriodComparison) {
                    comparisonChart
                }

                chartSection(L10n.shared.chartTitlePeriodComparison) {
                    comparisonSummaryTable
                }
            }
            .padding(24)
        }
        .onChange(of: comparisonPreset) { _ in applyPreset() }
    }

    // MARK: - Controls (preset picker + custom date pickers)

    @ViewBuilder
    var comparisonControls: some View {
        let l = L10n.shared
        VStack(alignment: .leading, spacing: 16) {
            // Preset buttons
            HStack(spacing: 8) {
                presetButton(label: l.comparisonPresetWeek,  tag: 1)
                presetButton(label: l.comparisonPresetMonth, tag: 2)
                presetButton(label: l.comparisonPresetCustom, tag: 0)
            }

            // Date pickers (always visible; disabled when a preset is active)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text(l.comparisonPeriodA)
                        .font(.subheadline.bold())
                        .foregroundStyle(theme.accentColor)
                        .gridColumnAlignment(.leading)
                    DatePicker(l.comparisonFrom, selection: $comparisonAStart,
                               in: ...comparisonAEnd, displayedComponents: .date)
                        .labelsHidden()
                        .disabled(comparisonPreset != 0)
                    DatePicker(l.comparisonTo,   selection: $comparisonAEnd,
                               in: comparisonAStart..., displayedComponents: .date)
                        .labelsHidden()
                        .disabled(comparisonPreset != 0)
                }
                GridRow {
                    Text(l.comparisonPeriodB)
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                        .gridColumnAlignment(.leading)
                    DatePicker(l.comparisonFrom, selection: $comparisonBStart,
                               in: ...comparisonBEnd, displayedComponents: .date)
                        .labelsHidden()
                        .disabled(comparisonPreset != 0)
                    DatePicker(l.comparisonTo,   selection: $comparisonBEnd,
                               in: comparisonBStart..., displayedComponents: .date)
                        .labelsHidden()
                        .disabled(comparisonPreset != 0)
                }
            }
            .opacity(comparisonPreset == 0 ? 1.0 : 0.6)
        }
    }

    @ViewBuilder
    func presetButton(label: String, tag: Int) -> some View {
        Button(label) { comparisonPreset = tag }
            .buttonStyle(.bordered)
            .tint(comparisonPreset == tag ? theme.accentColor : .secondary)
    }

    // MARK: - Overlaid chart

    @ViewBuilder
    var comparisonChart: some View {
        let seriesA = comparisonSeries(from: comparisonAStart, to: comparisonAEnd, label: L10n.shared.comparisonPeriodA)
        let seriesB = comparisonSeries(from: comparisonBStart, to: comparisonBEnd, label: L10n.shared.comparisonPeriodB)
        let allEmpty = seriesA.isEmpty && seriesB.isEmpty

        if allEmpty {
            Text(L10n.shared.comparisonNoData)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
        } else {
            let combined = seriesA + seriesB
            Chart(combined) { point in
                AreaMark(
                    x: .value(L10n.shared.comparisonDayOffset, point.dayOffset),
                    y: .value(L10n.shared.axisLabelKeys, point.total)
                )
                .foregroundStyle(by: .value("Period", point.series))
                .opacity(0.12)
                LineMark(
                    x: .value(L10n.shared.comparisonDayOffset, point.dayOffset),
                    y: .value(L10n.shared.axisLabelKeys, point.total)
                )
                .foregroundStyle(by: .value("Period", point.series))
                .interpolationMethod(.catmullRom)
                PointMark(
                    x: .value(L10n.shared.comparisonDayOffset, point.dayOffset),
                    y: .value(L10n.shared.axisLabelKeys, point.total)
                )
                .foregroundStyle(by: .value("Period", point.series))
                .symbolSize(25)
            }
            .chartForegroundStyleScale([
                L10n.shared.comparisonPeriodA: theme.accentColor,
                L10n.shared.comparisonPeriodB: Color.orange,
            ])
            .chartXAxisLabel(L10n.shared.comparisonDayOffset)
            .chartYAxisLabel(L10n.shared.axisLabelKeys, alignment: .trailing)
            .frame(height: 220)
        }
    }

    // MARK: - Summary table

    @ViewBuilder
    var comparisonSummaryTable: some View {
        let l = L10n.shared
        let statsA = comparisonStats(from: comparisonAStart, to: comparisonAEnd)
        let statsB = comparisonStats(from: comparisonBStart, to: comparisonBEnd)

        Grid(alignment: .trailing, horizontalSpacing: 20, verticalSpacing: 0) {
            GridRow {
                Text("").gridColumnAlignment(.leading)
                Text(l.comparisonPeriodA)
                    .font(.caption).bold()
                    .foregroundStyle(theme.accentColor)
                Text(l.comparisonPeriodB)
                    .font(.caption).bold()
                    .foregroundStyle(.orange)
                Text("Δ").font(.caption).bold().foregroundStyle(.secondary)
            }
            .padding(.bottom, 6)
            Divider().gridCellUnsizedAxes(.horizontal)

            summaryRow(label: l.comparisonTotalKeys,
                       a: statsA.total, b: statsB.total,
                       format: { Int($0).formatted() }, lowerIsBetter: false)
            summaryRow(label: l.comparisonAvgPerDay,
                       a: statsA.avgPerDay, b: statsB.avgPerDay,
                       format: { Int($0).formatted() }, lowerIsBetter: false)
            summaryRow(label: l.comparisonPeakDay,
                       a: statsA.peak, b: statsB.peak,
                       format: { Int($0).formatted() }, lowerIsBetter: false)
        }
    }

    @ViewBuilder
    func summaryRow(label: String, a: Double, b: Double,
                    format: (Double) -> String, lowerIsBetter: Bool) -> some View {
        let delta = a - b
        let threshold = max(a, b) * 0.01
        let isImprovement = lowerIsBetter ? delta < -threshold : delta > threshold
        let isRegression  = lowerIsBetter ? delta > threshold  : delta < -threshold
        let deltaColor: Color = isImprovement ? .green : (isRegression ? .red : .secondary)
        let arrow = delta > threshold ? "↑" : (delta < -threshold ? "↓" : "→")

        GridRow {
            Text(label)
                .font(.callout)
                .gridColumnAlignment(.leading)
            Text(format(a))
                .font(.callout.monospacedDigit())
                .foregroundStyle(theme.accentColor)
            Text(format(b))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.orange)
            Text("\(arrow) \(format(abs(delta)))")
                .font(.callout.monospacedDigit())
                .foregroundStyle(deltaColor)
        }
        .padding(.vertical, 5)
    }

    // MARK: - Data helpers

    /// Build an array of (dayOffset, total, series) for chart plotting.
    private func comparisonSeries(from start: Date, to end: Date, label: String) -> [ComparisonPoint] {
        KeyCountStore.shared.dailyTotals(from: start, to: end)
            .enumerated()
            .map { i, item in ComparisonPoint(dayOffset: i + 1, total: item.total, series: label) }
    }

    private struct ComparisonStats {
        var total: Double
        var avgPerDay: Double
        var peak: Double
    }

    private func comparisonStats(from start: Date, to end: Date) -> ComparisonStats {
        let data = KeyCountStore.shared.dailyTotals(from: start, to: end)
        let total = Double(data.map(\.total).reduce(0, +))
        let days  = Double(max(data.count, 1))
        let peak  = Double(data.map(\.total).max() ?? 0)
        return ComparisonStats(total: total, avgPerDay: total / days, peak: peak)
    }

    // MARK: - Preset application

    private func applyPreset() {
        let cal = Calendar.current
        let today = Date()
        switch comparisonPreset {
        case 1: // This week (Mon–today) vs last week
            let weekday = cal.component(.weekday, from: today)
            let daysFromMonday = (weekday + 5) % 7  // 0 = Mon, 6 = Sun
            comparisonAStart = cal.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
            comparisonAEnd   = today
            comparisonBStart = cal.date(byAdding: .day, value: -(daysFromMonday + 7), to: today) ?? today
            comparisonBEnd   = cal.date(byAdding: .day, value: -(daysFromMonday + 1), to: today) ?? today
        case 2: // This month vs last month
            let startOfThisMonth = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
            let startOfLastMonth = cal.date(byAdding: .month, value: -1, to: startOfThisMonth) ?? today
            let endOfLastMonth   = cal.date(byAdding: .day, value: -1, to: startOfThisMonth) ?? today
            comparisonAStart = startOfThisMonth
            comparisonAEnd   = today
            comparisonBStart = startOfLastMonth
            comparisonBEnd   = endOfLastMonth
        default:
            break  // custom — leave pickers as-is
        }
    }
}

// MARK: - Chart data point

private struct ComparisonPoint: Identifiable {
    let id = UUID()
    let dayOffset: Int
    let total: Int
    let series: String
}
