import Foundation
import GRDB
import KeyLensCore

// MARK: - Ergonomic queries
// Read-only queries are delegated to KeyMetricsQuery (constructed as a snapshot inside queue.sync).

extension KeyCountStore {

    var averageIntervalMs: Double? {
        queue.sync { makeQuery().averageIntervalMs }
    }

    var estimatedWPM: Double? {
        queue.sync { makeQuery().estimatedWPM }
    }

    func rollingWPM(windowSeconds: Double = 5.0) -> Double {
        queue.sync { makeQuery().rollingWPM(windowSeconds: windowSeconds) }
    }

    var backspaceRate: Double? {
        queue.sync { makeQuery().backspaceRate }
    }

    var todayBackspaceRate: Double? {
        queue.sync { makeQuery().todayBackspaceRate }
    }

    func dailyBackspaceRates() -> [(date: String, rate: Double)] {
        queue.sync { makeQuery().dailyBackspaceRates() }
    }

    func dailyWPM() -> [(date: String, wpm: Double)] {
        queue.sync { makeQuery().dailyWPM() }
    }

    var todayMinIntervalMs: Double? {
        queue.sync { makeQuery().todayMinIntervalMs }
    }

    var sameFingerRate: Double? {
        queue.sync { makeQuery().sameFingerRate }
    }

    var todaySameFingerRate: Double? {
        queue.sync { makeQuery().todaySameFingerRate }
    }

    var handAlternationRate: Double? {
        queue.sync { makeQuery().handAlternationRate }
    }

    var todayHandAlternationRate: Double? {
        queue.sync { makeQuery().todayHandAlternationRate }
    }

    var alternationRewardScore: Double {
        queue.sync { makeQuery().alternationRewardScore }
    }

    var thumbImbalanceRatio: Double? {
        queue.sync { makeQuery().thumbImbalanceRatio }
    }

    func dailyThumbImbalance(for date: String) -> Double? {
        queue.sync { makeQuery().dailyThumbImbalance(for: date) }
    }

    func dailyErgonomicRates() -> [(date: String, sameFingerRate: Double, handAltRate: Double, highStrainRate: Double)] {
        queue.sync { makeQuery().dailyErgonomicRates() }
    }

    var highStrainBigramCount: Int {
        queue.sync { makeQuery().highStrainBigramCount }
    }

    var highStrainBigramRate: Double? {
        queue.sync { makeQuery().highStrainBigramRate }
    }

    var highStrainTrigramCount: Int {
        queue.sync { makeQuery().highStrainTrigramCount }
    }

    func topHighStrainBigrams(limit: Int = 10) -> [(pair: String, count: Int)] {
        queue.sync { makeQuery().topHighStrainBigrams(limit: limit) }
    }

    var thumbEfficiencyCoefficient: Double? {
        queue.sync { makeQuery().thumbEfficiencyCoefficient }
    }

    var currentErgonomicScore: Double {
        queue.sync { makeQuery().currentErgonomicScore }
    }

    public var currentTypingStyle: TypingStyle {
        queue.sync { makeQuery().currentTypingStyle }
    }

    public var currentTypingRhythm: TypingRhythm {
        queue.sync { makeQuery().currentTypingRhythm }
    }

    public var currentFatigueLevel: FatigueLevel {
        queue.sync { makeQuery().currentFatigueLevel }
    }

    func todayHourlyFatigueCurve() -> [HourlyFatigueEntry] {
        queue.sync { makeQuery().todayHourlyFatigueCurve() }
    }

    var dailyErgonomicScore: [String: Double] {
        queue.sync { makeQuery().dailyErgonomicScore }
    }
}

// MARK: - Issue #61: Layout Efficiency Scores

extension KeyCountStore {

    func layoutEfficiencyScores() -> [LayoutEfficiencyEntry] {
        // Capture the snapshot inside the queue, then compute outside (expensive layout simulation).
        let q = queue.sync { makeQuery() }
        return q.layoutEfficiencyScores()
    }
}

// MARK: - Issue #209: Layer Key Efficiency

extension KeyCountStore {

    func layerEfficiency() -> [LayerEfficiencyEntry] {
        let q = queue.sync { makeQuery() }
        return q.layerEfficiency()
    }
}

// MARK: - Issue #299: Ergonomic Recommendations

extension KeyCountStore {

    /// Returns top ergonomic recommendations derived from the current snapshot.
    /// Captures bigram/key counts inside the serial queue, then runs the expensive
    /// ErgonomicSnapshot.capture() and recommendation engine outside it.
    func topRecommendations(limit: Int = 3) -> [ErgonomicRecommendation] {
        let q = queue.sync { makeQuery() }
        let bigramCounts = q.allBigramCounts
        let keyCounts    = q.allKeyCounts
        let snapshot = ErgonomicSnapshot.capture(
            bigramCounts: bigramCounts,
            keyCounts:    keyCounts,
            layout:       .shared
        )
        let sampleCount = bigramCounts.values.reduce(0, +)
        return ErgonomicRecommendationEngine(topK: limit).topRecommendations(
            from: snapshot,
            sampleCount: sampleCount
        )
    }
}
