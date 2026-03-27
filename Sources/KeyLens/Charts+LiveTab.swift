import SwiftUI
import Charts

// MARK: - Live sub-tab enum (Issue #271)

enum LiveSubTab: String, CaseIterable {
    case monitor
    case intelligence
    case wpmTest
}

extension ChartsView {

    var liveTab: some View {
        VStack(spacing: 0) {
            // Sub-tab picker
            Picker("", selection: $liveSubTab) {
                Text(L10n.shared.liveSubTabMonitor).tag(LiveSubTab.monitor)
                Text(L10n.shared.liveSubTabIntelligence).tag(LiveSubTab.intelligence)
                Text(L10n.shared.liveSubTabWPMTest).tag(LiveSubTab.wpmTest)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Sub-tab content — each fits without scrolling
            switch liveSubTab {
            case .monitor:
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        chartSection(L10n.shared.chartTitleSpeedometer, helpText: L10n.shared.helpSpeedometer) {
                            SpeedometerView()
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(.top, 24)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)

                        Divider().padding(.horizontal, 24)

                        chartSection(L10n.shared.chartTitleRecentIKI, helpText: L10n.shared.helpRecentIKI) { recentIKIChart }
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 24)
                            .padding(.leading, 24)
                            .padding(.bottom, 24)
                            .padding(.trailing, 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

            case .intelligence:
                ScrollView {
                    chartSection(L10n.shared.intelligenceSection, helpText: L10n.shared.helpIntelligence) { intelligenceGroup }
                        .padding(.top, 24)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }

            case .wpmTest:
                ScrollView {
                    wpmMeasurementSection
                        .padding(.horizontal, 24)
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .onAppear {
            model.refreshLiveData()
            liveTimer?.invalidate()
            liveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                model.refreshLiveData()
            }
        }
        .onDisappear {
            liveTimer?.invalidate()
            liveTimer = nil
        }
    }

    /// Bar chart of IKI (ms) for the last 20 keystrokes. Bars are color-coded by speed.
    /// 直近20打鍵のIKI棒グラフ。速度に応じて色分けする。
    @ViewBuilder
    var recentIKIChart: some View {
        let entries = model.recentIKIEntries
        if entries.isEmpty {
            VStack(spacing: 6) {
                emptyState
                Text(L10n.shared.liveTypingHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(width: recentIKIChartWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Chart(entries) { item in
                    let bar = BarMark(
                        x: .value("Key", item.id),
                        y: .value("IKI (ms)", item.chartIKI)
                    )
                    .foregroundStyle(item.isAnchor  ? Color.gray.opacity(0.4)   :
                                     item.isFast    ? Color.green.opacity(0.8)  :
                                     item.isSlow    ? Color.red.opacity(0.8)    :
                                                      Color.orange.opacity(0.75))
                    .cornerRadius(2)
                    if item.isSlow {
                        // Capped at 300ms — show actual value so it's distinct from a genuine 300ms bar.
                        bar.annotation(position: .top, spacing: 2) {
                            Text("\(Int(item.iki))ms")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Color.red)
                        }
                    } else if ikichartShowKeyLabels {
                        bar.annotation(position: .top, spacing: 2) {
                            Text(item.key)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        bar
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in AxisGridLine() }
                }
                .chartYScale(domain: 0...recentIKIChartMaxDisplay)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 100, 200, 300]) { value in
                        AxisValueLabel { Text("\(value.as(Double.self).map { Int($0) } ?? 0)ms") }
                        AxisGridLine()
                    }
                }
                .frame(height: recentIKIPlotHeight)
                HStack(spacing: 16) {
                    Label(L10n.shared.ikiSpeedFast,   systemImage: "circle.fill").foregroundStyle(.green)
                    Label(L10n.shared.ikiSpeedMedium, systemImage: "circle.fill").foregroundStyle(.orange)
                    Label(L10n.shared.ikiSpeedSlow,   systemImage: "circle.fill").foregroundStyle(.red)
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .frame(width: recentIKIChartWidth, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Manual WPM Measurement (Issue #150)

    @ViewBuilder
    var wpmMeasurementSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.shared.wpmMeasureTitle)
                .font(.headline)

            Text(L10n.shared.wpmMeasureHint)
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Start / Stop button
            HStack(spacing: 12) {
                Button {
                    if isMeasuringWPM {
                        wpmResult = KeyCountStore.shared.stopWPMMeasurement()
                        isMeasuringWPM = false
                    } else {
                        KeyCountStore.shared.startWPMMeasurement()
                        wpmResult = nil
                        isMeasuringWPM = true
                    }
                } label: {
                    Label(
                        isMeasuringWPM ? L10n.shared.wpmMeasureStop : L10n.shared.wpmMeasureStart,
                        systemImage: isMeasuringWPM ? "stop.circle.fill" : "play.circle.fill"
                    )
                    .font(.body.bold())
                    .foregroundStyle(isMeasuringWPM ? .red : .green)
                }
                .buttonStyle(.plain)

                if isMeasuringWPM {
                    Label(L10n.shared.wpmRecording, systemImage: "record.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            // Result
            if let r = wpmResult {
                Text(L10n.shared.wpmMeasureResult(wpm: r.wpm, duration: r.duration, keystrokes: r.keystrokes))
                    .font(.title2.monospacedDigit().bold())
                    .foregroundStyle(.orange)
                    .transition(.opacity)
            }

            // Hotkey display and recorder
            HStack(spacing: 6) {
                Text(L10n.shared.wpmHotkeyLabel)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(wpmHotkeyDisplay)
                    .font(.footnote.monospaced())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Button(isRecordingHotkey ? L10n.shared.wpmHotkeyRecording : L10n.shared.wpmHotkeyRecord) {
                    isRecordingHotkey = true
                    WPMHotkeyManager.shared.recordNextHotkey { newDisplay in
                        wpmHotkeyDisplay = newDisplay
                        isRecordingHotkey = false
                    }
                }
                .buttonStyle(.plain)
                .font(.footnote)
                .foregroundStyle(isRecordingHotkey ? .orange : .accentColor)
                .disabled(isRecordingHotkey)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isMeasuringWPM)
        .animation(.easeInOut(duration: 0.2), value: wpmResult != nil)
        // Sync UI when hotkey toggles measurement from outside the window
        .onReceive(NotificationCenter.default.publisher(for: .wpmMeasurementStarted)) { _ in
            wpmResult = nil
            isMeasuringWPM = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .wpmMeasurementStopped)) { note in
            isMeasuringWPM = false
            wpmResult = note.object as? (wpm: Double, duration: TimeInterval, keystrokes: Int)
        }
    }
}
