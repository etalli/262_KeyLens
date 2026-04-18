import Foundation
import GRDB
import KeyLensCore

// MARK: - KeyMetricsQuery
// Immutable snapshot of KeyCountStore data for read-only queries.
// Always constructed inside KeyCountStore.queue.sync via KeyCountStore.makeQuery().
// All methods operate on the captured snapshot — no locking needed.

struct KeyMetricsQuery {
    let store: CountData
    let pending: PendingStore
    let dbQueue: DatabaseQueue?
    let recentIKIs: [(key: String, iki: Double)]
    let rhythmIKIs: [Double]
    let todayKey: String
    let wpmSessionStart: Date?
}

// MARK: - Private helpers

private extension KeyMetricsQuery {

    func topEntries(_ dict: [String: Int], limit: Int) -> [(String, Int)] {
        dict.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    func dailyKeyCounts(for date: String) -> [String: Int] {
        var result: [String: Int] = [:]
        if let db = dbQueue,
           let rows = try? db.read({ db in
               try Row.fetchAll(db, sql: "SELECT key, count FROM daily_keys WHERE date = ?", arguments: [date])
           }) {
            for row in rows { result[row["key"], default: 0] += (row["count"] as Int) }
        }
        for (k, v) in pending.dailyKeys[date, default: [:]] { result[k, default: 0] += v }
        return result
    }

    func dailyTotal(for date: String) -> Int {
        var total = 0
        if let db = dbQueue {
            total = (try? db.read { db in
                try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(count),0) FROM daily_keys WHERE date = ?",
                                 arguments: [date])
            }) ?? 0
        }
        total += pending.dailyKeys[date, default: [:]].values.reduce(0, +)
        return total
    }

    func allDates() -> [String] {
        guard let db = dbQueue else { return [] }
        return (try? db.read { db in
            try String.fetchAll(db, sql: "SELECT DISTINCT date FROM daily_keys ORDER BY date")
        }) ?? []
    }

    func mergedBigramIKI() -> [String: (sum: Double, count: Int)] {
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
    }
}

// MARK: - Activity queries

extension KeyMetricsQuery {

    func todayTopKeys(limit: Int = 10) -> [(key: String, count: Int)] {
        topEntries(dailyKeyCounts(for: todayKey), limit: limit)
    }

    var todayCount: Int {
        dailyTotal(for: todayKey)
    }

    func hourlyCounts(for date: String) -> [Int] {
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

    func shortcutEfficiencyToday() -> Double? {
        let shortcuts = store.shortcuts.dailyModifiedCount[todayKey] ?? 0
        let dayCounts = dailyKeyCounts(for: todayKey)
        let mouseClicks = dayCounts.filter { $0.key.hasPrefix("🖱") }.values.reduce(0, +)
        let total = shortcuts + mouseClicks
        guard total > 0 else { return nil }
        return Double(shortcuts) / Double(total) * 100.0
    }

    func topModifiedKeys(prefix: String = "", limit: Int = 20) -> [(key: String, count: Int)] {
        let filtered = prefix.isEmpty
            ? store.shortcuts.modifiedCounts
            : store.shortcuts.modifiedCounts.filter { $0.key.hasPrefix(prefix) }
        return topEntries(filtered, limit: limit)
    }

    // Issue #334: modifier key press counts broken down by finger assignment.
    // Uses LayoutRegistry.finger(for:) so ThumbClusterConfig overrides are respected.
    // Counts are derived from modifiedCounts (combo strings like "⌘t", "⌃h")
    // because modifier keypresses are not stored as individual keystrokes in keyCounts.
    func modifierFingerBreakdown() -> [ModifierFingerEntry] {
        let registry  = LayoutRegistry.shared
        let modCounts = store.shortcuts.modifiedCounts

        // (symbol in combo string, display label, canonical key name for finger lookup)
        let modifiers: [(symbol: String, displayLabel: String, keyName: String)] = [
            ("⌘", "⌘ Cmd",    "⌘Cmd"),
            ("⇧", "⇧ Shift",  "⇧Shift"),
            ("⌥", "⌥ Option", "⌥Option"),
            ("⌃", "⌃ Ctrl",   "⌃Ctrl"),
        ]

        return modifiers.compactMap { (symbol, displayLabel, keyName) -> ModifierFingerEntry? in
            // Sum counts of all combos that contain this modifier symbol
            let count = modCounts.reduce(0) { acc, pair in
                pair.key.contains(symbol) ? acc + pair.value : acc
            }
            guard let finger = registry.finger(for: keyName) else { return nil }
            let isThumb = finger == .thumb
            return ModifierFingerEntry(
                id:           displayLabel,
                displayLabel: displayLabel,
                keyName:      keyName,
                fingerLabel:  Self.fingerLabel(finger),
                isThumb:      isThumb,
                count:        count
            )
        }
    }

    // Issue #335: same-hand shortcut strain analysis.
    // A chord is "strained" when both the modifier and base key are on the same hand,
    // requiring one hand to stretch across two keys simultaneously.
    // (Same-finger is physically impossible for chords; same-hand is the actual ergonomic concern.)
    // Returns same-hand entries sorted by count, plus total presses across all combos.
    func shortcutStrainEntries() -> (entries: [ShortcutStrainEntry], totalPresses: Int) {
        let registry  = LayoutRegistry.shared
        let modCounts = store.shortcuts.modifiedCounts
        let totalPresses = modCounts.values.reduce(0, +)

        let modifierSymbols = ["⌘", "⇧", "⌥", "⌃"]
        let modifierKeyNames: [String: String] = [
            "⌘": "⌘Cmd", "⇧": "⇧Shift", "⌥": "⌥Option", "⌃": "⌃Ctrl"
        ]

        var result: [ShortcutStrainEntry] = []

        for (combo, count) in modCounts {
            // Strip leading modifier symbols to find the base key
            var remaining = combo
            var mods: [String] = []
            var changed = true
            while changed {
                changed = false
                for sym in modifierSymbols {
                    if remaining.hasPrefix(sym) {
                        mods.append(sym)
                        remaining = String(remaining.dropFirst(sym.count))
                        changed = true
                        break
                    }
                }
            }
            let baseKey = remaining
            guard !baseKey.isEmpty, !mods.isEmpty else { continue }
            guard let keyHand = registry.hand(for: baseKey) else { continue }

            // Flag if any modifier is on the same hand as the base key
            for sym in mods {
                guard let modKeyName = modifierKeyNames[sym],
                      let modHand    = registry.hand(for: modKeyName),
                      modHand == keyHand else { continue }
                result.append(ShortcutStrainEntry(id: combo, combo: combo, count: count))
                break  // one match per combo is enough
            }
        }

        let sorted = result.sorted { $0.count > $1.count }
        return (sorted, totalPresses)
    }

    // Shared finger label helper
    private static func fingerLabel(_ finger: Finger) -> String {
        switch finger {
        case .thumb:  return "Thumb"
        case .pinky:  return "Pinky"
        case .ring:   return "Ring"
        case .middle: return "Middle"
        case .index:  return "Index"
        }
    }

    func topKeys(limit: Int = 10) -> [(key: String, count: Int)] {
        topEntries(store.counts, limit: limit)
    }

    func topApps(limit: Int = 20) -> [(app: String, count: Int)] {
        topEntries(store.appTracker.appCounts, limit: limit)
    }

    func topDevices(limit: Int = 20) -> [(device: String, count: Int)] {
        topEntries(store.appTracker.deviceCounts, limit: limit)
    }

    func appErgonomicScores(minKeystrokes: Int = 100) -> [(app: String, score: Double, keystrokes: Int)] {
        store.appTracker.appCounts
            .filter { $0.value >= minKeystrokes }
            .compactMap { (app, keystrokes) -> (app: String, score: Double, keystrokes: Int)? in
                let bigrams = store.appTracker.appTotalBigramCount[app] ?? 0
                guard bigrams > 0 else { return nil }
                let score = KeyMetricsComputation.ergonomicScore(
                    sfCount:     store.appTracker.appSameFingerCount[app]       ?? 0,
                    hsCount:     store.appTracker.appHighStrainBigramCount[app] ?? 0,
                    altCount:    store.appTracker.appHandAlternationCount[app]  ?? 0,
                    bigramCount: bigrams
                )
                return (app: app, score: score, keystrokes: keystrokes)
            }
            .sorted { $0.score > $1.score }
    }

    func deviceErgonomicScores(minKeystrokes: Int = 100) -> [(device: String, score: Double, keystrokes: Int)] {
        store.appTracker.deviceCounts
            .filter { $0.value >= minKeystrokes }
            .compactMap { (device, keystrokes) -> (device: String, score: Double, keystrokes: Int)? in
                let bigrams = store.appTracker.deviceTotalBigramCount[device] ?? 0
                guard bigrams > 0 else { return nil }
                let score = KeyMetricsComputation.ergonomicScore(
                    sfCount:     store.appTracker.deviceSameFingerCount[device]       ?? 0,
                    hsCount:     store.appTracker.deviceHighStrainBigramCount[device] ?? 0,
                    altCount:    store.appTracker.deviceHandAlternationCount[device]  ?? 0,
                    bigramCount: bigrams
                )
                return (device: device, score: score, keystrokes: keystrokes)
            }
            .sorted { $0.score > $1.score }
    }

    func todayTopApps(limit: Int = 10) -> [(app: String, count: Int)] {
        var result: [String: Int] = [:]
        if let db = dbQueue,
           let rows = try? db.read({ db in
               try Row.fetchAll(db, sql: "SELECT app, count FROM daily_apps WHERE date = ?", arguments: [todayKey])
           }) {
            for row in rows { result[row["app"], default: 0] += (row["count"] as Int) }
        }
        for (a, v) in pending.dailyApps[todayKey, default: [:]] { result[a, default: 0] += v }
        return topEntries(result, limit: limit)
    }

    func todayTopDevices(limit: Int = 10) -> [(device: String, count: Int)] {
        var result: [String: Int] = [:]
        if let db = dbQueue,
           let rows = try? db.read({ db in
               try Row.fetchAll(db, sql: "SELECT device, count FROM daily_devices WHERE date = ?", arguments: [todayKey])
           }) {
            for row in rows { result[row["device"], default: 0] += (row["count"] as Int) }
        }
        for (d, v) in pending.dailyDevices[todayKey, default: [:]] { result[d, default: 0] += v }
        return topEntries(result, limit: limit)
    }

    var allBigramCounts: [String: Int] {
        store.ergonomics.bigramCounts
    }

    var allKeyCounts: [String: Int] {
        store.counts
    }

    func topBigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        topEntries(store.ergonomics.bigramCounts, limit: limit)
    }

    func todayTopBigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        var result: [String: Int] = [:]
        if let db = dbQueue,
           let rows = try? db.read({ db in
               try Row.fetchAll(db, sql: "SELECT bigram, count FROM daily_bigrams WHERE date = ?", arguments: [todayKey])
           }) {
            for row in rows { result[row["bigram"], default: 0] += (row["count"] as Int) }
        }
        for (b, v) in pending.dailyBigrams[todayKey, default: [:]] { result[b, default: 0] += v }
        return topEntries(result, limit: limit)
    }

    func topTrigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        topEntries(store.ergonomics.trigramCounts, limit: limit)
    }

    func todayTopTrigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        var result: [String: Int] = [:]
        if let db = dbQueue,
           let rows = try? db.read({ db in
               try Row.fetchAll(db, sql: "SELECT trigram, count FROM daily_trigrams WHERE date = ?", arguments: [todayKey])
           }) {
            for row in rows { result[row["trigram"], default: 0] += (row["count"] as Int) }
        }
        for (t, v) in pending.dailyTrigrams[todayKey, default: [:]] { result[t, default: 0] += v }
        return topEntries(result, limit: limit)
    }

    func avgBigramIKI(for bigram: String) -> Double? {
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

    func rankedBigramsForTraining(minCount: Int = 5, topK: Int = 10) -> [BigramScore] {
        let merged = mergedBigramIKI()
        let candidates = merged.compactMap { bigram, data -> BigramScore? in
            guard data.count > 0 else { return nil }
            let meanIKI = data.sum / Double(data.count)
            return BigramScore(bigram: bigram, meanIKI: meanIKI, count: data.count)
        }
        return BigramScore.topCandidates(candidates, minCount: minCount, topK: topK)
    }

    func rankedTrigramsForTraining(minCount: Int = 5, topK: Int = 10) -> [TrigramScore] {
        let bigramMeanIKI: [String: Double] = mergedBigramIKI().compactMapValues { data -> Double? in
            guard data.count > 0 else { return nil }
            return data.sum / Double(data.count)
        }

        var counts: [String: Int] = store.ergonomics.trigramCounts
        for (_, dayMap) in pending.dailyTrigrams {
            for (t, v) in dayMap { counts[t, default: 0] += v }
        }

        let candidates: [TrigramScore] = counts.compactMap { trigram, count -> TrigramScore? in
            guard let t = Trigram.parse(trigram),
                  let ikiAB = bigramMeanIKI[t.leadingBigram],
                  let ikiBC = bigramMeanIKI[t.trailingBigram]
            else { return nil }
            return TrigramScore(trigram: trigram, estimatedIKI: ikiAB + ikiBC, count: count)
        }
        return TrigramScore.topCandidates(candidates, minCount: minCount, topK: topK)
    }

    func allBigramIKI() -> [String: Double] {
        mergedBigramIKI().compactMapValues { data -> Double? in
            guard data.count > 0 else { return nil }
            return data.sum / Double(data.count)
        }
    }

    func ikiPerFinger() -> [(finger: String, avgIKI: Double)] {
        let layout = ANSILayout()
        var perFinger: [String: (sum: Double, count: Int)] = [:]
        for (bigramKey, data) in mergedBigramIKI() where data.count > 0 {
            guard let bigram = Bigram.parse(bigramKey),
                  let finger = layout.finger(for: bigram.to) else { continue }
            let e = perFinger[finger.rawValue] ?? (sum: 0, count: 0)
            perFinger[finger.rawValue] = (sum: e.sum + data.sum, count: e.count + data.count)
        }
        return perFinger
            .compactMap { finger, data -> (finger: String, avgIKI: Double)? in
                guard data.count > 0 else { return nil }
                return (finger: finger, avgIKI: data.sum / Double(data.count))
            }
            .sorted { $0.avgIKI > $1.avgIKI }
    }

    func slowestBigrams(minCount: Int = 5, limit: Int = 20) -> [(bigram: String, avgIKI: Double)] {
        mergedBigramIKI()
            .compactMap { bigram, data -> (bigram: String, avgIKI: Double)? in
                guard data.count >= minCount else { return nil }
                return (bigram: bigram, avgIKI: data.sum / Double(data.count))
            }
            .sorted { $0.avgIKI > $1.avgIKI }
            .prefix(limit)
            .map { $0 }
    }

    func keyTransitions(
        for key: String,
        minCount: Int = 3,
        limit: Int = 15
    ) -> (incoming: [(bigram: String, avgIKI: Double, count: Int)],
          outgoing: [(bigram: String, avgIKI: Double, count: Int)]) {
        let merged = mergedBigramIKI()

        func toEntry(_ kv: (key: String, value: (sum: Double, count: Int)))
            -> (bigram: String, avgIKI: Double, count: Int)? {
            guard kv.value.count >= minCount else { return nil }
            return (bigram: kv.key, avgIKI: kv.value.sum / Double(kv.value.count), count: kv.value.count)
        }

        let incoming = merged
            .filter { $0.key.hasSuffix("→\(key)") }
            .compactMap { toEntry($0) }
            .sorted { $0.avgIKI > $1.avgIKI }
            .prefix(limit).map { $0 }

        let outgoing = merged
            .filter { $0.key.hasPrefix("\(key)→") }
            .compactMap { toEntry($0) }
            .sorted { $0.avgIKI > $1.avgIKI }
            .prefix(limit).map { $0 }

        return (incoming: incoming, outgoing: outgoing)
    }

    func dailyTotals() -> [(date: String, total: Int)] {
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

    func dailyTotals(forDevice device: String) -> [(date: String, total: Int)] {
        guard let db = dbQueue else { return [] }
        var map: [String: Int] = [:]
        if let rows = try? db.read({ db in
            try Row.fetchAll(db, sql: """
                SELECT date, SUM(count) as total FROM daily_devices
                WHERE device = ? GROUP BY date ORDER BY date
                """, arguments: [device])
        }) {
            for row in rows { map[row["date"], default: 0] = (row["total"] as Int) }
        }
        for (date, devices) in pending.dailyDevices {
            if let count = devices[device] { map[date, default: 0] += count }
        }
        return map.sorted { $0.key < $1.key }.map { (date: $0.key, total: $0.value) }
    }

    func dailyTotals(last days: Int) -> [(date: String, count: Int)] {
        let cal = Calendar.current
        let cutoffDate = cal.date(byAdding: .day, value: -(days - 1), to: Date()) ?? Date()
        guard let db = dbQueue else { return [] }
        let cutoff = KeyCountStore.dayFormatter.string(from: cutoffDate)
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
            let key = KeyCountStore.dayFormatter.string(from: date)
            return (key, map[key] ?? 0)
        }
    }

    func hourlyCountsByDayOfWeek() -> [(weekday: Int, hour: Int, avgCount: Double, avgWPM: Double?)] {
        var sums = [Int: [Int: Int]]()
        var days = [Int: Set<String>]()
        // iki_sum / iki_count per (weekday, hour) for WPM computation
        var ikiSums   = [Int: [Int: Double]]()
        var ikiCounts = [Int: [Int: Int]]()

        if let db = dbQueue {
            // Keystroke counts
            if let rows = try? db.read({ db in
                try Row.fetchAll(db, sql: """
                    SELECT date,
                           CAST(strftime('%w', date) AS INTEGER) AS weekday,
                           hour,
                           count
                    FROM hourly_counts
                    """)
            }) {
                for row in rows {
                    let date: String = row["date"]
                    let wd: Int      = row["weekday"]
                    let h: Int       = row["hour"]
                    let c: Int       = row["count"]
                    guard h < 24 else { continue }
                    sums[wd, default: [:]][h, default: 0] += c
                    days[wd, default: []].insert(date)
                }
            }
            // WPM data from hourly_ergonomics
            if let rows = try? db.read({ db in
                try Row.fetchAll(db, sql: """
                    SELECT date,
                           CAST(strftime('%w', date) AS INTEGER) AS weekday,
                           hour, iki_sum, iki_count
                    FROM hourly_ergonomics
                    WHERE iki_count > 0
                    """)
            }) {
                for row in rows {
                    let wd: Int      = row["weekday"]
                    let h: Int       = row["hour"]
                    let s: Double    = row["iki_sum"]
                    let n: Int       = row["iki_count"]
                    guard h < 24 else { continue }
                    ikiSums[wd, default: [:]][h, default: 0.0] += s
                    ikiCounts[wd, default: [:]][h, default: 0] += n
                }
            }
        }

        let cal = Calendar.current
        for (date, hours) in pending.hourly {
            guard let d = KeyCountStore.dayFormatter.date(from: date) else { continue }
            let wd = cal.component(.weekday, from: d) - 1
            days[wd, default: []].insert(date)
            for (h, v) in hours where h < 24 {
                sums[wd, default: [:]][h, default: 0] += v
            }
        }
        // Merge pending hourly IKI slices
        for (date, slices) in pending.hourlySlices {
            guard let d = KeyCountStore.dayFormatter.date(from: date) else { continue }
            let wd = cal.component(.weekday, from: d) - 1
            for (h, sl) in slices where h < 24 && sl.ikiCount > 0 {
                ikiSums[wd, default: [:]][h, default: 0.0]  += sl.ikiSum
                ikiCounts[wd, default: [:]][h, default: 0]  += sl.ikiCount
            }
        }

        var result: [(weekday: Int, hour: Int, avgCount: Double, avgWPM: Double?)] = []
        for wd in 0..<7 {
            let dayCount = days[wd]?.count ?? 0
            for h in 0..<24 {
                let sum    = sums[wd]?[h] ?? 0
                let avg    = dayCount > 0 ? Double(sum) / Double(dayCount) : 0.0
                let ikiSum = ikiSums[wd]?[h] ?? 0
                let ikiN   = ikiCounts[wd]?[h] ?? 0
                let wpm: Double? = ikiN > 0
                    ? KeyMetricsComputation.wpm(avgIntervalMs: ikiSum / Double(ikiN))
                    : nil
                result.append((weekday: wd, hour: h, avgCount: avg, avgWPM: wpm))
            }
        }
        return result
    }

    func hourlyDistribution() -> [Int] {
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

    func monthlyTotals() -> [(month: String, total: Int)] {
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
            map[String(date.prefix(7)), default: 0] += keys.values.reduce(0, +)
        }
        return map.sorted { $0.key < $1.key }.map { (month: $0.key, total: $0.value) }
    }

    func countsByType() -> [(type: KeyType, count: Int)] {
        var totals: [KeyType: Int] = [:]
        for (key, count) in store.counts {
            totals[KeyType.classify(key), default: 0] += count
        }
        return KeyType.allCases
            .compactMap { t in totals[t].map { (type: t, count: $0) } }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    func topKeysPerDay(limit: Int = 10, recentDays: Int = 14) -> [(date: String, key: String, count: Int)] {
        guard let db = dbQueue else { return [] }
        let cal = Calendar.current
        let cutoffDate = cal.date(byAdding: .day, value: -recentDays, to: Date()) ?? Date()
        let cutoff = KeyCountStore.dayFormatter.string(from: cutoffDate)

        var dateMap: [String: [String: Int]] = [:]
        if let rows = try? db.read({ db in
            try Row.fetchAll(db, sql: "SELECT date, key, count FROM daily_keys WHERE date >= ? ORDER BY date",
                             arguments: [cutoff])
        }) {
            for row in rows {
                dateMap[row["date"], default: [:]][row["key"], default: 0] += (row["count"] as Int)
            }
        }
        for (date, keys) in pending.dailyKeys where date >= cutoff {
            for (k, v) in keys { dateMap[date, default: [:]][k, default: 0] += v }
        }

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

    func latestIKIs() -> [(key: String, iki: Double)] { recentIKIs }

    var isWPMMeasuring: Bool { wpmSessionStart != nil }

    func allEntries() -> [(key: String, total: Int, today: Int)] {
        let todayData = dailyKeyCounts(for: todayKey)
        return store.counts.sorted { $0.value > $1.value }
            .map { (key: $0.key, total: $0.value, today: todayData[$0.key] ?? 0) }
    }
}

// MARK: - Ergonomic queries

extension KeyMetricsQuery {

    var averageIntervalMs: Double? {
        store.activity.avgIntervalCount > 0 ? store.activity.avgIntervalMs : nil
    }

    var estimatedWPM: Double? {
        guard let ms = averageIntervalMs, ms > 0 else { return nil }
        return KeyMetricsComputation.wpm(avgIntervalMs: ms)
    }

    func rollingWPM(windowSeconds: Double = 5.0) -> Double {
        guard let last = store.activity.lastInputTime,
              Date().timeIntervalSince(last) <= AppConfiguration.wpmIdleDecaySecs else { return 0.0 }
        let windowMs = windowSeconds * 1000.0
        var totalMs = 0.0
        var count = 0
        for entry in recentIKIs.reversed() {
            // Skip IKIs below 30 ms (~2000 KPM) — these are key-repeat or system artifacts.
            guard entry.iki >= 30 else { continue }
            guard totalMs + entry.iki <= windowMs else { break }
            totalMs += entry.iki
            count += 1
        }
        guard count > 0, totalMs > 0 else { return 0.0 }
        return KeyMetricsComputation.wpm(avgIntervalMs: totalMs / Double(count))
    }

    var backspaceRate: Double? {
        let total = store.counts.values.reduce(0, +)
        guard total > 0 else { return nil }
        return Double(store.counts["Delete", default: 0]) / Double(total) * 100.0
    }

    var todayBackspaceRate: Double? {
        let dayCounts = dailyKeyCounts(for: todayKey)
        let total = dayCounts.values.reduce(0, +)
        guard total > 0 else { return nil }
        return Double(dayCounts["Delete", default: 0]) / Double(total) * 100.0
    }

    func dailyBackspaceRates() -> [(date: String, rate: Double)] {
        guard let db = dbQueue else { return [] }
        var result: [(date: String, rate: Double)] = []
        if let rows = try? db.read({ db in
            try Row.fetchAll(db, sql: """
                SELECT date,
                       SUM(count) as total,
                       SUM(CASE WHEN key = 'Delete' THEN count ELSE 0 END) as deletes
                FROM daily_keys WHERE date < ?
                GROUP BY date HAVING total > 0 ORDER BY date
                """, arguments: [todayKey])
        }) {
            for row in rows {
                let total: Int = row["total"]
                guard total > 0 else { continue }
                result.append((row["date"], Double(row["deletes"] as Int) / Double(total) * 100.0))
            }
        }
        let todayCounts = dailyKeyCounts(for: todayKey)
        let todayTotal  = todayCounts.values.reduce(0, +)
        if todayTotal > 0 {
            result.append((todayKey, Double(todayCounts["Delete", default: 0]) / Double(todayTotal) * 100.0))
        }
        return result
    }

    func dailyWPM() -> [(date: String, wpm: Double)] {
        store.activity.dailyAvgIntervalMs.compactMap { date, avgMs -> (date: String, wpm: Double)? in
            guard let count = store.activity.dailyAvgIntervalCount[date], count > 0, avgMs > 0 else { return nil }
            return (date, KeyMetricsComputation.wpm(avgIntervalMs: avgMs))
        }
        .sorted { $0.date < $1.date }
    }

    var todayMinIntervalMs: Double? {
        store.activity.dailyMinIntervalMs[todayKey]
    }

    var sameFingerRate: Double? {
        guard store.ergonomics.totalBigramCount > 0 else { return nil }
        return Double(store.ergonomics.sameFingerCount) / Double(store.ergonomics.totalBigramCount)
    }

    var todaySameFingerRate: Double? {
        let total = store.ergonomics.dailyTotalBigramCount[todayKey] ?? 0
        guard total > 0 else { return nil }
        return Double(store.ergonomics.dailySameFingerCount[todayKey] ?? 0) / Double(total)
    }

    var handAlternationRate: Double? {
        guard store.ergonomics.totalBigramCount > 0 else { return nil }
        return Double(store.ergonomics.handAlternationCount) / Double(store.ergonomics.totalBigramCount)
    }

    var todayHandAlternationRate: Double? {
        let total = store.ergonomics.dailyTotalBigramCount[todayKey] ?? 0
        guard total > 0 else { return nil }
        return Double(store.ergonomics.dailyHandAlternationCount[todayKey] ?? 0) / Double(total)
    }

    var alternationRewardScore: Double {
        store.ergonomics.alternationRewardScore
    }

    var thumbImbalanceRatio: Double? {
        LayoutRegistry.shared.thumbImbalanceDetector
            .imbalanceRatio(counts: store.counts, layout: LayoutRegistry.shared)
    }

    func dailyThumbImbalance(for date: String) -> Double? {
        let dayCounts = dailyKeyCounts(for: date)
        guard !dayCounts.isEmpty else { return nil }
        return LayoutRegistry.shared.thumbImbalanceDetector
            .imbalanceRatio(counts: dayCounts, layout: LayoutRegistry.shared)
    }

    func dailyErgonomicRates() -> [(date: String, sameFingerRate: Double, handAltRate: Double, highStrainRate: Double)] {
        allDates().compactMap { date in
            let bigrams = store.ergonomics.dailyTotalBigramCount[date] ?? 0
            guard bigrams > 0 else { return nil }
            let sf = Double(store.ergonomics.dailySameFingerCount[date]       ?? 0) / Double(bigrams)
            let ha = Double(store.ergonomics.dailyHandAlternationCount[date]  ?? 0) / Double(bigrams)
            let hs = Double(store.ergonomics.dailyHighStrainBigramCount[date] ?? 0) / Double(bigrams)
            return (date: date, sameFingerRate: sf, handAltRate: ha, highStrainRate: hs)
        }
    }

    var highStrainBigramCount: Int {
        store.ergonomics.highStrainBigramCount
    }

    var highStrainBigramRate: Double? {
        guard store.ergonomics.totalBigramCount > 0 else { return nil }
        return Double(store.ergonomics.highStrainBigramCount) / Double(store.ergonomics.totalBigramCount)
    }

    var highStrainTrigramCount: Int {
        store.ergonomics.highStrainTrigramCount
    }

    func topHighStrainBigrams(limit: Int = 10) -> [(pair: String, count: Int)] {
        let detector = LayoutRegistry.shared.highStrainDetector
        let layout   = LayoutRegistry.shared
        return store.ergonomics.bigramCounts
            .filter { pair, _ in
                guard let b = Bigram.parse(pair) else { return false }
                return detector.isHighStrain(from: b.from, to: b.to, layout: layout)
            }
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (pair: $0.key, count: $0.value) }
    }

    var thumbEfficiencyCoefficient: Double? {
        LayoutRegistry.shared.thumbEfficiencyCalculator
            .coefficient(counts: store.counts, layout: LayoutRegistry.shared)
    }

    var currentErgonomicScore: Double {
        KeyMetricsComputation.ergonomicScore(
            sfCount:      store.ergonomics.sameFingerCount,
            hsCount:      store.ergonomics.highStrainBigramCount,
            altCount:     store.ergonomics.handAlternationCount,
            bigramCount:  store.ergonomics.totalBigramCount,
            keyCounts:    store.counts
        )
    }

    var currentTypingStyle: TypingStyle {
        TypingStyleAnalyzer().analyze(keyCounts: store.counts)
    }

    var currentTypingRhythm: TypingRhythm {
        TypingRhythmAnalyzer().analyze(ikis: rhythmIKIs)
    }

    var currentFatigueLevel: FatigueLevel {
        let bigrams = store.ergonomics.totalBigramCount
        let hsRate = bigrams > 0 ? Double(store.ergonomics.highStrainBigramCount) / Double(bigrams) : 0.0
        return FatigueRiskModel().analyze(
            currentAvgIntervalMs:   nil,
            baselineAvgIntervalMs:  nil,
            currentHighStrainRate:  hsRate,
            baselineHighStrainRate: 0.02
        )
    }

    func todayHourlyFatigueCurve() -> [HourlyFatigueEntry] {
        var slices: [Int: (ikiSum: Double, ikiCount: Int, ergTotal: Int, ergSF: Int, ergHS: Int)] = [:]

        if let db = dbQueue,
           let rows = try? db.read({ db in
               try Row.fetchAll(db,
                   sql: "SELECT hour, iki_sum, iki_count, erg_total, erg_sf, erg_hs FROM hourly_ergonomics WHERE date = ?",
                   arguments: [todayKey])
           }) {
            for row in rows {
                let h: Int = row["hour"]
                slices[h] = (row["iki_sum"], row["iki_count"], row["erg_total"], row["erg_sf"], row["erg_hs"])
            }
        }

        for (h, sl) in pending.hourlySlices[todayKey, default: [:]] {
            let e = slices[h] ?? (0, 0, 0, 0, 0)
            slices[h] = (e.ikiSum   + sl.ikiSum,   e.ikiCount + sl.ikiCount,
                         e.ergTotal + sl.ergTotal, e.ergSF    + sl.ergSF,
                         e.ergHS    + sl.ergHS)
        }

        return slices.compactMap { hour, s -> HourlyFatigueEntry? in
            guard s.ikiCount > 0 || s.ergTotal > 0 else { return nil }
            let wpm: Double? = s.ikiCount > 0
                ? KeyMetricsComputation.wpm(avgIntervalMs: s.ikiSum / Double(s.ikiCount))
                : nil
            let sfRate: Double? = s.ergTotal > 0 ? Double(s.ergSF) / Double(s.ergTotal) : nil
            let hsRate: Double? = s.ergTotal > 0 ? Double(s.ergHS) / Double(s.ergTotal) : nil
            return HourlyFatigueEntry(id: hour, hour: hour, wpm: wpm, sameFingerRate: sfRate, highStrainRate: hsRate)
        }
        .sorted { $0.hour < $1.hour }
    }

    var dailyErgonomicScore: [String: Double] {
        var result: [String: Double] = [:]
        for date in allDates() {
            let bigrams = store.ergonomics.dailyTotalBigramCount[date] ?? 0
            guard bigrams > 0 else { continue }
            result[date] = KeyMetricsComputation.ergonomicScore(
                sfCount:     store.ergonomics.dailySameFingerCount[date]       ?? 0,
                hsCount:     store.ergonomics.dailyHighStrainBigramCount[date] ?? 0,
                altCount:    store.ergonomics.dailyHandAlternationCount[date]  ?? 0,
                bigramCount: bigrams,
                keyCounts:   dailyKeyCounts(for: date)
            )
        }
        return result
    }

    // MARK: - Layer efficiency (Issue #209)

    /// Returns per-layer-key efficiency summaries using data from LayerMappingStore.
    func layerEfficiency() -> [LayerEfficiencyEntry] {
        let lms = LayerMappingStore.shared
        guard !lms.layerKeys.isEmpty else { return [] }

        // Issue #236: load today's ergonomic stats from SQLite + pending
        var ergStats: [String: (total: Int, sf: Int, ha: Int, hs: Int)] = [:]
        if let db = dbQueue,
           let rows = try? db.read({ db in
               try Row.fetchAll(db, sql: """
                   SELECT layer_key, erg_total, erg_sf, erg_ha, erg_hs
                   FROM daily_layer_ergonomics WHERE date = ?
                   """, arguments: [todayKey])
           }) {
            for row in rows {
                let lk: String = row["layer_key"]
                ergStats[lk] = (
                    total: (row["erg_total"] as Int) + (ergStats[lk]?.total ?? 0),
                    sf:    (row["erg_sf"]    as Int) + (ergStats[lk]?.sf    ?? 0),
                    ha:    (row["erg_ha"]    as Int) + (ergStats[lk]?.ha    ?? 0),
                    hs:    (row["erg_hs"]    as Int) + (ergStats[lk]?.hs    ?? 0)
                )
            }
        }
        for (lk, sl) in pending.layerErgSlices[todayKey, default: [:]] {
            let e = ergStats[lk] ?? (0, 0, 0, 0)
            ergStats[lk] = (e.total + sl.ergTotal, e.sf + sl.ergSF, e.ha + sl.ergHA, e.hs + sl.ergHS)
        }

        return lms.layerKeys.map { layerKey in
            let allTime   = lms.allTimePressCount[layerKey.name] ?? 0
            let todayCount = lms.dailyPressCount[todayKey]?[layerKey.name] ?? 0
            let outputCounts = lms.allTimeOutputCounts[layerKey.name] ?? [:]
            let topCombos = outputCounts
                .sorted { $0.value > $1.value }
                .prefix(5)
                .map { (outputKey: $0.key, count: $0.value) }
            let erg = ergStats[layerKey.name]
            return LayerEfficiencyEntry(
                layerKeyName:      layerKey.name,
                finger:            layerKey.finger,
                pressCount:        todayCount,
                allTimePressCount: allTime,
                topCombos:         topCombos,
                totalBigrams:      erg?.total ?? 0,
                sfCount:           erg?.sf    ?? 0,
                haCount:           erg?.ha    ?? 0,
                hsCount:           erg?.hs    ?? 0
            )
        }
        .sorted { $0.allTimePressCount > $1.allTimePressCount }
    }

    func layoutEfficiencyScores() -> [LayoutEfficiencyEntry] {
        let bigrams   = store.ergonomics.bigramCounts
        let keyCounts = store.counts
        guard !bigrams.isEmpty else { return [] }
        let totalBigrams = bigrams.values.reduce(0, +)

        let templateRaw = UserDefaults.standard.string(forKey: UDKeys.heatmapTemplate) ?? "ANSI"
        let hasKLE = !(UserDefaults.standard.string(forKey: UDKeys.kleCustomLayoutJSON) ?? "").isEmpty
        let userLayoutLabel: String = {
            switch templateRaw {
            case "Custom":              return "Your Layout (Custom)"
            case "Auto" where hasKLE:   return "Your Layout (Custom)"
            case "Ortho":               return "Your Layout (Ortho)"
            case "JIS":                 return "Your Layout (JIS)"
            default:                    return "Your Layout (ANSI)"
            }
        }()

        func makeEntry(name: String, layout: any KeyboardLayout, isUserLayout: Bool = false) -> LayoutEfficiencyEntry {
            let simRegistry = LayoutRegistry.forSimulation(layout: layout)
            let snapshot    = ErgonomicSnapshot.capture(
                bigramCounts: bigrams,
                keyCounts:    keyCounts,
                layout:       simRegistry
            )
            return LayoutEfficiencyEntry(
                name:                name,
                sameFingerRate:      snapshot.sameFingerRate,
                handAlternationRate: snapshot.handAlternationRate,
                ergonomicScore:      snapshot.ergonomicScore,
                travelDistance:      snapshot.estimatedTravelDistance,
                totalBigrams:        totalBigrams,
                isUserLayout:        isUserLayout
            )
        }

        let userEntry = makeEntry(name: userLayoutLabel, layout: ANSILayout(), isUserLayout: true)

        let sorted = [("QWERTY", ANSILayout() as any KeyboardLayout),
                      ("Colemak", ColemakLayout()),
                      ("Dvorak", DvorakLayout())]
            .map { makeEntry(name: $0.0, layout: $0.1) }
            .sorted { $0.ergonomicScore > $1.ergonomicScore }

        return [userEntry] + sorted
    }
}
