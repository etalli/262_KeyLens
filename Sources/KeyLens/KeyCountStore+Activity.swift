import Foundation
import KeyLensCore

// MARK: - Activity & frequency queries
// Read-only queries for keystroke counts, distributions, and n-gram frequencies.

extension KeyCountStore {

    /// Today's top limit keys sorted descending.
    func todayTopKeys(limit: Int = 10) -> [(key: String, count: Int)] {
        queue.sync {
            (store.dailyCounts[todayKey] ?? [:])
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { ($0.key, $0.value) }
        }
    }

    /// Today's total keystroke count.
    var todayCount: Int {
        queue.sync { store.dailyCounts[todayKey]?.values.reduce(0, +) ?? 0 }
    }

    /// Hourly keystroke counts for a given date (24-element array, index = hour 0–23).
    func hourlyCounts(for date: String) -> [Int] {
        queue.sync {
            (0..<24).map { hour in
                let key = String(format: "%@-%02d", date, hour)
                return store.hourlyCounts[key] ?? 0
            }
        }
    }

    /// Shortcut efficiency for today: shortcuts / (shortcuts + mouse clicks), or nil if no data.
    func shortcutEfficiencyToday() -> Double? {
        queue.sync {
            let shortcuts = store.dailyModifiedCount[todayKey] ?? 0
            let dayCounts = store.dailyCounts[todayKey] ?? [:]
            let mouseClicks = dayCounts.filter { $0.key.hasPrefix("🖱") }.values.reduce(0, +)
            let total = shortcuts + mouseClicks
            guard total > 0 else { return nil }
            return Double(shortcuts) / Double(total) * 100.0
        }
    }

    /// Top modifier+key combos sorted descending. Optional prefix filter (e.g. "⌘").
    func topModifiedKeys(prefix: String = "", limit: Int = 20) -> [(key: String, count: Int)] {
        queue.sync {
            store.modifiedCounts
                .filter { prefix.isEmpty || $0.key.hasPrefix(prefix) }
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { ($0.key, $0.value) }
        }
    }

    /// Top-N keys by cumulative count, sorted descending.
    func topKeys(limit: Int = 10) -> [(key: String, count: Int)] {
        queue.sync {
            store.counts.sorted { $0.value > $1.value }
                        .prefix(limit)
                        .map { ($0.key, $0.value) }
        }
    }

    /// Top-N apps by cumulative keystroke count, sorted descending.
    func topApps(limit: Int = 20) -> [(app: String, count: Int)] {
        queue.sync {
            store.appCounts.sorted { $0.value > $1.value }
                           .prefix(limit)
                           .map { ($0.key, $0.value) }
        }
    }

    /// Top-N devices by cumulative keystroke count, sorted descending.
    func topDevices(limit: Int = 20) -> [(device: String, count: Int)] {
        queue.sync {
            store.deviceCounts.sorted { $0.value > $1.value }
                              .prefix(limit)
                              .map { ($0.key, $0.value) }
        }
    }

    /// Per-app ergonomic scores for apps with at least minKeystrokes total keystrokes.
    func appErgonomicScores(minKeystrokes: Int = 100) -> [(app: String, score: Double, keystrokes: Int)] {
        queue.sync {
            let engine = LayoutRegistry.shared.ergonomicScoreEngine
            return store.appCounts
                .filter { $0.value >= minKeystrokes }
                .compactMap { (app, keystrokes) -> (app: String, score: Double, keystrokes: Int)? in
                    let bigrams = store.appTotalBigramCount[app] ?? 0
                    guard bigrams > 0 else { return nil }
                    let sfRate  = Double(store.appSameFingerCount[app]       ?? 0) / Double(bigrams)
                    let hsRate  = Double(store.appHighStrainBigramCount[app] ?? 0) / Double(bigrams)
                    let altRate = Double(store.appHandAlternationCount[app]  ?? 0) / Double(bigrams)
                    let score = engine.score(
                        sameFingerRate:             sfRate,
                        highStrainRate:             hsRate,
                        thumbImbalanceRatio:        0.0,
                        handAlternationRate:        altRate,
                        thumbEfficiencyCoefficient: 0.0
                    )
                    return (app: app, score: score, keystrokes: keystrokes)
                }
                .sorted { $0.score > $1.score }
        }
    }

    /// Per-device ergonomic scores for devices with at least minKeystrokes total keystrokes.
    func deviceErgonomicScores(minKeystrokes: Int = 100) -> [(device: String, score: Double, keystrokes: Int)] {
        queue.sync {
            let engine = LayoutRegistry.shared.ergonomicScoreEngine
            return store.deviceCounts
                .filter { $0.value >= minKeystrokes }
                .compactMap { (device, keystrokes) -> (device: String, score: Double, keystrokes: Int)? in
                    let bigrams = store.deviceTotalBigramCount[device] ?? 0
                    guard bigrams > 0 else { return nil }
                    let sfRate  = Double(store.deviceSameFingerCount[device]       ?? 0) / Double(bigrams)
                    let hsRate  = Double(store.deviceHighStrainBigramCount[device] ?? 0) / Double(bigrams)
                    let altRate = Double(store.deviceHandAlternationCount[device]  ?? 0) / Double(bigrams)
                    let score = engine.score(
                        sameFingerRate:             sfRate,
                        highStrainRate:             hsRate,
                        thumbImbalanceRatio:        0.0,
                        handAlternationRate:        altRate,
                        thumbEfficiencyCoefficient: 0.0
                    )
                    return (device: device, score: score, keystrokes: keystrokes)
                }
                .sorted { $0.score > $1.score }
        }
    }

    /// Today's top apps sorted descending.
    func todayTopApps(limit: Int = 10) -> [(app: String, count: Int)] {
        queue.sync {
            (store.dailyAppCounts[todayKey] ?? [:])
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { ($0.key, $0.value) }
        }
    }

    /// Today's top devices sorted descending.
    func todayTopDevices(limit: Int = 10) -> [(device: String, count: Int)] {
        queue.sync {
            (store.dailyDeviceCounts[todayKey] ?? [:])
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { ($0.key, $0.value) }
        }
    }

    /// Full cumulative bigram frequency table. Used by ErgonomicSnapshot / LayoutComparison.
    var allBigramCounts: [String: Int] {
        queue.sync { store.bigramCounts }
    }

    /// Full cumulative per-key keystroke counts. Used for thumb imbalance and efficiency metrics.
    var allKeyCounts: [String: Int] {
        queue.sync { store.counts }
    }

    /// Top-N bigrams by cumulative count (Issue #12).
    func topBigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        queue.sync {
            store.bigramCounts.sorted { $0.value > $1.value }
                              .prefix(limit)
                              .map { ($0.key, $0.value) }
        }
    }

    /// Today's top bigrams (Issue #12).
    func todayTopBigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        let today = todayKey
        return queue.sync {
            (store.dailyBigramCounts[today] ?? [:])
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { ($0.key, $0.value) }
        }
    }

    /// Top-N trigrams by cumulative frequency (Issue #12).
    func topTrigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        queue.sync {
            store.trigramCounts.sorted { $0.value > $1.value }
                               .prefix(limit)
                               .map { ($0.key, $0.value) }
        }
    }

    /// Today's top trigrams (Issue #12).
    func todayTopTrigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        let today = todayKey
        return queue.sync {
            (store.dailyTrigramCounts[today] ?? [:])
                .sorted { $0.value > $1.value }
                .prefix(limit)
                .map { ($0.key, $0.value) }
        }
    }

    /// Average IKI (ms) for a bigram. Returns nil if no samples exist (Issue #24).
    func avgBigramIKI(for bigram: String) -> Double? {
        queue.sync {
            guard let count = store.bigramIKICount[bigram], count > 0 else { return nil }
            return store.bigramIKISum[bigram].map { $0 / Double(count) }
        }
    }

    /// All daily totals sorted ascending by date.
    func dailyTotals() -> [(date: String, total: Int)] {
        queue.sync {
            store.dailyCounts
                .map { (date: $0.key, total: $0.value.values.reduce(0, +)) }
                .sorted { $0.date < $1.date }
        }
    }

    /// Per-day keystroke totals for the last N calendar days (oldest first).
    func dailyTotals(last days: Int) -> [(date: String, count: Int)] {
        let cal = Calendar.current
        return queue.sync {
            (0..<days).reversed().compactMap { offset -> (String, Int)? in
                guard let date = cal.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
                let key = Self.dayFormatter.string(from: date)
                let count = store.dailyCounts[key]?.values.reduce(0, +) ?? 0
                return (key, count)
            }
        }
    }

    /// Aggregate hourly keystroke counts across all recorded dates.
    /// Returns a 24-element array where index = hour of day (0–23).
    func hourlyDistribution() -> [Int] {
        queue.sync {
            var result = [Int](repeating: 0, count: 24)
            for (key, count) in store.hourlyCounts {
                // key format: "yyyy-MM-dd-HH"
                let parts = key.split(separator: "-")
                guard parts.count == 4, let hour = Int(parts[3]), hour < 24 else { continue }
                result[hour] += count
            }
            return result
        }
    }

    /// Aggregate total keystrokes by calendar month ("yyyy-MM"), sorted ascending.
    func monthlyTotals() -> [(month: String, total: Int)] {
        queue.sync {
            var monthMap: [String: Int] = [:]
            for (date, keyCounts) in store.dailyCounts {
                guard date.count >= 7 else { continue }
                let month = String(date.prefix(7))
                monthMap[month, default: 0] += keyCounts.values.reduce(0, +)
            }
            return monthMap
                .map { (month: $0.key, total: $0.value) }
                .sorted { $0.month < $1.month }
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
            let dates = Array(store.dailyCounts.keys.sorted().suffix(recentDays))
            var combined: [String: Int] = [:]
            for date in dates {
                for (k, v) in store.dailyCounts[date] ?? [:] {
                    combined[k, default: 0] += v
                }
            }
            let topKeyNames = combined.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
            var result: [(date: String, key: String, count: Int)] = []
            for date in dates {
                let dayCounts = store.dailyCounts[date] ?? [:]
                for key in topKeyNames {
                    result.append((date: date, key: key, count: dayCounts[key] ?? 0))
                }
            }
            return result
        }
    }

    /// All keys sorted by cumulative count descending, including today's count.
    func allEntries() -> [(key: String, total: Int, today: Int)] {
        queue.sync {
            let todayData = store.dailyCounts[todayKey] ?? [:]
            return store.counts.sorted { $0.value > $1.value }
                .map { (key: $0.key, total: $0.value, today: todayData[$0.key] ?? 0) }
        }
    }
}
