import AppKit
import Foundation
import GRDB
import KeyLensCore
import UserNotifications

// MARK: - Data model

/// Persisted scalars and small fixed-size maps. Large per-day dictionaries
/// are stored in keylens.db (see KeyCountStore+SQLite.swift).
/// 永続化するスカラー値と小規模マップ。大きな日次ディクショナリは keylens.db に移行済み。
struct CountData: Codable {
    var startedAt: Date
    var counts: [String: Int]                      // all-time per-key cumulative count
    var lastInputTime: Date?
    var avgIntervalMs: Double                      // Welford moving average (ms)
    var avgIntervalCount: Int                      // Welford sample count
    var modifiedCounts: [String: Int]              // "⌘c", "⇧a" modifier+key combos
    var dailyMinIntervalMs: [String: Double]       // "yyyy-MM-dd" -> daily min IKI (ms, ≤1000ms)
    // Daily Welford average interval (Issue #59 Phase 2)
    var dailyAvgIntervalMs:    [String: Double]
    var dailyAvgIntervalCount: [String: Int]
    // Same-finger bigram tracking (Issue #16)
    var sameFingerCount: Int
    var totalBigramCount: Int
    var dailySameFingerCount:  [String: Int]
    var dailyTotalBigramCount: [String: Int]
    // Hand alternation tracking (Issue #17)
    var handAlternationCount: Int
    var dailyHandAlternationCount: [String: Int]
    // All-time bigram / trigram frequency (small enough to stay in JSON)
    var bigramCounts:  [String: Int]
    var trigramCounts: [String: Int]
    // Alternation reward (Issue #25)
    var alternationRewardScore: Double
    // High-strain sequence tracking (Issue #28)
    var highStrainBigramCount: Int
    var dailyHighStrainBigramCount:  [String: Int]
    var highStrainTrigramCount: Int
    var dailyHighStrainTrigramCount: [String: Int]
    // Per-app / per-device cumulative totals and ergonomic counters
    var appCounts:    [String: Int]
    var deviceCounts: [String: Int]
    var appSameFingerCount:      [String: Int]
    var appTotalBigramCount:     [String: Int]
    var appHandAlternationCount: [String: Int]
    var appHighStrainBigramCount:[String: Int]
    var deviceSameFingerCount:      [String: Int]
    var deviceTotalBigramCount:     [String: Int]
    var deviceHandAlternationCount: [String: Int]
    var deviceHighStrainBigramCount:[String: Int]
    // Daily shortcut counts (Issue #66)
    var dailyModifiedCount: [String: Int]

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
        self.startedAt = startedAt
        self.counts    = counts
        self.lastInputTime        = nil
        self.avgIntervalMs        = 0
        self.avgIntervalCount     = 0
        self.modifiedCounts       = [:]
        self.dailyMinIntervalMs   = [:]
        self.dailyAvgIntervalMs   = [:]
        self.dailyAvgIntervalCount = [:]
        self.sameFingerCount      = 0
        self.totalBigramCount     = 0
        self.dailySameFingerCount  = [:]
        self.dailyTotalBigramCount = [:]
        self.handAlternationCount  = 0
        self.dailyHandAlternationCount = [:]
        self.bigramCounts  = [:]
        self.trigramCounts = [:]
        self.alternationRewardScore = 0
        self.highStrainBigramCount  = 0
        self.dailyHighStrainBigramCount  = [:]
        self.highStrainTrigramCount = 0
        self.dailyHighStrainTrigramCount = [:]
        self.appCounts    = [:]
        self.deviceCounts = [:]
        self.appSameFingerCount      = [:]
        self.appTotalBigramCount     = [:]
        self.appHandAlternationCount = [:]
        self.appHighStrainBigramCount = [:]
        self.deviceSameFingerCount      = [:]
        self.deviceTotalBigramCount     = [:]
        self.deviceHandAlternationCount = [:]
        self.deviceHighStrainBigramCount = [:]
        self.dailyModifiedCount = [:]
    }

    /// Backward-compatible decode — new fields default to zero/empty.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        counts    = try c.decode([String: Int].self, forKey: .counts)
        lastInputTime    = try? c.decode(Date.self,   forKey: .lastInputTime)
        avgIntervalMs    = (try? c.decode(Double.self, forKey: .avgIntervalMs))    ?? 0
        avgIntervalCount = (try? c.decode(Int.self,    forKey: .avgIntervalCount)) ?? 0
        modifiedCounts   = (try? c.decode([String: Int].self, forKey: .modifiedCounts)) ?? [:]
        dailyMinIntervalMs    = (try? c.decode([String: Double].self, forKey: .dailyMinIntervalMs))    ?? [:]
        dailyAvgIntervalMs    = (try? c.decode([String: Double].self, forKey: .dailyAvgIntervalMs))    ?? [:]
        dailyAvgIntervalCount = (try? c.decode([String: Int].self,    forKey: .dailyAvgIntervalCount)) ?? [:]
        sameFingerCount  = (try? c.decode(Int.self, forKey: .sameFingerCount))  ?? 0
        totalBigramCount = (try? c.decode(Int.self, forKey: .totalBigramCount)) ?? 0
        dailySameFingerCount  = (try? c.decode([String: Int].self, forKey: .dailySameFingerCount))  ?? [:]
        dailyTotalBigramCount = (try? c.decode([String: Int].self, forKey: .dailyTotalBigramCount)) ?? [:]
        handAlternationCount      = (try? c.decode(Int.self,            forKey: .handAlternationCount))      ?? 0
        dailyHandAlternationCount = (try? c.decode([String: Int].self,  forKey: .dailyHandAlternationCount)) ?? [:]
        bigramCounts  = (try? c.decode([String: Int].self, forKey: .bigramCounts))  ?? [:]
        trigramCounts = (try? c.decode([String: Int].self, forKey: .trigramCounts)) ?? [:]
        alternationRewardScore       = (try? c.decode(Double.self,          forKey: .alternationRewardScore))       ?? 0
        highStrainBigramCount        = (try? c.decode(Int.self,             forKey: .highStrainBigramCount))        ?? 0
        dailyHighStrainBigramCount   = (try? c.decode([String: Int].self,   forKey: .dailyHighStrainBigramCount))   ?? [:]
        highStrainTrigramCount       = (try? c.decode(Int.self,             forKey: .highStrainTrigramCount))       ?? 0
        dailyHighStrainTrigramCount  = (try? c.decode([String: Int].self,   forKey: .dailyHighStrainTrigramCount))  ?? [:]
        appCounts    = (try? c.decode([String: Int].self, forKey: .appCounts))    ?? [:]
        deviceCounts = (try? c.decode([String: Int].self, forKey: .deviceCounts)) ?? [:]
        appSameFingerCount       = (try? c.decode([String: Int].self, forKey: .appSameFingerCount))       ?? [:]
        appTotalBigramCount      = (try? c.decode([String: Int].self, forKey: .appTotalBigramCount))      ?? [:]
        appHandAlternationCount  = (try? c.decode([String: Int].self, forKey: .appHandAlternationCount))  ?? [:]
        appHighStrainBigramCount = (try? c.decode([String: Int].self, forKey: .appHighStrainBigramCount)) ?? [:]
        deviceSameFingerCount       = (try? c.decode([String: Int].self, forKey: .deviceSameFingerCount))       ?? [:]
        deviceTotalBigramCount      = (try? c.decode([String: Int].self, forKey: .deviceTotalBigramCount))      ?? [:]
        deviceHandAlternationCount  = (try? c.decode([String: Int].self, forKey: .deviceHandAlternationCount))  ?? [:]
        deviceHighStrainBigramCount = (try? c.decode([String: Int].self, forKey: .deviceHighStrainBigramCount)) ?? [:]
        dailyModifiedCount = (try? c.decode([String: Int].self, forKey: .dailyModifiedCount)) ?? [:]
    }
}

// MARK: - Store

/// Singleton that manages keystroke counts.
/// Scalars are persisted to counts.json; large per-day data is persisted to keylens.db.
/// キーストロークカウントを管理するシングルトン。
/// スカラー値は counts.json、大きな日次データは keylens.db に永続化する。
final class KeyCountStore {
    static let shared = KeyCountStore()

    var store: CountData
    let queue = DispatchQueue(label: "com.keycounter.store")

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
    private var lastBigramWasHighStrain: Bool = false
    private var alternationStreak: Int = 0

    // In-memory ring buffer: last 20 IKI values (key + interval ms, ≤1000ms only).
    private(set) var recentIKIs: [(key: String, iki: Double)] = []
    private let recentIKICapacity = 20

    // In-memory slow-event counter (resets on app relaunch, not persisted).
    // アプリ再起動でリセット。永続化しない診断用カウンター。
    private(set) var slowEventCount: Int = 0

    /// Increments the slow-event counter. Thread-safe: must be called from outside the store queue.
    func recordSlowEvent() {
        queue.async { self.slowEventCount += 1 }
    }

    private init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyLens")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        saveURL = dir.appendingPathComponent("counts.json")
        store = CountData(startedAt: Date(), counts: [:])
        setupDatabase()      // creates keylens.db and schema
        migrateIfNeeded()    // one-time import from counts.json
        load()               // load slim JSON scalars
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

    // MARK: - Mutation

    /// Increment count by 1. Returns (newCount, isMilestone).
    func increment(key: String, at timestamp: Date = Date(), appName: String? = nil) -> (count: Int, milestone: Bool) {
        let today = todayKey
        let hour  = Calendar.current.component(.hour, from: timestamp)
        let deviceName = LayoutRegistry.shared.currentDeviceLabel

        let count: Int = queue.sync {
            // All-time per-key count (stays in JSON)
            store.counts[key, default: 0] += 1

            // Per-day key count → SQLite pending
            pending.dailyKeys[today, default: [:]][key, default: 0] += 1
            // Hourly count → SQLite pending
            pending.hourly[today, default: [:]][hour, default: 0] += 1
            // Per-app → SQLite pending
            if let app = appName {
                store.appCounts[app, default: 0] += 1
                pending.dailyApps[today, default: [:]][app, default: 0] += 1
            }
            // Per-device → SQLite pending
            store.deviceCounts[deviceName, default: 0] += 1
            pending.dailyDevices[today, default: [:]][deviceName, default: 0] += 1

            // Update today count cache
            if _todayCacheDate != today {
                _todayCacheDate = today
                _todayCount = dailyTotalLocked(for: today)
            }
            _todayCount += 1

            let prevInputTime = store.lastInputTime

            // Welford IKI update (≤1000ms only)
            if let last = store.lastInputTime {
                let intervalMs = timestamp.timeIntervalSince(last) * 1000
                if intervalMs <= 1000 {
                    // Global Welford
                    store.avgIntervalCount += 1
                    store.avgIntervalMs += (intervalMs - store.avgIntervalMs) / Double(store.avgIntervalCount)
                    // Daily min
                    if intervalMs < (store.dailyMinIntervalMs[today] ?? Double.infinity) {
                        store.dailyMinIntervalMs[today] = intervalMs
                    }
                    // Daily Welford (Issue #59)
                    let dc = store.dailyAvgIntervalCount[today, default: 0] + 1
                    store.dailyAvgIntervalCount[today] = dc
                    let prevAvg = store.dailyAvgIntervalMs[today, default: 0.0]
                    store.dailyAvgIntervalMs[today] = prevAvg + (intervalMs - prevAvg) / Double(dc)
                    // Live ring buffer
                    recentIKIs.append((key: key, iki: intervalMs))
                    if recentIKIs.count > recentIKICapacity { recentIKIs.removeFirst() }
                    // IKI histogram bucket → SQLite pending
                    let bucket = KeyCountStore.ikiBucket(for: intervalMs)
                    pending.ikiBuckets[today, default: [:]][bucket, default: 0] += 1
                }
            } else {
                // First keystroke in session — anchor (iki = 0)
                recentIKIs.append((key: key, iki: 0))
                if recentIKIs.count > recentIKICapacity { recentIKIs.removeFirst() }
            }
            store.lastInputTime = timestamp

            // Same-finger / alternation / bigram ergonomics
            let layout = LayoutRegistry.shared
            if let prev = lastKeyName,
               let prevFinger = layout.current.finger(for: prev),
               let prevHand   = layout.hand(for: prev),
               let curFinger  = layout.current.finger(for: key),
               let curHand    = layout.hand(for: key) {

                store.totalBigramCount += 1
                store.dailyTotalBigramCount[today, default: 0] += 1

                if prevFinger == curFinger && prevHand == curHand {
                    store.sameFingerCount += 1
                    store.dailySameFingerCount[today, default: 0] += 1
                }

                if prevHand != curHand {
                    store.handAlternationCount += 1
                    store.dailyHandAlternationCount[today, default: 0] += 1
                    alternationStreak += 1
                    store.alternationRewardScore +=
                        layout.alternationRewardModel.reward(forStreak: alternationStreak)
                } else {
                    alternationStreak = 0
                }

                // Bigram frequency (all-time stays in JSON; daily → SQLite)
                let pair = Bigram(from: prev, to: key).key
                store.bigramCounts[pair, default: 0] += 1
                pending.dailyBigrams[today, default: [:]][pair, default: 0] += 1

                // Bigram IKI → SQLite pending (Issue #24)
                if let prevTime = prevInputTime {
                    let iki = timestamp.timeIntervalSince(prevTime) * 1000
                    if iki <= 1000 {
                        let existing = pending.bigramIKI[pair] ?? (sum: 0, count: 0)
                        pending.bigramIKI[pair] = (sum: existing.sum + iki, count: existing.count + 1)
                    }
                }

                // High-strain detection (Issue #28)
                let highStrain = layout.highStrainDetector.isHighStrain(from: prev, to: key, layout: layout)
                if highStrain {
                    store.highStrainBigramCount += 1
                    store.dailyHighStrainBigramCount[today, default: 0] += 1
                    if lastBigramWasHighStrain {
                        store.highStrainTrigramCount += 1
                        store.dailyHighStrainTrigramCount[today, default: 0] += 1
                    }
                }
                lastBigramWasHighStrain = highStrain

                // Per-app bigram ergonomics
                if let app = appName {
                    store.appTotalBigramCount[app, default: 0] += 1
                    if prevFinger == curFinger && prevHand == curHand {
                        store.appSameFingerCount[app, default: 0] += 1
                    }
                    if prevHand != curHand { store.appHandAlternationCount[app, default: 0] += 1 }
                    if highStrain          { store.appHighStrainBigramCount[app, default: 0] += 1 }
                }
                // Per-device bigram ergonomics
                store.deviceTotalBigramCount[deviceName, default: 0] += 1
                if prevFinger == curFinger && prevHand == curHand {
                    store.deviceSameFingerCount[deviceName, default: 0] += 1
                }
                if prevHand != curHand { store.deviceHandAlternationCount[deviceName, default: 0] += 1 }
                if highStrain          { store.deviceHighStrainBigramCount[deviceName, default: 0] += 1 }

                // Trigram frequency (all-time stays in JSON; daily → SQLite) (Issue #12)
                if let prev2 = secondLastKeyName {
                    let trigram = "\(prev2)→\(prev)→\(key)"
                    store.trigramCounts[trigram, default: 0] += 1
                    pending.dailyTrigrams[today, default: [:]][trigram, default: 0] += 1
                }
                secondLastKeyName = prev
            } else {
                secondLastKeyName = nil
            }
            lastKeyName = key

            checkGoalNotificationLocked(todayStr: today)

            return store.counts[key, default: 0]
        }
        scheduleSave()
        return (count, count % KeyCountStore.milestoneInterval == 0)
    }

    /// Increment a modifier+key combo count.
    func incrementModified(key: String) {
        queue.sync {
            store.modifiedCounts[key, default: 0] += 1
            store.dailyModifiedCount[todayKey, default: 0] += 1
        }
        scheduleSave()
    }

    // MARK: - Metadata

    var totalCount: Int {
        queue.sync { store.counts.values.reduce(0, +) }
    }

    var startedAt: Date {
        queue.sync { store.startedAt }
    }

    /// Reload JSON scalars from disk; resets pending and rolling state.
    func reload() {
        queue.sync {
            load()
            pending = PendingStore()
            lastKeyName = nil
            secondLastKeyName = nil
            alternationStreak = 0
            lastBigramWasHighStrain = false
            // Re-prime today cache
            _todayCacheDate = todayKey
            _todayCount = dailyTotalLocked(for: _todayCacheDate)
        }
    }

    /// Reset all counts to zero.
    func reset() {
        queue.sync {
            store = CountData(startedAt: Date(), counts: [:])
            pending = PendingStore()
            lastKeyName = nil
            secondLastKeyName = nil
            alternationStreak = 0
            lastBigramWasHighStrain = false
            _todayCount = 0
            _todayCacheDate = todayKey
            // Clear SQLite tables
            if let db = dbQueue {
                try? db.write { db in
                    for table in ["daily_keys","daily_bigrams","daily_trigrams",
                                  "daily_apps","daily_devices","hourly_counts",
                                  "bigram_iki","iki_buckets"] {
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

    // MARK: - Persistence (JSON scalars)

    /// Debounces JSON scalar writes: schedules a save 2 seconds after the last call.
    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.save() }
        saveWorkItem = item
        queue.asyncAfter(deadline: .now() + 2.0, execute: item)
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(store) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(CountData.self, from: data) {
            store = decoded
        }
    }
}
