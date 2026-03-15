import Foundation
import GRDB
import KeyLensCore

// MARK: - Activity & frequency queries
// Read-only queries for keystroke counts, distributions, and n-gram frequencies.

extension KeyCountStore {

    /// Today's top limit keys sorted descending.
    func todayTopKeys(limit: Int = 10) -> [(key: String, count: Int)] {
        queue.sync { topEntries(dailyKeyCountsLocked(for: todayKey), limit: limit) }
    }

    /// Today's total keystroke count (SQLite + pending).
    var todayCount: Int {
        queue.sync { dailyTotalLocked(for: todayKey) }
    }

    /// Hourly keystroke counts for a given date (24-element array, index = hour 0–23).
    func hourlyCounts(for date: String) -> [Int] {
        queue.sync {
            var result = [Int](repeating: 0, count: 24)
            if let db = dbQueue,
               let rows = try? db.read({ db in
                   try Row.fetchAll(db, sql: "SELECT hour, count FROM hourly_counts WHERE date = ?", arguments: [date])
               }) {
                for row in rows {
                    let h: Int = row["hour"]
                    if h < 24 { result[h] += (row["count"] as Int) }
                }
            }
            for (h, v) in pending.hourly[date, default: [:]] where h < 24 { result[h] += v }
            return result
        }
    }

    /// Shortcut efficiency for today: shortcuts / (shortcuts + mouse clicks), or nil if no data.
    func shortcutEfficiencyToday() -> Double? {
        queue.sync {
            let shortcuts = store.dailyModifiedCount[todayKey] ?? 0
            let dayCounts = dailyKeyCountsLocked(for: todayKey)
            let mouseClicks = dayCounts.filter { $0.key.hasPrefix("🖱") }.values.reduce(0, +)
            let total = shortcuts + mouseClicks
            guard total > 0 else { return nil }
            return Double(shortcuts) / Double(total) * 100.0
        }
    }

    /// Top modifier+key combos sorted descending. Optional prefix filter (e.g. "⌘").
    func topModifiedKeys(prefix: String = "", limit: Int = 20) -> [(key: String, count: Int)] {
        queue.sync {
            let filtered = prefix.isEmpty
                ? store.modifiedCounts
                : store.modifiedCounts.filter { $0.key.hasPrefix(prefix) }
            return topEntries(filtered, limit: limit)
        }
    }

    /// Top-N keys by cumulative count, sorted descending.
    func topKeys(limit: Int = 10) -> [(key: String, count: Int)] {
        queue.sync { topEntries(store.counts, limit: limit) }
    }

    /// Top-N apps by cumulative keystroke count, sorted descending.
    func topApps(limit: Int = 20) -> [(app: String, count: Int)] {
        queue.sync { topEntries(store.appCounts, limit: limit) }
    }

    /// Top-N devices by cumulative keystroke count, sorted descending.
    func topDevices(limit: Int = 20) -> [(device: String, count: Int)] {
        queue.sync { topEntries(store.deviceCounts, limit: limit) }
    }

    /// Per-app ergonomic scores for apps with at least minKeystrokes total keystrokes.
    func appErgonomicScores(minKeystrokes: Int = 100) -> [(app: String, score: Double, keystrokes: Int)] {
        queue.sync {
            store.appCounts
                .filter { $0.value >= minKeystrokes }
                .compactMap { (app, keystrokes) -> (app: String, score: Double, keystrokes: Int)? in
                    let bigrams = store.appTotalBigramCount[app] ?? 0
                    guard bigrams > 0 else { return nil }
                    let score = ergonomicScore(
                        sfCount:     store.appSameFingerCount[app]       ?? 0,
                        hsCount:     store.appHighStrainBigramCount[app] ?? 0,
                        altCount:    store.appHandAlternationCount[app]  ?? 0,
                        bigramCount: bigrams
                    )
                    return (app: app, score: score, keystrokes: keystrokes)
                }
                .sorted { $0.score > $1.score }
        }
    }

    /// Per-device ergonomic scores for devices with at least minKeystrokes total keystrokes.
    func deviceErgonomicScores(minKeystrokes: Int = 100) -> [(device: String, score: Double, keystrokes: Int)] {
        queue.sync {
            store.deviceCounts
                .filter { $0.value >= minKeystrokes }
                .compactMap { (device, keystrokes) -> (device: String, score: Double, keystrokes: Int)? in
                    let bigrams = store.deviceTotalBigramCount[device] ?? 0
                    guard bigrams > 0 else { return nil }
                    let score = ergonomicScore(
                        sfCount:     store.deviceSameFingerCount[device]       ?? 0,
                        hsCount:     store.deviceHighStrainBigramCount[device] ?? 0,
                        altCount:    store.deviceHandAlternationCount[device]  ?? 0,
                        bigramCount: bigrams
                    )
                    return (device: device, score: score, keystrokes: keystrokes)
                }
                .sorted { $0.score > $1.score }
        }
    }

    /// Today's top apps sorted descending.
    func todayTopApps(limit: Int = 10) -> [(app: String, count: Int)] {
        let today = todayKey
        return queue.sync {
            var result: [String: Int] = [:]
            if let db = dbQueue,
               let rows = try? db.read({ db in
                   try Row.fetchAll(db, sql: "SELECT app, count FROM daily_apps WHERE date = ?", arguments: [today])
               }) {
                for row in rows { result[row["app"], default: 0] += (row["count"] as Int) }
            }
            for (a, v) in pending.dailyApps[today, default: [:]] { result[a, default: 0] += v }
            return topEntries(result, limit: limit)
        }
    }

    /// Today's top devices sorted descending.
    func todayTopDevices(limit: Int = 10) -> [(device: String, count: Int)] {
        let today = todayKey
        return queue.sync {
            var result: [String: Int] = [:]
            if let db = dbQueue,
               let rows = try? db.read({ db in
                   try Row.fetchAll(db, sql: "SELECT device, count FROM daily_devices WHERE date = ?", arguments: [today])
               }) {
                for row in rows { result[row["device"], default: 0] += (row["count"] as Int) }
            }
            for (d, v) in pending.dailyDevices[today, default: [:]] { result[d, default: 0] += v }
            return topEntries(result, limit: limit)
        }
    }

    /// Full cumulative bigram frequency table. Used by ErgonomicSnapshot / LayoutComparison.
    var allBigramCounts: [String: Int] {
        queue.sync { store.bigramCounts }
    }

    /// Full cumulative per-key keystroke counts.
    var allKeyCounts: [String: Int] {
        queue.sync { store.counts }
    }

    /// Top-N bigrams by cumulative count.
    func topBigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        queue.sync { topEntries(store.bigramCounts, limit: limit) }
    }

    /// Today's top bigrams.
    func todayTopBigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        let today = todayKey
        return queue.sync {
            var result: [String: Int] = [:]
            if let db = dbQueue,
               let rows = try? db.read({ db in
                   try Row.fetchAll(db, sql: "SELECT bigram, count FROM daily_bigrams WHERE date = ?", arguments: [today])
               }) {
                for row in rows { result[row["bigram"], default: 0] += (row["count"] as Int) }
            }
            for (b, v) in pending.dailyBigrams[today, default: [:]] { result[b, default: 0] += v }
            return topEntries(result, limit: limit)
        }
    }

    /// Top-N trigrams by cumulative frequency.
    func topTrigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        queue.sync { topEntries(store.trigramCounts, limit: limit) }
    }

    /// Today's top trigrams.
    func todayTopTrigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        let today = todayKey
        return queue.sync {
            var result: [String: Int] = [:]
            if let db = dbQueue,
               let rows = try? db.read({ db in
                   try Row.fetchAll(db, sql: "SELECT trigram, count FROM daily_trigrams WHERE date = ?", arguments: [today])
               }) {
                for row in rows { result[row["trigram"], default: 0] += (row["count"] as Int) }
            }
            for (t, v) in pending.dailyTrigrams[today, default: [:]] { result[t, default: 0] += v }
            return topEntries(result, limit: limit)
        }
    }

    /// Average IKI (ms) for a bigram. Returns nil if no samples exist (Issue #24).
    func avgBigramIKI(for bigram: String) -> Double? {
        queue.sync {
            var sum: Double = 0
            var count: Int  = 0
            if let db = dbQueue,
               let row = try? db.read({ db in
                   try Row.fetchOne(db, sql: "SELECT iki_sum, iki_count FROM bigram_iki WHERE bigram = ?", arguments: [bigram])
               }) {
                sum   = row["iki_sum"]   ?? 0
                count = row["iki_count"] ?? 0
            }
            if let p = pending.bigramIKI[bigram] { sum += p.sum; count += p.count }
            guard count > 0 else { return nil }
            return sum / Double(count)
        }
    }

    /// Bigrams ranked by training priority (Issue #85).
    ///
    /// Reads all bigram IKI data from SQLite + pending, computes
    /// `BigramScore` for each, and returns the top-k candidates.
    ///
    /// - Parameters:
    ///   - minCount: Minimum observation count to include a bigram (default: 5).
    ///   - topK:     Maximum results returned (default: 10).
    func rankedBigramsForTraining(minCount: Int = 5, topK: Int = 10) -> [BigramScore] {
        queue.sync {
            var merged: [String: (sum: Double, count: Int)] = [:]

            if let db = dbQueue,
               let rows = try? db.read({ db in
                   try Row.fetchAll(db, sql: "SELECT bigram, iki_sum, iki_count FROM bigram_iki")
               }) {
                for row in rows {
                    let key: String = row["bigram"]
                    let sum: Double = row["iki_sum"]
                    let cnt: Int    = row["iki_count"]
                    merged[key] = (sum: sum, count: cnt)
                }
            }

            for (bigram, p) in pending.bigramIKI {
                let e = merged[bigram] ?? (sum: 0, count: 0)
                merged[bigram] = (sum: e.sum + p.sum, count: e.count + p.count)
            }

            let candidates = merged.compactMap { bigram, data -> BigramScore? in
                guard data.count > 0 else { return nil }
                let meanIKI = data.sum / Double(data.count)
                return BigramScore(bigram: bigram, meanIKI: meanIKI, count: data.count)
            }

            return BigramScore.topCandidates(candidates, minCount: minCount, topK: topK)
        }
    }

    /// Average IKI broken down by finger (Issue #104).
    ///
    /// Aggregates `bigram_iki` data by mapping the destination key of each bigram
    /// to its finger via `ANSILayout`. IKI is attributed to the receiving finger —
    /// how fast each finger responds when it is the next key to press.
    ///
    /// - Returns: Array of `(finger, avgIKI)` for fingers with data, sorted slowest-first.
    func ikiPerFinger() -> [(finger: String, avgIKI: Double)] {
        let layout = ANSILayout()
        var perFinger: [String: (sum: Double, count: Int)] = [:]

        queue.sync {
            var merged: [String: (sum: Double, count: Int)] = [:]

            if let db = dbQueue,
               let rows = try? db.read({ db in
                   try Row.fetchAll(db, sql: "SELECT bigram, iki_sum, iki_count FROM bigram_iki")
               }) {
                for row in rows {
                    let key: String = row["bigram"]
                    let sum: Double = row["iki_sum"]
                    let cnt: Int    = row["iki_count"]
                    merged[key] = (sum: sum, count: cnt)
                }
            }
            for (bigram, p) in pending.bigramIKI {
                let e = merged[bigram] ?? (sum: 0, count: 0)
                merged[bigram] = (sum: e.sum + p.sum, count: e.count + p.count)
            }

            for (bigramKey, data) in merged where data.count > 0 {
                guard let bigram = Bigram.parse(bigramKey),
                      let finger = layout.finger(for: bigram.to) else { continue }
                let e = perFinger[finger.rawValue] ?? (sum: 0, count: 0)
                perFinger[finger.rawValue] = (sum: e.sum + data.sum, count: e.count + data.count)
            }
        }

        return perFinger
            .compactMap { finger, data -> (finger: String, avgIKI: Double)? in
                guard data.count > 0 else { return nil }
                return (finger: finger, avgIKI: data.sum / Double(data.count))
            }
            .sorted { $0.avgIKI > $1.avgIKI }
    }

    /// Top N slowest bigrams by average IKI (Issue #103).
    ///
    /// - Parameters:
    ///   - minCount: Minimum observation count; bigrams below this are excluded (default: 5).
    ///   - limit:    Maximum number of results (default: 20).
    /// - Returns: Array of `(bigram, avgIKI)` sorted descending by avg IKI (slowest first).
    func slowestBigrams(minCount: Int = 5, limit: Int = 20) -> [(bigram: String, avgIKI: Double)] {
        queue.sync {
            var merged: [String: (sum: Double, count: Int)] = [:]

            if let db = dbQueue,
               let rows = try? db.read({ db in
                   try Row.fetchAll(db, sql: "SELECT bigram, iki_sum, iki_count FROM bigram_iki")
               }) {
                for row in rows {
                    let key: String = row["bigram"]
                    let sum: Double = row["iki_sum"]
                    let cnt: Int    = row["iki_count"]
                    merged[key] = (sum: sum, count: cnt)
                }
            }

            for (bigram, p) in pending.bigramIKI {
                let e = merged[bigram] ?? (sum: 0, count: 0)
                merged[bigram] = (sum: e.sum + p.sum, count: e.count + p.count)
            }

            return merged
                .compactMap { bigram, data -> (bigram: String, avgIKI: Double)? in
                    guard data.count >= minCount else { return nil }
                    return (bigram: bigram, avgIKI: data.sum / Double(data.count))
                }
                .sorted { $0.avgIKI > $1.avgIKI }
                .prefix(limit)
                .map { $0 }
        }
    }

    /// All daily totals sorted ascending by date.
    func dailyTotals() -> [(date: String, total: Int)] {
        queue.sync {
            guard let db = dbQueue else { return [] }
            var map: [String: Int] = [:]
            if let rows = try? db.read({ db in
                try Row.fetchAll(db, sql: "SELECT date, SUM(count) as total FROM daily_keys GROUP BY date ORDER BY date")
            }) {
                for row in rows { map[row["date"], default: 0] = (row["total"] as Int) }
            }
            for (date, keys) in pending.dailyKeys { map[date, default: 0] += keys.values.reduce(0, +) }
            return map.sorted { $0.key < $1.key }.map { (date: $0.key, total: $0.value) }
        }
    }

    /// Per-day keystroke totals for the last N calendar days (oldest first).
    func dailyTotals(last days: Int) -> [(date: String, count: Int)] {
        let cal = Calendar.current
        let cutoffDate = cal.date(byAdding: .day, value: -(days - 1), to: Date()) ?? Date()
        return queue.sync {
            guard let db = dbQueue else { return [] }
            let cutoff = Self.dayFormatter.string(from: cutoffDate)
            var map: [String: Int] = [:]
            if let rows = try? db.read({ db in
                try Row.fetchAll(db, sql: """
                    SELECT date, SUM(count) as total FROM daily_keys WHERE date >= ? GROUP BY date
                    """, arguments: [cutoff])
            }) {
                for row in rows { map[row["date"], default: 0] = (row["total"] as Int) }
            }
            for (date, keys) in pending.dailyKeys where date >= cutoff {
                map[date, default: 0] += keys.values.reduce(0, +)
            }
            return (0..<days).reversed().compactMap { offset -> (String, Int)? in
                guard let date = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
                let key = Self.dayFormatter.string(from: date)
                return (key, map[key] ?? 0)
            }
        }
    }

    /// Aggregate hourly keystroke counts across all recorded dates.
    func hourlyDistribution() -> [Int] {
        queue.sync {
            var result = [Int](repeating: 0, count: 24)
            if let db = dbQueue,
               let rows = try? db.read({ db in
                   try Row.fetchAll(db, sql: "SELECT hour, SUM(count) as total FROM hourly_counts GROUP BY hour")
               }) {
                for row in rows {
                    let h: Int = row["hour"]
                    if h < 24 { result[h] += (row["total"] as Int) }
                }
            }
            for (_, hours) in pending.hourly { for (h, v) in hours where h < 24 { result[h] += v } }
            return result
        }
    }

    /// Aggregate total keystrokes by calendar month ("yyyy-MM"), sorted ascending.
    func monthlyTotals() -> [(month: String, total: Int)] {
        queue.sync {
            guard let db = dbQueue else { return [] }
            var map: [String: Int] = [:]
            if let rows = try? db.read({ db in
                try Row.fetchAll(db, sql: """
                    SELECT SUBSTR(date,1,7) as month, SUM(count) as total
                    FROM daily_keys GROUP BY month ORDER BY month
                    """)
            }) {
                for row in rows { map[row["month"], default: 0] = (row["total"] as Int) }
            }
            for (date, keys) in pending.dailyKeys {
                guard date.count >= 7 else { continue }
                let month = String(date.prefix(7))
                map[month, default: 0] += keys.values.reduce(0, +)
            }
            return map.sorted { $0.key < $1.key }.map { (month: $0.key, total: $0.value) }
        }
    }

    /// Keystroke counts broken down by KeyType, sorted descending.
    func countsByType() -> [(type: KeyType, count: Int)] {
        queue.sync {
            var totals: [KeyType: Int] = [:]
            for (key, count) in store.counts {
                totals[KeyType.classify(key), default: 0] += count
            }
            return KeyType.allCases
                .compactMap { t in totals[t].map { (type: t, count: $0) } }
                .filter { $0.count > 0 }
                .sorted { $0.count > $1.count }
        }
    }

    /// Top limit keys per day over the most recent recentDays days.
    func topKeysPerDay(limit: Int = 10, recentDays: Int = 14) -> [(date: String, key: String, count: Int)] {
        queue.sync {
            guard let db = dbQueue else { return [] }
            let cal = Calendar.current
            let cutoffDate = cal.date(byAdding: .day, value: -recentDays, to: Date()) ?? Date()
            let cutoff = Self.dayFormatter.string(from: cutoffDate)

            // Load all rows in range
            var dateMap: [String: [String: Int]] = [:]
            if let rows = try? db.read({ db in
                try Row.fetchAll(db, sql: "SELECT date, key, count FROM daily_keys WHERE date >= ? ORDER BY date", arguments: [cutoff])
            }) {
                for row in rows {
                    dateMap[row["date"], default: [:]][row["key"], default: 0] += (row["count"] as Int)
                }
            }
            for (date, keys) in pending.dailyKeys where date >= cutoff {
                for (k, v) in keys { dateMap[date, default: [:]][k, default: 0] += v }
            }

            // Compute top keys across the range
            var combined: [String: Int] = [:]
            for (_, keys) in dateMap { for (k, v) in keys { combined[k, default: 0] += v } }
            let topKeyNames = topEntries(combined, limit: limit).map { $0.0 }

            let dates = Array(dateMap.keys.sorted().suffix(recentDays))
            var result: [(date: String, key: String, count: Int)] = []
            for date in dates {
                let dayCounts = dateMap[date] ?? [:]
                for key in topKeyNames {
                    result.append((date: date, key: key, count: dayCounts[key] ?? 0))
                }
            }
            return result
        }
    }

    /// Last N IKI values from the live ring buffer (main-thread safe snapshot).
    func latestIKIs() -> [(key: String, iki: Double)] {
        queue.sync { recentIKIs }
    }

    /// All keys sorted by cumulative count descending, including today's count.
    func allEntries() -> [(key: String, total: Int, today: Int)] {
        queue.sync {
            let todayData = dailyKeyCountsLocked(for: todayKey)
            return store.counts.sorted { $0.value > $1.value }
                .map { (key: $0.key, total: $0.value, today: todayData[$0.key] ?? 0) }
        }
    }
}

// MARK: - Private helpers

extension KeyCountStore {

    /// Returns the top-N entries from a [String: Int] dictionary, sorted by value descending.
    /// Must be called from inside `queue.sync`.
    func topEntries(_ dict: [String: Int], limit: Int) -> [(String, Int)] {
        dict.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }
}
