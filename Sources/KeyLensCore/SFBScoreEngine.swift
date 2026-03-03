// SFBScoreEngine.swift
// Aggregates the weighted same-finger bigram (SFB) penalty across a keystroke dataset.
// 打鍵データ全体の同指ビグラム(SFB)加重ペナルティを集計するエンジン。
//
// ## Score definition
//
//   SFB score = Σ { count(k1→k2) × SameFingerPenalty(k1, k2, fingerWeight(finger)) }
//               over all bigrams where finger(k1) == finger(k2)
//
// A lower score is better: it indicates fewer and/or less physically costly
// same-finger movements in the user's keystroke history.
//
// ## Usage
//
//   let engine = SFBScoreEngine()
//   let baseline = engine.score(bigramCounts: store.bigramCounts, layout: ANSILayout())
//
//   var swapMap: [String: String] = [:]
//   KeyRelocationSimulator.applySwap(key1: "f", key2: "j", to: &swapMap)
//   let simulated = engine.score(bigramCounts: store.bigramCounts,
//                                layout: KeyRelocationSimulator.layout(applying: swapMap,
//                                                                       over: ANSILayout()))
//   let improvement = baseline - simulated  // positive = better
//
// スコアが低いほど良い。SameFingerOptimizer はこのスコアを最小化するスワップを探索する。
//
// ## Relationship to Issue #29 (ErgonomicScoreEngine)
// SFBScoreEngine computes the "same-finger penalty" component of the full ergonomic score
// described in #29. The full composite score (including alternation reward, thumb imbalance,
// etc.) will be assembled in ErgonomicScoreEngine when Issue #29 is implemented.
// SFBScoreEngine は Issue #29 の「同指ペナルティ」コンポーネントを担当する。
// フルスコア（交互打鍵ボーナス・親指バランス等含む）は Issue #29 で組み立てる。

import Foundation

/// Computes the aggregate weighted same-finger bigram penalty for a layout and dataset.
/// レイアウトとデータセットに対する同指ビグラムの加重ペナルティ合計を計算する。
public struct SFBScoreEngine {

    public let penalty: SameFingerPenalty
    public let fingerWeights: FingerLoadWeight

    public init(
        penalty: SameFingerPenalty = .default,
        fingerWeights: FingerLoadWeight = .default
    ) {
        self.penalty = penalty
        self.fingerWeights = fingerWeights
    }

    // MARK: - Default

    /// Default configuration using standard penalty and finger weight models.
    /// 標準ペナルティ・指重みモデルを使ったデフォルト設定。
    public static let `default` = SFBScoreEngine()

    // MARK: - Score computation

    /// Computes the total SFB penalty score for the given bigram frequency data and layout.
    ///
    /// - Parameters:
    ///   - bigramCounts: Bigram frequency map from KeyCountStore ("k1→k2" format).
    ///   - layout: The keyboard layout to evaluate against.
    /// - Returns: Sum of `count × penalty` for all same-finger bigrams. Zero if none exist.
    ///
    /// bigramCounts のキー形式は KeyCountStore が生成する "k1→k2" 形式であること。
    /// 同指ビグラムが存在しない場合は 0 を返す。
    public func score(bigramCounts: [String: Int], layout: any KeyboardLayout) -> Double {
        var total = 0.0
        for (bigram, count) in bigramCounts where count > 0 {
            let parts = bigram.components(separatedBy: "→")
            guard parts.count == 2 else { continue }
            let k1 = parts[0], k2 = parts[1]
            // Only same-hand, same-finger bigrams contribute to the SFB penalty.
            // Left-index and right-index are different fingers — hand must also match.
            // 同手・同指ビグラムのみがSFBペナルティに寄与する。
            // 左人差し指と右人差し指は別の指 — hand も一致していなければならない。
            guard let f1 = layout.finger(for: k1),
                  let f2 = layout.finger(for: k2),
                  f1 == f2,
                  let h1 = layout.hand(for: k1),
                  let h2 = layout.hand(for: k2),
                  h1 == h2 else { continue }
            guard let p1 = layout.position(for: k1),
                  let p2 = layout.position(for: k2) else { continue }
            let fw = fingerWeights.weight(for: f1)
            total += Double(count) * penalty.penalty(from: p1, to: p2, fingerWeight: fw)
        }
        return total
    }
}
