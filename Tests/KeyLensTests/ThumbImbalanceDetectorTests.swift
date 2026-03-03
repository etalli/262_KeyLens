import XCTest
@testable import KeyLensCore

// Tests for ThumbImbalanceDetector (Issue #26 — Phase 1).
//
// ## What is being tested
//
// 1. imbalanceRatio computation
//    Formula: |left - right| / total
//
//    Key cases:
//      empty counts        → nil  (no thumb keystrokes)
//      left=50, right=50   → 0.0  (perfectly balanced)
//      left=80, right=20   → 0.6  (left-heavy)
//      left=20, right=80   → 0.6  (right-heavy, symmetric)
//      left=100, right=0   → 1.0  (one side only)
//
// 2. isImbalanced threshold
//    Returns true when ratio > threshold (default 0.3).
//    Boundary: ratio == threshold is NOT imbalanced (strict >).
//
// 3. Configurable threshold
//    Custom threshold must be honoured.
//
// 4. Default static values
//    ThumbImbalanceDetector.default.threshold == 0.3
//
// 5. LayoutRegistry integration
//    The shared registry must expose thumbImbalanceDetector.
//    Replacing it with a custom instance must take effect immediately.
//
// 左右の親指使用量の計算・閾値判定・設定可能パラメータ・LayoutRegistry統合をテストする。

final class ThumbImbalanceDetectorTests: XCTestCase {

    let detector = ThumbImbalanceDetector.default

    // MARK: - Helper: build a mock counts dictionary

    /// Creates a counts dict with `left` presses on "Space" and `right` on a right-thumb key.
    /// Uses keyCodes known to resolve to right thumb via ANSILayout.table fallback.
    private func thumbCounts(left: Int, right: Int) -> [String: Int] {
        var d: [String: Int] = [:]
        if left  > 0 { d["Space"] = left }       // left thumb
        if right > 0 { d["Key(54)"] = right }    // Right Cmd keyCode → right thumb via fallback
        return d
    }

    // MARK: - imbalanceRatio: nil when empty

    func testImbalanceRatio_emptyCountsReturnsNil() {
        XCTAssertNil(detector.imbalanceRatio(counts: [:], layout: LayoutRegistry.shared))
    }

    func testImbalanceRatio_noThumbKeysReturnsNil() {
        // Only non-thumb keys — ratio must be nil.
        let counts = ["a": 10, "s": 5, "f": 3]
        XCTAssertNil(detector.imbalanceRatio(counts: counts, layout: LayoutRegistry.shared))
    }

    // MARK: - imbalanceRatio: balanced

    func testImbalanceRatio_perfectlyBalanced() {
        // left=50, right=50 → |50-50|/100 = 0.0
        let counts = thumbCounts(left: 50, right: 50)
        let ratio = detector.imbalanceRatio(counts: counts, layout: LayoutRegistry.shared)
        XCTAssertEqual(ratio!, 0.0, accuracy: 1e-10)
    }

    // MARK: - imbalanceRatio: one side heavier

    func testImbalanceRatio_leftHeavy() {
        // left=80, right=20 → |80-20|/100 = 0.6
        let counts = thumbCounts(left: 80, right: 20)
        let ratio = detector.imbalanceRatio(counts: counts, layout: LayoutRegistry.shared)
        XCTAssertEqual(ratio!, 0.6, accuracy: 1e-10)
    }

    func testImbalanceRatio_rightHeavy() {
        // left=20, right=80 → 0.6 (symmetric with left-heavy)
        let counts = thumbCounts(left: 20, right: 80)
        let ratio = detector.imbalanceRatio(counts: counts, layout: LayoutRegistry.shared)
        XCTAssertEqual(ratio!, 0.6, accuracy: 1e-10)
    }

    func testImbalanceRatio_leftOnly() {
        // left=100, right=0 → maximum imbalance = 1.0
        let counts = thumbCounts(left: 100, right: 0)
        let ratio = detector.imbalanceRatio(counts: counts, layout: LayoutRegistry.shared)
        XCTAssertEqual(ratio!, 1.0, accuracy: 1e-10)
    }

    func testImbalanceRatio_rightOnly() {
        // left=0, right=100 → maximum imbalance = 1.0
        let counts = thumbCounts(left: 0, right: 100)
        let ratio = detector.imbalanceRatio(counts: counts, layout: LayoutRegistry.shared)
        XCTAssertEqual(ratio!, 1.0, accuracy: 1e-10)
    }

    // MARK: - imbalanceRatio: mixed with non-thumb keys

    func testImbalanceRatio_ignoresNonThumbKeys() {
        // Non-thumb keys must not affect the ratio.
        var counts = thumbCounts(left: 80, right: 20)
        counts["a"] = 500   // left index — should be ignored
        counts["j"] = 300   // right index — should be ignored
        let ratio = detector.imbalanceRatio(counts: counts, layout: LayoutRegistry.shared)
        XCTAssertEqual(ratio!, 0.6, accuracy: 1e-10)
    }

    // MARK: - isImbalanced threshold

    func testIsImbalanced_belowThreshold_returnsFalse() {
        // ratio = 0.0 < threshold 0.3
        let counts = thumbCounts(left: 50, right: 50)
        XCTAssertFalse(detector.isImbalanced(counts: counts, layout: LayoutRegistry.shared))
    }

    func testIsImbalanced_atThreshold_returnsFalse() {
        // ratio == threshold is NOT considered imbalanced (strict >).
        // left=65, right=35 → |65-35|/100 = 0.30 (exactly at threshold)
        let counts = thumbCounts(left: 65, right: 35)
        XCTAssertFalse(detector.isImbalanced(counts: counts, layout: LayoutRegistry.shared))
    }

    func testIsImbalanced_aboveThreshold_returnsTrue() {
        // ratio = 0.6 > threshold 0.3
        let counts = thumbCounts(left: 80, right: 20)
        XCTAssertTrue(detector.isImbalanced(counts: counts, layout: LayoutRegistry.shared))
    }

    func testIsImbalanced_emptyCounts_returnsFalse() {
        // No thumb keys → ratio nil → treated as not imbalanced.
        XCTAssertFalse(detector.isImbalanced(counts: [:], layout: LayoutRegistry.shared))
    }

    // MARK: - Configurable threshold

    func testCustomThreshold_tighter() {
        // threshold = 0.1: even a small imbalance triggers it.
        let strict = ThumbImbalanceDetector(threshold: 0.1)
        let counts = thumbCounts(left: 60, right: 40)  // ratio = 0.2
        XCTAssertTrue(strict.isImbalanced(counts: counts, layout: LayoutRegistry.shared))
    }

    func testCustomThreshold_looser() {
        // threshold = 0.7: only extreme imbalance triggers it.
        let loose = ThumbImbalanceDetector(threshold: 0.7)
        let counts = thumbCounts(left: 80, right: 20)  // ratio = 0.6
        XCTAssertFalse(loose.isImbalanced(counts: counts, layout: LayoutRegistry.shared))
    }

    // MARK: - Default value

    func testDefault_threshold() {
        XCTAssertEqual(ThumbImbalanceDetector.default.threshold, 0.3)
    }

    // MARK: - Equatable

    func testEquatable_sameThreshold() {
        XCTAssertEqual(ThumbImbalanceDetector(threshold: 0.3), ThumbImbalanceDetector(threshold: 0.3))
    }

    func testEquatable_differentThreshold() {
        XCTAssertNotEqual(ThumbImbalanceDetector(threshold: 0.3), ThumbImbalanceDetector(threshold: 0.5))
    }

    // MARK: - LayoutRegistry integration

    func testLayoutRegistry_hasDefaultDetector() {
        XCTAssertEqual(LayoutRegistry.shared.thumbImbalanceDetector, ThumbImbalanceDetector.default)
    }

    func testLayoutRegistry_detectorReplacement() {
        let custom = ThumbImbalanceDetector(threshold: 0.1)
        LayoutRegistry.shared.thumbImbalanceDetector = custom
        defer { LayoutRegistry.shared.thumbImbalanceDetector = .default }

        XCTAssertEqual(LayoutRegistry.shared.thumbImbalanceDetector, custom)
        // With threshold=0.1, a 60:40 split should be flagged.
        let counts = thumbCounts(left: 60, right: 40)
        XCTAssertTrue(LayoutRegistry.shared.thumbImbalanceDetector
            .isImbalanced(counts: counts, layout: LayoutRegistry.shared))
    }
}
