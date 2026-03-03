import XCTest
@testable import KeyLensCore

// Tests for ThumbEfficiencyCalculator (Issue #27 — Phase 1).
//
// ## What is being tested
//
// 1. coefficient computation
//    Formula: thumb_count / (total_count × expectedThumbRatio)
//
//    Key cases (default ratio = 0.15):
//      empty counts                   → nil
//      thumb = 15%, total = 100       → 1.0  (exactly at expected)
//      thumb = 30%, total = 100       → 2.0  (twice expected — efficient)
//      thumb = 7.5%, total = 200      → 0.5  (half expected — underutilised)
//      all thumb keys, no others      → very high coefficient
//
// 2. Configurable expectedThumbRatio
//    Custom ratio must be honoured; zero ratio returns nil.
//
// 3. Non-thumb keys are excluded from thumbCount but included in totalCount.
//
// 4. Default static value
//    ThumbEfficiencyCalculator.default.expectedThumbRatio == 0.15
//
// 5. LayoutRegistry integration
//    The shared registry must expose thumbEfficiencyCalculator.
//
// 親指効率係数の計算・設定可能パラメータ・LayoutRegistry統合をテストする。

final class ThumbEfficiencyCalculatorTests: XCTestCase {

    let calc = ThumbEfficiencyCalculator.default   // expectedThumbRatio = 0.15

    // MARK: - Helper

    /// Builds a counts dictionary with `thumbCount` presses on "Space" (left thumb)
    /// and `otherCount` presses on "a" (non-thumb key).
    private func counts(thumb: Int, other: Int) -> [String: Int] {
        var d: [String: Int] = [:]
        if thumb > 0 { d["Space"] = thumb }
        if other > 0 { d["a"]     = other }
        return d
    }

    // MARK: - nil cases

    func testCoefficient_emptyCountsReturnsNil() {
        XCTAssertNil(calc.coefficient(counts: [:], layout: LayoutRegistry.shared))
    }

    func testCoefficient_zeroExpectedRatioReturnsNil() {
        let c = ThumbEfficiencyCalculator(expectedThumbRatio: 0.0)
        XCTAssertNil(c.coefficient(counts: counts(thumb: 10, other: 90), layout: LayoutRegistry.shared))
    }

    func testCoefficient_noKeystrokesReturnsNil() {
        // All counts are 0 — total is 0.
        XCTAssertNil(calc.coefficient(counts: ["Space": 0, "a": 0], layout: LayoutRegistry.shared))
    }

    // MARK: - Coefficient = 1.0 (exactly at expected)

    func testCoefficient_atExpectedRatio() {
        // thumb=15, total=100 → 15 / (100 × 0.15) = 1.0
        let c = counts(thumb: 15, other: 85)
        XCTAssertEqual(calc.coefficient(counts: c, layout: LayoutRegistry.shared)!, 1.0, accuracy: 1e-10)
    }

    // MARK: - Coefficient > 1.0 (efficient)

    func testCoefficient_overUtilised() {
        // thumb=30, total=100 → 30 / (100 × 0.15) = 2.0
        let c = counts(thumb: 30, other: 70)
        XCTAssertEqual(calc.coefficient(counts: c, layout: LayoutRegistry.shared)!, 2.0, accuracy: 1e-10)
    }

    func testCoefficient_allThumbKeys() {
        // thumb=100, total=100 → 100 / (100 × 0.15) ≈ 6.67
        let c = ["Space": 100]
        let coeff = calc.coefficient(counts: c, layout: LayoutRegistry.shared)!
        XCTAssertEqual(coeff, 1.0 / 0.15, accuracy: 1e-10)
        XCTAssertGreaterThan(coeff, 1.0)
    }

    // MARK: - Coefficient < 1.0 (underutilised)

    func testCoefficient_underUtilised() {
        // thumb=15, total=200 → 15 / (200 × 0.15) = 0.5
        let c = counts(thumb: 15, other: 185)
        XCTAssertEqual(calc.coefficient(counts: c, layout: LayoutRegistry.shared)!, 0.5, accuracy: 1e-10)
    }

    func testCoefficient_noThumbKeys() {
        // thumb=0, total=100 → 0 / (100 × 0.15) = 0.0
        let c = ["a": 50, "s": 50]
        XCTAssertEqual(calc.coefficient(counts: c, layout: LayoutRegistry.shared)!, 0.0, accuracy: 1e-10)
    }

    // MARK: - Non-thumb keys contribute to total but not thumbCount

    func testCoefficient_nonThumbKeysCountedInTotal() {
        // thumb=10, alpha=90, total=100 → 10 / (100 × 0.15) ≈ 0.667
        let c: [String: Int] = ["Space": 10, "a": 50, "s": 40]
        let expected = 10.0 / (100.0 * 0.15)
        XCTAssertEqual(calc.coefficient(counts: c, layout: LayoutRegistry.shared)!, expected, accuracy: 1e-10)
    }

    // MARK: - Configurable expectedThumbRatio

    func testCustomRatio_higher() {
        // expectedThumbRatio = 0.30: thumb=15, total=100 → 15 / (100 × 0.30) = 0.5
        let c2 = ThumbEfficiencyCalculator(expectedThumbRatio: 0.30)
        let c = counts(thumb: 15, other: 85)
        XCTAssertEqual(c2.coefficient(counts: c, layout: LayoutRegistry.shared)!, 0.5, accuracy: 1e-10)
    }

    func testCustomRatio_lower() {
        // expectedThumbRatio = 0.10: thumb=15, total=100 → 15 / (100 × 0.10) = 1.5
        let c2 = ThumbEfficiencyCalculator(expectedThumbRatio: 0.10)
        let c = counts(thumb: 15, other: 85)
        XCTAssertEqual(c2.coefficient(counts: c, layout: LayoutRegistry.shared)!, 1.5, accuracy: 1e-10)
    }

    // MARK: - Default value

    func testDefault_expectedThumbRatio() {
        XCTAssertEqual(ThumbEfficiencyCalculator.default.expectedThumbRatio, 0.15)
    }

    // MARK: - Equatable

    func testEquatable_sameRatio() {
        XCTAssertEqual(
            ThumbEfficiencyCalculator(expectedThumbRatio: 0.15),
            ThumbEfficiencyCalculator(expectedThumbRatio: 0.15)
        )
    }

    func testEquatable_differentRatio() {
        XCTAssertNotEqual(
            ThumbEfficiencyCalculator(expectedThumbRatio: 0.15),
            ThumbEfficiencyCalculator(expectedThumbRatio: 0.20)
        )
    }

    // MARK: - LayoutRegistry integration

    func testLayoutRegistry_hasDefaultCalculator() {
        XCTAssertEqual(LayoutRegistry.shared.thumbEfficiencyCalculator, ThumbEfficiencyCalculator.default)
    }

    func testLayoutRegistry_calculatorReplacement() {
        let custom = ThumbEfficiencyCalculator(expectedThumbRatio: 0.30)
        LayoutRegistry.shared.thumbEfficiencyCalculator = custom
        defer { LayoutRegistry.shared.thumbEfficiencyCalculator = .default }

        XCTAssertEqual(LayoutRegistry.shared.thumbEfficiencyCalculator, custom)
        // thumb=15, total=100, ratio=0.30 → 15/(100×0.30) = 0.5
        let c = counts(thumb: 15, other: 85)
        let coeff = LayoutRegistry.shared.thumbEfficiencyCalculator
            .coefficient(counts: c, layout: LayoutRegistry.shared)
        XCTAssertEqual(coeff!, 0.5, accuracy: 1e-10)
    }
}
