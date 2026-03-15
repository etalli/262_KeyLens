import Foundation
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
            let dayCounts = store.dailyCounts[todayKey] ?? [:]
            let total = dayCounts.values.reduce(0, +)
            guard total > 0 else { return nil }
            return Double(dayCounts["Delete", default: 0]) / Double(total) * 100.0
        }
    }

    /// Returns per-day backspace rate sorted ascending. Days with zero keystrokes are excluded.
    func dailyBackspaceRates() -> [(date: String, rate: Double)] {
        queue.sync {
            store.dailyCounts.compactMap { date, dayCounts -> (date: String, rate: Double)? in
                let total = dayCounts.values.reduce(0, +)
                guard total > 0 else { return nil }
                let bs = dayCounts["Delete", default: 0]
                return (date, Double(bs) / Double(total) * 100.0)
            }
            .sorted { $0.date < $1.date }
        }
    }

    /// Returns per-day estimated WPM sorted by date ascending. Only days with accumulated data are included.
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

    /// Cumulative same-finger bigram rate. Returns nil if no bigrams recorded.
    var sameFingerRate: Double? {
        queue.sync {
            guard store.totalBigramCount > 0 else { return nil }
            return Double(store.sameFingerCount) / Double(store.totalBigramCount)
        }
    }

    /// Today's same-finger bigram rate. Returns nil if no bigrams recorded today.
    var todaySameFingerRate: Double? {
        let today = todayKey
        return queue.sync {
            let total = store.dailyTotalBigramCount[today] ?? 0
            guard total > 0 else { return nil }
            let same = store.dailySameFingerCount[today] ?? 0
            return Double(same) / Double(total)
        }
    }

    /// Cumulative hand-alternation rate. Returns nil if no bigrams recorded.
    var handAlternationRate: Double? {
        queue.sync {
            guard store.totalBigramCount > 0 else { return nil }
            return Double(store.handAlternationCount) / Double(store.totalBigramCount)
        }
    }

    /// Today's hand-alternation rate. Returns nil if no bigrams recorded today.
    var todayHandAlternationRate: Double? {
        let today = todayKey
        return queue.sync {
            let total = store.dailyTotalBigramCount[today] ?? 0
            guard total > 0 else { return nil }
            let alt = store.dailyHandAlternationCount[today] ?? 0
            return Double(alt) / Double(total)
        }
    }

    /// Cumulative alternation reward score (Issue #25). Includes streak multiplier bonus.
    var alternationRewardScore: Double {
        queue.sync { store.alternationRewardScore }
    }

    /// Cumulative thumb imbalance ratio (Issue #26). Returns nil if no thumb keystrokes recorded.
    var thumbImbalanceRatio: Double? {
        queue.sync {
            LayoutRegistry.shared.thumbImbalanceDetector
                .imbalanceRatio(counts: store.counts, layout: LayoutRegistry.shared)
        }
    }

    /// Thumb imbalance ratio for a specific day (Issue #26).
    func dailyThumbImbalance(for date: String) -> Double? {
        queue.sync {
            guard let dayCounts = store.dailyCounts[date] else { return nil }
            return LayoutRegistry.shared.thumbImbalanceDetector
                .imbalanceRatio(counts: dayCounts, layout: LayoutRegistry.shared)
        }
    }

    /// Per-day ergonomic rates for Learning Curve visualization (Phase 3).
    /// Returns rows only for dates that have at least one bigram recorded.
    func dailyErgonomicRates() -> [(date: String, sameFingerRate: Double, handAltRate: Double, highStrainRate: Double)] {
        queue.sync {
            store.dailyCounts.keys.sorted().compactMap { date in
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

    /// Fraction of all bigrams that are high-strain. Returns nil if no bigrams recorded.
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

    /// Thumb efficiency coefficient (Issue #27). Returns nil if no keystrokes recorded.
    var thumbEfficiencyCoefficient: Double? {
        queue.sync {
            LayoutRegistry.shared.thumbEfficiencyCalculator
                .coefficient(counts: store.counts, layout: LayoutRegistry.shared)
        }
    }

    /// Unified ergonomic score (0–100) computed from cumulative keystroke data (Issue #29).
    /// Higher is better. Returns 100.0 when no bigram data is available.
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
        queue.sync {
            TypingStyleAnalyzer().analyze(keyCounts: store.counts)
        }
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
    /// Keys are "yyyy-MM-dd" strings. Only dates with at least one bigram are included.
    var dailyErgonomicScore: [String: Double] {
        queue.sync {
            var result: [String: Double] = [:]
            for date in store.dailyCounts.keys {
                let bigrams = store.dailyTotalBigramCount[date] ?? 0
                guard bigrams > 0 else { continue }
                result[date] = ergonomicScore(
                    sfCount:     store.dailySameFingerCount[date]       ?? 0,
                    hsCount:     store.dailyHighStrainBigramCount[date] ?? 0,
                    altCount:    store.dailyHandAlternationCount[date]  ?? 0,
                    bigramCount: bigrams,
                    keyCounts:   store.dailyCounts[date] ?? [:]
                )
            }
            return result
        }
    }
}

// MARK: - Private helpers

extension KeyCountStore {

    /// Computes a unified ergonomic score (0–100) from raw bigram counters.
    /// Must be called from inside `queue.sync` — does not re-acquire the queue.
    /// - Parameter keyCounts: Per-key counts used to compute thumb metrics.
    ///   Pass `nil` (or omit) when per-key counts are unavailable (e.g. per-app/device context);
    ///   thumb imbalance and efficiency will be treated as 0.
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
