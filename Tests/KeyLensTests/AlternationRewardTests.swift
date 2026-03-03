import XCTest
@testable import KeyLensCore

// Tests for AlternationReward (Issue #25 — Phase 1).
//
// ## What is being tested
//
// 1. reward(forStreak:) — boundary values around streakThreshold
//    The function must return baseReward for streaks below threshold, and
//    baseReward × streakMultiplier at and above threshold.
//
//    Default (baseReward=1.0, threshold=3, multiplier=1.5):
//      streak 0: undefined (no alternation), but tested for safety
//      streak 1: 1.0 × 1.0 = 1.0  (below threshold)
//      streak 2: 1.0 × 1.0 = 1.0  (still below)
//      streak 3: 1.0 × 1.5 = 1.5  (threshold reached)
//      streak 4: 1.0 × 1.5 = 1.5  (continuing streak)
//
// 2. Configurable parameters
//    Custom baseReward, threshold, and multiplier must all be honoured.
//    These verify the formula is not hardcoded.
//
// 3. Default static values
//    AlternationReward.default must match the documented defaults.
//
// 4. LayoutRegistry model replacement
//    The shared registry must expose alternationRewardModel, and replacing
//    it (non-default values) must produce the new reward immediately.
//
// ストリーク閾値前後の境界値・設定可能パラメータ・LayoutRegistryへの統合をテストする。

final class AlternationRewardTests: XCTestCase {

    let model = AlternationReward.default

    // MARK: - reward(forStreak:) — below threshold

    func testReward_streak1_belowThreshold() {
        // First alternating pair: streak=1 < threshold(3) → baseReward × 1.0
        XCTAssertEqual(model.reward(forStreak: 1), 1.0)
    }

    func testReward_streak2_belowThreshold() {
        // Second consecutive alternating pair: streak=2 < threshold(3) → 1.0
        XCTAssertEqual(model.reward(forStreak: 2), 1.0)
    }

    // MARK: - reward(forStreak:) — at and above threshold

    func testReward_streak3_atThreshold() {
        // streak=3 == threshold → streakMultiplier kicks in → 1.0 × 1.5 = 1.5
        XCTAssertEqual(model.reward(forStreak: 3), 1.5)
    }

    func testReward_streak4_aboveThreshold() {
        // streak=4 > threshold → still uses multiplier → 1.5
        XCTAssertEqual(model.reward(forStreak: 4), 1.5)
    }

    func testReward_streak10_aboveThreshold() {
        // Long streak — multiplier should continue to apply.
        XCTAssertEqual(model.reward(forStreak: 10), 1.5)
    }

    // MARK: - Streak=0 edge case

    func testReward_streak0_returnsBase() {
        // streak=0 is below threshold — returns baseReward (no reward fires in practice,
        // but the function must not crash).
        XCTAssertEqual(model.reward(forStreak: 0), 1.0)
    }

    // MARK: - Default values

    func testDefault_baseReward() {
        XCTAssertEqual(AlternationReward.default.baseReward, 1.0)
    }

    func testDefault_streakThreshold() {
        XCTAssertEqual(AlternationReward.default.streakThreshold, 3)
    }

    func testDefault_streakMultiplier() {
        XCTAssertEqual(AlternationReward.default.streakMultiplier, 1.5)
    }

    // MARK: - Configurable parameters

    func testCustom_baseReward() {
        // baseReward = 2.0: all rewards are doubled.
        let m = AlternationReward(baseReward: 2.0, streakThreshold: 3, streakMultiplier: 1.5)
        XCTAssertEqual(m.reward(forStreak: 1), 2.0)   // below threshold
        XCTAssertEqual(m.reward(forStreak: 3), 3.0)   // 2.0 × 1.5
    }

    func testCustom_streakThreshold() {
        // threshold = 2: multiplier fires at streak=2 instead of 3.
        let m = AlternationReward(baseReward: 1.0, streakThreshold: 2, streakMultiplier: 1.5)
        XCTAssertEqual(m.reward(forStreak: 1), 1.0)   // streak=1 < 2 → no bonus
        XCTAssertEqual(m.reward(forStreak: 2), 1.5)   // streak=2 == threshold → bonus
        XCTAssertEqual(m.reward(forStreak: 3), 1.5)   // still in streak
    }

    func testCustom_streakMultiplier() {
        // multiplier = 2.0: streak bonus doubles the reward.
        let m = AlternationReward(baseReward: 1.0, streakThreshold: 3, streakMultiplier: 2.0)
        XCTAssertEqual(m.reward(forStreak: 2), 1.0)   // below threshold
        XCTAssertEqual(m.reward(forStreak: 3), 2.0)   // 1.0 × 2.0
    }

    func testCustom_multiplierOne_linearReward() {
        // multiplier = 1.0: no streak bonus; reward is always baseReward.
        let m = AlternationReward(baseReward: 1.0, streakThreshold: 3, streakMultiplier: 1.0)
        XCTAssertEqual(m.reward(forStreak: 1), 1.0)
        XCTAssertEqual(m.reward(forStreak: 3), 1.0)
        XCTAssertEqual(m.reward(forStreak: 10), 1.0)
    }

    // MARK: - Equatable

    func testEquatable_sameValues() {
        let a = AlternationReward(baseReward: 1.0, streakThreshold: 3, streakMultiplier: 1.5)
        let b = AlternationReward(baseReward: 1.0, streakThreshold: 3, streakMultiplier: 1.5)
        XCTAssertEqual(a, b)
    }

    func testEquatable_differentMultiplier() {
        let a = AlternationReward(baseReward: 1.0, streakThreshold: 3, streakMultiplier: 1.5)
        let b = AlternationReward(baseReward: 1.0, streakThreshold: 3, streakMultiplier: 2.0)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - LayoutRegistry integration

    func testLayoutRegistry_hasDefaultModel() {
        // LayoutRegistry.shared should expose the default alternation model.
        XCTAssertEqual(LayoutRegistry.shared.alternationRewardModel, AlternationReward.default)
    }

    func testLayoutRegistry_modelReplacement() {
        // Replacing the model should immediately affect reward computation.
        let custom = AlternationReward(baseReward: 2.0, streakThreshold: 2, streakMultiplier: 3.0)
        LayoutRegistry.shared.alternationRewardModel = custom
        defer { LayoutRegistry.shared.alternationRewardModel = .default }   // restore

        XCTAssertEqual(LayoutRegistry.shared.alternationRewardModel, custom)
        // streak=1: below threshold(2) → 2.0 × 1.0 = 2.0
        XCTAssertEqual(LayoutRegistry.shared.alternationRewardModel.reward(forStreak: 1), 2.0)
        // streak=2: at threshold → 2.0 × 3.0 = 6.0
        XCTAssertEqual(LayoutRegistry.shared.alternationRewardModel.reward(forStreak: 2), 6.0)
    }
}
