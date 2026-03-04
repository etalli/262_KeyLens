// TravelDistanceEstimator.swift
// Estimates the total finger travel distance implied by a user's bigram data.
// ユーザーのバイグラムデータから総指移動距離を推定する。
//
// ## Formula
//
//   travel(bigram "a→b") = sqrt((col_a - col_b)² × columnWidth²
//                              + (row_a - row_b)² × rowHeight²)
//   totalTravel = Σ bigramCounts[pair] × travel(pair)
//
// Grid coordinates come from KeyPosition.row / KeyPosition.column in ANSILayout.
// A configurable rowHeight / columnWidth ratio accounts for the non-square key grid
// (rows are physically taller than columns on standard keyboards).
//
// グリッド座標は ANSILayout の KeyPosition.row / column から取得する。
// rowHeight / columnWidth で行と列の物理比率を設定可能（標準キーボードは行が縦に広い）。
//
// ## Relationship to Phase 2 optimizer
//
// projectedTravel wraps the layout in a RemappedLayout (Issue #38) to simulate
// the travel distance after applying a proposed key relocation, enabling
// before/after comparison without mutating the base layout.
//
// projectedTravel は RemappedLayout (#38) でスワップ後の移動距離を計算し、
// ベースレイアウトを変更せずに Before/After 比較を可能にする。
//
// ## Phase
// Phase 2 – Optimization Engine (Issue #40)

import Foundation

/// Estimates total finger travel distance from bigram frequency data.
/// バイグラム頻度データから総指移動距離を推定する。
public struct TravelDistanceEstimator {

    /// Physical width of one column unit.
    /// 列1単位あたりの物理幅。
    public let columnWidth: Double

    /// Physical height of one row unit.
    /// 行1単位あたりの物理高さ。
    public let rowHeight: Double

    public init(columnWidth: Double = 1.0, rowHeight: Double = 1.0) {
        self.columnWidth = columnWidth
        self.rowHeight   = rowHeight
    }

    // MARK: - Default

    /// Default configuration: unit grid (columnWidth = rowHeight = 1.0).
    /// デフォルト設定：単位グリッド（columnWidth = rowHeight = 1.0）。
    public static let `default` = TravelDistanceEstimator()

    // MARK: - Distance

    /// Euclidean distance between two key positions on the key grid.
    ///
    /// - Parameters:
    ///   - a: Starting key position.
    ///   - b: Ending key position.
    /// - Returns: `sqrt((Δcol × columnWidth)² + (Δrow × rowHeight)²)`
    ///
    /// キーグリッド上の2キー位置間のユークリッド距離を返す。
    public func distance(from a: KeyPosition, to b: KeyPosition) -> Double {
        let dc = Double(a.column - b.column) * columnWidth
        let dr = Double(a.row    - b.row)    * rowHeight
        return (dc * dc + dr * dr).squareRoot()
    }

    // MARK: - Total travel

    /// Computes total weighted finger travel distance across all bigrams.
    ///
    /// - Parameters:
    ///   - counts: Bigram frequency map from KeyCountStore ("k1→k2" format).
    ///   - layout: The keyboard layout to evaluate.
    /// - Returns: Σ count(k1→k2) × euclidean_distance(pos(k1), pos(k2)).
    ///            Bigrams whose keys are not found in the layout are silently skipped.
    ///
    /// レイアウトに存在しないキーを含むバイグラムは無視される。
    public func totalTravel(counts: [String: Int], layout: any KeyboardLayout) -> Double {
        var total = 0.0
        for (bigram, count) in counts where count > 0 {
            let parts = bigram.components(separatedBy: "→")
            guard parts.count == 2 else { continue }
            guard let p1 = layout.position(for: parts[0]),
                  let p2 = layout.position(for: parts[1]) else { continue }
            total += Double(count) * distance(from: p1, to: p2)
        }
        return total
    }

    // MARK: - Projected travel

    /// Computes projected total travel after applying a key relocation map.
    ///
    /// Wraps `layout` in a `RemappedLayout` (Issue #38), then delegates to `totalTravel`.
    /// Use this to compare travel distance before and after a proposed key swap.
    ///
    /// - Parameters:
    ///   - counts: Bigram frequency map from KeyCountStore ("k1→k2" format).
    ///   - relocation: Key relocation map built via `KeyRelocationSimulator.applySwap`.
    ///   - layout: The base keyboard layout.
    /// - Returns: Total travel distance under the proposed remapped layout.
    ///
    /// RemappedLayout でスワップ後の総移動距離を計算する。スワップ前後の比較に使用する。
    public func projectedTravel(
        counts: [String: Int],
        relocation: [String: String],
        layout: any KeyboardLayout
    ) -> Double {
        let remapped = KeyRelocationSimulator.layout(applying: relocation, over: layout)
        return totalTravel(counts: counts, layout: remapped)
    }
}
