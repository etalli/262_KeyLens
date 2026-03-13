import AppKit
import Foundation
import KeyLensCore
import UserNotifications

// MARK: - Data model

/// All persisted data. startedAt records when tracking began.
/// 永続化するデータ全体。startedAt でいつから記録を開始したかを保持する
struct CountData: Codable {
    var startedAt: Date
    var counts: [String: Int]
    var dailyCounts: [String: [String: Int]]   // "yyyy-MM-dd" -> keyName -> count
    var lastInputTime: Date?
    var avgIntervalMs: Double                  // Welford 移動平均（単位: ms）
    var avgIntervalCount: Int                  // 平均の標本数
    var modifiedCounts: [String: Int]          // "⌘c", "⇧a" など修飾キー+キー組み合わせ
    var dailyMinIntervalMs: [String: Double]   // "yyyy-MM-dd" -> 当日の最小入力間隔（ms, 1000ms以内のみ）
    // Daily Welford average interval tracking (Issue #59 Phase 2) — for per-day WPM chart
    // 日別 Welford 平均間隔（日別 WPM チャート用）
    var dailyAvgIntervalMs:    [String: Double] // "yyyy-MM-dd" -> daily Welford avg interval (ms)
    var dailyAvgIntervalCount: [String: Int]    // "yyyy-MM-dd" -> daily Welford sample count
    // Same-finger bigram tracking (Issue #16)
    var sameFingerCount: Int                   // Cumulative same-finger consecutive pairs
    var totalBigramCount: Int                  // Cumulative consecutive pairs (denominator)
    var dailySameFingerCount: [String: Int]    // "yyyy-MM-dd" -> same-finger pairs that day
    var dailyTotalBigramCount: [String: Int]   // "yyyy-MM-dd" -> total pairs that day
    // Hand alternation tracking (Issue #17)
    var handAlternationCount: Int              // Cumulative hand-alternating pairs
    var dailyHandAlternationCount: [String: Int] // "yyyy-MM-dd" -> alternating pairs that day
    // Hourly keystroke counts (Issue #18) — key: "yyyy-MM-dd-HH", value: total keystrokes
    // Retention: entries older than 365 days are pruned on load.
    var hourlyCounts: [String: Int]
    // Bigram frequency table (Issue #12) — key: "a→s", value: cumulative count
    var bigramCounts: [String: Int]
    // Daily bigram frequency — "yyyy-MM-dd" -> pair -> count
    var dailyBigramCounts: [String: [String: Int]]
    // Bigram IKI accumulation (Issue #24)
    var bigramIKISum: [String: Double]   // "a→s" -> cumulative IKI sum (ms)
    var bigramIKICount: [String: Int]    // "a→s" -> number of IKI samples
    // Alternation reward accumulation (Issue #25)
    var alternationRewardScore: Double   // cumulative reward score
    // High-strain sequence tracking (Issue #28)
    var highStrainBigramCount: Int               // cumulative high-strain bigrams
    var dailyHighStrainBigramCount: [String: Int] // "yyyy-MM-dd" -> count
    var highStrainTrigramCount: Int               // cumulative high-strain trigrams
    var dailyHighStrainTrigramCount: [String: Int] // "yyyy-MM-dd" -> count
    // General trigram frequency table (Issue #12)
    var trigramCounts: [String: Int]
    // Daily trigram frequency — "yyyy-MM-dd" -> trigram -> count
    var dailyTrigramCounts: [String: [String: Int]]
    // Per-application keystroke counts — appName -> total count
    var appCounts: [String: Int]
    // Daily per-application keystroke counts — "yyyy-MM-dd" -> appName -> count
    var dailyAppCounts: [String: [String: Int]]
    // Per-device keystroke counts — deviceLabel -> total count
    var deviceCounts: [String: Int]
    // Daily per-device keystroke counts — "yyyy-MM-dd" -> deviceLabel -> count
    var dailyDeviceCounts: [String: [String: Int]]
    // Per-application bigram tracking for ergonomic score computation
    var appSameFingerCount:      [String: Int]
    var appTotalBigramCount:     [String: Int]
    var appHandAlternationCount: [String: Int]
    var appHighStrainBigramCount: [String: Int]
    // Per-device bigram tracking for ergonomic score computation
    var deviceSameFingerCount:      [String: Int]
    var deviceTotalBigramCount:     [String: Int]
    var deviceHandAlternationCount: [String: Int]
    var deviceHighStrainBigramCount: [String: Int]
    // Daily shortcut counts (Issue #66) — "yyyy-MM-dd" -> total modifier+key combos that day
    var dailyModifiedCount: [String: Int]

    enum CodingKeys: String, CodingKey {
        case startedAt, counts, dailyCounts
        case lastInputTime, avgIntervalMs, avgIntervalCount
        case modifiedCounts, dailyMinIntervalMs
        case dailyAvgIntervalMs, dailyAvgIntervalCount
        case sameFingerCount, totalBigramCount
        case dailySameFingerCount, dailyTotalBigramCount
        case handAlternationCount, dailyHandAlternationCount
        case hourlyCounts
        case bigramCounts, dailyBigramCounts
        case bigramIKISum, bigramIKICount
        case alternationRewardScore
        case highStrainBigramCount, dailyHighStrainBigramCount
        case highStrainTrigramCount, dailyHighStrainTrigramCount
        case trigramCounts, dailyTrigramCounts
        case appCounts, dailyAppCounts
        case deviceCounts, dailyDeviceCounts
        case appSameFingerCount, appTotalBigramCount
        case appHandAlternationCount, appHighStrainBigramCount
        case deviceSameFingerCount, deviceTotalBigramCount
        case deviceHandAlternationCount, deviceHighStrainBigramCount
        case dailyModifiedCount
    }

    init(startedAt: Date, counts: [String: Int], dailyCounts: [String: [String: Int]]) {
        self.startedAt = startedAt
        self.counts = counts
        self.dailyCounts = dailyCounts
        self.lastInputTime = nil
        self.avgIntervalMs = 0
        self.avgIntervalCount = 0
        self.modifiedCounts = [:]
        self.dailyMinIntervalMs = [:]
        self.dailyAvgIntervalMs    = [:]
        self.dailyAvgIntervalCount = [:]
        self.sameFingerCount = 0
        self.totalBigramCount = 0
        self.dailySameFingerCount = [:]
        self.dailyTotalBigramCount = [:]
        self.handAlternationCount = 0
        self.dailyHandAlternationCount = [:]
        self.hourlyCounts = [:]
        self.bigramCounts = [:]
        self.dailyBigramCounts = [:]
        self.bigramIKISum = [:]
        self.bigramIKICount = [:]
        self.alternationRewardScore = 0
        self.highStrainBigramCount = 0
        self.dailyHighStrainBigramCount = [:]
        self.highStrainTrigramCount = 0
        self.dailyHighStrainTrigramCount = [:]
        self.trigramCounts = [:]
        self.dailyTrigramCounts = [:]
        self.appCounts = [:]
        self.dailyAppCounts = [:]
        self.deviceCounts = [:]
        self.dailyDeviceCounts = [:]
        self.appSameFingerCount = [:]
        self.appTotalBigramCount = [:]
        self.appHandAlternationCount = [:]
        self.appHighStrainBigramCount = [:]
        self.deviceSameFingerCount = [:]
        self.deviceTotalBigramCount = [:]
        self.deviceHandAlternationCount = [:]
        self.deviceHighStrainBigramCount = [:]
        self.dailyModifiedCount = [:]
    }

    /// Migration from legacy formats and backward-compatible decode for new fields.
    /// 旧フォーマットからのマイグレーション。新フィールドはデフォルト値で開始。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        counts    = try c.decode([String: Int].self, forKey: .counts)
        dailyCounts = (try? c.decode([String: [String: Int]].self, forKey: .dailyCounts)) ?? [:]
        lastInputTime   = try? c.decode(Date.self, forKey: .lastInputTime)
        avgIntervalMs   = (try? c.decode(Double.self, forKey: .avgIntervalMs)) ?? 0
        avgIntervalCount = (try? c.decode(Int.self, forKey: .avgIntervalCount)) ?? 0
        modifiedCounts  = (try? c.decode([String: Int].self, forKey: .modifiedCounts)) ?? [:]
        dailyMinIntervalMs    = (try? c.decode([String: Double].self, forKey: .dailyMinIntervalMs)) ?? [:]
        dailyAvgIntervalMs    = (try? c.decode([String: Double].self, forKey: .dailyAvgIntervalMs))    ?? [:]
        dailyAvgIntervalCount = (try? c.decode([String: Int].self,    forKey: .dailyAvgIntervalCount)) ?? [:]
        sameFingerCount  = (try? c.decode(Int.self, forKey: .sameFingerCount))  ?? 0
        totalBigramCount = (try? c.decode(Int.self, forKey: .totalBigramCount)) ?? 0
        dailySameFingerCount  = (try? c.decode([String: Int].self, forKey: .dailySameFingerCount))  ?? [:]
        dailyTotalBigramCount = (try? c.decode([String: Int].self, forKey: .dailyTotalBigramCount)) ?? [:]
        handAlternationCount      = (try? c.decode(Int.self, forKey: .handAlternationCount))          ?? 0
        dailyHandAlternationCount = (try? c.decode([String: Int].self, forKey: .dailyHandAlternationCount)) ?? [:]
        hourlyCounts = (try? c.decode([String: Int].self, forKey: .hourlyCounts)) ?? [:]
        bigramCounts = (try? c.decode([String: Int].self, forKey: .bigramCounts)) ?? [:]
        dailyBigramCounts = (try? c.decode([String: [String: Int]].self, forKey: .dailyBigramCounts)) ?? [:]
        bigramIKISum   = (try? c.decode([String: Double].self, forKey: .bigramIKISum))  ?? [:]
        bigramIKICount = (try? c.decode([String: Int].self,    forKey: .bigramIKICount)) ?? [:]
        alternationRewardScore = (try? c.decode(Double.self, forKey: .alternationRewardScore)) ?? 0
        highStrainBigramCount        = (try? c.decode(Int.self,            forKey: .highStrainBigramCount))        ?? 0
        dailyHighStrainBigramCount   = (try? c.decode([String: Int].self,  forKey: .dailyHighStrainBigramCount))   ?? [:]
        highStrainTrigramCount       = (try? c.decode(Int.self,            forKey: .highStrainTrigramCount))       ?? 0
        dailyHighStrainTrigramCount  = (try? c.decode([String: Int].self,  forKey: .dailyHighStrainTrigramCount))  ?? [:]
        trigramCounts      = (try? c.decode([String: Int].self,           forKey: .trigramCounts))      ?? [:]
        dailyTrigramCounts = (try? c.decode([String: [String: Int]].self, forKey: .dailyTrigramCounts)) ?? [:]
        appCounts      = (try? c.decode([String: Int].self,            forKey: .appCounts))      ?? [:]
        dailyAppCounts = (try? c.decode([String: [String: Int]].self, forKey: .dailyAppCounts)) ?? [:]
        deviceCounts      = (try? c.decode([String: Int].self,            forKey: .deviceCounts))      ?? [:]
        dailyDeviceCounts = (try? c.decode([String: [String: Int]].self, forKey: .dailyDeviceCounts)) ?? [:]
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

/// Singleton that manages keystroke counts and persists them to a JSON file.
/// キーごとのカウントを管理し、JSONファイルに永続化するシングルトン
final class KeyCountStore {
    static let shared = KeyCountStore()

    // Internal so extension files in this target can access them.
    var store: CountData
    let queue = DispatchQueue(label: "com.keycounter.store")

    let saveURL: URL
    private var saveWorkItem: DispatchWorkItem?

    // In-memory only: last key pressed, used for same-finger bigram detection.
    private var lastKeyName: String?
    // In-memory only: second-to-last key pressed, used for trigram rolling window (Issue #12).
    private var secondLastKeyName: String?
    // In-memory only: whether the previous bigram was high-strain (Issue #28).
    private var lastBigramWasHighStrain: Bool = false
    // In-memory only: consecutive hand-alternating pair count for streak detection (Issue #25).
    private var alternationStreak: Int = 0

    // In-memory ring buffer: last 20 IKI values (key + interval ms, ≤1000ms only).
    // Readable from extension files; writable only from this file.
    private(set) var recentIKIs: [(key: String, iki: Double)] = []
    private let recentIKICapacity = 20

    private init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyLens")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        saveURL = dir.appendingPathComponent("counts.json")
        store = CountData(startedAt: Date(), counts: [:], dailyCounts: [:])
        load()
    }

    /// Notification interval (persisted in UserDefaults, default 1000).
    static var milestoneInterval: Int {
        get { let v = UserDefaults.standard.integer(forKey: "milestoneInterval"); return v > 0 ? v : 1000 }
        set { UserDefaults.standard.set(newValue, forKey: "milestoneInterval") }
    }

    // MARK: - Date helpers (internal for use by extension files)

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HH"
        return f
    }()

    var todayKey: String { Self.dayFormatter.string(from: Date()) }
    var currentHourKey: String { Self.hourFormatter.string(from: Date()) }

    // MARK: - Mutation

    /// Increment count by 1. Returns (newCount, isMilestone).
    /// カウントを1増やす。milestoneInterval の倍数に達したら milestone = true を返す
    func increment(key: String, at timestamp: Date = Date(), appName: String? = nil) -> (count: Int, milestone: Bool) {
        let today = todayKey
        let hourKey = currentHourKey
        let deviceName = LayoutRegistry.shared.currentDeviceLabel
        let count: Int = queue.sync {
            store.counts[key, default: 0] += 1
            store.dailyCounts[today, default: [:]][key, default: 0] += 1
            // Hourly count (Issue #18)
            store.hourlyCounts[hourKey, default: 0] += 1
            // Per-application count
            if let app = appName {
                store.appCounts[app, default: 0] += 1
                store.dailyAppCounts[today, default: [:]][app, default: 0] += 1
            }
            store.deviceCounts[deviceName, default: 0] += 1
            store.dailyDeviceCounts[today, default: [:]][deviceName, default: 0] += 1

            // Save previous timestamp before updating — needed for per-bigram IKI below.
            let prevInputTime = store.lastInputTime

            // Welford's online algorithm: only intervals ≤1000ms contribute to average and min.
            if let last = store.lastInputTime {
                let intervalMs = timestamp.timeIntervalSince(last) * 1000
                if intervalMs <= 1000 {
                    // Global Welford update
                    store.avgIntervalCount += 1
                    store.avgIntervalMs += (intervalMs - store.avgIntervalMs) / Double(store.avgIntervalCount)
                    // Daily min interval
                    if intervalMs < (store.dailyMinIntervalMs[today] ?? Double.infinity) {
                        store.dailyMinIntervalMs[today] = intervalMs
                    }
                    // Daily Welford update (Issue #59 Phase 2)
                    let dc = store.dailyAvgIntervalCount[today, default: 0] + 1
                    store.dailyAvgIntervalCount[today] = dc
                    let prevAvg = store.dailyAvgIntervalMs[today, default: 0.0]
                    store.dailyAvgIntervalMs[today] = prevAvg + (intervalMs - prevAvg) / Double(dc)
                    // Live IKI ring buffer (capped at recentIKICapacity)
                    recentIKIs.append((key: key, iki: intervalMs))
                    if recentIKIs.count > recentIKICapacity { recentIKIs.removeFirst() }
                }
            }
            store.lastInputTime = timestamp

            // Same-finger bigram detection (Issue #16)
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
                // Hand alternation detection (Issue #17) + reward accumulation (Issue #25)
                if prevHand != curHand {
                    store.handAlternationCount += 1
                    store.dailyHandAlternationCount[today, default: 0] += 1
                    alternationStreak += 1
                    store.alternationRewardScore +=
                        layout.alternationRewardModel.reward(forStreak: alternationStreak)
                } else {
                    alternationStreak = 0
                }
                // Raw bigram pair frequency (Issue #12)
                let pair = "\(prev)→\(key)"
                store.bigramCounts[pair, default: 0] += 1
                store.dailyBigramCounts[today, default: [:]][pair, default: 0] += 1
                // Bigram IKI accumulation (Issue #24)
                if let prevTime = prevInputTime {
                    let iki = timestamp.timeIntervalSince(prevTime) * 1000
                    if iki <= 1000 {
                        store.bigramIKISum[pair, default: 0]   += iki
                        store.bigramIKICount[pair, default: 0] += 1
                    }
                }
                // High-strain sequence detection (Issue #28)
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
                // Per-app bigram ergonomic tracking
                if let app = appName {
                    store.appTotalBigramCount[app, default: 0] += 1
                    if prevFinger == curFinger && prevHand == curHand {
                        store.appSameFingerCount[app, default: 0] += 1
                    }
                    if prevHand != curHand {
                        store.appHandAlternationCount[app, default: 0] += 1
                    }
                    if highStrain {
                        store.appHighStrainBigramCount[app, default: 0] += 1
                    }
                }
                store.deviceTotalBigramCount[deviceName, default: 0] += 1
                if prevFinger == curFinger && prevHand == curHand {
                    store.deviceSameFingerCount[deviceName, default: 0] += 1
                }
                if prevHand != curHand {
                    store.deviceHandAlternationCount[deviceName, default: 0] += 1
                }
                if highStrain {
                    store.deviceHighStrainBigramCount[deviceName, default: 0] += 1
                }
                // General trigram frequency (Issue #12) — 3-key rolling window.
                if let prev2 = secondLastKeyName {
                    let trigram = "\(prev2)→\(prev)→\(key)"
                    store.trigramCounts[trigram, default: 0] += 1
                    store.dailyTrigramCounts[today, default: [:]][trigram, default: 0] += 1
                }
                secondLastKeyName = prev
            } else {
                // Chain broken (unmapped key / mouse click) — reset trigram window.
                secondLastKeyName = nil
            }
            lastKeyName = key

            // Daily goal notification check (Issue #69)
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

    /// Date tracking began.
    var startedAt: Date {
        queue.sync { store.startedAt }
    }

    /// Reload data from disk — call after externally replacing counts.json.
    func reload() {
        queue.sync {
            load()
            lastKeyName = nil
            secondLastKeyName = nil
            alternationStreak = 0
            lastBigramWasHighStrain = false
        }
    }

    /// Reset all counts and start date to now.
    func reset() {
        queue.sync {
            store = CountData(startedAt: Date(), counts: [:], dailyCounts: [:])
            lastKeyName = nil
            secondLastKeyName = nil
            alternationStreak = 0
            lastBigramWasHighStrain = false
        }
        scheduleSave()
    }

    // MARK: - Daily Goal & Streak

    private static let dailyGoalKey    = "dailyGoalCount"
    private static let goalNotifiedKey = "goalNotifiedDate"

    /// Daily keystroke goal. 0 = off. Persisted in UserDefaults.
    var dailyGoal: Int {
        get { UserDefaults.standard.integer(forKey: Self.dailyGoalKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.dailyGoalKey) }
    }

    /// Inner streak calculation — must be called inside queue.sync.
    private func streakLocked(goal: Int) -> Int {
        var streak = 0
        let cal = Calendar.current
        var date = Date()
        for _ in 0..<365 {
            let key = Self.dayFormatter.string(from: date)
            let count = store.dailyCounts[key]?.values.reduce(0, +) ?? 0
            if count >= goal {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
                date = prev
            } else {
                break
            }
        }
        return streak
    }

    /// Current streak: consecutive days (including today if goal met) where daily total >= dailyGoal.
    func currentStreak() -> Int {
        let goal = dailyGoal
        guard goal > 0 else { return 0 }
        return queue.sync { streakLocked(goal: goal) }
    }

    /// Fires a one-per-day notification when today's goal is first crossed. Called inside queue.sync.
    private func checkGoalNotificationLocked(todayStr: String) {
        let goal = dailyGoal
        guard goal > 0 else { return }
        let notified = UserDefaults.standard.string(forKey: Self.goalNotifiedKey)
        guard notified != todayStr else { return }
        let todayTotal = store.dailyCounts[todayStr]?.values.reduce(0, +) ?? 0
        guard todayTotal >= goal else { return }
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

    // MARK: - Persistence

    /// Debounces disk writes: schedules a save 2 seconds after the last call.
    /// 2秒以内の連続呼び出しをまとめて1回の書き込みに集約する
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
        if var decoded = try? decoder.decode(CountData.self, from: data) {
            // Retention policy (Issue #18): prune hourlyCounts entries older than 365 days.
            if let cutoffDate = Calendar.current.date(byAdding: .day, value: -365, to: Date()) {
                let cutoff = Self.dayFormatter.string(from: cutoffDate)
                decoded.hourlyCounts = decoded.hourlyCounts.filter { $0.key.prefix(10) >= cutoff }
            }
            store = decoded
        }
    }
}
