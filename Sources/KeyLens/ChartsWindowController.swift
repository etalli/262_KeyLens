import AppKit
import SwiftUI
import KeyLensCore

// MARK: - ChartDataModel

/// チャート用データを保持・更新する ObservableObject
final class ChartDataModel: ObservableObject {
    @Published var topKeys:              [TopKeyEntry]          = []
    @Published var dailyTotals:          [DailyTotalEntry]      = []
    @Published var categories:           [CategoryEntry]        = []
    @Published var perDayKeys:           [DailyKeyEntry]        = []
    @Published var shortcuts:            [ShortcutEntry]        = []
    @Published var allCombos:            [ShortcutEntry]        = []
    @Published var keyCounts:            [String: Int]          = [:]
    @Published var topBigrams:           [BigramEntry]          = []
    @Published var sameFingerRate:       Double?                = nil
    @Published var todaySameFingerRate:  Double?                = nil
    @Published var handAlternationRate:  Double?                = nil
    @Published var todayHandAltRate:     Double?                = nil
    // Phase 3
    @Published var dailyErgonomics:      [DailyErgonomicEntry]  = []
    @Published var weeklyDeltas:         [WeeklyDeltaRow]       = []
    // Phase 2: Before/After layout comparison (Issue #3)
    @Published var layoutComparison:          LayoutComparison? = nil
    @Published var isLayoutComparisonLoading: Bool              = false
    // Issue #5: Activity Trends
    @Published var hourlyDistribution:   [Int]                  = []
    @Published var monthlyTotals:        [MonthlyTotalEntry]    = []
    // Per-application counts
    @Published var topApps:              [AppEntry]             = []
    @Published var todayTopApps:         [AppEntry]             = []
    // Per-application ergonomic scores
    @Published var appErgScores:         [AppErgScoreEntry]     = []
    // Per-device counts
    @Published var topDevices:           [DeviceEntry]          = []
    @Published var todayTopDevices:      [DeviceEntry]          = []
    // Per-device ergonomic scores
    @Published var deviceErgScores:      [DeviceErgScoreEntry]  = []
    // Issue #59 Phase 2: daily WPM time-series
    // 日別 WPM 時系列（タイピング速度チャート用）
    @Published var dailyWPM:             [DailyWPMEntry]        = []
    // Issue #65: daily backspace rate time-series
    // 日別 BS 率時系列（タイピング精度チャート用）
    @Published var dailyAccuracy:        [DailyAccuracyEntry]   = []
    // Live IKI ring buffer — refreshed every 0.5s by a timer in ChartsWindowController.
    // リアルタイムIKIリングバッファ（ChartsWindowControllerのタイマーで0.5秒ごとに更新）。
    @Published var recentIKIEntries:     [RecentIKIEntry]       = []
    // Issue #102: IKI histogram — all-time bucket distribution
    // 全打鍵データのIKI分布（バケット別）。
    @Published var ikiHistogram:         [IKIHistogramEntry]    = []
    // Issue #103: slowest bigrams by average IKI
    @Published var slowBigrams:          [SlowBigramEntry]      = []
    // Issue #104: average IKI broken down by finger
    @Published var fingerIKI:            [FingerIKIEntry]       = []
    // Issue #98: key transition analysis — incoming and outgoing transitions for the selected key
    @Published var keyTransitionIncoming: [KeyTransitionEntry]  = []
    @Published var keyTransitionOutgoing: [KeyTransitionEntry]  = []
    // Issue #61: layout efficiency comparison — QWERTY vs Colemak vs Dvorak
    @Published var layoutEfficiency:      [LayoutEfficiencyEntry] = []
    // Issue #60: Session detection
    @Published var sessionSummaries:      [DailySessionSummary]   = []
    // Issue #168: Mouse tab
    @Published var mouseDailyDistances:        [MouseDailyEntry]            = []
    @Published var mouseHourlyActivity:        [MouseHourEntry]             = []
    @Published var mouseDirectionEntries:      [MouseDirectionEntry]        = []
    @Published var mouseDailyDirectionEntries: [MouseDailyDirectionEntry]   = []
    // Issue #182: Mouse vs Keyboard balance
    @Published var mouseKeyboardBalance:       [MouseKeyboardBalanceEntry]  = []
    // Issue #90: Ranked bigrams for training — session is built in the view using the user's length preference.
    @Published var trainingScores:             [BigramScore]                 = []
    // Issue #89: Ranked trigrams for training (Phase 2).
    @Published var trainingTrigramScores:      [TrigramScore]                = []
    // Issue #63: Hourly fatigue curve for today.
    @Published var fatigueCurve:               [HourlyFatigueEntry]          = []
    // Issue #88: Training result history
    @Published var trainingHistory:            [TrainingRecord]              = []
    // Issue #84: Full bigram → current mean IKI map for before/after comparison in training history.
    @Published var bigramIKIMap:               [String: Double]              = [:]
    // Issue #78: Weekly Activity Heatmap
    @Published var weeklyHeatmap:              [HeatmapCell]                 = []
    // Issue #209: Layer key efficiency
    @Published var layerEfficiency:            [LayerEfficiencyEntry]        = []
    // Issue #258: background loading state
    @Published var isLoading: Bool = false

    /// Loads all chart data on a background queue and publishes results to the main thread.
    /// Previously all queries ran synchronously on the main thread, causing stutter on window open.
    /// LayoutComparison is excluded — it is deferred to the Layout sub-tab's onAppear (Issue #280).
    func reload() {
        isLoading = true
        layoutComparison = nil  // Invalidate so it is recomputed on next Layout tab visit.
        let store = KeyCountStore.shared
        let ms    = MouseStore.shared

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // --- Keyboard data ---
            let topKeys             = store.topKeys(limit: 20).map(TopKeyEntry.init)
            let rawDailyTotals      = store.dailyTotals()
            let dailyTotals         = rawDailyTotals.map(DailyTotalEntry.init)
            let categories          = store.countsByType().map(CategoryEntry.init)
            let perDayKeys          = store.topKeysPerDay(limit: 10).map(DailyKeyEntry.init)
            let shortcuts           = store.topModifiedKeys(prefix: "⌘", limit: 20).map(ShortcutEntry.init)
            let allCombos           = store.topModifiedKeys(prefix: "", limit: 30).map(ShortcutEntry.init)
            let keyCounts           = Dictionary(uniqueKeysWithValues: store.allEntries().map { ($0.key, $0.total) })
            let topBigrams          = store.topBigrams(limit: 20).map(BigramEntry.init)
            let sameFingerRate      = store.sameFingerRate
            let todaySameFingerRate = store.todaySameFingerRate
            let handAlternationRate = store.handAlternationRate
            let todayHandAltRate    = store.todayHandAlternationRate

            // Phase 3: Learning Curve
            let ergRates       = store.dailyErgonomicRates()
            let dailyErgonomics = ergRates.flatMap { row -> [DailyErgonomicEntry] in
                [
                    DailyErgonomicEntry(date: row.date, series: "Same-finger", rate: row.sameFingerRate),
                    DailyErgonomicEntry(date: row.date, series: "Alternation",  rate: row.handAltRate),
                    DailyErgonomicEntry(date: row.date, series: "High-strain",  rate: row.highStrainRate),
                ]
            }
            let weeklyDeltas = Self.computeWeeklyDeltas(ergRates: ergRates, rawDailyTotals: rawDailyTotals)

            // Issue #5: Activity Trends
            let hourlyDistribution = store.hourlyDistribution()
            let monthlyTotals      = store.monthlyTotals().map(MonthlyTotalEntry.init)
            // Issue #78: Weekly Activity Heatmap
            let weeklyHeatmap      = store.hourlyCountsByDayOfWeek().map(HeatmapCell.init)
            // Per-application counts
            let topApps            = store.topApps(limit: 20).map(AppEntry.init)
            let todayTopApps       = store.todayTopApps(limit: 10).map(AppEntry.init)
            let appErgScores       = store.appErgonomicScores(minKeystrokes: 100).map(AppErgScoreEntry.init)
            // Per-device counts
            let topDevices         = store.topDevices(limit: 20).map(DeviceEntry.init)
            let todayTopDevices    = store.todayTopDevices(limit: 10).map(DeviceEntry.init)
            let deviceErgScores    = store.deviceErgonomicScores(minKeystrokes: 100).map(DeviceErgScoreEntry.init)
            // Issue #59 Phase 2: daily WPM
            let dailyWPM           = store.dailyWPM().map(DailyWPMEntry.init)
            // Issue #65: daily backspace rate
            let dailyAccuracy      = store.dailyBackspaceRates().map(DailyAccuracyEntry.init)
            // Issue #102: IKI histogram
            let ikiHistogram       = store.ikiHistogramEntries()
            // Issue #103: slowest bigrams by average IKI
            let slowBigrams        = store.slowestBigrams(minCount: 5, limit: 20).map(SlowBigramEntry.init)
            // Issue #104: IKI per finger
            let fingerIKI          = store.ikiPerFinger().map(FingerIKIEntry.init)
            // Issue #61: layout efficiency comparison
            let layoutEfficiency   = store.layoutEfficiencyScores()
            // Issue #60: session detection
            let sessionSummaries   = store.allSessionSummaries()
            // Issue #90: Training
            let trainingScores     = store.rankedBigramsForTraining(minCount: 5, topK: 10)
            // Issue #89: Trigram training targets
            let trainingTrigramScores = store.rankedTrigramsForTraining(minCount: 5, topK: 8)
            // Issue #63: Today's hourly fatigue curve
            let fatigueCurve       = store.todayHourlyFatigueCurve()
            // Issue #88: Training history
            let trainingHistory    = store.trainingHistory(limit: 20)
            // Issue #84: Full IKI map for before/after comparison.
            // Issue #280: Bounded to bigrams between the top-40 keys (≤1,600 entries).
            let topKeySet = Set(keyCounts.sorted { $0.value > $1.value }.prefix(40).map(\.key))
            let bigramIKIMap = store.allBigramIKI().filter { bigram, _ in
                guard let b = Bigram.parse(bigram) else { return true }
                return topKeySet.contains(b.from) && topKeySet.contains(b.to)
            }
            // Issue #209: Layer key efficiency
            let layerEfficiency    = store.layerEfficiency()

            // --- Mouse data ---
            let mouseDailyDistances    = ms.dailyDistances().map(MouseDailyEntry.init)
            let mouseHourlyActivity    = ms.hourlyDistributionMouse().map { MouseHourEntry(hour: $0.hour, distancePts: $0.distancePts) }
            let dir                    = ms.directionBreakdown()
            let mouseDirectionEntries  = [
                MouseDirectionEntry(id: "left",  direction: "Left ←",  distancePts: dir.left),
                MouseDirectionEntry(id: "right", direction: "Right →", distancePts: dir.right),
                MouseDirectionEntry(id: "up",    direction: "Up ↑",    distancePts: dir.up),
                MouseDirectionEntry(id: "down",  direction: "Down ↓",  distancePts: dir.down),
            ].filter { $0.distancePts > 0 }
            let mouseDailyDirectionEntries = ms.dailyDirectionBreakdown().map {
                MouseDailyDirectionEntry(id: $0.date, date: $0.date,
                                         right: $0.dxPos, left: $0.dxNeg,
                                         down: $0.dyPos,  up:   $0.dyNeg)
            }
            let keystrokesByDate = Dictionary(uniqueKeysWithValues: rawDailyTotals.map { ($0.date, $0.total) })
            let mouseKeyboardBalance = ms.dailyDistances().compactMap { entry -> MouseKeyboardBalanceEntry? in
                guard let keys = keystrokesByDate[entry.date], entry.distancePts > 0 || keys > 0 else { return nil }
                return MouseKeyboardBalanceEntry(id: entry.date, date: entry.date,
                                                 distancePts: entry.distancePts, keystrokes: keys)
            }.sorted { $0.date < $1.date }

            // Publish all results on the main thread in one batch.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.topKeys              = topKeys
                self.dailyTotals          = dailyTotals
                self.categories           = categories
                self.perDayKeys           = perDayKeys
                self.shortcuts            = shortcuts
                self.allCombos            = allCombos
                self.keyCounts            = keyCounts
                self.topBigrams           = topBigrams
                self.sameFingerRate       = sameFingerRate
                self.todaySameFingerRate  = todaySameFingerRate
                self.handAlternationRate  = handAlternationRate
                self.todayHandAltRate     = todayHandAltRate
                self.dailyErgonomics      = dailyErgonomics
                self.weeklyDeltas         = weeklyDeltas
                self.hourlyDistribution   = hourlyDistribution
                self.monthlyTotals        = monthlyTotals
                self.weeklyHeatmap        = weeklyHeatmap
                self.topApps              = topApps
                self.todayTopApps         = todayTopApps
                self.appErgScores         = appErgScores
                self.topDevices           = topDevices
                self.todayTopDevices      = todayTopDevices
                self.deviceErgScores      = deviceErgScores
                self.dailyWPM             = dailyWPM
                self.dailyAccuracy        = dailyAccuracy
                self.ikiHistogram         = ikiHistogram
                self.slowBigrams          = slowBigrams
                self.fingerIKI            = fingerIKI
                self.layoutEfficiency     = layoutEfficiency
                self.sessionSummaries     = sessionSummaries
                self.trainingScores       = trainingScores
                self.trainingTrigramScores = trainingTrigramScores
                self.fatigueCurve         = fatigueCurve
                self.trainingHistory      = trainingHistory
                self.bigramIKIMap         = bigramIKIMap
                self.layerEfficiency      = layerEfficiency
                self.mouseDailyDistances        = mouseDailyDistances
                self.mouseHourlyActivity        = mouseHourlyActivity
                self.mouseDirectionEntries      = mouseDirectionEntries
                self.mouseDailyDirectionEntries = mouseDailyDirectionEntries
                self.mouseKeyboardBalance       = mouseKeyboardBalance
                self.isLoading                  = false
            }
        }

    }

    /// Runs LayoutComparison on a background queue (Issue #280).
    /// Called lazily from the Ergonomics → Layout sub-tab's onAppear instead of reload(),
    /// because the optimizer runs ~1,800 ErgonomicSnapshot simulations and is CPU-heavy.
    func reloadLayoutComparison() {
        guard !isLayoutComparisonLoading, layoutComparison == nil else { return }
        isLayoutComparisonLoading = true
        let store = KeyCountStore.shared
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let bigramSnapshot = store.allBigramCounts
            let keySnapshot    = store.allKeyCounts
            let result         = LayoutComparison.make(bigramCounts: bigramSnapshot, keyCounts: keySnapshot)
            DispatchQueue.main.async { [weak self] in
                self?.layoutComparison          = result
                self?.isLayoutComparisonLoading = false
            }
        }
    }

    /// Reloads key transition data for the given target key (Issue #98).
    func reloadKeyTransitions(for key: String) {
        guard !key.isEmpty else {
            keyTransitionIncoming = []
            keyTransitionOutgoing = []
            return
        }
        let result = KeyCountStore.shared.keyTransitions(for: key)
        keyTransitionIncoming = result.incoming.map(KeyTransitionEntry.init)
        keyTransitionOutgoing = result.outgoing.map(KeyTransitionEntry.init)
    }

    /// Lightweight refresh — reads only the live IKI ring buffer. Called by the 0.5s timer.
    func refreshLiveData() {
        let raw = KeyCountStore.shared.latestIKIs()
        recentIKIEntries = raw.enumerated().map { i, item in
            RecentIKIEntry(id: i, key: item.key, iki: item.iki)
        }
    }

    // Compare the most recent 7 days against the 7 days before that.
    // 直近7日 vs その前7日の比較。
    private static func computeWeeklyDeltas(
        ergRates: [(date: String, sameFingerRate: Double, handAltRate: Double, highStrainRate: Double)],
        rawDailyTotals: [(date: String, total: Int)]
    ) -> [WeeklyDeltaRow] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let today = Date()

        func dateStr(_ daysAgo: Int) -> String? {
            Calendar.current.date(byAdding: .day, value: -daysAgo, to: today).map { fmt.string(from: $0) }
        }

        let thisWeekDates = Set((0..<7).compactMap  { dateStr($0) })
        let lastWeekDates = Set((7..<14).compactMap { dateStr($0) })

        // Keystroke totals per week
        let totalMap = Dictionary(uniqueKeysWithValues: rawDailyTotals.map { ($0.date, $0.total) })
        let thisWeekKeys = Double(thisWeekDates.compactMap { totalMap[$0] }.reduce(0, +))
        let lastWeekKeys = Double(lastWeekDates.compactMap { totalMap[$0] }.reduce(0, +))

        // Average ergonomic rate over a set of dates
        func avg(_ dates: Set<String>, _ selector: (Double, Double, Double) -> Double) -> Double? {
            let vals = ergRates
                .filter { dates.contains($0.date) }
                .map    { selector($0.sameFingerRate, $0.handAltRate, $0.highStrainRate) }
            return vals.isEmpty ? nil : vals.reduce(0, +) / Double(vals.count)
        }

        var rows: [WeeklyDeltaRow] = []

        // Always include keystrokes (even if last week is 0)
        if thisWeekKeys > 0 || lastWeekKeys > 0 {
            rows.append(WeeklyDeltaRow(metric: "Keystrokes",      thisWeek: thisWeekKeys, lastWeek: lastWeekKeys, lowerIsBetter: false))
        }
        if let tw = avg(thisWeekDates, { sf, _, _ in sf }), let lw = avg(lastWeekDates, { sf, _, _ in sf }) {
            rows.append(WeeklyDeltaRow(metric: "Same-finger rate", thisWeek: tw, lastWeek: lw, lowerIsBetter: true))
        }
        if let tw = avg(thisWeekDates, { _, ha, _ in ha }), let lw = avg(lastWeekDates, { _, ha, _ in ha }) {
            rows.append(WeeklyDeltaRow(metric: "Alternation rate", thisWeek: tw, lastWeek: lw, lowerIsBetter: false))
        }
        if let tw = avg(thisWeekDates, { _, _, hs in hs }), let lw = avg(lastWeekDates, { _, _, hs in hs }) {
            rows.append(WeeklyDeltaRow(metric: "High-strain rate", thisWeek: tw, lastWeek: lw, lowerIsBetter: true))
        }
        return rows
    }
}

// MARK: - ChartsWindowController

/// Swift Charts を NSHostingController で包んで表示するウィンドウ
final class ChartsWindowController: NSWindowController {
    static let shared = ChartsWindowController()
    private let model = ChartDataModel()
    private var liveTimer:    Timer?
    private var fatigueTimer: Timer?

    private init() {
        let hostVC = NSHostingController(rootView: ChartsView(model: model))
        let window = NSWindow(contentViewController: hostVC)
        window.title = "KeyLens — Charts"
        window.setContentSize(NSSize(width: 700, height: 650))
        window.center()
        window.setFrameAutosaveName("ChartsWindow")
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func showWindow() {
        model.reload()
        if !(window?.isVisible ?? false) { window?.center() }
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        startLiveTimer()
    }

    private func startLiveTimer() {
        guard liveTimer == nil else { return }
        liveTimer = Timer.scheduledTimer(withTimeInterval: AppConfiguration.liveRefreshIntervalSecs, repeats: true) { [weak self] _ in
            self?.model.refreshLiveData()
        }
        // Refresh fatigue curve every 10s so it updates without reopening the window.
        fatigueTimer = Timer.scheduledTimer(withTimeInterval: AppConfiguration.fatigueRefreshIntervalSecs, repeats: true) { [weak self] _ in
            self?.model.fatigueCurve = KeyCountStore.shared.todayHourlyFatigueCurve()
        }
    }
}
