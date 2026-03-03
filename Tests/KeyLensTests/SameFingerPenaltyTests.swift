import XCTest
import CoreGraphics
@testable import KeyLensCore

// Tests for SameFingerPenalty (Issue #24 — Phase 1).
//
// ## What is being tested
//
// 1. Distance tier classification
//    Given two KeyPositions, `tier(from:to:)` must return the correct tier based
//    on row distance. This is the decision boundary for how severe a same-finger
//    bigram is considered.
//
// 2. Penalty values per tier (default exponent = 2.0)
//    penalty = finger_weight × factor² must produce the expected values:
//      sameKey  (factor 0.5): weight × 0.25
//      adjacent (factor 1.0): weight × 1.0
//      oneRow   (factor 2.0): weight × 4.0
//      multiRow (factor 4.0): weight × 16.0
//
// 3. Configurable exponent
//    With exponent = 1.0 (linear), penalty = weight × factor (no squaring).
//    This verifies the formula is not hardcoded.
//
// 4. LayoutRegistry end-to-end via key name bigram strings
//    sameFingerPenalty(for: "f→g") chains:
//      key name → finger/hand → KeyPosition → tier → penalty
//    Cross-hand bigrams (e.g. "f→j") must return nil — they are not same-finger.
//
// 距離ティア分類・ペナルティ計算・キー名エンドツーエンドの3軸でテストする。
// 異手ビグラム（f→j）は nil を返すことを確認する。

final class SameFingerPenaltyTests: XCTestCase {

    let model = SameFingerPenalty.default

    // Helper: build a KeyPosition without importing the full table.
    // テーブルを参照せずにテスト用の KeyPosition を生成するヘルパー。
    private func pos(_ row: Int, _ col: Int) -> KeyPosition {
        KeyPosition(row: row, column: col, hand: .left, finger: .index)
    }

    // MARK: - Distance tier classification

    func testTier_sameKey() {
        // Identical positions → key repeat (e.g. Space Space).
        let p = pos(2, 4)
        XCTAssertEqual(model.tier(from: p, to: p), .sameKey)
    }

    func testTier_adjacent_sameRowDifferentColumn() {
        // f(2,4) → g(2,5): same row, 1 column apart — index finger lateral stretch.
        // f(2,4) → g(2,5): 同行・隣接列 — 人差し指の横伸び。
        let f = pos(2, 4)
        let g = pos(2, 5)
        XCTAssertEqual(model.tier(from: f, to: g), .adjacent)
        XCTAssertEqual(model.tier(from: g, to: f), .adjacent)  // symmetric
    }

    func testTier_adjacent_largeColumnGap_sameRow() {
        // Same row but many columns apart still counts as adjacent (row diff = 0).
        let left  = pos(2, 0)
        let right = pos(2, 10)
        XCTAssertEqual(model.tier(from: left, to: right), .adjacent)
    }

    func testTier_oneRow() {
        // f(2,4) → r(1,4): 1 row apart — home row to top alpha row.
        // f(2,4) → r(1,4): ホームロウ→上の行。
        let f = pos(2, 4)
        let r = pos(1, 4)
        XCTAssertEqual(model.tier(from: f, to: r), .oneRow)
        XCTAssertEqual(model.tier(from: r, to: f), .oneRow)  // symmetric
    }

    func testTier_multiRow_twoRows() {
        // f(2,4) → 4(0,5): 2 rows apart — home row to number row.
        // f(2,4) → 4(0,5): ホームロウ→数字行（2行差）。
        let f     = pos(2, 4)
        let num4  = pos(0, 5)
        XCTAssertEqual(model.tier(from: f, to: num4), .multiRow)
    }

    func testTier_multiRow_threeRows() {
        // Function row (row 5) to home row (row 2): 3 rows apart.
        let fn = pos(5, 4)
        let hr = pos(2, 4)
        XCTAssertEqual(model.tier(from: fn, to: hr), .multiRow)
    }

    // MARK: - Factor values

    func testFactor_sameKey()  { XCTAssertEqual(model.factor(for: .sameKey),  0.5) }
    func testFactor_adjacent() { XCTAssertEqual(model.factor(for: .adjacent), 1.0) }
    func testFactor_oneRow()   { XCTAssertEqual(model.factor(for: .oneRow),   2.0) }
    func testFactor_multiRow() { XCTAssertEqual(model.factor(for: .multiRow), 4.0) }

    // MARK: - Penalty values (default exponent = 2.0, finger_weight = 1.0)
    //
    // penalty = finger_weight × factor²
    // With weight=1.0 the expected values are: 0.25, 1.0, 4.0, 16.0

    func testPenalty_sameKey_indexWeight() {
        // index weight = 1.0, factor 0.5² = 0.25
        XCTAssertEqual(model.penalty(from: pos(2,4), to: pos(2,4), fingerWeight: 1.0), 0.25)
    }

    func testPenalty_adjacent_indexWeight() {
        // 1.0 × 1.0² = 1.0
        XCTAssertEqual(model.penalty(from: pos(2,4), to: pos(2,5), fingerWeight: 1.0), 1.0)
    }

    func testPenalty_oneRow_indexWeight() {
        // 1.0 × 2.0² = 4.0
        XCTAssertEqual(model.penalty(from: pos(2,4), to: pos(1,4), fingerWeight: 1.0), 4.0)
    }

    func testPenalty_multiRow_indexWeight() {
        // 1.0 × 4.0² = 16.0
        XCTAssertEqual(model.penalty(from: pos(2,4), to: pos(0,5), fingerWeight: 1.0), 16.0)
    }

    func testPenalty_oneRow_pinkyWeight() {
        // pinky weight = 0.5 → 0.5 × 4.0 = 2.0
        // 小指（重み 0.5）で1行差ビグラム → ペナルティ 2.0。
        XCTAssertEqual(model.penalty(from: pos(2,0), to: pos(1,0), fingerWeight: 0.5), 2.0)
    }

    func testPenalty_multiRow_pinkyWeight() {
        // pinky weight = 0.5 → 0.5 × 16.0 = 8.0
        XCTAssertEqual(model.penalty(from: pos(2,0), to: pos(0,0), fingerWeight: 0.5), 8.0)
    }

    // MARK: - Configurable exponent

    func testPenalty_linearExponent() {
        // exponent = 1.0: penalty = weight × factor (no squaring)
        // 指数 1.0 のとき二乗しない（線形ペナルティ）。
        let linear = SameFingerPenalty(exponent: 1.0)
        XCTAssertEqual(linear.penalty(from: pos(2,4), to: pos(1,4), fingerWeight: 1.0), 2.0)
        XCTAssertEqual(linear.penalty(from: pos(2,4), to: pos(0,5), fingerWeight: 1.0), 4.0)
    }

    func testPenalty_cubicExponent() {
        // exponent = 3.0: 1.0 × 2.0³ = 8.0 for oneRow
        let cubic = SameFingerPenalty(exponent: 3.0)
        XCTAssertEqual(cubic.penalty(from: pos(2,4), to: pos(1,4), fingerWeight: 1.0), 8.0)
    }

    // MARK: - LayoutRegistry end-to-end

    // These tests use real ANSILayout key positions via positionNameTable.
    // 実際の ANSILayout を通じてキー名→位置→ペナルティの変換を検証する。

    func testSameFingerPenalty_adjacent_fToG() {
        // f(2,4) → g(2,5): left index, adjacent, weight=1.0 → 1.0 × 1.0² = 1.0
        let p = LayoutRegistry.shared.sameFingerPenalty(for: "f→g")
        XCTAssertEqual(p, 1.0)
    }

    func testSameFingerPenalty_oneRow_fToR() {
        // f(2,4) → r(1,4): left index, oneRow, weight=1.0 → 1.0 × 2.0² = 4.0
        let p = LayoutRegistry.shared.sameFingerPenalty(for: "f→r")
        XCTAssertEqual(p, 4.0)
    }

    func testSameFingerPenalty_multiRow_fTo4() {
        // f(2,4) → 4(0,5): left index, multiRow, weight=1.0 → 1.0 × 4.0² = 16.0
        let p = LayoutRegistry.shared.sameFingerPenalty(for: "f→4")
        XCTAssertEqual(p, 16.0)
    }

    func testSameFingerPenalty_sameKey_space() {
        // Space→Space: left thumb, sameKey, weight=0.8 → 0.8 × 0.5² = 0.2
        let p = LayoutRegistry.shared.sameFingerPenalty(for: "Space→Space")
        XCTAssertEqual(p!, 0.2, accuracy: 1e-10)
    }

    func testSameFingerPenalty_crossHand_returnsNil() {
        // f = left index, j = right index — same finger TYPE but different hands.
        // This is hand alternation (good), not a same-finger bigram.
        // f（左人差し指）→j（右人差し指）は手交互打鍵。同指ビグラムではないため nil。
        XCTAssertNil(LayoutRegistry.shared.sameFingerPenalty(for: "f→j"))
    }

    func testSameFingerPenalty_differentFinger_returnsNil() {
        // f (index) → s (ring): different fingers → nil
        XCTAssertNil(LayoutRegistry.shared.sameFingerPenalty(for: "f→s"))
    }

    func testSameFingerPenalty_unknownKey_returnsNil() {
        XCTAssertNil(LayoutRegistry.shared.sameFingerPenalty(for: "unknown→f"))
        XCTAssertNil(LayoutRegistry.shared.sameFingerPenalty(for: "🖱Left→f"))
    }

    func testSameFingerPenalty_malformedBigram_returnsNil() {
        // No "→" separator
        XCTAssertNil(LayoutRegistry.shared.sameFingerPenalty(for: "fg"))
        XCTAssertNil(LayoutRegistry.shared.sameFingerPenalty(for: ""))
    }

    // MARK: - positionNameTable coverage

    func testPositionNameTable_homeRowKeys() {
        let layout = ANSILayout()
        // Verify a selection of home-row keys are present in the table.
        for key in ["a", "s", "d", "f", "g", "h", "j", "k", "l"] {
            XCTAssertNotNil(layout.position(for: key), "Missing position for '\(key)'")
        }
    }

    func testPositionNameTable_spaceAndModifiers() {
        let layout = ANSILayout()
        XCTAssertNotNil(layout.position(for: "Space"))
        XCTAssertNotNil(layout.position(for: "⌘Cmd"))
        XCTAssertNotNil(layout.position(for: "⇧Shift"))
    }

    func testPositionNameTable_unknownReturnsNil() {
        let layout = ANSILayout()
        XCTAssertNil(layout.position(for: "🖱Left"))
        XCTAssertNil(layout.position(for: "unknown"))
    }
}
