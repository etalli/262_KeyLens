import AppKit
import Foundation
import GRDB
import KeyLensCore
import UserNotifications

// MARK: - Data model

/// In-memory snapshot of all keystroke counters. Persisted to keylens.db via the
/// `scalars` table (see KeyCountStore+SQLite.swift). Large time-series data is in
/// separate time-series tables in the same database.
/// キーストロークカウンターのインメモリスナップショット。keylens.db の scalars テーブルに永続化される。
struct CountData: Codable {
    var startedAt: Date
    var counts: [String: Int]           // all-time per-key cumulative count
    var activity: ActivityData
    var ergonomics: ErgonomicsData
    var appTracker: AppTrackerData
    var shortcuts: ShortcutData

    // CodingKeys stay flat for backward-compatible JSON (same keys as before).
    enum CodingKeys: String, CodingKey {
        case startedAt, counts
        case lastInputTime, avgIntervalMs, avgIntervalCount
        case modifiedCounts, dailyMinIntervalMs
        case dailyAvgIntervalMs, dailyAvgIntervalCount
        case sameFingerCount, totalBigramCount
        case dailySameFingerCount, dailyTotalBigramCount
        case handAlternationCount, dailyHandAlternationCount
        case bigramCounts, trigramCounts
        case alternationRewardScore
        case highStrainBigramCount, dailyHighStrainBigramCount
        case highStrainTrigramCount, dailyHighStrainTrigramCount
        case appCounts, deviceCounts
        case appSameFingerCount, appTotalBigramCount
        case appHandAlternationCount, appHighStrainBigramCount
        case deviceSameFingerCount, deviceTotalBigramCount
        case deviceHandAlternationCount, deviceHighStrainBigramCount
        case dailyModifiedCount
    }

    init(startedAt: Date, counts: [String: Int]) {
        self.startedAt  = startedAt
        self.counts     = counts
        self.activity   = ActivityData()
        self.ergonomics = ErgonomicsData()
        self.appTracker = AppTrackerData()
        self.shortcuts  = ShortcutData()
    }

    /// Backward-compatible decode — new fields default to zero/empty.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try c.decode(Date.self,         forKey: .startedAt)
        counts    = try c.decode([String: Int].self, forKey: .counts)

        // ActivityData
        var act = ActivityData()
        act.lastInputTime       = try? c.decode(Date.self,            forKey: .lastInputTime)
        act.avgIntervalMs       = (try? c.decode(Double.self,         forKey: .avgIntervalMs))        ?? 0
        act.avgIntervalCount    = (try? c.decode(Int.self,            forKey: .avgIntervalCount))     ?? 0
        act.dailyMinIntervalMs  = (try? c.decode([String: Double].self, forKey: .dailyMinIntervalMs)) ?? [:]
        act.dailyAvgIntervalMs  = (try? c.decode([String: Double].self, forKey: .dailyAvgIntervalMs)) ?? [:]
        act.dailyAvgIntervalCount = (try? c.decode([String: Int].self, forKey: .dailyAvgIntervalCount)) ?? [:]
        activity = act

        // ErgonomicsData
        var erg = ErgonomicsData()
        erg.sameFingerCount             = (try? c.decode(Int.self,             forKey: .sameFingerCount))             ?? 0
        erg.totalBigramCount            = (try? c.decode(Int.self,             forKey: .totalBigramCount))            ?? 0
        erg.dailySameFingerCount        = (try? c.decode([String: Int].self,   forKey: .dailySameFingerCount))        ?? [:]
        erg.dailyTotalBigramCount       = (try? c.decode([String: Int].self,   forKey: .dailyTotalBigramCount))       ?? [:]
        erg.handAlternationCount        = (try? c.decode(Int.self,             forKey: .handAlternationCount))        ?? 0
        erg.dailyHandAlternationCount   = (try? c.decode([String: Int].self,   forKey: .dailyHandAlternationCount))   ?? [:]
        erg.bigramCounts                = (try? c.decode([String: Int].self,   forKey: .bigramCounts))                ?? [:]
        erg.trigramCounts               = (try? c.decode([String: Int].self,   forKey: .trigramCounts))               ?? [:]
        erg.alternationRewardScore      = (try? c.decode(Double.self,          forKey: .alternationRewardScore))      ?? 0
        erg.highStrainBigramCount       = (try? c.decode(Int.self,             forKey: .highStrainBigramCount))       ?? 0
        erg.dailyHighStrainBigramCount  = (try? c.decode([String: Int].self,   forKey: .dailyHighStrainBigramCount))  ?? [:]
        erg.highStrainTrigramCount      = (try? c.decode(Int.self,             forKey: .highStrainTrigramCount))      ?? 0
        erg.dailyHighStrainTrigramCount = (try? c.decode([String: Int].self,   forKey: .dailyHighStrainTrigramCount)) ?? [:]
        ergonomics = erg

        // AppTrackerData
        var app = AppTrackerData()
        app.appCounts                  = (try? c.decode([String: Int].self, forKey: .appCounts))                  ?? [:]
        app.deviceCounts               = (try? c.decode([String: Int].self, forKey: .deviceCounts))               ?? [:]
        app.appSameFingerCount         = (try? c.decode([String: Int].self, forKey: .appSameFingerCount))         ?? [:]
        app.appTotalBigramCount        = (try? c.decode([String: Int].self, forKey: .appTotalBigramCount))        ?? [:]
        app.appHandAlternationCount    = (try? c.decode([String: Int].self, forKey: .appHandAlternationCount))    ?? [:]
        app.appHighStrainBigramCount   = (try? c.decode([String: Int].self, forKey: .appHighStrainBigramCount))   ?? [:]
        app.deviceSameFingerCount      = (try? c.decode([String: Int].self, forKey: .deviceSameFingerCount))      ?? [:]
        app.deviceTotalBigramCount     = (try? c.decode([String: Int].self, forKey: .deviceTotalBigramCount))     ?? [:]
        app.deviceHandAlternationCount = (try? c.decode([String: Int].self, forKey: .deviceHandAlternationCount)) ?? [:]
        app.deviceHighStrainBigramCount = (try? c.decode([String: Int].self, forKey: .deviceHighStrainBigramCount)) ?? [:]
        appTracker = app

        // ShortcutData
        var sc = ShortcutData()
        sc.modifiedCounts    = (try? c.decode([String: Int].self, forKey: .modifiedCounts))    ?? [:]
        sc.dailyModifiedCount = (try? c.decode([String: Int].self, forKey: .dailyModifiedCount)) ?? [:]
        shortcuts = sc
    }

    /// Encodes flat (same JSON keys as before) to preserve backward compatibility.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encode(counts,    forKey: .counts)
        // ActivityData — encoded flat
        try c.encodeIfPresent(activity.lastInputTime,         forKey: .lastInputTime)
        try c.encode(activity.avgIntervalMs,                  forKey: .avgIntervalMs)
        try c.encode(activity.avgIntervalCount,               forKey: .avgIntervalCount)
        try c.encode(activity.dailyMinIntervalMs,             forKey: .dailyMinIntervalMs)
        try c.encode(activity.dailyAvgIntervalMs,             forKey: .dailyAvgIntervalMs)
        try c.encode(activity.dailyAvgIntervalCount,          forKey: .dailyAvgIntervalCount)
        // ErgonomicsData — encoded flat
        try c.encode(ergonomics.sameFingerCount,              forKey: .sameFingerCount)
        try c.encode(ergonomics.totalBigramCount,             forKey: .totalBigramCount)
        try c.encode(ergonomics.dailySameFingerCount,         forKey: .dailySameFingerCount)
        try c.encode(ergonomics.dailyTotalBigramCount,        forKey: .dailyTotalBigramCount)
        try c.encode(ergonomics.handAlternationCount,         forKey: .handAlternationCount)
        try c.encode(ergonomics.dailyHandAlternationCount,    forKey: .dailyHandAlternationCount)
        try c.encode(ergonomics.bigramCounts,                 forKey: .bigramCounts)
        try c.encode(ergonomics.trigramCounts,                forKey: .trigramCounts)
        try c.encode(ergonomics.alternationRewardScore,       forKey: .alternationRewardScore)
        try c.encode(ergonomics.highStrainBigramCount,        forKey: .highStrainBigramCount)
        try c.encode(ergonomics.dailyHighStrainBigramCount,   forKey: .dailyHighStrainBigramCount)
        try c.encode(ergonomics.highStrainTrigramCount,       forKey: .highStrainTrigramCount)
        try c.encode(ergonomics.dailyHighStrainTrigramCount,  forKey: .dailyHighStrainTrigramCount)
        // AppTrackerData — encoded flat
        try c.encode(appTracker.appCounts,                    forKey: .appCounts)
        try c.encode(appTracker.deviceCounts,                 forKey: .deviceCounts)
        try c.encode(appTracker.appSameFingerCount,           forKey: .appSameFingerCount)
        try c.encode(appTracker.appTotalBigramCount,          forKey: .appTotalBigramCount)
        try c.encode(appTracker.appHandAlternationCount,      forKey: .appHandAlternationCount)
        try c.encode(appTracker.appHighStrainBigramCount,     forKey: .appHighStrainBigramCount)
        try c.encode(appTracker.deviceSameFingerCount,        forKey: .deviceSameFingerCount)
        try c.encode(appTracker.deviceTotalBigramCount,       forKey: .deviceTotalBigramCount)
        try c.encode(appTracker.deviceHandAlternationCount,   forKey: .deviceHandAlternationCount)
        try c.encode(appTracker.deviceHighStrainBigramCount,  forKey: .deviceHighStrainBigramCount)
        // ShortcutData — encoded flat
        try c.encode(shortcuts.modifiedCounts,                forKey: .modifiedCounts)
        try c.encode(shortcuts.dailyModifiedCount,            forKey: .dailyModifiedCount)
    }

    // MARK: - SQLite scalars serialization

    /// Serializes all persistent fields to (key, value) pairs for the `scalars` SQLite table.
    func toScalars() -> [(key: String, value: String)] {
        var entries: [(String, String)] = []
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Simple scalars
        entries.append(("startedAt",              fmt.string(from: startedAt)))
        if let t = activity.lastInputTime {
            entries.append(("lastInputTime",      fmt.string(from: t)))
        }
        entries.append(("avgIntervalMs",          "\(activity.avgIntervalMs)"))
        entries.append(("avgIntervalCount",       "\(activity.avgIntervalCount)"))
        entries.append(("sameFingerCount",        "\(ergonomics.sameFingerCount)"))
        entries.append(("totalBigramCount",       "\(ergonomics.totalBigramCount)"))
        entries.append(("handAlternationCount",   "\(ergonomics.handAlternationCount)"))
        entries.append(("alternationRewardScore", "\(ergonomics.alternationRewardScore)"))
        entries.append(("highStrainBigramCount",  "\(ergonomics.highStrainBigramCount)"))
        entries.append(("highStrainTrigramCount", "\(ergonomics.highStrainTrigramCount)"))

        // JSON blob entries
        let enc = JSONEncoder()
        func js<V: Encodable>(_ v: V) -> String {
            (try? String(data: enc.encode(v), encoding: .utf8)) ?? "{}"
        }
        entries.append(("keyCounts",                       js(counts)))
        entries.append(("bigramCounts",                    js(ergonomics.bigramCounts)))
        entries.append(("trigramCounts",                   js(ergonomics.trigramCounts)))
        entries.append(("appCounts",                       js(appTracker.appCounts)))
        entries.append(("deviceCounts",                    js(appTracker.deviceCounts)))
        entries.append(("appSameFingerCount",               js(appTracker.appSameFingerCount)))
        entries.append(("appTotalBigramCount",              js(appTracker.appTotalBigramCount)))
        entries.append(("appHandAlternationCount",          js(appTracker.appHandAlternationCount)))
        entries.append(("appHighStrainBigramCount",         js(appTracker.appHighStrainBigramCount)))
        entries.append(("deviceSameFingerCount",            js(appTracker.deviceSameFingerCount)))
        entries.append(("deviceTotalBigramCount",           js(appTracker.deviceTotalBigramCount)))
        entries.append(("deviceHandAlternationCount",       js(appTracker.deviceHandAlternationCount)))
        entries.append(("deviceHighStrainBigramCount",      js(appTracker.deviceHighStrainBigramCount)))
        entries.append(("modifiedCounts",                  js(shortcuts.modifiedCounts)))
        entries.append(("dailyModifiedCount",               js(shortcuts.dailyModifiedCount)))
        entries.append(("dailyMinIntervalMs",               js(activity.dailyMinIntervalMs)))
        entries.append(("dailyAvgIntervalMs",               js(activity.dailyAvgIntervalMs)))
        entries.append(("dailyAvgIntervalCount",            js(activity.dailyAvgIntervalCount)))
        entries.append(("dailySameFingerCount",             js(ergonomics.dailySameFingerCount)))
        entries.append(("dailyTotalBigramCount",            js(ergonomics.dailyTotalBigramCount)))
        entries.append(("dailyHandAlternationCount",        js(ergonomics.dailyHandAlternationCount)))
        entries.append(("dailyHighStrainBigramCount",       js(ergonomics.dailyHighStrainBigramCount)))
        entries.append(("dailyHighStrainTrigramCount",      js(ergonomics.dailyHighStrainTrigramCount)))
        return entries
    }

    /// Restores all persistent fields from key-value pairs read from the `scalars` SQLite table.
    mutating func loadScalars(_ dict: [String: String]) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dec = JSONDecoder()

        if let s = dict["startedAt"],              let d = fmt.date(from: s) { startedAt = d }
        if let s = dict["lastInputTime"],          let d = fmt.date(from: s) { activity.lastInputTime = d }
        if let s = dict["avgIntervalMs"],          let v = Double(s)         { activity.avgIntervalMs = v }
        if let s = dict["avgIntervalCount"],       let v = Int(s)            { activity.avgIntervalCount = v }
        if let s = dict["sameFingerCount"],        let v = Int(s)            { ergonomics.sameFingerCount = v }
        if let s = dict["totalBigramCount"],       let v = Int(s)            { ergonomics.totalBigramCount = v }
        if let s = dict["handAlternationCount"],   let v = Int(s)            { ergonomics.handAlternationCount = v }
        if let s = dict["alternationRewardScore"], let v = Double(s)         { ergonomics.alternationRewardScore = v }
        if let s = dict["highStrainBigramCount"],  let v = Int(s)            { ergonomics.highStrainBigramCount = v }
        if let s = dict["highStrainTrigramCount"], let v = Int(s)            { ergonomics.highStrainTrigramCount = v }

        func intDict(_ key: String) -> [String: Int] {
            guard let s = dict[key], let data = s.data(using: .utf8) else { return [:] }
            return (try? dec.decode([String: Int].self, from: data)) ?? [:]
        }
        func doubleDict(_ key: String) -> [String: Double] {
            guard let s = dict[key], let data = s.data(using: .utf8) else { return [:] }
            return (try? dec.decode([String: Double].self, from: data)) ?? [:]
        }

        counts                                     = intDict("keyCounts")
        ergonomics.bigramCounts                    = intDict("bigramCounts")
        ergonomics.trigramCounts                   = intDict("trigramCounts")
        appTracker.appCounts                       = intDict("appCounts")
        appTracker.deviceCounts                    = intDict("deviceCounts")
        appTracker.appSameFingerCount              = intDict("appSameFingerCount")
        appTracker.appTotalBigramCount             = intDict("appTotalBigramCount")
        appTracker.appHandAlternationCount         = intDict("appHandAlternationCount")
        appTracker.appHighStrainBigramCount        = intDict("appHighStrainBigramCount")
        appTracker.deviceSameFingerCount           = intDict("deviceSameFingerCount")
        appTracker.deviceTotalBigramCount          = intDict("deviceTotalBigramCount")
        appTracker.deviceHandAlternationCount      = intDict("deviceHandAlternationCount")
        appTracker.deviceHighStrainBigramCount     = intDict("deviceHighStrainBigramCount")
        shortcuts.modifiedCounts                   = intDict("modifiedCounts")
        shortcuts.dailyModifiedCount               = intDict("dailyModifiedCount")
        activity.dailyMinIntervalMs                = doubleDict("dailyMinIntervalMs")
        activity.dailyAvgIntervalMs                = doubleDict("dailyAvgIntervalMs")
        activity.dailyAvgIntervalCount             = intDict("dailyAvgIntervalCount")
        ergonomics.dailySameFingerCount            = intDict("dailySameFingerCount")
        ergonomics.dailyTotalBigramCount           = intDict("dailyTotalBigramCount")
        ergonomics.dailyHandAlternationCount       = intDict("dailyHandAlternationCount")
        ergonomics.dailyHighStrainBigramCount      = intDict("dailyHighStrainBigramCount")
        ergonomics.dailyHighStrainTrigramCount     = intDict("dailyHighStrainTrigramCount")
    }
}

// MARK: - Store

/// Singleton that manages keystroke counts.
/// All data is persisted to keylens.db (scalars table + time-series tables).
/// キーストロークカウントを管理するシングルトン。
/// すべてのデータは keylens.db に永続化する (scalars テーブル + 時系列テーブル)。
final class KeyCountStore {
    static let shared = KeyCountStore()

    var store: CountData
    let queue = DispatchQueue(label: "com.keycounter.store")
    private let saveQueue = DispatchQueue(label: "com.keycounter.save", qos: .background)

    let saveURL: URL
    private var saveWorkItem: DispatchWorkItem?

    // SQLite backing store (set up in setupDatabase())
    var dbQueue: DatabaseQueue?
    var pending = PendingStore()
    var flushTimer: DispatchSourceTimer?

    // Today count cache — avoids SQLite reads in the hot path.
    // Updated in increment(); reset when the calendar date changes.
    private var _todayCount: Int = 0
    private var _todayCacheDate: String = ""

    // In-memory rolling state (not persisted)
    private var lastKeyName: String?
    private var secondLastKeyName: String?
    private var lastPhysicalKeyName: String?   // physical base key for layer-mapped keys (Issue #236)
    private var lastBigramWasHighStrain: Bool = false
    private var alternationStreak: Int = 0

    // In-memory ring buffer: last 6 IKI values for responsive instantaneous WPM.
    // Fewer entries = needle reacts to speed changes within ~5 keystrokes.
    private(set) var recentIKIs: [(key: String, iki: Double)] = []
    private let recentIKICapacity = 6

    // Larger ring buffer for rhythm classification (needs ~50 samples for stable CV).
    private(set) var rhythmIKIs: [Double] = []
    private let rhythmIKICapacity = 50

    // In-memory slow-event counter (resets on app relaunch, not persisted).
    private(set) var slowEventCount: Int = 0

    /// Increments the slow-event counter. Thread-safe: must be called from outside the store queue.
    func recordSlowEvent() {
        queue.async { self.slowEventCount += 1 }
    }

    // Manual WPM measurement session (Issue #150). All access on `queue`.
    var wpmSessionStart: Date? = nil
    var wpmSessionKeystrokes: Int = 0

    // Typing session detection (Issue #60). All access on `queue`.
    // A session boundary is defined as a gap of ≥ sessionGapThreshold with no keystrokes.
    static let sessionGapThreshold: TimeInterval = 5 * 60  // 5 minutes
    private var currentSessionStart: Date? = nil
    private var currentSessionKeystrokes: Int = 0

    private init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyLens")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        saveURL = dir.appendingPathComponent("counts.json")
        store = CountData(startedAt: Date(), counts: [:])
        setupDatabase()            // creates keylens.db and schema
        migrateIfNeeded()          // one-time import of legacy daily data from counts.json
        migrateScalarsIfNeeded()   // one-time import of scalars from counts.json
        loadFromSQLite()           // load scalars from keylens.db
        // Prime today count cache from SQLite
        let today = todayKey
        _todayCacheDate = today
        if let db = dbQueue {
            _todayCount = (try? db.read { db in
                try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(count),0) FROM daily_keys WHERE date = ?",
                                 arguments: [today])
            }) ?? 0
        }
        startFlushTimer()
    }

    /// Notification interval (persisted in UserDefaults, default 1000).
    static var milestoneInterval: Int {
        get { let v = UserDefaults.standard.integer(forKey: "milestoneInterval"); return v > 0 ? v : 1000 }
        set { UserDefaults.standard.set(newValue, forKey: "milestoneInterval") }
    }

    // MARK: - Date helpers

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var todayKey: String { Self.dayFormatter.string(from: Date()) }

    // MARK: - Query factory

    /// Creates a read-only snapshot of the current store state for use with KeyMetricsQuery.
    /// Must be called from inside queue.sync.
    func makeQuery() -> KeyMetricsQuery {
        KeyMetricsQuery(
            store:               store,
            pending:             pending,
            dbQueue:             dbQueue,
            recentIKIs:          recentIKIs,
            rhythmIKIs:          rhythmIKIs,
            todayKey:            todayKey,
            wpmSessionStart:     wpmSessionStart
        )
    }

    // MARK: - Mutation

    /// Increment count by 1. Dispatches work asynchronously; calls completion on the main thread with (newCount, isMilestone).
    func increment(key: String, at timestamp: Date = Date(), appName: String? = nil, completion: ((_ count: Int, _ milestone: Bool) -> Void)? = nil) {
        let today = todayKey
        let hour  = Calendar.current.component(.hour, from: timestamp)
        let deviceName = LayoutRegistry.shared.currentDeviceLabel
        let incrementStart = Date()

        queue.async { [weak self] in
            guard let self else { return }
            var count: Int = 0
            do {
            // All-time per-key count (in-memory; persisted via scalars table)
            store.counts[key, default: 0] += 1

            // Per-day key count → SQLite pending
            pending.dailyKeys[today, default: [:]][key, default: 0] += 1
            // Hourly count → SQLite pending
            pending.hourly[today, default: [:]][hour, default: 0] += 1
            // Per-app → SQLite pending
            if let app = appName {
                store.appTracker.appCounts[app, default: 0] += 1
                pending.dailyApps[today, default: [:]][app, default: 0] += 1
            }
            // Per-device → SQLite pending
            store.appTracker.deviceCounts[deviceName, default: 0] += 1
            pending.dailyDevices[today, default: [:]][deviceName, default: 0] += 1

            // Manual WPM session keystroke counter
            if wpmSessionStart != nil { wpmSessionKeystrokes += 1 }

            // Update today count cache
            if _todayCacheDate != today {
                _todayCacheDate = today
                _todayCount = dailyTotalLocked(for: today)
            }
            _todayCount += 1

            let prevInputTime = store.activity.lastInputTime

            // Session detection (Issue #60): detect ≥5-min gaps and record completed sessions.
            if let prev = prevInputTime {
                let gap = timestamp.timeIntervalSince(prev)
                if gap >= Self.sessionGapThreshold {
                    // Gap is large enough to close the current session and start a new one.
                    finalizeCurrentSessionLocked(at: prev)
                    currentSessionStart = timestamp
                    currentSessionKeystrokes = 1
                } else {
                    if currentSessionStart == nil { currentSessionStart = timestamp }
                    currentSessionKeystrokes += 1
                }
            } else {
                // First keystroke ever recorded.
                currentSessionStart = timestamp
                currentSessionKeystrokes = 1
            }

            // Welford IKI update (≤1000ms only)
            if let last = store.activity.lastInputTime {
                let intervalMs = timestamp.timeIntervalSince(last) * 1000
                if intervalMs <= AppConfiguration.ikiCutoffMs {
                    // Global Welford
                    store.activity.avgIntervalCount += 1
                    store.activity.avgIntervalMs += (intervalMs - store.activity.avgIntervalMs) / Double(store.activity.avgIntervalCount)
                    // Daily min
                    if intervalMs < (store.activity.dailyMinIntervalMs[today] ?? Double.infinity) {
                        store.activity.dailyMinIntervalMs[today] = intervalMs
                    }
                    // Daily Welford (Issue #59)
                    let dc = store.activity.dailyAvgIntervalCount[today, default: 0] + 1
                    store.activity.dailyAvgIntervalCount[today] = dc
                    let prevAvg = store.activity.dailyAvgIntervalMs[today, default: 0.0]
                    store.activity.dailyAvgIntervalMs[today] = prevAvg + (intervalMs - prevAvg) / Double(dc)
                    // Live ring buffer
                    recentIKIs.append((key: key, iki: intervalMs))
                    if recentIKIs.count > recentIKICapacity { recentIKIs.removeFirst() }
                    rhythmIKIs.append(intervalMs)
                    if rhythmIKIs.count > rhythmIKICapacity { rhythmIKIs.removeFirst() }
                    // IKI histogram bucket → SQLite pending
                    let bucket = KeyCountStore.ikiBucket(for: intervalMs)
                    pending.ikiBuckets[today, default: [:]][bucket, default: 0] += 1
                    // Hourly IKI for fatigue detection (Issue #63)
                    var hs = pending.hourlySlices[today, default: [:]][hour, default: PendingStore.HourlySlice()]
                    hs.ikiSum   += intervalMs
                    hs.ikiCount += 1
                    pending.hourlySlices[today, default: [:]][hour] = hs
                }
            } else {
                // First keystroke in session — anchor (iki = 0)
                recentIKIs.append((key: key, iki: 0))
                if recentIKIs.count > recentIKICapacity { recentIKIs.removeFirst() }
            }
            store.activity.lastInputTime = timestamp

            // Same-finger / alternation / bigram ergonomics
            // Issue #236: resolve physical key for layer-mapped output keys.
            // If this key is a layer output (e.g. "←" = Lower+J), use the base key ("J")
            // for finger/hand lookup so ergonomic scoring reflects the actual physical key pressed.
            let physicalKey = LayerMappingStore.shared.lookupTable[key]?.baseKey ?? key
            let prevPhysical = lastPhysicalKeyName ?? lastKeyName

            let layout = LayoutRegistry.shared
            if let prev = lastKeyName,
               let prevFinger = layout.finger(for: prevPhysical ?? prev),
               let prevHand   = layout.hand(for: prevPhysical ?? prev),
               let curFinger  = layout.finger(for: physicalKey),
               let curHand    = layout.hand(for: physicalKey) {

                store.ergonomics.totalBigramCount += 1
                store.ergonomics.dailyTotalBigramCount[today, default: 0] += 1

                if prevFinger == curFinger && prevHand == curHand {
                    store.ergonomics.sameFingerCount += 1
                    store.ergonomics.dailySameFingerCount[today, default: 0] += 1
                }

                if prevHand != curHand {
                    store.ergonomics.handAlternationCount += 1
                    store.ergonomics.dailyHandAlternationCount[today, default: 0] += 1
                    alternationStreak += 1
                    store.ergonomics.alternationRewardScore +=
                        layout.alternationRewardModel.reward(forStreak: alternationStreak)
                } else {
                    alternationStreak = 0
                }

                // Bigram frequency (all-time stays in JSON; daily → SQLite)
                let pair = Bigram(from: prev, to: key).key
                store.ergonomics.bigramCounts[pair, default: 0] += 1
                pending.dailyBigrams[today, default: [:]][pair, default: 0] += 1

                // Bigram IKI → SQLite pending (Issue #24)
                if let prevTime = prevInputTime {
                    let iki = timestamp.timeIntervalSince(prevTime) * 1000
                    if iki <= AppConfiguration.ikiCutoffMs {
                        let existing = pending.bigramIKI[pair] ?? (sum: 0, count: 0)
                        pending.bigramIKI[pair] = (sum: existing.sum + iki, count: existing.count + 1)
                    }
                }

                // High-strain detection (Issue #28); use physical keys for accuracy (Issue #236)
                let highStrain = layout.highStrainDetector.isHighStrain(
                    from: prevPhysical ?? prev, to: physicalKey, layout: layout)
                if highStrain {
                    store.ergonomics.highStrainBigramCount += 1
                    store.ergonomics.dailyHighStrainBigramCount[today, default: 0] += 1
                    if lastBigramWasHighStrain {
                        store.ergonomics.highStrainTrigramCount += 1
                        store.ergonomics.dailyHighStrainTrigramCount[today, default: 0] += 1
                    }
                }
                lastBigramWasHighStrain = highStrain

                // Hourly ergonomics for fatigue detection (Issue #63)
                var hse = pending.hourlySlices[today, default: [:]][hour, default: PendingStore.HourlySlice()]
                hse.ergTotal += 1
                if prevFinger == curFinger && prevHand == curHand { hse.ergSF += 1 }
                if highStrain { hse.ergHS += 1 }
                pending.hourlySlices[today, default: [:]][hour] = hse

                // Per-app bigram ergonomics
                if let app = appName {
                    store.appTracker.appTotalBigramCount[app, default: 0] += 1
                    if prevFinger == curFinger && prevHand == curHand {
                        store.appTracker.appSameFingerCount[app, default: 0] += 1
                    }
                    if prevHand != curHand { store.appTracker.appHandAlternationCount[app, default: 0] += 1 }
                    if highStrain          { store.appTracker.appHighStrainBigramCount[app, default: 0] += 1 }
                }
                // Per-device bigram ergonomics
                store.appTracker.deviceTotalBigramCount[deviceName, default: 0] += 1
                if prevFinger == curFinger && prevHand == curHand {
                    store.appTracker.deviceSameFingerCount[deviceName, default: 0] += 1
                }
                if prevHand != curHand { store.appTracker.deviceHandAlternationCount[deviceName, default: 0] += 1 }
                if highStrain          { store.appTracker.deviceHighStrainBigramCount[deviceName, default: 0] += 1 }

                // Trigram frequency (all-time stays in JSON; daily → SQLite) (Issue #12)
                if let prev2 = secondLastKeyName {
                    let trigram = "\(prev2)→\(prev)→\(key)"
                    store.ergonomics.trigramCounts[trigram, default: 0] += 1
                    pending.dailyTrigrams[today, default: [:]][trigram, default: 0] += 1
                }
                secondLastKeyName = prev
            } else {
                secondLastKeyName = nil
            }
            lastKeyName = key
            lastPhysicalKeyName = (physicalKey == key) ? nil : physicalKey

            // Layer key tracking (Issue #209 / #236): record activation and per-layer ergonomic stats.
            if let combo = LayerMappingStore.shared.physicalCombo(for: key) {
                LayerMappingStore.shared.recordPress(
                    layerKeyName: combo.layerKeyName,
                    outputKey: key,
                    date: today
                )
                // Issue #236: accumulate per-layer ergonomic deltas using the physical base key.
                // prevPhysical was captured before lastKeyName/lastPhysicalKeyName were updated.
                if let prevPhys = prevPhysical,
                   let pFinger = layout.finger(for: prevPhys),
                   let pHand   = layout.hand(for: prevPhys),
                   let cFinger = layout.finger(for: physicalKey),
                   let cHand   = layout.hand(for: physicalKey) {
                    let sf = (pFinger == cFinger && pHand == cHand)
                    let ha = (pHand != cHand)
                    let hs = layout.highStrainDetector.isHighStrain(from: prevPhys, to: physicalKey, layout: layout)
                    var sl = pending.layerErgSlices[today, default: [:]][combo.layerKeyName, default: PendingStore.LayerErgSlice()]
                    sl.ergTotal += 1
                    if sf { sl.ergSF += 1 }
                    if ha { sl.ergHA += 1 }
                    if hs { sl.ergHS += 1 }
                    pending.layerErgSlices[today, default: [:]][combo.layerKeyName] = sl
                }
            }

            checkGoalNotificationLocked(todayStr: today)

            count = store.counts[key, default: 0]
            }
            let elapsedMs = Date().timeIntervalSince(incrementStart) * 1000
            PerformanceProfiler.shared.record(metric: "store.increment", ms: elapsedMs)
            if elapsedMs > 5.0 {
                KeyLens.log("[perf] store.increment slow: \(String(format: "%.1f", elapsedMs))ms (key: \(key))")
                self.slowEventCount += 1
            }
            self.scheduleSave()
            if let completion {
                let milestone = count % KeyCountStore.milestoneInterval == 0
                DispatchQueue.main.async { completion(count, milestone) }
            }
        }
    }

    /// Increment a modifier+key combo count.
    func incrementModified(key: String) {
        queue.sync {
            store.shortcuts.modifiedCounts[key, default: 0] += 1
            store.shortcuts.dailyModifiedCount[todayKey, default: 0] += 1
        }
        scheduleSave()
    }

    // MARK: - Session management (Issue #60)

    /// Finalize the in-progress session and add it to pending. Must be called on `queue`.
    func finalizeCurrentSessionLocked(at endTime: Date) {
        guard let start = currentSessionStart,
              currentSessionKeystrokes > 0,
              endTime.timeIntervalSince(start) > 0 else { return }
        let date = Self.dayFormatter.string(from: start)
        pending.pendingSessions.append(PendingStore.SessionRecord(
            date: date,
            startTime: start.timeIntervalSince1970,
            endTime: endTime.timeIntervalSince1970,
            keystrokeCount: currentSessionKeystrokes
        ))
        currentSessionStart = nil
        currentSessionKeystrokes = 0
    }

    /// Finalize the open session and flush it. Call from AppDelegate on termination.
    func finalizeCurrentSession() {
        queue.sync {
            guard let last = store.activity.lastInputTime else { return }
            finalizeCurrentSessionLocked(at: last)
        }
    }

    // MARK: - Metadata

    var totalCount: Int {
        queue.sync { store.counts.values.reduce(0, +) }
    }

    var startedAt: Date {
        queue.sync { store.startedAt }
    }

    /// Reload scalars from SQLite; resets pending and rolling state.
    func reload() {
        queue.sync {
            loadFromSQLite()
            pending = PendingStore()
            lastKeyName = nil
            secondLastKeyName = nil
            lastPhysicalKeyName = nil
            alternationStreak = 0
            lastBigramWasHighStrain = false
            currentSessionStart = nil
            currentSessionKeystrokes = 0
            // Re-prime today cache
            _todayCacheDate = todayKey
            _todayCount = dailyTotalLocked(for: _todayCacheDate)
        }
    }

    /// Copies keylens.db to a temp file and returns the URL. Call before reset() to enable undo.
    func backupDBForUndo() -> URL? {
        guard let db = dbQueue else { return nil }
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("keylens_undo_\(Int(Date().timeIntervalSince1970)).db")
        let src = URL(fileURLWithPath: db.path)
        do {
            try FileManager.default.copyItem(at: src, to: tmp)
            return tmp
        } catch {
            return nil
        }
    }

    /// Restores data from a backup URL produced by backupDBForUndo().
    /// Closes the current DB, overwrites the live file with the backup, and reloads in-memory state.
    func restoreFromUndo(url: URL) {
        queue.sync {
            guard let db = dbQueue else { return }
            let dest = URL(fileURLWithPath: db.path)
            dbQueue = nil
            do {
                try FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: url, to: dest)
                try FileManager.default.removeItem(at: url)
                dbQueue = try DatabaseQueue(path: dest.path)
            } catch {
                return
            }
            store = CountData(startedAt: Date(), counts: [:])
            pending = PendingStore()
            _todayCount = 0
            _todayCacheDate = todayKey
        }
        loadFromSQLite()
    }

    /// Reset all counts to zero.
    func reset() {
        queue.sync {
            store = CountData(startedAt: Date(), counts: [:])
            pending = PendingStore()
            lastKeyName = nil
            secondLastKeyName = nil
            lastPhysicalKeyName = nil
            alternationStreak = 0
            lastBigramWasHighStrain = false
            currentSessionStart = nil
            currentSessionKeystrokes = 0
            _todayCount = 0
            _todayCacheDate = todayKey
            // Clear SQLite tables
            if let db = dbQueue {
                try? db.write { db in
                    for table in ["daily_keys","daily_bigrams","daily_trigrams",
                                  "daily_apps","daily_devices","hourly_counts",
                                  "bigram_iki","iki_buckets","sessions","scalars"] {
                        try db.execute(sql: "DELETE FROM \(table)")
                    }
                }
            }
        }
        scheduleSave()
    }

    // MARK: - Daily Goal & Streak

    private static let dailyGoalKey    = "dailyGoalCount"
    private static let goalNotifiedKey = "goalNotifiedDate"

    var dailyGoal: Int {
        get { UserDefaults.standard.integer(forKey: Self.dailyGoalKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.dailyGoalKey) }
    }

    /// Compute consecutive-day streak using a single SQL query.
    /// Must be called inside queue.sync.
    private func streakLocked(goal: Int) -> Int {
        guard let db = dbQueue else { return 0 }
        let cal = Calendar.current
        let cutoffDate = cal.date(byAdding: .day, value: -365, to: Date()) ?? Date()
        let cutoff = Self.dayFormatter.string(from: cutoffDate)

        // Load all daily totals in one query
        var totals: [String: Int] = [:]
        if let rows = try? db.read({ db in
            try Row.fetchAll(db, sql: """
                SELECT date, SUM(count) as total FROM daily_keys
                WHERE date >= ? GROUP BY date
                """, arguments: [cutoff])
        }) {
            for row in rows { totals[row["date"]] = (row["total"] as Int) }
        }
        // Merge pending
        for (date, keys) in pending.dailyKeys where date >= cutoff {
            totals[date, default: 0] += keys.values.reduce(0, +)
        }

        var streak = 0
        var date = Date()
        for _ in 0..<365 {
            let key = Self.dayFormatter.string(from: date)
            if (totals[key] ?? 0) >= goal {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
                date = prev
            } else {
                break
            }
        }
        return streak
    }

    func currentStreak() -> Int {
        let goal = dailyGoal
        guard goal > 0 else { return 0 }
        return queue.sync { streakLocked(goal: goal) }
    }

    /// Fires a one-per-day notification when today's goal is first crossed.
    /// Must be called inside queue.sync.
    private func checkGoalNotificationLocked(todayStr: String) {
        let goal = dailyGoal
        guard goal > 0 else { return }
        let notified = UserDefaults.standard.string(forKey: Self.goalNotifiedKey)
        guard notified != todayStr else { return }
        guard _todayCount >= goal else { return }
        UserDefaults.standard.set(todayStr, forKey: Self.goalNotifiedKey)
        let streak = streakLocked(goal: goal)
        DispatchQueue.main.async {
            let content = UNMutableNotificationContent()
            content.title = L10n.shared.goalReachedTitle
            content.body  = L10n.shared.goalReachedBody(streak: streak)
            content.sound = .default
            let req = UNNotificationRequest(
                identifier: "com.keylens.goalReached",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(req) { _ in }
        }
    }

    // MARK: - Persistence (SQLite scalars)

    /// Debounces SQLite scalar writes: schedules a save 2 seconds after the last call.
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.snapshotAndSave() }
        saveWorkItem = item
        queue.asyncAfter(deadline: .now() + 2.0, execute: item)
    }

    // Captures a snapshot of `store` on `queue`, then writes scalars to SQLite on `saveQueue`.
    // This prevents serialization (O(store size)) from blocking `queue.sync` in increment().
    private func snapshotAndSave() {
        let snapshotStart = CFAbsoluteTimeGetCurrent()
        let snapshot = store
        PerformanceProfiler.shared.record(
            metric: "store.snapshot.capture",
            ms: (CFAbsoluteTimeGetCurrent() - snapshotStart) * 1000
        )
        guard let db = dbQueue else { return }
        saveQueue.async {
            let writeStart = CFAbsoluteTimeGetCurrent()
            do {
                try db.write { db in
                    for (key, value) in snapshot.toScalars() {
                        try db.execute(
                            sql: "INSERT OR REPLACE INTO scalars (key, value) VALUES (?, ?)",
                            arguments: [key, value])
                    }
                }
                PerformanceProfiler.shared.record(
                    metric: "store.snapshot.sqliteWrite",
                    ms: (CFAbsoluteTimeGetCurrent() - writeStart) * 1000
                )
            } catch {
                KeyLens.log("KeyCountStore: scalars write error: \(error)")
            }
        }
    }

    func loadFromSQLite() {
        guard let db = dbQueue else { return }
        let rows = (try? db.read { db in
            try Row.fetchAll(db, sql: "SELECT key, value FROM scalars")
        }) ?? []
        guard !rows.isEmpty else { return }
        var dict: [String: String] = [:]
        for row in rows { dict[row["key"]] = (row["value"] as String?) ?? "" }
        store.loadScalars(dict)
    }
}
