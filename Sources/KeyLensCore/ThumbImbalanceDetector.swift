// ThumbImbalanceDetector.swift
// Detects uneven thumb key usage between left and right thumbs.
// 左右の親指キー使用量の偏りを検出する。
//
// ## Purpose
// Split keyboards expose a problem that standard layouts hide: if one thumb
// handles significantly more keys than the other, that thumb becomes a
// bottleneck and a common source of long-term strain.
//
// This detector computes a normalised imbalance ratio in [0, 1]:
//
//   imbalance_ratio = |left_thumb_count - right_thumb_count| / total_thumb_count
//
//   0.0 = perfectly balanced
//   1.0 = one thumb handles everything (maximum imbalance)
//
// A ratio above `threshold` (default 0.3) is flagged as imbalanced.
//
// ## How thumb keys are identified
// Keys are classified as thumb-assigned when `LayoutRegistry.current.finger(for:)`
// returns `.thumb`. The hand (left / right) is resolved via `LayoutRegistry.hand(for:)`.
// This means the detector automatically respects any custom layout or split config.
//
// ## Calibration note
// The default threshold (0.3) corresponds roughly to a 65:35 left/right split.
// It can be adjusted to match individual ergonomic requirements.
//
// デフォルト閾値 0.3 は左右比 65:35 程度に相当する。個人の要件に合わせて変更可能。

// MARK: - ThumbImbalanceDetector

/// Detects uneven thumb key usage between left and right thumbs.
///
/// Usage:
/// ```swift
/// let ratio = ThumbImbalanceDetector.default.imbalanceRatio(
///     counts: store.allCounts, layout: LayoutRegistry.shared
/// )
/// // → 0.6 means one thumb handles 80% of thumb keystrokes
/// ```
public struct ThumbImbalanceDetector: Equatable {

    /// Ratio above which thumb usage is considered imbalanced.
    /// 親指使用量の偏りが問題とみなされる比率の閾値。
    public let threshold: Double

    public init(threshold: Double) {
        self.threshold = threshold
    }

    // MARK: - Default

    /// Default configuration: threshold = 0.3 (≈ 65:35 left/right split).
    /// デフォルト設定：閾値 0.3（左右比 約 65:35 に相当）。
    public static let `default` = ThumbImbalanceDetector(threshold: 0.3)

    // MARK: - Computation

    /// Computes the imbalance ratio from a key-count dictionary.
    ///
    /// - Parameters:
    ///   - counts: Key name → keystroke count mapping (e.g. from `KeyCountStore`).
    ///   - layout: The active layout registry used to resolve finger and hand assignments.
    /// - Returns: A value in [0, 1], or `nil` if no thumb keystrokes are found.
    ///
    /// キーカウント辞書から親指の偏り比率を計算する。親指打鍵が0件の場合は nil。
    public func imbalanceRatio(counts: [String: Int], layout: LayoutRegistry) -> Double? {
        var left = 0
        var right = 0

        for (key, count) in counts {
            guard layout.current.finger(for: key) == .thumb else { continue }
            switch layout.hand(for: key) {
            case .left:  left  += count
            case .right: right += count
            case .none:  break
            }
        }

        let total = left + right
        guard total > 0 else { return nil }
        return Double(abs(left - right)) / Double(total)
    }

    /// Returns `true` if the imbalance ratio exceeds `threshold`.
    ///
    /// Always returns `false` when no thumb keystrokes are found (ratio is nil).
    /// 親指打鍵が0件の場合は false を返す（偏りなしとして扱う）。
    public func isImbalanced(counts: [String: Int], layout: LayoutRegistry) -> Bool {
        guard let ratio = imbalanceRatio(counts: counts, layout: layout) else { return false }
        return ratio > threshold
    }
}
