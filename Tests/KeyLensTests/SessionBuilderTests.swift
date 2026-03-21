import XCTest
@testable import KeyLensCore

// Tests for SessionBuilder and TrainingSession (Issue #86).
//
// Rules under test:
//   - Top maxTargets bigrams are selected
//   - Tier-based repetition: high(8) > mid(5) > low(3)
//   - High-tier drills appear before mid, mid before low
//   - Alternating drills appended per tier when includeAlternating=true
//   - totalWords reflects the sum of all drill word counts

final class SessionBuilderTests: XCTestCase {

    // MARK: - Helpers

    private func score(_ key: String, iki: Double, count: Int = 20) -> BigramScore {
        BigramScore(bigram: key, meanIKI: iki, count: count)
    }

    /// Five bigrams ranked highest → lowest by IKI (scores already ordered).
    private var fiveScores: [BigramScore] {
        [
            score("t→h", iki: 250),
            score("h→e", iki: 220),
            score("e→r", iki: 190),
            score("r→s", iki: 160),
            score("s→t", iki: 130),
        ]
    }

    // MARK: - Empty input

    func test_build_emptyInput_returnsEmptySession() {
        let session = SessionBuilder.build(from: [])
        XCTAssertTrue(session.targets.isEmpty)
        XCTAssertTrue(session.drills.isEmpty)
    }

    // MARK: - Target selection

    func test_build_selectsTopMaxTargets() {
        let config  = SessionConfig(maxTargets: 3)
        let session = SessionBuilder.build(from: fiveScores, config: config)
        XCTAssertEqual(session.targets.count, 3)
        XCTAssertEqual(session.targets[0].bigram, "t→h")
        XCTAssertEqual(session.targets[1].bigram, "h→e")
        XCTAssertEqual(session.targets[2].bigram, "e→r")
    }

    func test_build_fewerScoresThanMaxTargets_usesAll() {
        let config  = SessionConfig(maxTargets: 10)
        let session = SessionBuilder.build(from: fiveScores, config: config)
        XCTAssertEqual(session.targets.count, 5)
    }

    func test_build_singleBigram_producesOneDrill() {
        let session = SessionBuilder.build(from: [score("t→h", iki: 200)])
        XCTAssertEqual(session.targets.count, 1)
        XCTAssertFalse(session.drills.isEmpty)
    }

    // MARK: - Tier repetitions

    func test_build_highTierDrill_usesHighReps() {
        let config = SessionConfig(maxTargets: 5, highReps: 8, midReps: 5, lowReps: 3,
                                   highTierSize: 2, midTierSize: 2, includeAlternating: false)
        let session = SessionBuilder.build(from: fiveScores, config: config)

        // First drill is rank-1 bigram repeated 8 times
        let firstDrill = session.drills.first!
        let wordCount  = firstDrill.text.split(separator: " ").count
        XCTAssertEqual(wordCount, 8)
    }

    func test_build_midTierDrill_usesMidReps() {
        let config = SessionConfig(maxTargets: 5, highReps: 8, midReps: 5, lowReps: 3,
                                   highTierSize: 2, midTierSize: 2, includeAlternating: false)
        let session = SessionBuilder.build(from: fiveScores, config: config)

        // Drills 0,1 are high tier. Drill 2 is first mid-tier.
        let midDrill  = session.drills[2]
        let wordCount = midDrill.text.split(separator: " ").count
        XCTAssertEqual(wordCount, 5)
    }

    func test_build_lowTierDrill_usesLowReps() {
        let config = SessionConfig(maxTargets: 5, highReps: 8, midReps: 5, lowReps: 3,
                                   highTierSize: 2, midTierSize: 2, includeAlternating: false)
        let session = SessionBuilder.build(from: fiveScores, config: config)

        // Drills 0,1 high; 2,3 mid; 4 low
        let lowDrill  = session.drills[4]
        let wordCount = lowDrill.text.split(separator: " ").count
        XCTAssertEqual(wordCount, 3)
    }

    // MARK: - Drill ordering (high → mid → low)

    func test_build_drillsOrderedHighBeforeMidBeforeLow() {
        let config = SessionConfig(maxTargets: 5, highReps: 8, midReps: 5, lowReps: 3,
                                   highTierSize: 2, midTierSize: 2, includeAlternating: false)
        let session = SessionBuilder.build(from: fiveScores, config: config)

        // high tier drills = 2, mid = 2, low = 1 → total 5
        XCTAssertEqual(session.drills.count, 5)

        // Verify descending word count order by tier boundary
        let wc = session.drills.map { $0.text.split(separator: " ").count }
        XCTAssertEqual(wc[0], 8)
        XCTAssertEqual(wc[1], 8)
        XCTAssertEqual(wc[2], 5)
        XCTAssertEqual(wc[3], 5)
        XCTAssertEqual(wc[4], 3)
    }

    // MARK: - Alternating drills

    func test_build_includeAlternating_addsAlternatingDrills() {
        let config  = SessionConfig(maxTargets: 4, includeAlternating: true)
        let session = SessionBuilder.build(from: fiveScores, config: config)
        let altCount = session.drills.filter { $0.kind == .alternating }.count
        XCTAssertGreaterThan(altCount, 0)
    }

    func test_build_excludeAlternating_noAlternatingDrills() {
        let config  = SessionConfig(includeAlternating: false)
        let session = SessionBuilder.build(from: fiveScores, config: config)
        let altCount = session.drills.filter { $0.kind == .alternating }.count
        XCTAssertEqual(altCount, 0)
    }

    func test_build_alternatingDrill_appearsAfterRepeatedInSameTier() {
        let config = SessionConfig(maxTargets: 4, highReps: 8, midReps: 5, lowReps: 3,
                                   highTierSize: 2, midTierSize: 2, includeAlternating: true)
        let session = SessionBuilder.build(from: fiveScores, config: config)

        // Within high tier: [rep, rep, alt] → alternating comes after both repeated
        let highTierDrills = session.drills.prefix(3)
        let kinds = highTierDrills.map { $0.kind }
        XCTAssertEqual(kinds, [.repeated, .repeated, .alternating])
    }

    func test_build_singleBigramInTier_noAlternatingForThatTier() {
        // 3 bigrams: high(2) mid(0) low(1) — low tier has 1 bigram, no alternating
        let config  = SessionConfig(maxTargets: 3, highTierSize: 2, midTierSize: 0,
                                    includeAlternating: true)
        let session = SessionBuilder.build(from: fiveScores, config: config)
        let lowDrills = session.drills.filter { $0.kind == .repeated && $0.targets.count == 1 }
        // The single low-tier bigram should not have an alternating partner
        let altDrills = session.drills.filter { $0.kind == .alternating }
        // Only the high tier (2 bigrams) produces an alternating drill
        XCTAssertEqual(altDrills.count, 1)
        _ = lowDrills // suppress unused warning
    }

    // MARK: - totalWords

    func test_totalWords_matchesSumOfAllDrillWords() {
        let config  = SessionConfig(maxTargets: 3, includeAlternating: false)
        let session = SessionBuilder.build(from: fiveScores, config: config)
        let expected = session.drills.reduce(0) { $0 + $1.text.split(separator: " ").count }
        XCTAssertEqual(session.totalWords, expected)
    }

    func test_totalWords_emptySession_isZero() {
        let session = SessionBuilder.build(from: [])
        XCTAssertEqual(session.totalWords, 0)
    }

    // MARK: - Config clamping

    func test_config_zeroMaxTargets_clampsToOne() {
        let config = SessionConfig(maxTargets: 0)
        XCTAssertEqual(config.maxTargets, 1)
    }

    func test_config_negativeReps_clampsToOne() {
        let config = SessionConfig(highReps: -5, midReps: 0, lowReps: -1)
        XCTAssertEqual(config.highReps, 1)
        XCTAssertEqual(config.midReps, 1)
        XCTAssertEqual(config.lowReps, 1)
    }

    // MARK: - Config stored on session

    func test_build_sessionStoresConfig() {
        let config  = SessionConfig(maxTargets: 3, highReps: 7)
        let session = SessionBuilder.build(from: fiveScores, config: config)
        XCTAssertEqual(session.config, config)
    }

    // MARK: - Default config

    func test_defaultConfig_hasExpectedValues() {
        let c = SessionConfig.default
        XCTAssertEqual(c.maxTargets,   3)
        XCTAssertEqual(c.highReps,     5)
        XCTAssertEqual(c.midReps,      3)
        XCTAssertEqual(c.lowReps,      2)
        XCTAssertEqual(c.highTierSize, 2)
        XCTAssertEqual(c.midTierSize,  1)
        XCTAssertTrue(c.includeAlternating)
    }
}
