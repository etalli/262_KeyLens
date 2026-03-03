// HighStrainDetector.swift
// Detects key sequences where same-finger use and large vertical reach coincide.
// 同指連打と大きな縦移動が重なる高負荷キーシーケンスを検出する。
//
// ## Purpose
// Individual metrics (same-finger rate, distance) miss compound strain.
// A bigram can look acceptable on each axis individually, yet be highly taxing
// when both stress factors coincide simultaneously.
//
// This detector classifies two levels of high-strain sequences:
//
//   High-strain bigram (2 keys):
//     Both conditions must hold:
//       1. Same finger AND same hand
//       2. Distance tier ≥ minimumTier (default: .oneRow)
//     Example: f→r  (left index, 1 row apart) → high-strain
//              f→g  (left index, adjacent)    → NOT high-strain (too close)
//              f→j  (different hands)         → NOT high-strain (hand alternation)
//
//   High-strain trigram (3 keys):
//     Two consecutive bigrams are both high-strain.
//     Example: f→r→t — if f→r and r→t are both high-strain bigrams → trigram flagged.
//
// ## Tier threshold
// The default minimumTier is .oneRow (≥ 1 row of vertical travel).
// .adjacent (same row, different column) is not considered high-strain because
// lateral reach on the same row has significantly lower biomechanical cost than
// vertical movement across rows.
//
// デフォルト最小ティアは .oneRow（縦1行以上の移動）。
// 同行の横移動（.adjacent）は縦移動より生体力学的コストが低いため除外する。

// MARK: - HighStrainDetector

/// Detects high-strain bigrams and trigrams based on same-finger use and distance tier.
///
/// Usage:
/// ```swift
/// let detector = HighStrainDetector.default
/// detector.isHighStrain(from: "f", to: "r", layout: LayoutRegistry.shared)  // → true
/// detector.isHighStrain(from: "f", to: "g", layout: LayoutRegistry.shared)  // → false
/// ```
public struct HighStrainDetector: Equatable {

    /// Minimum distance tier required to qualify as high-strain.
    /// Bigrams with a tier below this threshold are not flagged.
    /// 高負荷と判定するための最小距離ティア。これ未満は対象外。
    public let minimumTier: SameFingerDistanceTier

    public init(minimumTier: SameFingerDistanceTier) {
        self.minimumTier = minimumTier
    }

    // MARK: - Default

    /// Default configuration: minimumTier = .oneRow (≥ 1 row of vertical travel).
    /// デフォルト設定：最小ティア = .oneRow（縦1行以上の移動）。
    public static let `default` = HighStrainDetector(minimumTier: .oneRow)

    // MARK: - Tier qualification

    /// Returns true if the given tier qualifies as high-strain under this detector's minimumTier.
    ///
    /// Tier ordering: sameKey < adjacent < oneRow < multiRow
    /// 指定ティアが高負荷条件を満たすか返す。ティア順: sameKey < adjacent < oneRow < multiRow
    public func isHighStrain(tier: SameFingerDistanceTier) -> Bool {
        switch minimumTier {
        case .sameKey:   return true
        case .adjacent:  return tier == .adjacent || tier == .oneRow || tier == .multiRow
        case .oneRow:    return tier == .oneRow   || tier == .multiRow
        case .multiRow:  return tier == .multiRow
        }
    }

    // MARK: - Bigram classification

    /// Returns true if the bigram (key1 → key2) is high-strain.
    ///
    /// Conditions:
    ///   1. Both keys assigned to the same finger AND same hand.
    ///   2. Distance tier ≥ minimumTier.
    ///
    /// Returns false for unknown keys, cross-hand pairs, or different-finger pairs.
    ///
    /// 同指・同手、かつ距離ティアが閾値以上のとき true を返す。
    /// 未知キー・異手・異指の場合は false。
    public func isHighStrain(from key1: String, to key2: String, layout: LayoutRegistry) -> Bool {
        // Same finger AND same hand
        guard let f1 = layout.current.finger(for: key1),
              let f2 = layout.current.finger(for: key2),
              f1 == f2,
              let h1 = layout.hand(for: key1),
              let h2 = layout.hand(for: key2),
              h1 == h2 else { return false }

        // Distance tier must meet the threshold
        guard let pos1 = layout.current.position(for: key1),
              let pos2 = layout.current.position(for: key2) else { return false }

        let tier = layout.sameFingerPenaltyModel.tier(from: pos1, to: pos2)
        return isHighStrain(tier: tier)
    }
}
