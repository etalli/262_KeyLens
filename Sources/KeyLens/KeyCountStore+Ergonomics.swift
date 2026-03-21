import Foundation
import GRDB
import KeyLensCore

// MARK: - Ergonomic queries
// Read-only ergonomic metrics derived from the stored bigram/keystroke data.

extension KeyCountStore {

    /// Average inter-keystroke interval (ms). Returns nil if fewer than 1 sample.
    var averageIntervalMs: Double? {
        queue.sync { store.activity.avgIntervalCount > 0 ? store.activity.avgIntervalMs : nil }
    }

    /// Estimated typing speed in WPM. Based on the standard definition: 1 word = 5 keystrokes.
    var estimatedWPM: Double? {
        guard let ms = averageIntervalMs, ms > 0 else { return nil }
        return 60_000.0 / (ms * 5.0)
    }

    /// Rolling WPM from keystrokes in the last `windowSeconds` using the recentIKIs ring buffer.
    /// Returns 0 if no keystroke was received in the last 2 seconds (idle decay).
    func rollingWPM(windowSeconds: Double = 5.0) -> Double {
        queue.sync {
            guard let last = store.activity.lastInputTime,
                  Date().timeIntervalSince(last) <= 1.5 else { return 0.0 }
            let windowMs = windowSeconds * 1000.0
            var totalMs = 0.0
            var count = 0
            for entry in recentIKIs.reversed() {
                guard entry.iki > 0 else { continue }
                guard totalMs + entry.iki <= windowMs else { break }
                totalMs += entry.iki
                count += 1
            }
            guard count > 0, totalMs > 0 else { return 0.0 }
            return Double(count) / 5.0 * (60_000.0 / totalMs)
        }
    }

    /// Cumulative backspace rate: Delete count / total keystrokes × 100 (%).
    var backspaceRate: Double? {
        queue.sync {
            let total = store.counts.values.reduce(0, +)
            guard total > 0 else { return nil }
            return Double(store.counts["Delete", default: 0]) / Double(total) * 100.0
        }
    }

    /// Today's backspace rate (%).
    var todayBackspaceRate: Double? {
        queue.sync {
            let dayCounts = dailyKeyCountsLocked(for: todayKey)
            let total = dayCounts.values.reduce(0, +)
            guard total > 0 else { return nil }
            return Double(dayCounts["Delete", default: 0]) / Double(total) * 100.0
        }
    }

    /// Returns per-day backspace rate sorted ascending. Days with zero keystrokes are excluded.
    func dailyBackspaceRates() -> [(date: String, rate: Double)] {
        queue.sync {
            guard let db = dbQueue else { return [] }
            let today = todayKey
            // Historical dates (before today) via a single SQL aggregation
            var result: [(date: String, rate: Double)] = []
            if let rows = try? db.read({ db in
                try Row.fetchAll(db, sql: """
                    SELECT date,
                           SUM(count) as total,
                           SUM(CASE WHEN key = 'Delete' THEN count ELSE 0 END) as deletes
                    FROM daily_keys WHERE date < ?
                    GROUP BY date HAVING total > 0 ORDER BY date
                    """, arguments: [today])
            }) {
                for row in rows {
                    let total: Int = row["total"]
                    guard total > 0 else { continue }
                    result.append((row["date"], Double(row["deletes"] as Int) / Double(total) * 100.0))
                }
            }
            // Today: merge SQL + pending for accuracy
            let todayCounts = dailyKeyCountsLocked(for: today)
            let todayTotal  = todayCounts.values.reduce(0, +)
            if todayTotal > 0 {
                let bs = todayCounts["Delete", default: 0]
                result.append((today, Double(bs) / Double(todayTotal) * 100.0))
            }
            return result
        }
    }

    /// Returns per-day estimated WPM sorted by date ascending.
    func dailyWPM() -> [(date: String, wpm: Double)] {
        queue.sync {
            store.activity.dailyAvgIntervalMs.compactMap { date, avgMs -> (date: String, wpm: Double)? in
                guard let count = store.activity.dailyAvgIntervalCount[date], count > 0, avgMs > 0 else { return nil }
                return (date, 60_000.0 / (avgMs * 5.0))
            }
            .sorted { $0.date < $1.date }
        }
    }

    /// Today's minimum inter-keystroke interval (ms, ≤1000ms only).
    var todayMinIntervalMs: Double? {
        let key = todayKey
        return queue.sync { store.activity.dailyMinIntervalMs[key] }
    }

    /// Cumulative same-finger bigram rate.
    var sameFingerRate: Double? {
        queue.sync {
            guard store.ergonomics.totalBigramCount > 0 else { return nil }
            return Double(store.ergonomics.sameFingerCount) / Double(store.ergonomics.totalBigramCount)
        }
    }

    /// Today's same-finger bigram rate.
    var todaySameFingerRate: Double? {
        let today = todayKey
        return queue.sync {
            let total = store.ergonomics.dailyTotalBigramCount[today] ?? 0
            guard total > 0 else { return nil }
            return Double(store.ergonomics.dailySameFingerCount[today] ?? 0) / Double(total)
        }
    }

    /// Cumulative hand-alternation rate.
    var handAlternationRate: Double? {
        queue.sync {
            guard store.ergonomics.totalBigramCount > 0 else { return nil }
            return Double(store.ergonomics.handAlternationCount) / Double(store.ergonomics.totalBigramCount)
        }
    }

    /// Today's hand-alternation rate.
    var todayHandAlternationRate: Double? {
        let today = todayKey
        return queue.sync {
            let total = store.ergonomics.dailyTotalBigramCount[today] ?? 0
            guard total > 0 else { return nil }
            return Double(store.ergonomics.dailyHandAlternationCount[today] ?? 0) / Double(total)
        }
    }

    /// Cumulative alternation reward score (Issue #25).
    var alternationRewardScore: Double {
        queue.sync { store.ergonomics.alternationRewardScore }
    }

    /// Cumulative thumb imbalance ratio (Issue #26).
    var thumbImbalanceRatio: Double? {
        queue.sync {
            LayoutRegistry.shared.thumbImbalanceDetector
                .imbalanceRatio(counts: store.counts, layout: LayoutRegistry.shared)
        }
    }

    /// Thumb imbalance ratio for a specific day (Issue #26).
    func dailyThumbImbalance(for date: String) -> Double? {
        queue.sync {
            let dayCounts = dailyKeyCountsLocked(for: date)
            guard !dayCounts.isEmpty else { return nil }
            return LayoutRegistry.shared.thumbImbalanceDetector
                .imbalanceRatio(counts: dayCounts, layout: LayoutRegistry.shared)
        }
    }

    /// Per-day ergonomic rates for Learning Curve visualization (Phase 3).
    func dailyErgonomicRates() -> [(date: String, sameFingerRate: Double, handAltRate: Double, highStrainRate: Double)] {
        queue.sync {
            allDatesLocked().compactMap { date in
                let bigrams = store.ergonomics.dailyTotalBigramCount[date] ?? 0
                guard bigrams > 0 else { return nil }
                let sf = Double(store.ergonomics.dailySameFingerCount[date]       ?? 0) / Double(bigrams)
                let ha = Double(store.ergonomics.dailyHandAlternationCount[date]  ?? 0) / Double(bigrams)
                let hs = Double(store.ergonomics.dailyHighStrainBigramCount[date] ?? 0) / Double(bigrams)
                return (date: date, sameFingerRate: sf, handAltRate: ha, highStrainRate: hs)
            }
        }
    }

    /// Cumulative high-strain bigram count (Issue #28).
    var highStrainBigramCount: Int {
        queue.sync { store.ergonomics.highStrainBigramCount }
    }

    /// Fraction of all bigrams that are high-strain.
    var highStrainBigramRate: Double? {
        queue.sync {
            guard store.ergonomics.totalBigramCount > 0 else { return nil }
            return Double(store.ergonomics.highStrainBigramCount) / Double(store.ergonomics.totalBigramCount)
        }
    }

    /// Cumulative high-strain trigram count (Issue #28).
    var highStrainTrigramCount: Int {
        queue.sync { store.ergonomics.highStrainTrigramCount }
    }

    /// Top-N high-strain bigrams by frequency (Issue #28).
    func topHighStrainBigrams(limit: Int = 10) -> [(pair: String, count: Int)] {
        queue.sync {
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
    }

    /// Thumb efficiency coefficient (Issue #27).
    var thumbEfficiencyCoefficient: Double? {
        queue.sync {
            LayoutRegistry.shared.thumbEfficiencyCalculator
                .coefficient(counts: store.counts, layout: LayoutRegistry.shared)
        }
    }


    /// Unified ergonomic score (0–100) from cumulative keystroke data (Issue #29).
    var currentErgonomicScore: Double {
        queue.sync {
            ergonomicScore(
                sfCount:      store.ergonomics.sameFingerCount,
                hsCount:      store.ergonomics.highStrainBigramCount,
                altCount:     store.ergonomics.handAlternationCount,
                bigramCount:  store.ergonomics.totalBigramCount,
                keyCounts:    store.counts
            )
        }
    }

    /// Inferred typing style based on cumulative data.
    public var currentTypingStyle: TypingStyle {
        queue.sync { TypingStyleAnalyzer().analyze(keyCounts: store.counts) }
    }

    /// Detected fatigue risk level.
    public var currentFatigueLevel: FatigueLevel {
        queue.sync {
            let bigrams = store.ergonomics.totalBigramCount
            let hsRate = bigrams > 0 ? Double(store.ergonomics.highStrainBigramCount) / Double(bigrams) : 0.0
            return FatigueRiskModel().analyze(
                currentAvgIntervalMs:   nil,
                baselineAvgIntervalMs:  nil,
                currentHighStrainRate:  hsRate,
                baselineHighStrainRate: 0.02
            )
        }
    }

    /// Per-hour fatigue curve for today (Issue #63).
    ///
    /// Returns hourly WPM and ergonomic rates, merging persisted SQLite data with
    /// any pending in-memory slices. Hours with no data are omitted.
    func todayHourlyFatigueCurve() -> [HourlyFatigueEntry] {
        let today = todayKey
        return queue.sync {
            var slices: [Int: (ikiSum: Double, ikiCount: Int, ergTotal: Int, ergSF: Int, ergHS: Int)] = [:]

            // Load persisted data from SQLite
            if let db = dbQueue,
               let rows = try? db.read({ db in
                   try Row.fetchAll(db,
                       sql: "SELECT hour, iki_sum, iki_count, erg_total, erg_sf, erg_hs FROM hourly_ergonomics WHERE date = ?",
                       arguments: [today])
               }) {
                for row in rows {
                    let h: Int = row["hour"]
                    slices[h] = (row["iki_sum"], row["iki_count"], row["erg_total"], row["erg_sf"], row["erg_hs"])
                }
            }

            // Merge pending (current session, not yet flushed)
            for (h, sl) in pending.hourlySlices[today, default: [:]] {
                let e = slices[h] ?? (0, 0, 0, 0, 0)
                slices[h] = (e.ikiSum   + sl.ikiSum,   e.ikiCount + sl.ikiCount,
                             e.ergTotal + sl.ergTotal, e.ergSF    + sl.ergSF,
                             e.ergHS    + sl.ergHS)
            }

            return slices.compactMap { hour, s -> HourlyFatigueEntry? in
                guard s.ikiCount > 0 || s.ergTotal > 0 else { return nil }
                let wpm: Double? = s.ikiCount > 0
                    ? 60_000.0 / ((s.ikiSum / Double(s.ikiCount)) * 5.0)
                    : nil
                let sfRate: Double? = s.ergTotal > 0 ? Double(s.ergSF) / Double(s.ergTotal) : nil
                let hsRate: Double? = s.ergTotal > 0 ? Double(s.ergHS) / Double(s.ergTotal) : nil
                return HourlyFatigueEntry(id: hour, hour: hour, wpm: wpm, sameFingerRate: sfRate, highStrainRate: hsRate)
            }
            .sorted { $0.hour < $1.hour }
        }
    }

    /// Per-day ergonomic scores for trend tracking (Issue #29).
    var dailyErgonomicScore: [String: Double] {
        queue.sync {
            var result: [String: Double] = [:]
            for date in allDatesLocked() {
                let bigrams = store.ergonomics.dailyTotalBigramCount[date] ?? 0
                guard bigrams > 0 else { continue }
                result[date] = ergonomicScore(
                    sfCount:     store.ergonomics.dailySameFingerCount[date]       ?? 0,
                    hsCount:     store.ergonomics.dailyHighStrainBigramCount[date] ?? 0,
                    altCount:    store.ergonomics.dailyHandAlternationCount[date]  ?? 0,
                    bigramCount: bigrams,
                    keyCounts:   dailyKeyCountsLocked(for: date)
                )
            }
            return result
        }
    }
}

// MARK: - Issue #61: Layout Efficiency Scores

extension KeyCountStore {

    /// Computes same-finger bigram rate and hand-alternation rate for QWERTY, Colemak, and Dvorak,
    /// applied to the user's actual all-time bigram frequency distribution.
    ///
    /// Allows the user to see how their real typing patterns would perform across layouts without
    /// needing to type on each layout or export data to an external tool.
    ///
    /// - Returns: One entry per layout, sorted by hand-alternation rate descending (best first).
    func layoutEfficiencyScores() -> [LayoutEfficiencyEntry] {
        let (bigrams, keyCounts) = queue.sync { (store.ergonomics.bigramCounts, store.counts) }
        guard !bigrams.isEmpty else { return [] }

        let layouts: [(name: String, layout: any KeyboardLayout)] = [
            ("QWERTY",  ANSILayout()),
            ("Colemak", ColemakLayout()),
            ("Dvorak",  DvorakLayout()),
        ]

        return layouts.map { layoutName, layout in
            let simRegistry = LayoutRegistry.forSimulation(layout: layout)
            let snapshot    = ErgonomicSnapshot.capture(
                bigramCounts: bigrams,
                keyCounts:    keyCounts,
                layout:       simRegistry
            )
            return LayoutEfficiencyEntry(
                name:               layoutName,
                sameFingerRate:     snapshot.sameFingerRate,
                handAlternationRate: snapshot.handAlternationRate,
                ergonomicScore:     snapshot.ergonomicScore,
                travelDistance:     snapshot.estimatedTravelDistance,
                totalBigrams:       bigrams.values.reduce(0, +)
            )
        }
        .sorted { $0.ergonomicScore > $1.ergonomicScore }
    }
}

// MARK: - Private helpers

extension KeyCountStore {

    /// Computes a unified ergonomic score (0–100) from raw bigram counters.
    /// Must be called from inside `queue.sync`.
    func ergonomicScore(
        sfCount:     Int,
        hsCount:     Int,
        altCount:    Int,
        bigramCount: Int,
        keyCounts:   [String: Int]? = nil
    ) -> Double {
        guard bigramCount > 0 else { return 100.0 }
        let engine = LayoutRegistry.shared.ergonomicScoreEngine
        let layout = LayoutRegistry.shared
        let tiRatio = keyCounts.flatMap {
            layout.thumbImbalanceDetector.imbalanceRatio(counts: $0, layout: layout)
        } ?? 0.0
        let teCoeff = keyCounts.flatMap {
            layout.thumbEfficiencyCalculator.coefficient(counts: $0, layout: layout)
        } ?? 0.0
        return engine.score(
            sameFingerRate:             Double(sfCount)  / Double(bigramCount),
            highStrainRate:             Double(hsCount)  / Double(bigramCount),
            thumbImbalanceRatio:        tiRatio,
            handAlternationRate:        Double(altCount) / Double(bigramCount),
            thumbEfficiencyCoefficient: teCoeff
        )
    }
}
