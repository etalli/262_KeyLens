import XCTest
@testable import KeyLensCore

// Tests for HighStrainDetector (Issue #28 — Phase 1).
//
// ## What is being tested
//
// 1. isHighStrain(tier:) — tier qualification by minimumTier
//    Default minimumTier = .oneRow:
//      .sameKey  → false  (key repeat, not a strain concern)
//      .adjacent → false  (same-row lateral reach, below threshold)
//      .oneRow   → true   (1 row vertical travel)
//      .multiRow → true   (2+ rows vertical travel)
//
// 2. isHighStrain(from:to:layout:) — full bigram classification
//    Uses ANSILayout key positions via LayoutRegistry.shared:
//      f→r: left index, oneRow    → true
//      f→4: left index, multiRow  → true
//      f→g: left index, adjacent  → false (below minimumTier)
//      f→f: left index, sameKey   → false
//      f→j: cross-hand (index/index but different hands) → false
//      f→s: different finger (index vs ring) → false
//      unknown→f: unknown key → false
//
// 3. Configurable minimumTier
//    minimumTier=.adjacent: f→g → true (adjacent now qualifies)
//    minimumTier=.multiRow: f→r → false (oneRow no longer qualifies)
//
// 4. Default static value
//    HighStrainDetector.default.minimumTier == .oneRow
//
// 5. LayoutRegistry integration
//    The shared registry must expose highStrainDetector.
//
// 距離ティア判定・キー名ビグラム分類・設定可能パラメータ・LayoutRegistry統合をテストする。

final class HighStrainDetectorTests: XCTestCase {

    let detector = HighStrainDetector.default  // minimumTier = .oneRow

    // MARK: - isHighStrain(tier:) — default minimumTier = .oneRow

    func testTier_sameKey_isFalse() {
        XCTAssertFalse(detector.isHighStrain(tier: .sameKey))
    }

    func testTier_adjacent_isFalse() {
        XCTAssertFalse(detector.isHighStrain(tier: .adjacent))
    }

    func testTier_oneRow_isTrue() {
        XCTAssertTrue(detector.isHighStrain(tier: .oneRow))
    }

    func testTier_multiRow_isTrue() {
        XCTAssertTrue(detector.isHighStrain(tier: .multiRow))
    }

    // MARK: - isHighStrain(from:to:layout:) — key name bigrams via ANSILayout

    func testBigram_fToR_isHighStrain() {
        // f(2,4) → r(1,4): left index, oneRow → true
        XCTAssertTrue(detector.isHighStrain(from: "f", to: "r", layout: LayoutRegistry.shared))
    }

    func testBigram_fTo4_isHighStrain() {
        // f(2,4) → 4(0,5): left index, multiRow → true
        XCTAssertTrue(detector.isHighStrain(from: "f", to: "4", layout: LayoutRegistry.shared))
    }

    func testBigram_fToG_isNotHighStrain() {
        // f(2,4) → g(2,5): left index, adjacent → false (below minimumTier)
        XCTAssertFalse(detector.isHighStrain(from: "f", to: "g", layout: LayoutRegistry.shared))
    }

    func testBigram_fToF_isNotHighStrain() {
        // f → f: sameKey → false
        XCTAssertFalse(detector.isHighStrain(from: "f", to: "f", layout: LayoutRegistry.shared))
    }

    func testBigram_crossHand_isNotHighStrain() {
        // f (left index) → j (right index): different hands → false (hand alternation)
        XCTAssertFalse(detector.isHighStrain(from: "f", to: "j", layout: LayoutRegistry.shared))
    }

    func testBigram_differentFinger_isNotHighStrain() {
        // f (index) → s (ring): different fingers → false
        XCTAssertFalse(detector.isHighStrain(from: "f", to: "s", layout: LayoutRegistry.shared))
    }

    func testBigram_unknownKey_isNotHighStrain() {
        XCTAssertFalse(detector.isHighStrain(from: "unknown", to: "f", layout: LayoutRegistry.shared))
        XCTAssertFalse(detector.isHighStrain(from: "f", to: "unknown", layout: LayoutRegistry.shared))
    }

    func testBigram_symmetry() {
        // r→f should behave the same as f→r (same tier, same finger)
        XCTAssertTrue(detector.isHighStrain(from: "r", to: "f", layout: LayoutRegistry.shared))
    }

    // MARK: - Configurable minimumTier

    func testCustom_minimumTierAdjacent_fToGIsHighStrain() {
        // With minimumTier=.adjacent, lateral stretch on same row now qualifies.
        let loose = HighStrainDetector(minimumTier: .adjacent)
        XCTAssertTrue(loose.isHighStrain(from: "f", to: "g", layout: LayoutRegistry.shared))
    }

    func testCustom_minimumTierAdjacent_sameKeyIsNotHighStrain() {
        let loose = HighStrainDetector(minimumTier: .adjacent)
        XCTAssertFalse(loose.isHighStrain(from: "f", to: "f", layout: LayoutRegistry.shared))
    }

    func testCustom_minimumTierMultiRow_oneRowIsNotHighStrain() {
        // With minimumTier=.multiRow, f→r (oneRow) no longer qualifies.
        let strict = HighStrainDetector(minimumTier: .multiRow)
        XCTAssertFalse(strict.isHighStrain(from: "f", to: "r", layout: LayoutRegistry.shared))
    }

    func testCustom_minimumTierMultiRow_multiRowIsHighStrain() {
        let strict = HighStrainDetector(minimumTier: .multiRow)
        XCTAssertTrue(strict.isHighStrain(from: "f", to: "4", layout: LayoutRegistry.shared))
    }

    func testCustom_minimumTierSameKey_allTiersQualify() {
        // minimumTier=.sameKey: even key repeat qualifies.
        let all = HighStrainDetector(minimumTier: .sameKey)
        // f→f is same finger, but sameKey tier — with minimumTier=.sameKey it qualifies.
        XCTAssertTrue(all.isHighStrain(tier: .sameKey))
        XCTAssertTrue(all.isHighStrain(tier: .adjacent))
        XCTAssertTrue(all.isHighStrain(tier: .oneRow))
        XCTAssertTrue(all.isHighStrain(tier: .multiRow))
    }

    // MARK: - Default value

    func testDefault_minimumTier() {
        XCTAssertEqual(HighStrainDetector.default.minimumTier, .oneRow)
    }

    // MARK: - Equatable

    func testEquatable_sameTier() {
        XCTAssertEqual(HighStrainDetector(minimumTier: .oneRow), HighStrainDetector(minimumTier: .oneRow))
    }

    func testEquatable_differentTier() {
        XCTAssertNotEqual(HighStrainDetector(minimumTier: .oneRow), HighStrainDetector(minimumTier: .multiRow))
    }

    // MARK: - LayoutRegistry integration

    func testLayoutRegistry_hasDefaultDetector() {
        XCTAssertEqual(LayoutRegistry.shared.highStrainDetector, HighStrainDetector.default)
    }

    func testLayoutRegistry_detectorReplacement() {
        let strict = HighStrainDetector(minimumTier: .multiRow)
        LayoutRegistry.shared.highStrainDetector = strict
        defer { LayoutRegistry.shared.highStrainDetector = .default }

        XCTAssertEqual(LayoutRegistry.shared.highStrainDetector, strict)
        // f→r is oneRow — should NOT be high-strain with minimumTier=.multiRow
        XCTAssertFalse(LayoutRegistry.shared.highStrainDetector
            .isHighStrain(from: "f", to: "r", layout: LayoutRegistry.shared))
        // f→4 is multiRow — should still be high-strain
        XCTAssertTrue(LayoutRegistry.shared.highStrainDetector
            .isHighStrain(from: "f", to: "4", layout: LayoutRegistry.shared))
    }
}
