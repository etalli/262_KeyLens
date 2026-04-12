// ThumbEfficiencyCalculator.swift
// Quantifies how effectively thumb keys reduce load on the other eight fingers.
// 親指キーが他の8本の指の負荷をどれだけ効果的に軽減しているかを定量化する。
//
// ## Purpose
// Thumb keys are uniquely high-value real estate on split keyboards.
// If high-frequency keys (Space, Enter, modifiers) land on thumb keys, load is
// offloaded from weaker fingers (ring, pinky). If the user still hits Space with
// the index or pinky, the thumb keys are underutilised.
//
// The coefficient is:
//
//   thumb_efficiency = thumb_key_count / (total_count × expected_thumb_ratio)
//
//   > 1.0  thumbs are pulling above expected weight  (efficient)
//   = 1.0  thumbs match the expected usage proportion
//   < 1.0  thumbs are underutilised
//
// ## Default expected_thumb_ratio = 0.15
// In English text, Space alone accounts for roughly 15–20% of all keystrokes
// (Norvig, 2012; Carpalx corpus data). Using 0.15 as a conservative baseline
// means a typical typist who presses Space normally should score ≈ 1.0.
// The value is configurable so it can be adjusted for other languages or
// keyboard layouts where thumb key assignments differ.
//
// 英語テキストでは Space が全打鍵の約 15〜20% を占める（Norvig 2012 / Carpalx コーパス）。
// デフォルト 0.15 は保守的な基準値。言語や配列に合わせて変更可能。

// MARK: - ThumbEfficiencyCalculator

/// Computes the thumb efficiency coefficient from a key-count dictionary.
///
/// Usage:
/// ```swift
/// let coeff = ThumbEfficiencyCalculator.default.coefficient(
///     counts: store.allCounts, layout: LayoutRegistry.shared
/// )
/// // → 2.0 means thumbs handle twice the expected share of keystrokes
/// ```
public struct ThumbEfficiencyCalculator: Equatable {

    /// Expected proportion of keystrokes handled by thumb keys in a well-utilised layout.
    /// 理想的な親指キー使用割合（デフォルト 15%）。
    public let expectedThumbRatio: Double

    public init(expectedThumbRatio: Double) {
        self.expectedThumbRatio = expectedThumbRatio
    }

    // MARK: - Default

    /// Default configuration: expectedThumbRatio = 0.15 (15%, based on English Space frequency).
    /// デフォルト設定：期待比率 0.15（英語テキストの Space 頻度を基準）。
    public static let `default` = ThumbEfficiencyCalculator(expectedThumbRatio: 0.15)

    // MARK: - Coefficient computation

    /// Computes the thumb efficiency coefficient from a key-count dictionary.
    ///
    /// - Parameters:
    ///   - counts: Key name → keystroke count mapping (e.g. from `KeyCountStore`).
    ///   - layout: The active layout registry used to identify thumb-assigned keys.
    /// - Returns: `thumb_count / (total_count × expectedThumbRatio)`,
    ///   or `nil` if `total_count` is zero or `expectedThumbRatio` is zero.
    ///
    /// 親指効率係数を返す。総打鍵数が0、または期待比率が0の場合は nil。
    public func coefficient(counts: [String: Int], layout: LayoutRegistry) -> Double? {
        guard expectedThumbRatio > 0 else { return nil }

        var thumbCount = 0
        var totalCount = 0

        for (key, count) in counts {
            totalCount += count
            if layout.finger(for: key) == .thumb {
                thumbCount += count
            }
        }

        guard totalCount > 0 else { return nil }
        return Double(thumbCount) / (Double(totalCount) * expectedThumbRatio)
    }
}
