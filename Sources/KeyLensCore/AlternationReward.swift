// AlternationReward.swift
// Configurable reward coefficient for hand-alternating keystroke sequences.
// 手交互打鍵シーケンスに対する設定可能な報酬係数。
//
// ## Purpose
// Phase 0 (#17) measures the *rate* of hand alternation. Phase 1 (#25) converts
// that raw count into an active scoring reward:
//
//   Rewarding alternation — rather than merely penalizing same-hand usage —
//   produces better optimization targets: it guides the engine toward layouts
//   that exploit two-hand parallelism. (Roadmap Phase 1)
//
// The formula is:
//
//   score_delta = baseReward × (streak >= threshold ? streakMultiplier : 1.0)
//
// - `baseReward`:        base reward per alternating pair (default 1.0)
// - `streakThreshold`:   minimum consecutive alternating pairs to trigger bonus (default 3)
// - `streakMultiplier`:  multiplier applied when streak >= threshold (default 1.5)
//
// ## Streak semantics
// A "streak" counts how many consecutive keyboard pairs have been alternating.
// Same-hand pairs reset it to 0. Mouse clicks / unmapped keys are neutral —
// they neither increment nor reset the streak (they break the bigram chain
// naturally and no reward event fires).
//
// Example (threshold=3, baseReward=1.0, multiplier=1.5):
//   pair 1 (alt): streak=1 → delta 1.0  (below threshold)
//   pair 2 (alt): streak=2 → delta 1.0
//   pair 3 (alt): streak=3 → delta 1.5  (threshold reached)
//   pair 4 (alt): streak=4 → delta 1.5  (still in streak)
//   pair 5 (same-hand):    → streak resets to 0, no reward
//
// ## Calibration note
// The default values (1.0, 3, 1.5) are initial design choices, consistent with
// the approach taken for SameFingerPenalty distance factors. They can be replaced
// with empirically derived values once sufficient IKI and speed data is collected.
//
// デフォルト値は暫定設計値。SameFingerPenalty の距離係数と同様、実測データで校正する想定。

// MARK: - AlternationReward

/// Configurable reward coefficient for hand-alternating keystroke sequences.
///
/// Usage:
/// ```swift
/// let model = AlternationReward.default
/// // streak=1 (first alternating pair, below threshold)
/// model.reward(forStreak: 1)  // → 1.0
/// // streak=3 (threshold reached)
/// model.reward(forStreak: 3)  // → 1.5
/// ```
public struct AlternationReward: Equatable {

    /// Base reward added to the score for each alternating pair.
    /// Dimensionally comparable to FingerLoadWeight (1.0 = index finger baseline).
    /// 交互打鍵1ペアあたりの基本報酬。FingerLoadWeight と同スケール（1.0 = 人差し指基準）。
    public let baseReward: Double

    /// Minimum consecutive alternating pairs required to activate the streak multiplier.
    /// ストリーク乗数を発動するために必要な連続交互打鍵数の下限。
    public let streakThreshold: Int

    /// Multiplier applied to `baseReward` when the current streak meets or exceeds `streakThreshold`.
    /// Captures the ergonomic benefit of sustained two-hand flow beyond isolated alternation.
    /// ストリークがしきい値以上のとき baseReward に掛ける乗数。持続的な両手フローの効果を表す。
    public let streakMultiplier: Double

    public init(baseReward: Double, streakThreshold: Int, streakMultiplier: Double) {
        self.baseReward = baseReward
        self.streakThreshold = streakThreshold
        self.streakMultiplier = streakMultiplier
    }

    // MARK: - Default

    /// Default configuration.
    ///
    /// | Parameter        | Value | Rationale |
    /// |------------------|-------|-----------|
    /// | `baseReward`     | 1.0   | Same scale as FingerLoadWeight index baseline |
    /// | `streakThreshold`| 3     | Issue #25 spec: "≥3 consecutive alternating pairs" |
    /// | `streakMultiplier`| 1.5  | 50% bonus for sustained flow; provisional design value |
    public static let `default` = AlternationReward(
        baseReward: 1.0,
        streakThreshold: 3,
        streakMultiplier: 1.5
    )

    // MARK: - Reward computation

    /// Returns the score delta for a single alternating pair at the given streak length.
    ///
    /// - Parameter streak: Current consecutive alternation count **after** counting this pair
    ///   (must be ≥ 1 for an alternating pair).
    /// - Returns: `baseReward` if `streak < streakThreshold`, otherwise `baseReward × streakMultiplier`.
    ///
    /// 連続交互打鍵数（このペアを含む）に応じたスコア増分を返す。
    public func reward(forStreak streak: Int) -> Double {
        baseReward * (streak >= streakThreshold ? streakMultiplier : 1.0)
    }
}
