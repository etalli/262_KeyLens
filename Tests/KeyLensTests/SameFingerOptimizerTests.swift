import XCTest
@testable import KeyLensCore

// Tests for SameFingerOptimizer, SFBScoreEngine, RemappedLayout, and LayoutConstraints.
//
// ## What is being tested
//
// 1. SFBScoreEngine
//    - Score is zero when no same-finger bigrams exist.
//    - Score is positive for known same-finger bigrams.
//    - Score accounts for hand — left-index and right-index are NOT the same finger.
//
// 2. RemappedLayout / KeyRelocationSimulator
//    - Swapping A↔B causes A to be resolved through B's position and vice versa.
//    - Multiple swaps compose correctly via applySwap.
//
// 3. LayoutConstraints
//    - macOSDefaults preset contains expected keys.
//    - Fixed keys are never proposed in optimizer results.
//
// 4. SameFingerOptimizer
//    - Empty input → empty result.
//    - No SFB bigrams → empty result.
//    - High-SFB scenario → optimizer proposes at least one swap with positive reduction.
//    - Proposed swap actually reduces the score (verify against SFBScoreEngine).
//    - maxSwaps limits the result count.
//    - Fixed keys (LayoutConstraints) never appear in proposals.

final class SameFingerOptimizerTests: XCTestCase {

    private let layout = ANSILayout()
    private let engine = SFBScoreEngine()
    private let optimizer = SameFingerOptimizer()

    // MARK: - 1. SFBScoreEngine

    func test_score_noSameFinger_isZero() {
        // "f" (left.index) → "j" (right.index): different hands → not SFB
        let counts = ["f→j": 1000, "j→f": 1000]
        XCTAssertEqual(engine.score(bigramCounts: counts, layout: layout), 0.0)
    }

    func test_score_sameFinger_isPositive() {
        // "f" and "r" are both left.index in ANSILayout → SFB
        let counts = ["f→r": 100]
        let score = engine.score(bigramCounts: counts, layout: layout)
        XCTAssertGreaterThan(score, 0.0)
    }

    func test_score_handBoundary_leftIndexVsRightIndex() {
        // Left index keys: f, r, t, g, v, b
        // Right index keys: j, u, h, n, m
        // Cross-hand pairs must produce zero SFB score.
        let crossHand = ["f→j": 500, "r→u": 500, "g→h": 500]
        XCTAssertEqual(engine.score(bigramCounts: crossHand, layout: layout), 0.0,
                       "Cross-hand same-Finger-enum bigrams should not be counted as SFB")
    }

    func test_score_sameKey_isPositive() {
        // "f→f": same key repeat, tier = .sameKey (factor 0.5), still a penalty
        let counts = ["f→f": 100]
        let score = engine.score(bigramCounts: counts, layout: layout)
        XCTAssertGreaterThan(score, 0.0)
    }

    func test_score_emptyInput_isZero() {
        XCTAssertEqual(engine.score(bigramCounts: [:], layout: layout), 0.0)
    }

    func test_score_unknownKeys_skipped() {
        // Keys not in ANSILayout → no penalty (gracefully ignored)
        let counts = ["🖱Left→🖱Right": 999]
        XCTAssertEqual(engine.score(bigramCounts: counts, layout: layout), 0.0)
    }

    // MARK: - 2. RemappedLayout / KeyRelocationSimulator

    func test_remappedLayout_swapChangesFingerLookup() {
        // Swap "f" (left.index) ↔ "k" (right.middle)
        var map: [String: String] = [:]
        KeyRelocationSimulator.applySwap(key1: "f", key2: "k", to: &map)
        let remapped = RemappedLayout(base: layout, relocationMap: map)

        XCTAssertEqual(remapped.finger(for: "f"), layout.finger(for: "k"),
                       "After f↔k swap, f should resolve to k's finger")
        XCTAssertEqual(remapped.finger(for: "k"), layout.finger(for: "f"),
                       "After f↔k swap, k should resolve to f's finger")
    }

    func test_remappedLayout_unmappedKey_unchanged() {
        var map: [String: String] = [:]
        KeyRelocationSimulator.applySwap(key1: "f", key2: "k", to: &map)
        let remapped = RemappedLayout(base: layout, relocationMap: map)
        // "a" was not part of the swap — should be identical to the base layout.
        XCTAssertEqual(remapped.finger(for: "a"), layout.finger(for: "a"))
        XCTAssertEqual(remapped.hand(for: "a"),   layout.hand(for: "a"))
    }

    func test_applySwap_composesCorrectly() {
        // Swap f↔j, then swap j↔k (where j is now at f's original position)
        var map: [String: String] = [:]
        KeyRelocationSimulator.applySwap(key1: "f", key2: "j", to: &map)
        KeyRelocationSimulator.applySwap(key1: "j", key2: "k", to: &map)
        // After composition:
        //   f → j's original position
        //   j → k's original position
        //   k → f's original position
        let remapped = RemappedLayout(base: layout, relocationMap: map)
        XCTAssertEqual(remapped.position(for: "f"), layout.position(for: "j"))
        XCTAssertEqual(remapped.position(for: "j"), layout.position(for: "k"))
        XCTAssertEqual(remapped.position(for: "k"), layout.position(for: "f"))
    }

    func test_applySwap_reverseRestoresIdentity() {
        // Applying the same swap twice should cancel out (identity).
        var map: [String: String] = [:]
        KeyRelocationSimulator.applySwap(key1: "f", key2: "j", to: &map)
        KeyRelocationSimulator.applySwap(key1: "f", key2: "j", to: &map)
        XCTAssertTrue(map.isEmpty, "Swapping the same pair twice should restore identity (empty map)")
    }

    func test_remappedLayout_swapEliminatesSFB() {
        // "f→r": SFB (both left.index). Swap "f" with "j" (right.index).
        // After swap "f" is right.index, "r" stays left.index → no longer SFB.
        let counts = ["f→r": 1000]
        let baseScore = engine.score(bigramCounts: counts, layout: layout)
        XCTAssertGreaterThan(baseScore, 0)

        var map: [String: String] = [:]
        KeyRelocationSimulator.applySwap(key1: "f", key2: "j", to: &map)
        let remapped = KeyRelocationSimulator.layout(applying: map, over: layout)
        let newScore = engine.score(bigramCounts: counts, layout: remapped)
        XCTAssertEqual(newScore, 0.0, accuracy: 1e-10,
                       "After f↔j swap, f→r should no longer be same-finger")
    }

    // MARK: - 3. LayoutConstraints

    func test_layoutConstraints_macOSDefaults_containsEssentialKeys() {
        let fixed = LayoutConstraints.macOSDefaults.fixedKeys
        XCTAssertTrue(fixed.contains("Space"))
        XCTAssertTrue(fixed.contains("Return"))
        XCTAssertTrue(fixed.contains("Escape"))
        XCTAssertTrue(fixed.contains("Tab"))
        XCTAssertTrue(fixed.contains("q"))  // ⌘Q
        XCTAssertTrue(fixed.contains("c"))  // ⌘C
        XCTAssertTrue(fixed.contains("v"))  // ⌘V
    }

    func test_layoutConstraints_none_isEmpty() {
        XCTAssertTrue(LayoutConstraints.none.fixedKeys.isEmpty)
    }

    // MARK: - 4. SameFingerOptimizer

    func test_optimize_emptyInput_returnsEmpty() {
        let result = optimizer.optimize(bigramCounts: [:], layout: layout, constraints: .none)
        XCTAssertTrue(result.isEmpty)
    }

    func test_optimize_noSFBBigrams_returnsEmpty() {
        // Only cross-hand bigrams — SFB score is already 0, nothing to improve.
        let counts = ["f→j": 10000, "j→f": 10000]
        let result = optimizer.optimize(bigramCounts: counts, layout: layout, constraints: .none)
        XCTAssertTrue(result.isEmpty)
    }

    func test_optimize_highSFB_proposesAtLeastOneSwap() {
        // Heavy left-index same-finger load. "g" is added so the pool contains a right-hand
        // candidate key ("j", "u", "h", "m") that can relieve the SFB.
        // f, r, t, g, b → left.index  |  j, u, h, n, m → right.index
        let counts = [
            "f→r": 5000, "r→f": 5000,  // very heavy left-index SFB
            "f→j": 1,                   // adds "j" (right.index) to the swappable pool
        ]
        let result = optimizer.optimize(
            bigramCounts: counts,
            layout: layout,
            constraints: .none,
            maxSwaps: 3
        )
        XCTAssertFalse(result.isEmpty, "Optimizer should find at least one improving swap")
    }

    func test_optimize_projectedReduction_matchesActualScoreDrop() {
        let counts = [
            "f→r": 2000, "r→f": 2000,
            "f→j": 1,
        ]
        let baseline = engine.score(bigramCounts: counts, layout: layout)
        let swaps = optimizer.optimize(
            bigramCounts: counts,
            layout: layout,
            constraints: .none,
            maxSwaps: 1
        )
        guard let swap = swaps.first else {
            XCTFail("Expected at least one swap")
            return
        }
        // Verify the projected reduction matches an actual re-score.
        var map: [String: String] = [:]
        KeyRelocationSimulator.applySwap(key1: swap.from, key2: swap.to, to: &map)
        let actualScore = engine.score(
            bigramCounts: counts,
            layout: KeyRelocationSimulator.layout(applying: map, over: layout)
        )
        let actualReduction = baseline - actualScore
        XCTAssertEqual(swap.projectedSFBReduction, actualReduction, accuracy: 1e-9,
                       "projectedSFBReduction must match the actual score drop")
        XCTAssertGreaterThan(swap.projectedSFBReduction, 0,
                             "Accepted swap must have a positive reduction")
    }

    func test_optimize_maxSwaps_limitsResultCount() {
        let counts = [
            "f→r": 3000, "r→t": 3000, "t→g": 3000, "g→b": 3000,
            "f→j": 1, "r→j": 1, "t→j": 1, "g→j": 1, "b→j": 1,
        ]
        let result = optimizer.optimize(
            bigramCounts: counts,
            layout: layout,
            constraints: .none,
            maxSwaps: 2
        )
        XCTAssertLessThanOrEqual(result.count, 2)
    }

    func test_optimize_fixedKeys_neverAppearInProposals() {
        // Lock "r" — optimizer must not propose moving "r".
        let counts = [
            "f→r": 5000, "r→f": 5000,
            "f→j": 1,
        ]
        let constraints = LayoutConstraints(fixedKeys: ["r"])
        let result = optimizer.optimize(
            bigramCounts: counts,
            layout: layout,
            constraints: constraints,
            maxSwaps: 5
        )
        for swap in result {
            XCTAssertNotEqual(swap.from, "r", "'r' is fixed and must not appear as 'from'")
            XCTAssertNotEqual(swap.to,   "r", "'r' is fixed and must not appear as 'to'")
        }
    }

    func test_optimize_allCandidatesFixed_returnsEmpty() {
        // Both keys in the SFB bigram are fixed — no swap is possible.
        let counts = ["f→r": 5000, "r→f": 5000]
        let constraints = LayoutConstraints(fixedKeys: ["f", "r"])
        let result = optimizer.optimize(
            bigramCounts: counts,
            layout: layout,
            constraints: constraints
        )
        XCTAssertTrue(result.isEmpty)
    }
}
