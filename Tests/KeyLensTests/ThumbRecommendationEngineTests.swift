import XCTest
@testable import KeyLensCore

// Tests for ThumbRecommendationEngine (Issue #37).
//
// ## Key facts used (ANSILayout)
//
//   ";" → right pinky  (fingerTable[";"]=.pinky, NOT in macOSDefaults fixedKeys)
//   "'" → right pinky  (NOT in macOSDefaults fixedKeys)
//   "p" → right pinky  (NOT in macOSDefaults fixedKeys)
//   "f" → left index   (burdenReduction < 0 → excluded)
//   "Space" → left thumb (already thumb → excluded)
//   "q" → left pinky   (IN macOSDefaults fixedKeys → excluded)
//
// ## Burden reduction formula
//
//   burdenReduction = count × (1/fingerWeight − 1/thumbWeight)
//   pinky (0.5):  count × (2.0  − 1.25) = count × 0.75
//   ring  (0.6):  count × (1.67 − 1.25) = count × 0.417
//   index (1.0):  count × (1.0  − 1.25) = count × −0.25  → excluded
//
// ## Test coverage
//
// 1. High-frequency pinky key → appears in recommendations
// 2. burdenReduction value is computed correctly for a pinky key
// 3. Fixed key (macOSDefaults) → excluded from recommendations
// 4. Existing thumb key → excluded from recommendations
// 5. Index finger key → excluded (burdenReduction < 0)
// 6. Zero-count key → excluded
// 7. topK limits result count
// 8. Slot assignment: left-heavy thumb load → first slot is .right
// 9. Empty counts → empty result

final class ThumbRecommendationEngineTests: XCTestCase {

    private let layout = LayoutRegistry.shared
    private let engine = ThumbRecommendationEngine(
        fingerWeights: .default,
        constraints: .macOSDefaults,
        topK: 5
    )

    // MARK: - 1. High-frequency pinky key is recommended

    func test_pinkyKey_isRecommended() {
        // ";" is a right pinky key not in macOSDefaults — should appear in recommendations.
        let counts = [";": 1000]
        let recs = engine.topRecommendations(from: counts, layout: layout)
        let keys = recs.map { $0.key }
        XCTAssertTrue(keys.contains(";"), "'\"' should be recommended — it is a high-burden pinky key")
    }

    // MARK: - 2. burdenReduction is computed correctly

    func test_burdenReduction_pinky_isCorrect() {
        // pinky weight = 0.5, thumb weight = 0.8, count = 1000
        // reduction = 1000 × (1/0.5 − 1/0.8) = 1000 × (2.0 − 1.25) = 750.0
        let counts = [";": 1000]
        let recs = engine.topRecommendations(from: counts, layout: layout)
        guard let rec = recs.first(where: { $0.key == ";" }) else {
            return XCTFail("';' not found in recommendations")
        }
        XCTAssertEqual(rec.burdenReduction, 750.0, accuracy: 1e-6)
    }

    // MARK: - 3. Fixed key is excluded

    func test_fixedKey_isExcluded() {
        // "q" is in macOSDefaults.fixedKeys — must never be recommended.
        let counts = ["q": 9999, ";": 1]
        let recs = engine.topRecommendations(from: counts, layout: layout)
        XCTAssertFalse(recs.map { $0.key }.contains("q"), "'q' is a fixed key and must not be recommended")
    }

    // MARK: - 4. Existing thumb key is excluded

    func test_thumbKey_isExcluded() {
        // "Space" is already a thumb key — must not be recommended for relocation.
        let engineNoConstraints = ThumbRecommendationEngine(constraints: .none)
        let counts = ["Space": 9999, ";": 1]
        let recs = engineNoConstraints.topRecommendations(from: counts, layout: layout)
        XCTAssertFalse(recs.map { $0.key }.contains("Space"), "'Space' is already a thumb key")
    }

    // MARK: - 5. Index finger key is excluded (burdenReduction ≤ 0)

    func test_indexKey_isExcluded() {
        // "f" is left index (weight 1.0). Moving to thumb (0.8) increases burden → excluded.
        let engineNoConstraints = ThumbRecommendationEngine(constraints: .none)
        let counts = ["f": 9999, ";": 1]
        let recs = engineNoConstraints.topRecommendations(from: counts, layout: layout)
        XCTAssertFalse(recs.map { $0.key }.contains("f"), "'f' is an index key — burden would increase")
    }

    // MARK: - 6. Zero-count key is excluded

    func test_zeroCount_isExcluded() {
        let counts = [";": 0]
        let recs = engine.topRecommendations(from: counts, layout: layout)
        XCTAssertTrue(recs.isEmpty, "zero-count keys must be skipped")
    }

    // MARK: - 7. topK limits result count

    func test_topK_limitsResults() {
        // Provide more candidates than topK=3.
        let engineK3 = ThumbRecommendationEngine(
            fingerWeights: .default,
            constraints: .none,
            topK: 3
        )
        // Use pinky/ring keys not in fingerTable guard (skip unknown keys).
        // ";", "'", "p" are all right-pinky; "." and "o" are right-ring.
        let counts = [";": 100, "'": 90, "p": 80, ".": 70, "o": 60]
        let recs = engineK3.topRecommendations(from: counts, layout: layout)
        XCTAssertLessThanOrEqual(recs.count, 3)
    }

    // MARK: - 8. Slot assignment corrects thumb imbalance

    func test_slotAssignment_leftHeavy_firstSlotIsRight() {
        // Make left thumb very heavy by including many Space presses.
        // Space is left thumb → leftThumbCount >> rightThumbCount.
        // First recommendation should go to .right to correct imbalance.
        let counts = ["Space": 10000, ";": 500, "'": 400]
        let recs = engine.topRecommendations(from: counts, layout: layout)
        guard let first = recs.first else {
            return XCTFail("Expected at least one recommendation")
        }
        XCTAssertEqual(first.suggestedSlot, ThumbSlot.right,
                       "left-heavy thumb load → first slot should be .right to correct imbalance")
    }

    func test_slotAssignment_alternates() {
        // With two recommendations and left-heavy load, slots should be .right, .left.
        let counts = ["Space": 10000, ";": 500, "'": 400]
        let recs = engine.topRecommendations(from: counts, layout: layout)
        guard recs.count >= 2 else { return }
        XCTAssertEqual(recs[0].suggestedSlot, ThumbSlot.right)
        XCTAssertEqual(recs[1].suggestedSlot, ThumbSlot.left)
    }

    // MARK: - 9. Empty counts returns empty result

    func test_emptyCounts_returnsEmpty() {
        let recs = engine.topRecommendations(from: [:], layout: layout)
        XCTAssertTrue(recs.isEmpty)
    }
}
