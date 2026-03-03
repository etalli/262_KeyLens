import Foundation

// SameFingerPenalty.swift
// Non-linear same-finger bigram penalty calculator.
// 同指ビグラムに対する非線形ペナルティ計算。
//
// ## Purpose
// Phase 0 (#16) counts same-finger bigrams. Phase 1 (#24) makes the penalty
// *distance-sensitive*: pressing the same finger on keys far apart is
// significantly more taxing than pressing adjacent keys.
//
// The formula is:
//
//   penalty = finger_weight × distance_factor ^ exponent
//
// With the default exponent of 2.0, moving from "adjacent" (factor 1.0) to
// "one row apart" (factor 2.0) quadruples the penalty — capturing the
// non-linear biomechanical cost of larger finger stretches.
//
// ## Distance tiers
// Tier is determined by row distance (vertical travel), which is the primary
// fatigue axis for same-finger movement:
//
//   sameKey  → row diff = 0, col diff = 0  → factor 0.5  (key repeat, minimal effort)
//   adjacent → row diff = 0, col diff > 0  → factor 1.0  (same-row stretch, e.g. f→g)
//   oneRow   → row diff = 1               → factor 2.0  (one-row reach, e.g. f→r)
//   multiRow → row diff ≥ 2               → factor 4.0  (multi-row stretch, e.g. f→4)
//
// ## Calibration note
// The default factor values (0.5, 1.0, 2.0, 4.0) are initial design values
// inspired by the Carpalx effort model. They are intentionally configurable
// so they can be replaced with empirically derived values once sufficient
// bigram IKI (inter-keystroke interval) data has been collected.
// See KeyCountStore.bigramIKISum / bigramIKICount for the data collection hook.
//
// デフォルト係数は暫定値。bigramIKI データが蓄積された後に実測値で校正する想定。

// MARK: - Distance Tier

/// Classifies the physical distance between two keys pressed by the same finger.
/// 同指で押す2つのキー間の距離カテゴリ。
public enum SameFingerDistanceTier: Equatable, CaseIterable {
    /// The exact same key pressed twice (key repeat).
    /// 同一キーの連続押下。
    case sameKey

    /// Same row, different column — e.g. index finger covering f→g.
    /// 同じ行・異なる列 — 横方向の伸び（例：f→g）。
    case adjacent

    /// One row of vertical travel — e.g. f→r (home row to top row).
    /// 1行の縦移動 — 例：ホームロウ→上の行（f→r）。
    case oneRow

    /// Two or more rows of vertical travel — e.g. f→4 (home row to number row).
    /// 2行以上の縦移動 — 例：ホームロウ→数字行（f→4）。
    case multiRow
}

// MARK: - SameFingerPenalty

/// Calculates the ergonomic penalty for a same-finger bigram based on key distance.
///
/// Usage:
/// ```swift
/// let penalty = SameFingerPenalty.default.penalty(
///     from: positionF, to: positionR, fingerWeight: 1.0
/// )
/// // → 4.0  (index finger, one-row reach, 1.0 × 2.0² = 4.0)
/// ```
public struct SameFingerPenalty: Equatable {

    /// Exponent applied to the distance factor.
    /// Higher values amplify the difference between tiers.
    /// 距離係数に適用する指数。大きいほど距離の差が強調される。
    public let exponent: Double

    public init(exponent: Double) {
        self.exponent = exponent
    }

    // MARK: - Default

    /// Default configuration: exponent = 2.0 (quadratic penalty growth).
    /// デフォルト設定：指数 2.0（二次的ペナルティ増大）。
    public static let `default` = SameFingerPenalty(exponent: 2.0)

    // MARK: - Tier classification

    /// Returns the distance tier for a pair of key positions.
    /// Classification is based on row difference (primary fatigue axis).
    /// 2つのキー位置の距離ティアを分類する。行差を基準とする。
    public func tier(from a: KeyPosition, to b: KeyPosition) -> SameFingerDistanceTier {
        let rowDiff = abs(a.row - b.row)
        switch rowDiff {
        case 0 where a.column == b.column: return .sameKey
        case 0:                            return .adjacent
        case 1:                            return .oneRow
        default:                           return .multiRow
        }
    }

    // MARK: - Factor lookup

    /// Returns the raw distance factor for a tier (before applying the exponent).
    /// These are the calibration-point values; replace with empirical IKI ratios when available.
    /// ティアの生の距離係数を返す。IKIデータが揃い次第、実測比率で置き換える。
    public func factor(for tier: SameFingerDistanceTier) -> Double {
        switch tier {
        case .sameKey:  return 0.5
        case .adjacent: return 1.0
        case .oneRow:   return 2.0
        case .multiRow: return 4.0
        }
    }

    // MARK: - Penalty computation

    /// Computes the full penalty for a same-finger bigram.
    ///
    /// - Parameters:
    ///   - a: Key position of the first keystroke.
    ///   - b: Key position of the second keystroke.
    ///   - fingerWeight: Capability weight of the finger (from FingerLoadWeight).
    /// - Returns: `fingerWeight × factor(tier)^exponent`
    ///
    /// Example: index finger (weight 1.0), one-row reach (factor 2.0), exponent 2.0
    ///   → 1.0 × 2.0² = 4.0
    ///
    /// 同指ビグラムのペナルティ = 指重み × 距離係数^指数
    public func penalty(from a: KeyPosition, to b: KeyPosition, fingerWeight: Double) -> Double {
        let f = factor(for: tier(from: a, to: b))
        return fingerWeight * pow(f, exponent)
    }
}
