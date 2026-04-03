import SwiftUI
import Charts
import KeyLensCore

// MARK: - Ergonomics sub-tab enum (Issue #273)

enum ErgoSubTab: String, CaseIterable {
    case recommendations
    case bigrams
    case layout
    case fatigue
    case optimizer
}

extension ChartsView {

    var ergonomicsTab: some View {
        VStack(spacing: 0) {
            Picker("", selection: $ergoSubTab) {
                Text(L10n.shared.ergoSubTabRecommendations).tag(ErgoSubTab.recommendations)
                Text(L10n.shared.ergoSubTabBigrams).tag(ErgoSubTab.bigrams)
                Text(L10n.shared.ergoSubTabLayout).tag(ErgoSubTab.layout)
                Text(L10n.shared.ergoSubTabFatigue).tag(ErgoSubTab.fatigue)
                Text(L10n.shared.ergoSubTabOptimizer).tag(ErgoSubTab.optimizer)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            switch ergoSubTab {
            case .recommendations:
                ErgoRecommendationsView()

            case .bigrams:
                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        chartSection(L10n.shared.chartTitleTopBigrams, helpText: L10n.shared.helpBigrams, showSort: true) { bigramChart }
                        chartSection(L10n.shared.fingerIKITitle, helpText: L10n.shared.helpFingerIKI) { fingerIKIChart }
                        chartSection(L10n.shared.bigramIKIHeatmapTitle, helpText: L10n.shared.helpBigramIKIHeatmap) {
                            BigramHeatmapView(bigramIKIMap: model.bigramIKIMap, topKeyEntries: model.topKeys)
                        }
                        chartSection(L10n.shared.slowBigramsTitle, helpText: L10n.shared.helpSlowBigrams) { slowBigramChart }
                    }
                    .padding(24)
                }

            case .layout:
                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        chartSection(L10n.shared.layoutEfficiencyTitle, helpText: L10n.shared.helpLayoutEfficiency) { layoutEfficiencySection }
                        chartSection(L10n.shared.chartTitleLayoutComparison, helpText: L10n.shared.helpLayoutComparison) { layoutComparisonSection }
                        chartSection(L10n.shared.layerEfficiencyTitle, helpText: L10n.shared.layerEfficiencyHelp) { layerEfficiencySection }
                    }
                    .padding(24)
                }
                .onAppear { model.reloadLayoutComparison() }

            case .fatigue:
                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        chartSection(L10n.shared.keyTransitionTitle, helpText: L10n.shared.helpKeyTransition) { keyTransitionSection }
                        chartSection(L10n.shared.chartTitleLearningCurve, helpText: L10n.shared.helpLearningCurve) { learningCurveChart }
                        chartSection(L10n.shared.fatigueCurveTitle, helpText: L10n.shared.helpFatigueCurve) { fatigueCurveChart }
                    }
                    .padding(24)
                }

            case .optimizer:
                optimizerTab
            }
        }
    }

    @ViewBuilder
    var fingerIKIChart: some View {
        if model.fingerIKI.isEmpty {
            Text(L10n.shared.fingerIKINoData)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
        } else {
            let fingerOrder = model.fingerIKI.map(\.finger)
            Chart(model.fingerIKI) { item in
                BarMark(
                    x: .value("Avg IKI (ms)", item.avgIKI),
                    y: .value("Finger", item.finger)
                )
                .foregroundStyle(Color.indigo.opacity(0.8))
                .cornerRadius(3)
                .annotation(position: .trailing) {
                    Text(String(format: "%.0f ms", item.avgIKI))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: fingerOrder)
            .chartXAxisLabel("ms", alignment: .trailing)
            .chartLegend(.hidden)
            .frame(height: CGFloat(model.fingerIKI.count * 36 + 24))
        }
    }

    @ViewBuilder
    var slowBigramChart: some View {
        let layout = ANSILayout()
        let fingers = ["Pinky", "Ring", "Middle", "Index", "Thumb"]
        let filtered: [SlowBigramEntry] = {
            if !slowBigramKeyFilter.isEmpty {
                // Key filter: search all bigrams from bigramIKIMap (not just the preloaded top-20).
                let key = slowBigramKeyFilter.lowercased()
                return model.bigramIKIMap
                    .filter { bigram, _ in
                        guard let b = Bigram.parse(bigram) else { return false }
                        return b.from.lowercased() == key || b.to.lowercased() == key
                    }
                    .sorted { $0.value > $1.value }
                    .prefix(20)
                    .map { SlowBigramEntry((bigram: $0.key, avgIKI: $0.value)) }
            } else if let sel = slowBigramFingerFilter {
                return model.slowBigrams.filter { entry in
                    guard let bigram = Bigram.parse(entry.bigram),
                          let finger = layout.finger(for: bigram.to) else { return false }
                    return finger.rawValue.localizedCapitalized == sel
                }
            } else {
                return model.slowBigrams
            }
        }()

        VStack(alignment: .leading, spacing: 12) {
            // Key filter text field
            HStack(spacing: 8) {
                TextField(L10n.shared.slowBigramKeyFilterPlaceholder, text: $slowBigramKeyFilter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                if !slowBigramKeyFilter.isEmpty {
                    Button { slowBigramKeyFilter = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Finger filter picker (dimmed when key filter is active)
            HStack(spacing: 6) {
                fingerFilterButton(label: L10n.shared.fingerFilterAll, selected: slowBigramFingerFilter == nil) {
                    slowBigramFingerFilter = nil
                }
                ForEach(fingers, id: \.self) { finger in
                    fingerFilterButton(label: finger, selected: slowBigramFingerFilter == finger) {
                        slowBigramFingerFilter = slowBigramFingerFilter == finger ? nil : finger
                    }
                }
            }
            .opacity(slowBigramKeyFilter.isEmpty ? 1 : 0.35)
            .allowsHitTesting(slowBigramKeyFilter.isEmpty)

            if filtered.isEmpty {
                Text(L10n.shared.slowBigramsNoData)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
            } else {
                let bigramOrder = filtered.map(\.bigram)
                Chart(filtered) { item in
                    BarMark(
                        x: .value("Avg IKI (ms)", item.avgIKI),
                        y: .value("Bigram", item.bigram)
                    )
                    .foregroundStyle(Color.orange.opacity(0.8))
                    .cornerRadius(3)
                }
                .chartYScale(domain: bigramOrder)
                .chartXAxisLabel("ms", alignment: .trailing)
                .chartLegend(.hidden)
                .frame(height: CGFloat(filtered.count * 26 + 24))
            }
        }
    }

    // MARK: - Issue #61: Layout Efficiency Comparison

    @ViewBuilder
    var layoutEfficiencySection: some View {
        if model.layoutEfficiency.isEmpty {
            Text(L10n.shared.layoutEfficiencyNoData)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
        } else {
            let best = model.layoutEfficiency.first
            Grid(alignment: .trailing, horizontalSpacing: 20, verticalSpacing: 0) {
                // Header
                GridRow {
                    Text(L10n.shared.heatmapLayoutLabel)
                        .font(.footnote).bold().foregroundStyle(.secondary)
                        .gridColumnAlignment(.leading)
                    Text(L10n.shared.layoutEfficiencySFBHeader)
                        .font(.footnote).bold().foregroundStyle(.secondary)
                    Text(L10n.shared.layoutEfficiencyAltHeader)
                        .font(.footnote).bold().foregroundStyle(.secondary)
                    Text(L10n.shared.tableHeaderErgoScore)
                        .font(.footnote).bold().foregroundStyle(.secondary)
                    Text(L10n.shared.tableHeaderTravel)
                        .font(.footnote).bold().foregroundStyle(.secondary)
                }
                .padding(.bottom, 6)

                Divider().gridCellUnsizedAxes(.horizontal)

                ForEach(model.layoutEfficiency) { entry in
                    let isBest = entry.id == best?.id && !entry.isUserLayout
                    let valueColor: Color = entry.isUserLayout ? .blue : (isBest ? .green : .primary)
                    GridRow {
                        HStack(spacing: 4) {
                            if entry.isUserLayout {
                                Image(systemName: "person.fill")
                                    .font(.footnote)
                                    .foregroundStyle(.blue)
                            }
                            Text(entry.name)
                                .font(.callout)
                                .fontWeight(entry.isUserLayout ? .semibold : (isBest ? .semibold : .regular))
                                .foregroundStyle(entry.isUserLayout ? Color.blue : .primary)
                            if isBest {
                                Image(systemName: "crown.fill")
                                    .font(.footnote)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        .gridColumnAlignment(.leading)

                        Text(String(format: "%.1f%%", entry.sameFingerRate * 100))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(valueColor)

                        Text(String(format: "%.1f%%", entry.handAlternationRate * 100))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(valueColor)

                        Text(String(format: "%.1f", entry.ergonomicScore))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(valueColor)

                        Text(String(format: "%.0f", entry.travelDistance))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(valueColor)
                    }
                    .padding(.vertical, 5)
                }
            }
            .padding(.vertical, 4)

            Text(L10n.shared.layoutBasedOnBigrams(model.layoutEfficiency.first?.totalBigrams.formatted() ?? "0"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Issue #98: Key Transition Analysis

    @ViewBuilder
    var keyTransitionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Key input field
            HStack(spacing: 8) {
                TextField(L10n.shared.keyTransitionPlaceholder, text: $keyTransitionTarget)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .onChange(of: keyTransitionTarget) { _, newValue in
                        model.reloadKeyTransitions(for: newValue)
                    }

                if !keyTransitionTarget.isEmpty {
                    Button {
                        keyTransitionTarget = ""
                        model.reloadKeyTransitions(for: "")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if keyTransitionTarget.isEmpty {
                Text(L10n.shared.keyTransitionPlaceholder)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
            } else {
                // Incoming transitions
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.shared.keyTransitionIncomingTitle(keyTransitionTarget))
                        .font(.footnote).foregroundStyle(.secondary)
                    keyTransitionChart(entries: model.keyTransitionIncoming, color: .teal)
                }

                // Outgoing transitions
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.shared.keyTransitionOutgoingTitle(keyTransitionTarget))
                        .font(.footnote).foregroundStyle(.secondary)
                    keyTransitionChart(entries: model.keyTransitionOutgoing, color: .purple)
                }
            }
        }
    }

    @ViewBuilder
    private func keyTransitionChart(entries: [KeyTransitionEntry], color: Color) -> some View {
        if entries.isEmpty {
            Text(L10n.shared.keyTransitionNoData)
                .foregroundStyle(.secondary)
                .font(.footnote)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
        } else {
            let order = entries.map(\.bigram)
            Chart(entries) { item in
                BarMark(
                    x: .value("Avg IKI (ms)", item.avgIKI),
                    y: .value("Bigram", item.bigram)
                )
                .foregroundStyle(color.opacity(0.8))
                .cornerRadius(3)
                .annotation(position: .trailing) {
                    Text("n=\(item.count)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .chartYScale(domain: order)
            .chartXAxisLabel("ms", alignment: .trailing)
            .chartLegend(.hidden)
            .frame(height: CGFloat(entries.count * 28 + 24))
        }
    }

    @ViewBuilder
    private func fingerFilterButton(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.footnote)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(selected ? Color.orange.opacity(0.8) : Color.secondary.opacity(0.15))
                .foregroundStyle(selected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var bigramChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.topBigrams.isEmpty {
                emptyState
            } else {
                let pairOrder = model.topBigrams.map(\.pair)
                let domain = sortDescending ? Array(pairOrder.reversed()) : pairOrder

                Chart(model.topBigrams) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Bigram", item.pair)
                    )
                    .foregroundStyle(Color.teal.opacity(0.8))
                    .cornerRadius(3)
                }
                .chartYScale(domain: domain)
                .chartLegend(.hidden)
                .frame(height: CGFloat(model.topBigrams.count * 26 + 24))
            }

            // Ergonomic metrics summary (Phase 0 data — previously computed but not shown)
            HStack(spacing: 24) {
                ergonomicMetricPair(
                    label: L10n.shared.ergoMetricSameFingerRate,
                    allTime: model.sameFingerRate,
                    today: model.todaySameFingerRate
                )
                ergonomicMetricPair(
                    label: L10n.shared.ergoMetricHandAltRate,
                    allTime: model.handAlternationRate,
                    today: model.todayHandAltRate
                )
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    func ergonomicMetricPair(label: String, allTime: Double?, today: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.footnote).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                if let v = allTime {
                    Text(L10n.shared.ergoMetricAllTime(Int(v * 100))).font(.footnote.monospacedDigit())
                }
                if let v = today {
                    Text(L10n.shared.ergoMetricToday(Int(v * 100))).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                }
                if allTime == nil && today == nil {
                    Text("—").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    var layoutComparisonSection: some View {
        if let cmp = model.layoutComparison {
            VStack(alignment: .leading, spacing: 12) {
                // Recommended swaps header
                // 推奨スワップのヘッダー
                let swapLabels = cmp.recommendedSwaps
                    .map { "\($0.from) ↔ \($0.to)" }
                    .joined(separator: ", ")
                Text(L10n.shared.recommendedSwapsLabel(swapLabels))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                // Comparison Grid table
                // 比較グリッドテーブル
                Grid(alignment: .trailing, horizontalSpacing: 20, verticalSpacing: 0) {
                    // Header row
                    GridRow {
                        Text(L10n.shared.tableHeaderMetric)
                            .font(.footnote).bold().foregroundStyle(.secondary)
                            .gridColumnAlignment(.leading)
                        Text(L10n.shared.tableHeaderCurrent)
                            .font(.footnote).bold().foregroundStyle(.secondary)
                        Text(L10n.shared.tableHeaderProposed)
                            .font(.footnote).bold().foregroundStyle(.secondary)
                        Text(L10n.shared.tableHeaderChange)
                            .font(.footnote).bold().foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 6)

                    Divider().gridCellUnsizedAxes(.horizontal)

                    // Ergonomic score (higher is better)
                    comparisonRow(
                        metric: L10n.shared.ergoMetricErgoScore,
                        current:  String(format: "%.1f", cmp.current.ergonomicScore),
                        proposed: String(format: "%.1f", cmp.proposed.ergonomicScore),
                        delta: cmp.ergonomicScoreDelta,
                        positiveIsBetter: true,
                        format: { d in String(format: "%+.1f", d) }
                    )

                    // Same-finger rate (lower is better)
                    comparisonRow(
                        metric: L10n.shared.ergoMetricSameFingerRate,
                        current:  pct(cmp.current.sameFingerRate),
                        proposed: pct(cmp.proposed.sameFingerRate),
                        delta: cmp.sameFingerRateDelta,
                        positiveIsBetter: true,
                        format: { d in pp(d) }
                    )

                    // Hand alternation rate (higher is better)
                    comparisonRow(
                        metric: L10n.shared.ergoMetricHandAlt,
                        current:  pct(cmp.current.handAlternationRate),
                        proposed: pct(cmp.proposed.handAlternationRate),
                        delta: cmp.handAlternationDelta,
                        positiveIsBetter: true,
                        format: { d in pp(d) }
                    )

                    // High-strain rate (lower is better)
                    comparisonRow(
                        metric: L10n.shared.ergoMetricHighStrainRate,
                        current:  pct(cmp.current.highStrainRate),
                        proposed: pct(cmp.proposed.highStrainRate),
                        delta: cmp.highStrainRateDelta,
                        positiveIsBetter: true,
                        format: { d in pp(d) }
                    )

                    // Thumb imbalance (lower is better)
                    comparisonRow(
                        metric: L10n.shared.ergoMetricThumbImbalance,
                        current:  String(format: "%.2f", cmp.current.thumbImbalanceRatio),
                        proposed: String(format: "%.2f", cmp.proposed.thumbImbalanceRatio),
                        delta: cmp.thumbImbalanceDelta,
                        positiveIsBetter: true,
                        format: { d in String(format: "%+.2f", d) }
                    )

                    // Finger travel (lower is better)
                    comparisonRow(
                        metric: L10n.shared.ergoMetricFingerTravel,
                        current:  String(format: "%.0f", cmp.current.estimatedTravelDistance),
                        proposed: String(format: "%.0f", cmp.proposed.estimatedTravelDistance),
                        delta: cmp.travelDistanceDelta,
                        positiveIsBetter: true,
                        format: { d in String(format: "%+.0f", d) }
                    )
                }
                .padding(.vertical, 8)

                Divider()

                // Thumb Key Optimization toggle + suggestions (Issue #208)
                // 親指キー最適化トグルと提案（Issue #208）
                Toggle(L10n.shared.thumbOptimizationToggle, isOn: $thumbOptimizationEnabled)
                    .font(.callout)
                    .toggleStyle(.checkbox)

                if thumbOptimizationEnabled {
                    thumbSuggestionsView(cmp.thumbRecommendations)
                }
            }
        } else if model.isLayoutComparisonLoading {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text(L10n.shared.layoutComparisonCalculating)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
        } else {
            Text(L10n.shared.layoutComparisonNeedData)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
        }
    }

    /// Renders one row of the comparison table with colour-coded change column.
    /// 比較テーブルの1行を色付きの変化列と共にレンダリングする。
    @ViewBuilder
    func comparisonRow(
        metric: String,
        current: String,
        proposed: String,
        delta: Double,
        positiveIsBetter: Bool,
        format: (Double) -> String
    ) -> some View {
        let threshold = 0.001
        let isImprovement = positiveIsBetter ? delta > threshold  : delta < -threshold
        let isRegression  = positiveIsBetter ? delta < -threshold : delta > threshold
        let color: Color  = isImprovement ? .green : (isRegression ? .red : .secondary)
        let arrow: String = delta > threshold ? "↑" : (delta < -threshold ? "↓" : "→")

        GridRow {
            Text(metric)
                .font(.callout)
                .gridColumnAlignment(.leading)
            Text(current)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(proposed)
                .font(.callout.monospacedDigit())
            Text("\(arrow) \(format(delta))")
                .font(.callout.monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.vertical, 5)
    }

    /// Formats a rate as a percentage string (e.g. 0.083 → "8.3%").
    /// 比率をパーセント文字列に変換する。
    func pct(_ rate: Double) -> String { String(format: "%.1f%%", rate * 100) }

    /// Formats a rate delta as percentage points (e.g. 0.042 → "+4.2pp").
    /// 比率差をパーセントポイント表記に変換する。
    func pp(_ delta: Double) -> String { String(format: "%+.1fpp", delta * 100) }

    /// Thumb key suggestions subsection shown below the Layout Comparison table (Issue #208).
    /// Layout Comparison テーブルの下に表示する親指キー提案サブセクション（Issue #208）。
    @ViewBuilder
    func thumbSuggestionsView(_ recs: [ThumbRecommendation]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.shared.thumbSuggestionsHeader)
                .font(.callout).bold()

            if recs.isEmpty {
                Text(L10n.shared.thumbSuggestionsEmpty)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(recs.enumerated()), id: \.offset) { _, rec in
                    let slotLabel = rec.suggestedSlot == .left
                        ? L10n.shared.handLeft
                        : L10n.shared.handRight
                    HStack(spacing: 6) {
                        Text(rec.key)
                            .font(.system(.callout, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text("→ \(slotLabel) \(L10n.shared.thumbSuggestionsHeader.lowercased())")
                            .font(.callout)
                        Spacer()
                        Text(String(format: "−%.0f", rec.burdenReduction))
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    var learningCurveChart: some View {
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
                                    .font(.footnote)
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
                            Text(label).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Fatigue Curve (Issue #63)

    @ViewBuilder
    var fatigueCurveChart: some View {
        if model.fatigueCurve.isEmpty {
            Text(L10n.shared.fatigueNoData)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                // WPM over time
                let wpmPoints = model.fatigueCurve.compactMap { e -> (hour: Int, wpm: Double)? in
                    guard let w = e.wpm else { return nil }
                    return (e.hour, w)
                }
                if !wpmPoints.isEmpty {
                    let hours = wpmPoints.map(\.hour)
                    Chart {
                        ForEach(wpmPoints, id: \.hour) { pt in
                            LineMark(
                                x: .value("Hour", pt.hour),
                                y: .value("WPM", pt.wpm)
                            )
                            .foregroundStyle(Color.blue)
                            .interpolationMethod(.catmullRom)
                            PointMark(
                                x: .value("Hour", pt.hour),
                                y: .value("WPM", pt.wpm)
                            )
                            .foregroundStyle(Color.blue)
                            .symbolSize(30)
                        }
                    }
                    .chartXScale(domain: (hours.min() ?? 0)...(hours.max() ?? 23))
                    .chartXAxis {
                        AxisMarks(values: wpmPoints.map(\.hour)) { value in
                            AxisValueLabel {
                                if let h = value.as(Int.self) {
                                    Text(String(format: "%02d", h))
                                        .font(.footnote)
                                }
                            }
                            AxisGridLine()
                        }
                    }
                    .chartYAxisLabel("WPM", alignment: .trailing)
                    .frame(height: 140)
                }

                // Ergonomic rates over time
                let ergPoints: [(hour: Int, value: Double, series: String)] = model.fatigueCurve.flatMap { e -> [(hour: Int, value: Double, series: String)] in
                    var pts: [(Int, Double, String)] = []
                    if let sf = e.sameFingerRate { pts.append((e.hour, sf * 100, "Same-finger")) }
                    if let hs = e.highStrainRate  { pts.append((e.hour, hs * 100, "High-strain")) }
                    return pts
                }
                if !ergPoints.isEmpty {
                    let hours = model.fatigueCurve.map(\.hour)
                    Chart {
                        ForEach(ergPoints, id: \.series) { pt in
                            LineMark(
                                x: .value("Hour", pt.hour),
                                y: .value("%", pt.value)
                            )
                            .foregroundStyle(by: .value("Metric", pt.series))
                            .interpolationMethod(.catmullRom)
                            PointMark(
                                x: .value("Hour", pt.hour),
                                y: .value("%", pt.value)
                            )
                            .foregroundStyle(by: .value("Metric", pt.series))
                            .symbolSize(30)
                        }
                    }
                    .chartForegroundStyleScale([
                        "Same-finger": Color.orange,
                        "High-strain": Color.red
                    ])
                    .chartXScale(domain: (hours.min() ?? 0)...(hours.max() ?? 23))
                    .chartXAxis {
                        AxisMarks(values: model.fatigueCurve.map(\.hour)) { value in
                            AxisValueLabel {
                                if let h = value.as(Int.self) {
                                    Text(String(format: "%02d", h))
                                        .font(.footnote)
                                }
                            }
                            AxisGridLine()
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text(String(format: "%.0f%%", v)).font(.footnote)
                                }
                            }
                        }
                    }
                    .frame(height: 120)

                    HStack(spacing: 16) {
                        ForEach([("Same-finger", Color.orange), ("High-strain", Color.red)], id: \.0) { label, color in
                            HStack(spacing: 4) {
                                Circle().fill(color).frame(width: 8, height: 8)
                                Text(label).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Issue #299 (moved from MenuView): Ergonomic Recommendations sub-tab

private struct ErgoRecommendationsView: View {
    @State private var recs: [ErgonomicRecommendation] = []

    var body: some View {
        let l = L10n.shared
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if recs.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 20))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(l.recommendationsSectionTitle)
                                .font(.headline)
                            Text(l.recommendationsEmpty)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(24)
                } else {
                    ForEach(recs, id: \.id) { rec in
                        recCard(rec)
                    }
                }
            }
            .padding(24)
        }
        .onAppear { recs = KeyCountStore.shared.topRecommendations() }
    }

    private func recCard(_ rec: ErgonomicRecommendation) -> some View {
        let l = L10n.shared
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: severityIcon(rec.severity))
                .font(.system(size: 22))
                .foregroundColor(severityColor(rec.severity))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(l.ergoRecTitle(rec.titleKey))
                    .font(.headline)
                Text(l.ergoRecDetail(rec.detailKey))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Text(l.recImpact(Int(rec.estimatedScoreGain.rounded())))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(6)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private func severityIcon(_ s: ErgonomicRecommendationSeverity) -> String {
        switch s {
        case .high:   return "exclamationmark.circle.fill"
        case .medium: return "exclamationmark.circle"
        case .low:    return "info.circle"
        }
    }

    private func severityColor(_ s: ErgonomicRecommendationSeverity) -> Color {
        switch s {
        case .high:   return .red
        case .medium: return .orange
        case .low:    return .secondary
        }
    }
}
