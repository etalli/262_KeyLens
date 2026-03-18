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
                chartSection(l.chartTitleMouseClickCount, helpText: l.helpMouseClickCount) {
                    mouseClickCountView
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
            // ratio = mousePct / (mousePct + keysPct): 0% = keyboard-only, 100% = mouse-only
            let ratioEntries = entries.map { entry -> (date: String, ratio: Double) in
                let m = entry.distancePts / maxDist
                let k = Double(entry.keystrokes) / maxKeys
                let total = m + k
                return (date: entry.date, ratio: total > 0 ? m / total : 0.5)
            }
            Chart {
                // 50% reference line
                RuleMark(y: .value("Balanced", 0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.secondary.opacity(0.5))
                    .annotation(position: .trailing, alignment: .center) {
                        Text(l.mouseKeyboardBalanceBalanced)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                ForEach(ratioEntries, id: \.date) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        yStart: .value("Ratio", 0.5),
                        yEnd:   .value("Ratio", point.ratio)
                    )
                    .foregroundStyle(
                        (point.ratio >= 0.5 ? theme.accentColor : Color.orange).opacity(0.25)
                    )
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Ratio", point.ratio)
                    )
                    .foregroundStyle(point.ratio >= 0.5 ? theme.accentColor : Color.orange)
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Ratio", point.ratio)
                    )
                    .foregroundStyle(point.ratio >= 0.5 ? theme.accentColor : Color.orange)
                    .symbolSize(20)
                }
            }
            .chartXAxis {
                let stride = max(1, ratioEntries.count / 6)
                AxisMarks(values: ratioEntries.enumerated().compactMap { i, e in
                    i % stride == 0 ? e.date : nil
                }) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let s = value.as(String.self) {
                            // "yyyy-MM-dd" → "MM/dd"
                            let parts = s.split(separator: "-")
                            if parts.count == 3 {
                                Text("\(parts[1])/\(parts[2])")
                            } else {
                                Text(s)
                            }
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0.0, 0.5, 1.0]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            if v == 0.0 {
                                Text(l.mouseKeyboardBalanceKeysLabel).font(.system(size: 9))
                            } else if v == 1.0 {
                                Text(l.mouseKeyboardBalanceMouseLabel).font(.system(size: 9))
                            } else {
                                Text("50%").font(.system(size: 9))
                            }
                        }
                    }
                }
            }
            .chartYScale(domain: 0...1)
            .frame(height: 200)
        }
    }

    // MARK: - Mouse Click Count

    var mouseClickCountView: some View {
        let counts = model.keyCounts
        let buttons: [(label: String, key: String)] = [
            (label: "🖱 Left",   key: "🖱Left"),
            (label: "🖱 Middle", key: "🖱Middle"),
            (label: "🖱 Right",  key: "🖱Right"),
        ]
        let maxCount = buttons.map { counts[$0.key] ?? 0 }.max() ?? 1
        return HStack(spacing: 16) {
            ForEach(buttons, id: \.key) { btn in
                let count = counts[btn.key] ?? 0
                VStack(spacing: 6) {
                    Text(btn.label)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("\(count)")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.accentColor)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(theme.accentColor.opacity(0.25))
                            .frame(width: geo.size.width,
                                   height: max(4, geo.size.height * CGFloat(count) / CGFloat(maxCount)))
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .frame(height: 40)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
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
