import Foundation
import GRDB
import KeyLensCore

// MARK: - Activity & frequency queries
// Read-only queries are delegated to KeyMetricsQuery (constructed as a snapshot inside queue.sync).

extension KeyCountStore {

    func todayTopKeys(limit: Int = 10) -> [(key: String, count: Int)] {
        queue.sync { makeQuery().todayTopKeys(limit: limit) }
    }

    var todayCount: Int {
        queue.sync { makeQuery().todayCount }
    }

    func hourlyCounts(for date: String) -> [Int] {
        queue.sync { makeQuery().hourlyCounts(for: date) }
    }

    func shortcutEfficiencyToday() -> Double? {
        queue.sync { makeQuery().shortcutEfficiencyToday() }
    }

    func topModifiedKeys(prefix: String = "", limit: Int = 20) -> [(key: String, count: Int)] {
        queue.sync { makeQuery().topModifiedKeys(prefix: prefix, limit: limit) }
    }

    func topKeys(limit: Int = 10) -> [(key: String, count: Int)] {
        queue.sync { makeQuery().topKeys(limit: limit) }
    }

    func topApps(limit: Int = 20) -> [(app: String, count: Int)] {
        queue.sync { makeQuery().topApps(limit: limit) }
    }

    func topDevices(limit: Int = 20) -> [(device: String, count: Int)] {
        queue.sync { makeQuery().topDevices(limit: limit) }
    }

    func appErgonomicScores(minKeystrokes: Int = 100) -> [(app: String, score: Double, keystrokes: Int)] {
        queue.sync { makeQuery().appErgonomicScores(minKeystrokes: minKeystrokes) }
    }

    func deviceErgonomicScores(minKeystrokes: Int = 100) -> [(device: String, score: Double, keystrokes: Int)] {
        queue.sync { makeQuery().deviceErgonomicScores(minKeystrokes: minKeystrokes) }
    }

    func todayTopApps(limit: Int = 10) -> [(app: String, count: Int)] {
        queue.sync { makeQuery().todayTopApps(limit: limit) }
    }

    func todayTopDevices(limit: Int = 10) -> [(device: String, count: Int)] {
        queue.sync { makeQuery().todayTopDevices(limit: limit) }
    }

    var allBigramCounts: [String: Int] {
        queue.sync { makeQuery().allBigramCounts }
    }

    var allKeyCounts: [String: Int] {
        queue.sync { makeQuery().allKeyCounts }
    }

    func topBigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        queue.sync { makeQuery().topBigrams(limit: limit) }
    }

    func todayTopBigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        queue.sync { makeQuery().todayTopBigrams(limit: limit) }
    }

    func topTrigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        queue.sync { makeQuery().topTrigrams(limit: limit) }
    }

    func todayTopTrigrams(limit: Int = 20) -> [(pair: String, count: Int)] {
        queue.sync { makeQuery().todayTopTrigrams(limit: limit) }
    }

    func avgBigramIKI(for bigram: String) -> Double? {
        queue.sync { makeQuery().avgBigramIKI(for: bigram) }
    }

    func rankedBigramsForTraining(minCount: Int = 5, topK: Int = 10) -> [BigramScore] {
        queue.sync { makeQuery().rankedBigramsForTraining(minCount: minCount, topK: topK) }
    }

    func rankedTrigramsForTraining(minCount: Int = 5, topK: Int = 10) -> [TrigramScore] {
        queue.sync { makeQuery().rankedTrigramsForTraining(minCount: minCount, topK: topK) }
    }

    func allBigramIKI() -> [String: Double] {
        queue.sync { makeQuery().allBigramIKI() }
    }

    func ikiPerFinger() -> [(finger: String, avgIKI: Double)] {
        queue.sync { makeQuery().ikiPerFinger() }
    }

    func keystrokeSharePerFinger() -> [FingerLoadEntry] {
        queue.sync { makeQuery().keystrokeSharePerFinger() }
    }

    func slowestBigrams(minCount: Int = 5, limit: Int = 20) -> [(bigram: String, avgIKI: Double)] {
        queue.sync { makeQuery().slowestBigrams(minCount: minCount, limit: limit) }
    }

    func keyTransitions(
        for key: String,
        minCount: Int = 3,
        limit: Int = 15
    ) -> (incoming: [(bigram: String, avgIKI: Double, count: Int)],
          outgoing: [(bigram: String, avgIKI: Double, count: Int)]) {
        queue.sync { makeQuery().keyTransitions(for: key, minCount: minCount, limit: limit) }
    }

    func dailyTotals() -> [(date: String, total: Int)] {
        queue.sync { makeQuery().dailyTotals() }
    }

    func dailyTotals(forDevice device: String) -> [(date: String, total: Int)] {
        queue.sync { makeQuery().dailyTotals(forDevice: device) }
    }

    func dailyTotals(last days: Int) -> [(date: String, count: Int)] {
        queue.sync { makeQuery().dailyTotals(last: days) }
    }

    func hourlyCountsByDayOfWeek() -> [(weekday: Int, hour: Int, avgCount: Double, avgWPM: Double?)] {
        queue.sync { makeQuery().hourlyCountsByDayOfWeek() }
    }

    func hourlyDistribution() -> [Int] {
        queue.sync { makeQuery().hourlyDistribution() }
    }

    func monthlyTotals() -> [(month: String, total: Int)] {
        queue.sync { makeQuery().monthlyTotals() }
    }

    func countsByType() -> [(type: KeyType, count: Int)] {
        queue.sync { makeQuery().countsByType() }
    }

    func topKeysPerDay(limit: Int = 10, recentDays: Int = 14) -> [(date: String, key: String, count: Int)] {
        queue.sync { makeQuery().topKeysPerDay(limit: limit, recentDays: recentDays) }
    }

    func latestIKIs() -> [(key: String, iki: Double)] {
        queue.sync { makeQuery().latestIKIs() }
    }

    // MARK: - Manual WPM measurement (Issue #150)
    // Write operations remain on KeyCountStore.

    func startWPMMeasurement() {
        queue.sync {
            wpmSessionStart = Date()
            wpmSessionKeystrokes = 0
        }
    }

    func stopWPMMeasurement() -> (wpm: Double, duration: TimeInterval, keystrokes: Int)? {
        queue.sync {
            guard let start = wpmSessionStart else { return nil }
            let duration = Date().timeIntervalSince(start)
            let keystrokes = wpmSessionKeystrokes
            wpmSessionStart = nil
            wpmSessionKeystrokes = 0
            guard duration > 0, keystrokes > 0 else { return nil }
            let wpm = (Double(keystrokes) / 5.0) / (duration / 60.0)
            return (wpm: wpm, duration: duration, keystrokes: keystrokes)
        }
    }

    var isWPMMeasuring: Bool {
        queue.sync { makeQuery().isWPMMeasuring }
    }

    func allEntries() -> [(key: String, total: Int, today: Int)] {
        queue.sync { makeQuery().allEntries() }
    }

    /// Permanently removes a device and all its historical data.
    /// Deletes from in-memory store, pending buffer, and SQLite daily_devices table.
    func deleteDevice(_ device: String) {
        queue.sync {
            store.appTracker.deviceCounts.removeValue(forKey: device)
            for date in pending.dailyDevices.keys {
                pending.dailyDevices[date]?.removeValue(forKey: device)
            }
        }
        guard let db = dbQueue else { return }
        try? db.write { db in
            try db.execute(sql: "DELETE FROM daily_devices WHERE device = ?", arguments: [device])
        }
    }
}
