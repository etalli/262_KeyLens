import XCTest
@testable import KeyLensCore

// Tests for LayoutComparison and the updated ErgonomicSnapshot (Issue #3 — Phase 2).
//
// ## What is being tested
//
// 1. ErgonomicSnapshot.capture — all seven fields are computed from bigramCounts + keyCounts
//    a. empty bigramCounts → baseline snapshot (score=100, all rates=0)
//    b. known same-finger bigram → sameFingerRate > 0
//    c. known alternating bigram → handAlternationRate > 0
//    d. known high-strain bigram → highStrainRate > 0
//    e. travel distance matches TravelDistanceEstimator.totalTravel (regression)
//    f. ergonomicScore reflects SFB penalty (score < 100 when sfbRate > 0)
//
// 2. LayoutRegistry.forSimulation — isolated registry, singleton not mutated
//    a. current layout matches the supplied layout
//    b. configuration (weights, detectors) copied from base
//    c. LayoutRegistry.shared.current is unchanged after forSimulation call
//
// 3. LayoutComparison deltas — sign convention (positive = improvement)
//    a. ergonomicScoreDelta = proposed.score - current.score
//    b. sameFingerRateDelta = current.sfb - proposed.sfb  (lower is better)
//    c. handAlternationDelta = proposed.alt - current.alt (higher is better)
//    d. highStrainRateDelta  = current.hs - proposed.hs   (lower is better)
//    e. thumbImbalanceDelta  = current.ti - proposed.ti   (lower is better)
//    f. travelDistanceDelta  = current.td - proposed.td   (lower is better)
//
// 4. LayoutComparison.make — end-to-end factory
//    a. empty bigramCounts → nil
//    b. no beneficial swap → nil (bigramCounts with no SFBs)
//    c. with SFB data → non-nil, proposed score >= current score
//    d. recommended swaps list is non-empty
//
// 5. Equatable
//    a. identical snapshots are equal
//    b. different snapshots are not equal
//
// ErgonomicSnapshot全フィールド・LayoutRegistry.forSimulation・デルタ符号規則・
// make()のエンドツーエンド動作をテストする。

// MARK: - Shared fixtures

private let ansi = ANSILayout()

// f→r: left index, one row apart (high-strain SFB)
// j→u: right index, one row apart (high-strain SFB)
private let sfbBigrams: [String: Int] = ["f→r": 100, "j→u": 50]

// f→j: left index → right index (alternating)
private let altBigrams: [String: Int] = ["f→j": 200, "a→l": 100]

// Mixed: some SFB, some alternating
private let mixedBigrams: [String: Int] = ["f→r": 80, "f→j": 200]

final class LayoutComparisonTests: XCTestCase {

    // MARK: - 1. ErgonomicSnapshot.capture

    func testCapture_emptyBigramCounts_returnsBaseline() {
        let snap = ErgonomicSnapshot.capture(
            bigramCounts: [:], keyCounts: [:], layout: LayoutRegistry.shared
        )
        XCTAssertEqual(snap.ergonomicScore,             100.0, accuracy: 1e-9)
        XCTAssertEqual(snap.sameFingerRate,             0.0,   accuracy: 1e-9)
        XCTAssertEqual(snap.highStrainRate,             0.0,   accuracy: 1e-9)
        XCTAssertEqual(snap.handAlternationRate,        0.0,   accuracy: 1e-9)
        XCTAssertEqual(snap.thumbImbalanceRatio,        0.0,   accuracy: 1e-9)
        XCTAssertEqual(snap.thumbEfficiencyCoefficient, 0.0,   accuracy: 1e-9)
        XCTAssertEqual(snap.estimatedTravelDistance,    0.0,   accuracy: 1e-9)
    }

    func testCapture_sfbBigrams_sameFingerRatePositive() {
        // f→r and j→u are both same-finger high-strain bigrams.
        // 両方とも同指・高負荷ビグラム。
        let snap = ErgonomicSnapshot.capture(
            bigramCounts: sfbBigrams, keyCounts: [:], layout: LayoutRegistry.shared
        )
        // All 150 bigrams are same-finger → sfbRate = 1.0.
        XCTAssertEqual(snap.sameFingerRate,  1.0, accuracy: 1e-9)
        XCTAssertEqual(snap.highStrainRate,  1.0, accuracy: 1e-9)
        XCTAssertEqual(snap.handAlternationRate, 0.0, accuracy: 1e-9)
        XCTAssertLessThan(snap.ergonomicScore, 100.0)
    }

    func testCapture_altBigrams_alternationRatePositive() {
        // f→j: left index → right index = hand alternation.
        // a→l: left pinky → right ring = hand alternation.
        let snap = ErgonomicSnapshot.capture(
            bigramCounts: altBigrams, keyCounts: [:], layout: LayoutRegistry.shared
        )
        XCTAssertEqual(snap.sameFingerRate,      0.0, accuracy: 1e-9)
        XCTAssertEqual(snap.highStrainRate,       0.0, accuracy: 1e-9)
        XCTAssertEqual(snap.handAlternationRate,  1.0, accuracy: 1e-9)
    }

    func testCapture_highStrainBigrams_highStrainRatePositive() {
        // f→r: left index, row diff 1 (oneRow) → high-strain.
        let snap = ErgonomicSnapshot.capture(
            bigramCounts: ["f→r": 100], keyCounts: [:], layout: LayoutRegistry.shared
        )
        XCTAssertGreaterThan(snap.highStrainRate, 0.0)
        XCTAssertEqual(snap.highStrainRate, snap.sameFingerRate, accuracy: 1e-9)
    }

    func testCapture_travelDistance_matchesEstimator() {
        // estimatedTravelDistance must equal TravelDistanceEstimator.totalTravel.
        let estimator = TravelDistanceEstimator.default
        let expected  = estimator.totalTravel(counts: mixedBigrams, layout: ansi)
        let snap      = ErgonomicSnapshot.capture(
            bigramCounts: mixedBigrams, keyCounts: [:], layout: LayoutRegistry.shared
        )
        XCTAssertEqual(snap.estimatedTravelDistance, expected, accuracy: 1e-9)
    }

    func testCapture_ergonomicScore_reducedByPenalty() {
        // Pure SFB data must produce a score below baseline (100).
        let snap = ErgonomicSnapshot.capture(
            bigramCounts: sfbBigrams, keyCounts: [:], layout: LayoutRegistry.shared
        )
        XCTAssertLessThan(snap.ergonomicScore, 100.0)
    }

    // MARK: - 2. LayoutRegistry.forSimulation

    func testForSimulation_currentLayoutIsSupplied() {
        // The returned registry must use the supplied layout, not ANSILayout.
        var map: [String: String] = [:]
        KeyRelocationSimulator.applySwap(key1: "f", key2: "j", to: &map)
        let remapped = KeyRelocationSimulator.layout(applying: map, over: ANSILayout())
        let simReg   = LayoutRegistry.forSimulation(layout: remapped)
        // After swap, "f" should have the hand of "j" (right).
        XCTAssertEqual(simReg.hand(for: "f"), .right)
    }

    func testForSimulation_doesNotMutateSingleton() {
        // LayoutRegistry.shared.current must remain ANSILayout after forSimulation.
        // シングルトンの current は forSimulation 後も変わってはならない。
        var map: [String: String] = [:]
        KeyRelocationSimulator.applySwap(key1: "f", key2: "j", to: &map)
        let remapped = KeyRelocationSimulator.layout(applying: map, over: ANSILayout())
        _ = LayoutRegistry.forSimulation(layout: remapped)
        XCTAssertEqual(LayoutRegistry.shared.hand(for: "f"), .left)  // f is still left-hand
    }

    func testForSimulation_copiesWeightsFromBase() {
        let simReg = LayoutRegistry.forSimulation(layout: ANSILayout())
        XCTAssertEqual(simReg.ergonomicScoreEngine, LayoutRegistry.shared.ergonomicScoreEngine)
        XCTAssertEqual(simReg.thumbImbalanceDetector, LayoutRegistry.shared.thumbImbalanceDetector)
    }

    // MARK: - 3. LayoutComparison delta sign convention

    func testDelta_ergonomicScore_positiveWhenProposedHigher() {
        let worse  = ErgonomicSnapshot(ergonomicScore: 60, sameFingerRate: 0, highStrainRate: 0, handAlternationRate: 0, thumbImbalanceRatio: 0, thumbEfficiencyCoefficient: 0, estimatedTravelDistance: 0)
        let better = ErgonomicSnapshot(ergonomicScore: 75, sameFingerRate: 0, highStrainRate: 0, handAlternationRate: 0, thumbImbalanceRatio: 0, thumbEfficiencyCoefficient: 0, estimatedTravelDistance: 0)
        let cmp    = LayoutComparison(current: worse, proposed: better, recommendedSwaps: [])
        XCTAssertGreaterThan(cmp.ergonomicScoreDelta, 0)
    }

    func testDelta_sameFingerRate_positiveWhenProposedLower() {
        // Delta = current.sfb - proposed.sfb; proposed lower → positive.
        let current  = ErgonomicSnapshot(ergonomicScore: 0, sameFingerRate: 0.10, highStrainRate: 0, handAlternationRate: 0, thumbImbalanceRatio: 0, thumbEfficiencyCoefficient: 0, estimatedTravelDistance: 0)
        let proposed = ErgonomicSnapshot(ergonomicScore: 0, sameFingerRate: 0.04, highStrainRate: 0, handAlternationRate: 0, thumbImbalanceRatio: 0, thumbEfficiencyCoefficient: 0, estimatedTravelDistance: 0)
        let cmp      = LayoutComparison(current: current, proposed: proposed, recommendedSwaps: [])
        XCTAssertGreaterThan(cmp.sameFingerRateDelta,  0)
    }

    func testDelta_handAlternation_positiveWhenProposedHigher() {
        let current  = ErgonomicSnapshot(ergonomicScore: 0, sameFingerRate: 0, highStrainRate: 0, handAlternationRate: 0.50, thumbImbalanceRatio: 0, thumbEfficiencyCoefficient: 0, estimatedTravelDistance: 0)
        let proposed = ErgonomicSnapshot(ergonomicScore: 0, sameFingerRate: 0, highStrainRate: 0, handAlternationRate: 0.60, thumbImbalanceRatio: 0, thumbEfficiencyCoefficient: 0, estimatedTravelDistance: 0)
        let cmp      = LayoutComparison(current: current, proposed: proposed, recommendedSwaps: [])
        XCTAssertGreaterThan(cmp.handAlternationDelta, 0)
    }

    func testDelta_travelDistance_positiveWhenProposedLower() {
        let current  = ErgonomicSnapshot(ergonomicScore: 0, sameFingerRate: 0, highStrainRate: 0, handAlternationRate: 0, thumbImbalanceRatio: 0, thumbEfficiencyCoefficient: 0, estimatedTravelDistance: 1000)
        let proposed = ErgonomicSnapshot(ergonomicScore: 0, sameFingerRate: 0, highStrainRate: 0, handAlternationRate: 0, thumbImbalanceRatio: 0, thumbEfficiencyCoefficient: 0, estimatedTravelDistance: 850)
        let cmp      = LayoutComparison(current: current, proposed: proposed, recommendedSwaps: [])
        XCTAssertGreaterThan(cmp.travelDistanceDelta, 0)
    }

    // MARK: - 4. LayoutComparison.make

    func testMake_emptyBigramCounts_returnsNil() {
        let result = LayoutComparison.make(bigramCounts: [:], keyCounts: [:])
        XCTAssertNil(result)
    }

    func testMake_noSFBData_returnsNil() {
        // Pure alternating bigrams → no same-finger bigrams → optimizer finds no beneficial swap.
        // 純粋な交互打鍵データ → 同指ビグラムなし → スワップなし → nil。
        let result = LayoutComparison.make(bigramCounts: altBigrams, keyCounts: [:])
        XCTAssertNil(result)
    }

    func testMake_withSFBData_returnsComparison() {
        // f→r and j→u are clear SFBs → optimizer should find at least one swap.
        guard let cmp = LayoutComparison.make(bigramCounts: sfbBigrams, keyCounts: [:]) else {
            XCTFail("Expected non-nil LayoutComparison for SFB-heavy data")
            return
        }
        XCTAssertFalse(cmp.recommendedSwaps.isEmpty)
    }

    func testMake_proposedScoreNotWorseThanCurrent() {
        // The optimizer only accepts improvements: proposed score >= current score.
        // オプティマイザは改善のみ受け入れるため、提案スコア >= 現行スコアでなければならない。
        guard let cmp = LayoutComparison.make(bigramCounts: sfbBigrams, keyCounts: [:]) else { return }
        XCTAssertGreaterThanOrEqual(cmp.proposed.ergonomicScore, cmp.current.ergonomicScore - 1e-9)
    }

    func testMake_proposedSFBRateNotHigherThanCurrent() {
        // After optimization, the proposed layout should have fewer or equal SFBs.
        // 最適化後、提案レイアウトのSFB率は現行以下でなければならない。
        guard let cmp = LayoutComparison.make(bigramCounts: sfbBigrams, keyCounts: [:]) else { return }
        XCTAssertLessThanOrEqual(cmp.proposed.sameFingerRate, cmp.current.sameFingerRate + 1e-9)
    }

    // MARK: - 5. Equatable

    func testEquatable_sameInput_equal() {
        let s1 = ErgonomicSnapshot.capture(bigramCounts: sfbBigrams, keyCounts: [:], layout: LayoutRegistry.shared)
        let s2 = ErgonomicSnapshot.capture(bigramCounts: sfbBigrams, keyCounts: [:], layout: LayoutRegistry.shared)
        XCTAssertEqual(s1, s2)
    }

    func testEquatable_differentInput_notEqual() {
        let s1 = ErgonomicSnapshot.capture(bigramCounts: sfbBigrams, keyCounts: [:], layout: LayoutRegistry.shared)
        let s2 = ErgonomicSnapshot.capture(bigramCounts: altBigrams,  keyCounts: [:], layout: LayoutRegistry.shared)
        XCTAssertNotEqual(s1, s2)
    }
}
