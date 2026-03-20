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

    func reload() {
        let store            = KeyCountStore.shared
        topKeys              = store.topKeys(limit: 20).map(TopKeyEntry.init)
        let rawDailyTotals   = store.dailyTotals()
        dailyTotals          = rawDailyTotals.map(DailyTotalEntry.init)
        categories           = store.countsByType().map(CategoryEntry.init)
        perDayKeys           = store.topKeysPerDay(limit: 10).map(DailyKeyEntry.init)
        shortcuts            = store.topModifiedKeys(prefix: "⌘", limit: 20).map(ShortcutEntry.init)
        allCombos            = store.topModifiedKeys(prefix: "", limit: 30).map(ShortcutEntry.init)
        keyCounts            = Dictionary(uniqueKeysWithValues: store.allEntries().map { ($0.key, $0.total) })
        topBigrams           = store.topBigrams(limit: 20).map(BigramEntry.init)
        sameFingerRate       = store.sameFingerRate
        todaySameFingerRate  = store.todaySameFingerRate
        handAlternationRate  = store.handAlternationRate
        todayHandAltRate     = store.todayHandAlternationRate

        // Phase 3: Learning Curve
        let ergRates = store.dailyErgonomicRates()
        dailyErgonomics = ergRates.flatMap { row -> [DailyErgonomicEntry] in
            [
                DailyErgonomicEntry(date: row.date, series: "Same-finger", rate: row.sameFingerRate),
                DailyErgonomicEntry(date: row.date, series: "Alternation",  rate: row.handAltRate),
                DailyErgonomicEntry(date: row.date, series: "High-strain",  rate: row.highStrainRate),
            ]
        }

        // Phase 3: Weekly Delta (this 7 days vs. previous 7 days)
        weeklyDeltas = Self.computeWeeklyDeltas(ergRates: ergRates, rawDailyTotals: rawDailyTotals)

            // Phase 2: Before/After layout comparison — run FullErgonomicOptimizer on a background
        // thread so the main thread (and Charts window) is never blocked.
        // FullErgonomicOptimizer はバックグラウンドスレッドで実行し、メインスレッドをブロックしない。
        layoutComparison = nil
        isLayoutComparisonLoading = true
        let bigramSnapshot = store.allBigramCounts
        let keySnapshot    = store.allKeyCounts
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = LayoutComparison.make(bigramCounts: bigramSnapshot, keyCounts: keySnapshot)
            DispatchQueue.main.async {
                self?.layoutComparison = result
                self?.isLayoutComparisonLoading = false
            }
        }

        // Issue #5: Activity Trends
        hourlyDistribution = store.hourlyDistribution()
        monthlyTotals      = store.monthlyTotals().map(MonthlyTotalEntry.init)
        // Per-application counts
        topApps      = store.topApps(limit: 20).map(AppEntry.init)
        todayTopApps = store.todayTopApps(limit: 10).map(AppEntry.init)
        appErgScores = store.appErgonomicScores(minKeystrokes: 100).map(AppErgScoreEntry.init)
        // Per-device counts
        topDevices      = store.topDevices(limit: 20).map(DeviceEntry.init)
        todayTopDevices = store.todayTopDevices(limit: 10).map(DeviceEntry.init)
        deviceErgScores = store.deviceErgonomicScores(minKeystrokes: 100).map(DeviceErgScoreEntry.init)
        // Issue #59 Phase 2: daily WPM
        dailyWPM = store.dailyWPM().map(DailyWPMEntry.init)
        // Issue #65: daily backspace rate
        dailyAccuracy = store.dailyBackspaceRates().map(DailyAccuracyEntry.init)
        // Issue #102: IKI histogram
        ikiHistogram = store.ikiHistogramEntries()
        // Issue #103: slowest bigrams by average IKI
        slowBigrams = store.slowestBigrams(minCount: 5, limit: 20).map(SlowBigramEntry.init)
        // Issue #104: IKI per finger
        fingerIKI = store.ikiPerFinger().map(FingerIKIEntry.init)
        // Issue #61: layout efficiency comparison
        layoutEfficiency = store.layoutEfficiencyScores()
        // Issue #60: session detection
        sessionSummaries = store.allSessionSummaries()
        // Issue #168: Mouse tab
        let ms = MouseStore.shared
        mouseDailyDistances = ms.dailyDistances().map(MouseDailyEntry.init)
        mouseHourlyActivity = ms.hourlyDistributionMouse().map { MouseHourEntry(hour: $0.hour, distancePts: $0.distancePts) }
        let dir = ms.directionBreakdown()
        mouseDirectionEntries = [
            MouseDirectionEntry(id: "left",  direction: "Left ←",  distancePts: dir.left),
            MouseDirectionEntry(id: "right", direction: "Right →", distancePts: dir.right),
            MouseDirectionEntry(id: "up",    direction: "Up ↑",    distancePts: dir.up),
            MouseDirectionEntry(id: "down",  direction: "Down ↓",  distancePts: dir.down),
        ].filter { $0.distancePts > 0 }
        mouseDailyDirectionEntries = ms.dailyDirectionBreakdown().map {
            MouseDailyDirectionEntry(id: $0.date, date: $0.date,
                                     right: $0.dxPos, left: $0.dxNeg,
                                     down: $0.dyPos,  up:   $0.dyNeg)
        }
        // Issue #182: join mouse distance + keystroke totals by date
        let keystrokesByDate = Dictionary(uniqueKeysWithValues: rawDailyTotals.map { ($0.date, $0.total) })
        mouseKeyboardBalance = ms.dailyDistances().compactMap { entry -> MouseKeyboardBalanceEntry? in
            guard let keys = keystrokesByDate[entry.date], entry.distancePts > 0 || keys > 0 else { return nil }
            return MouseKeyboardBalanceEntry(id: entry.date, date: entry.date,
                                             distancePts: entry.distancePts, keystrokes: keys)
        }.sorted { $0.date < $1.date }
        // Issue #90: Training — store raw scores; session is built in the view with the user's length config.
        trainingScores = store.rankedBigramsForTraining(minCount: 5, topK: 10)
        // Issue #89: Trigram training targets (Phase 2).
        trainingTrigramScores = store.rankedTrigramsForTraining(minCount: 5, topK: 8)
        // Issue #63: Today's hourly fatigue curve.
        fatigueCurve = store.todayHourlyFatigueCurve()
        // Issue #88: Training history
        trainingHistory = store.trainingHistory(limit: 20)
        // Issue #84: Full IKI map for before/after comparison
        bigramIKIMap = store.allBigramIKI()
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
    private var liveTimer: Timer?

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
        liveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.model.refreshLiveData()
        }
    }
}
