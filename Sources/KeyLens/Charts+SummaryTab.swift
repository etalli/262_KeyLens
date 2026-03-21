import SwiftUI
import KeyLensCore

extension ChartsView {

    var summaryTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                chartSection(L10n.shared.weeklySummaryCardTitle) {
                    VStack(alignment: .leading, spacing: 12) {
                        WeeklySummaryCardView(data: .current(), embedded: true)
                    }
                }
                chartSection("Activity Calendar", helpText: L10n.shared.helpActivityCalendar) { activityCalendarChart }
                chartSection("Weekly Report", helpText: L10n.shared.helpWeeklyReport) { weeklyDeltaSection }
                chartSection(L10n.shared.intelligenceSection, helpText: L10n.shared.helpIntelligence) { intelligenceGroup }
                chartSection(L10n.shared.chartTitleMouseKeyboardBalance, helpText: L10n.shared.helpMouseKeyboardBalance) {
                    mouseKeyboardBalanceChart
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    var intelligenceGroup: some View {
        let l = L10n.shared
        let store = KeyCountStore.shared
        let style = store.currentTypingStyle
        let fatigue = store.currentFatigueLevel
        let rhythm = store.currentTypingRhythm

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 24) {
                intelligenceCard(
                    title: l.inferredStyle,
                    value: l.typingStyleLabel(style),
                    icon: styleIcon(style),
                    color: theme.accentColor
                )
                intelligenceCard(
                    title: l.fatigueRisk,
                    value: l.fatigueLevelLabel(fatigue),
                    icon: fatigueIcon(fatigue),
                    color: fatigueColor(fatigue)
                )
                intelligenceCard(
                    title: l.typingRhythm,
                    value: l.typingRhythmLabel(rhythm),
                    icon: rhythmIcon(rhythm),
                    color: rhythmColor(rhythm)
                )
            }

            // Personalized insight tip — tinted by current rhythm for instant visual feedback
            let rColor = rhythmColor(rhythm)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(rColor)
                    .font(.callout)
                VStack(alignment: .leading, spacing: 2) {
                    Text(l.typingInsightLabel)
                        .font(.caption).bold().foregroundStyle(.secondary)
                    Text(l.typingInsight(style: style, rhythm: rhythm, fatigue: fatigue))
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(rColor.opacity(0.1))
            .cornerRadius(10)
            .animation(.easeInOut(duration: 0.4), value: rhythm)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    func intelligenceCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(value)
                    .font(.title3.bold())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }

    func styleIcon(_ style: TypingStyle) -> String {
        switch style {
        case .prose:   return "doc.text"
        case .code:    return "terminal"
        case .chat:    return "message"
        case .unknown: return "questionmark.circle"
        }
    }

    func fatigueIcon(_ level: FatigueLevel) -> String {
        switch level {
        case .low:      return "checkmark.circle.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .high:     return "exclamationmark.octagon.fill"
        }
    }

    func fatigueColor(_ level: FatigueLevel) -> Color {
        switch level {
        case .low:      return .green
        case .moderate: return .orange
        case .high:     return .red
        }
    }

    func rhythmIcon(_ rhythm: TypingRhythm) -> String {
        switch rhythm {
        case .burst:      return "waveform.path.ecg"
        case .steadyFlow: return "waveform"
        case .balanced:   return "waveform.path"
        case .unknown:    return "ellipsis.circle"
        }
    }

    func rhythmColor(_ rhythm: TypingRhythm) -> Color {
        switch rhythm {
        case .burst:      return .purple
        case .steadyFlow: return .teal
        case .balanced:   return .blue
        case .unknown:    return .secondary
        }
    }

    @ViewBuilder
    var weeklyDeltaSection: some View {
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

    func weeklyFormat(_ value: Double, metric: String) -> String {
        if metric == "Keystrokes" {
            return Int(value).formatted()
        } else {
            return "\(Int(value * 100))%"
        }
    }

    @ViewBuilder
    func deltaLabel(_ row: WeeklyDeltaRow) -> some View {
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

    /// Calendar heatmap showing daily keystroke counts for the past 365 days.
    /// 過去365日の日別打鍵数をカレンダーヒートマップで表示する。
    @ViewBuilder
    var activityCalendarChart: some View {
        if model.dailyTotals.isEmpty {
            emptyState
        } else {
            ActivityCalendarView(dailyTotals: model.dailyTotals)
        }
    }
}
