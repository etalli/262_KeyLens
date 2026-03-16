import Foundation
import GRDB
import KeyLensCore

// MARK: - Ergonomic queries
// Read-only ergonomic metrics derived from the stored bigram/keystroke data.

extension KeyCountStore {

    /// Average inter-keystroke interval (ms). Returns nil if fewer than 1 sample.
    var averageIntervalMs: Double? {
        queue.sync { store.avgIntervalCount > 0 ? store.avgIntervalMs : nil }
    }

    /// Estimated typing speed in WPM. Based on the standard definition: 1 word = 5 keystrokes.
    var estimatedWPM: Double? {
        guard let ms = averageIntervalMs, ms > 0 else { return nil }
        return 60_000.0 / (ms * 5.0)
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
            store.dailyAvgIntervalMs.compactMap { date, avgMs -> (date: String, wpm: Double)? in
                guard let count = store.dailyAvgIntervalCount[date], count > 0, avgMs > 0 else { return nil }
                return (date, 60_000.0 / (avgMs * 5.0))
            }
            .sorted { $0.date < $1.date }
        }
    }

    /// Today's minimum inter-keystroke interval (ms, ≤1000ms only).
    var todayMinIntervalMs: Double? {
        let key = todayKey
        return queue.sync { store.dailyMinIntervalMs[key] }
    }

    /// Cumulative same-finger bigram rate.
    var sameFingerRate: Double? {
        queue.sync {
            guard store.totalBigramCount > 0 else { return nil }
            return Double(store.sameFingerCount) / Double(store.totalBigramCount)
        }
    }

    /// Today's same-finger bigram rate.
    var todaySameFingerRate: Double? {
        let today = todayKey
        return queue.sync {
            let total = store.dailyTotalBigramCount[today] ?? 0
            guard total > 0 else { return nil }
            return Double(store.dailySameFingerCount[today] ?? 0) / Double(total)
        }
    }

    /// Cumulative hand-alternation rate.
    var handAlternationRate: Double? {
        queue.sync {
            guard store.totalBigramCount > 0 else { return nil }
            return Double(store.handAlternationCount) / Double(store.totalBigramCount)
        }
    }

    /// Today's hand-alternation rate.
    var todayHandAlternationRate: Double? {
        let today = todayKey
        return queue.sync {
            let total = store.dailyTotalBigramCount[today] ?? 0
            guard total > 0 else { return nil }
            return Double(store.dailyHandAlternationCount[today] ?? 0) / Double(total)
        }
    }

    /// Cumulative alternation reward score (Issue #25).
    var alternationRewardScore: Double {
        queue.sync { store.alternationRewardScore }
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
                let bigrams = store.dailyTotalBigramCount[date] ?? 0
                guard bigrams > 0 else { return nil }
                let sf = Double(store.dailySameFingerCount[date]       ?? 0) / Double(bigrams)
                let ha = Double(store.dailyHandAlternationCount[date]  ?? 0) / Double(bigrams)
                let hs = Double(store.dailyHighStrainBigramCount[date] ?? 0) / Double(bigrams)
                return (date: date, sameFingerRate: sf, handAltRate: ha, highStrainRate: hs)
            }
        }
    }

    /// Cumulative high-strain bigram count (Issue #28).
    var highStrainBigramCount: Int {
        queue.sync { store.highStrainBigramCount }
    }

    /// Fraction of all bigrams that are high-strain.
    var highStrainBigramRate: Double? {
        queue.sync {
            guard store.totalBigramCount > 0 else { return nil }
            return Double(store.highStrainBigramCount) / Double(store.totalBigramCount)
        }
    }

    /// Cumulative high-strain trigram count (Issue #28).
    var highStrainTrigramCount: Int {
        queue.sync { store.highStrainTrigramCount }
    }

    /// Top-N high-strain bigrams by frequency (Issue #28).
    func topHighStrainBigrams(limit: Int = 10) -> [(pair: String, count: Int)] {
        queue.sync {
            let detector = LayoutRegistry.shared.highStrainDetector
            let layout   = LayoutRegistry.shared
            return store.bigramCounts
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
                sfCount:      store.sameFingerCount,
                hsCount:      store.highStrainBigramCount,
                altCount:     store.handAlternationCount,
                bigramCount:  store.totalBigramCount,
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
            let bigrams = store.totalBigramCount
            let hsRate = bigrams > 0 ? Double(store.highStrainBigramCount) / Double(bigrams) : 0.0
            return FatigueRiskModel().analyze(
                currentAvgIntervalMs:   nil,
                baselineAvgIntervalMs:  nil,
                currentHighStrainRate:  hsRate,
                baselineHighStrainRate: 0.02
            )
        }
    }

    /// Per-day ergonomic scores for trend tracking (Issue #29).
    var dailyErgonomicScore: [String: Double] {
        queue.sync {
            var result: [String: Double] = [:]
            for date in allDatesLocked() {
                let bigrams = store.dailyTotalBigramCount[date] ?? 0
                guard bigrams > 0 else { continue }
                result[date] = ergonomicScore(
                    sfCount:     store.dailySameFingerCount[date]       ?? 0,
                    hsCount:     store.dailyHighStrainBigramCount[date] ?? 0,
                    altCount:    store.dailyHandAlternationCount[date]  ?? 0,
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
        let bigrams = queue.sync { store.bigramCounts }
        guard !bigrams.isEmpty else { return [] }

        let layouts: [(name: String, layout: any KeyboardLayout)] = [
            ("QWERTY",  ANSILayout()),
            ("Colemak", ColemakLayout()),
            ("Dvorak",  DvorakLayout()),
        ]

        return layouts.map { layoutName, layout in
            var sfbCount = 0
            var altCount = 0
            var total    = 0

            for (bigramKey, count) in bigrams {
                guard let b     = Bigram.parse(bigramKey),
                      let handA = layout.hand(for: b.from),
                      let handB = layout.hand(for: b.to) else { continue }
                total += count
                if handA != handB {
                    altCount += count
                } else if let fingerA = layout.finger(for: b.from),
                          let fingerB = layout.finger(for: b.to),
                          fingerA == fingerB {
                    sfbCount += count
                }
            }

            let sfbRate = total > 0 ? Double(sfbCount) / Double(total) : 0
            let altRate = total > 0 ? Double(altCount) / Double(total) : 0
            return LayoutEfficiencyEntry(
                name: layoutName,
                sameFingerRate: sfbRate,
                handAlternationRate: altRate,
                totalBigrams: total
            )
        }
        .sorted { $0.handAlternationRate > $1.handAlternationRate }
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
