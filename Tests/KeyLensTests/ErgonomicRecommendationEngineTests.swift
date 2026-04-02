import XCTest
@testable import KeyLensCore

final class ErgonomicRecommendationEngineTests: XCTestCase {

    private let engine = ErgonomicRecommendationEngine.default

    private func snapshot(
        sameFingerRate: Double = 0,
        highStrainRate: Double = 0,
        handAlternationRate: Double = 0.5,
        rowReachScore: Double = 0,
        score: Double = 100
    ) -> ErgonomicSnapshot {
        ErgonomicSnapshot(
            ergonomicScore: score,
            sameFingerRate: sameFingerRate,
            highStrainRate: highStrainRate,
            handAlternationRate: handAlternationRate,
            thumbImbalanceRatio: 0,
            thumbEfficiencyCoefficient: 0,
            rowReachScore: rowReachScore,
            estimatedTravelDistance: 0
        )
    }

    func testLowSampleCount_returnsEmptySafely() {
        let recs = engine.topRecommendations(
            from: snapshot(sameFingerRate: 0.25, highStrainRate: 0.20, handAlternationRate: 0.10, rowReachScore: 0.80),
            sampleCount: 40
        )
        XCTAssertTrue(recs.isEmpty)
    }

    func testSameFingerTrigger_producesExpectedRuleId() {
        let recs = engine.topRecommendations(
            from: snapshot(sameFingerRate: 0.18),
            sampleCount: 300
        )
        XCTAssertTrue(recs.contains { $0.id == "same_finger_repetition" })
    }

    func testHighStrainTrigger_producesOuterColumnRule() {
        let recs = engine.topRecommendations(
            from: snapshot(highStrainRate: 0.12),
            sampleCount: 300
        )
        XCTAssertTrue(recs.contains { $0.id == "outer_column_load" })
    }

    func testWeakAlternationTrigger_producesAlternationRule() {
        let recs = engine.topRecommendations(
            from: snapshot(handAlternationRate: 0.20),
            sampleCount: 300
        )
        XCTAssertTrue(recs.contains { $0.id == "weak_hand_alternation" })
    }

    func testRowReachTrigger_producesRowReachRule() {
        let recs = engine.topRecommendations(
            from: snapshot(rowReachScore: 0.60),
            sampleCount: 300
        )
        XCTAssertTrue(recs.contains { $0.id == "high_row_reach" })
    }

    func testNoRuleTriggered_returnsEmpty() {
        let recs = engine.topRecommendations(
            from: snapshot(
                sameFingerRate: 0.04,
                highStrainRate: 0.02,
                handAlternationRate: 0.56,
                rowReachScore: 0.18
            ),
            sampleCount: 300
        )
        XCTAssertTrue(recs.isEmpty)
    }

    func testDeterministicOrder_sameInputSameOutput() {
        let snap = snapshot(
            sameFingerRate: 0.21,
            highStrainRate: 0.15,
            handAlternationRate: 0.12,
            rowReachScore: 0.72
        )
        let first = engine.topRecommendations(from: snap, sampleCount: 500)
        let second = engine.topRecommendations(from: snap, sampleCount: 500)
        XCTAssertEqual(first, second)
    }

    func testTopK_isCappedAtThreeForDefault() {
        let recs = engine.topRecommendations(
            from: snapshot(
                sameFingerRate: 0.30,
                highStrainRate: 0.30,
                handAlternationRate: 0.10,
                rowReachScore: 0.90
            ),
            sampleCount: 400
        )
        XCTAssertLessThanOrEqual(recs.count, 3)
    }

    func testRegression_scoreComputationPathUnchanged() {
        let scoreEngine = ErgonomicScoreEngine.default
        let s1 = scoreEngine.score(
            sameFingerRate: 0.12,
            highStrainRate: 0.06,
            thumbImbalanceRatio: 0.15,
            rowReachScore: 0.45,
            handAlternationRate: 0.38,
            thumbEfficiencyCoefficient: 1.1
        )

        _ = engine.topRecommendations(
            from: snapshot(
                sameFingerRate: 0.12,
                highStrainRate: 0.06,
                handAlternationRate: 0.38,
                rowReachScore: 0.45,
                score: s1
            ),
            sampleCount: 450
        )

        let s2 = scoreEngine.score(
            sameFingerRate: 0.12,
            highStrainRate: 0.06,
            thumbImbalanceRatio: 0.15,
            rowReachScore: 0.45,
            handAlternationRate: 0.38,
            thumbEfficiencyCoefficient: 1.1
        )
        XCTAssertEqual(s1, s2, accuracy: 1e-9)
    }
}
