// SameFingerOptimizer.swift
// Greedy hill-climb optimizer that finds key swaps minimizing the same-finger bigram score.
// 同指ビグラムスコアを最小化するキースワップを探索するグリーディーヒルクライムオプティマイザ。
//
// ## Algorithm
//
// 1. Build the set of "swappable" keys: keys that appear in bigramCounts, have a known
//    position in the layout, and are NOT in LayoutConstraints.fixedKeys.
//
// 2. Compute the baseline SFB score with the unmodified layout.
//
// 3. Iteration (repeated up to maxSwaps times):
//    a. Find the top-K same-finger bigrams by (count × penalty) weight.
//    b. Collect "candidate" keys: the swappable keys that appear in those bigrams.
//    c. For each (candidate, any-swappable) pair, build a RemappedLayout with that swap
//       and compute its SFB score.
//    d. Accept the pair with the largest score reduction.
//    e. Apply it to the accumulated relocation map; update the current score.
//    f. If no improvement is found, stop early.
//
// 4. Return the ordered list of accepted KeySwaps.
//
// ## Complexity
//   O(maxSwaps × K × |swappableKeys|) score evaluations.
//   Each evaluation is O(|bigramCounts|).
//   Typical inputs (thousands of bigrams, ~50 swappable keys, K=10, maxSwaps=5)
//   complete in well under 1 ms on modern hardware.
//
// ## Relationship to other issues
//   - Uses SFBScoreEngine (#29 component) for scoring.
//   - Uses RemappedLayout / KeyRelocationSimulator (#38) for simulation.
//   - Respects LayoutConstraints (#39) to preserve fixed keys.
//
// 依存: SFBScoreEngine (#29), RemappedLayout (#38), LayoutConstraints (#39)

import Foundation

// MARK: - KeySwap

/// A recommended key swap with its projected ergonomic benefit.
/// 推奨キースワップとその予測エルゴノミクス改善量。
public struct KeySwap: Equatable {
    /// The key whose current position will be swapped.
    public let from: String
    /// The key it will be swapped with.
    public let to: String
    /// Reduction in total SFB penalty score (positive means improvement).
    /// SFBペナルティスコアの減少量（正値＝改善）。
    public let projectedSFBReduction: Double

    public init(from: String, to: String, projectedSFBReduction: Double) {
        self.from = from
        self.to = to
        self.projectedSFBReduction = projectedSFBReduction
    }
}

// MARK: - SameFingerOptimizer

/// Greedy hill-climb optimizer that identifies key swaps reducing same-finger bigram cost.
/// 同指ビグラムコストを削減するキースワップを特定するグリーディーヒルクライムオプティマイザ。
public struct SameFingerOptimizer {

    /// Scoring engine used for evaluation.
    public let engine: SFBScoreEngine

    /// Number of top SFB bigrams used to identify candidate keys per iteration.
    /// 各イテレーションで候補キーを選ぶために使用するSFBビグラムの上位件数。
    public let topK: Int

    public init(engine: SFBScoreEngine = .default, topK: Int = 10) {
        self.engine = engine
        self.topK = topK
    }

    // MARK: - Public API

    /// Finds an ordered list of key swaps that progressively reduce the SFB score.
    ///
    /// - Parameters:
    ///   - bigramCounts: Keystroke bigram frequencies ("k1→k2" format from KeyCountStore).
    ///   - layout: The base keyboard layout to optimize against.
    ///   - constraints: Keys that must not be moved. Defaults to macOS system key preset.
    ///   - maxSwaps: Maximum number of swaps to propose (default 5).
    /// - Returns: Ordered list of `KeySwap` values, each improving SFB score. May be empty
    ///   if no beneficial swap exists or all candidate keys are fixed.
    ///
    /// bigramCounts は KeyCountStore の "k1→k2" 形式を使うこと。
    /// 結果は SFB スコアを改善する順に並ぶ。改善スワップが存在しない場合は空リストを返す。
    public func optimize(
        bigramCounts: [String: Int],
        layout: any KeyboardLayout,
        constraints: LayoutConstraints = .macOSDefaults,
        maxSwaps: Int = 5
    ) -> [KeySwap] {
        guard !bigramCounts.isEmpty, maxSwaps > 0 else { return [] }

        // 1. Build swappable key set: in data, in layout, not fixed.
        // スワップ可能キー集合：データ内・レイアウト内・固定されていない。
        let allKeysInData = keysInBigrams(bigramCounts)
        let swappable = allKeysInData.filter { key in
            !constraints.fixedKeys.contains(key) && layout.position(for: key) != nil
        }
        guard swappable.count >= 2 else { return [] }

        var result: [KeySwap] = []
        // Accumulated relocation map applied across all iterations.
        // 全イテレーションにわたって累積するリロケーションマップ。
        var currentMap: [String: String] = [:]
        var currentScore = engine.score(
            bigramCounts: bigramCounts,
            layout: RemappedLayout(base: layout, relocationMap: currentMap)
        )
        // Early exit: nothing to improve if baseline SFB is already zero.
        guard currentScore > 0 else { return [] }

        for _ in 0..<maxSwaps {
            let currentLayout = RemappedLayout(base: layout, relocationMap: currentMap)

            // 2a. Identify candidate keys from the top-K SFB bigrams.
            // トップKのSFBビグラムから候補キーを特定する。
            let candidates = topKCandidateKeys(
                bigramCounts: bigramCounts,
                layout: currentLayout,
                swappable: swappable
            )
            guard !candidates.isEmpty else { break }

            // 2b. Try all (candidate, swappable) pairs; keep the best.
            // 全（候補、スワップ可能）ペアを試し、最良のものを選ぶ。
            var bestReduction = 0.0
            var bestPair: (String, String)? = nil

            for candidate in candidates {
                for other in swappable where other != candidate {
                    var proposed = currentMap
                    KeyRelocationSimulator.applySwap(key1: candidate, key2: other, to: &proposed)
                    let newScore = engine.score(
                        bigramCounts: bigramCounts,
                        layout: RemappedLayout(base: layout, relocationMap: proposed)
                    )
                    let reduction = currentScore - newScore
                    if reduction > bestReduction {
                        bestReduction = reduction
                        bestPair = (candidate, other)
                    }
                }
            }

            // 2c. Accept the best swap, or stop if no improvement found.
            // 最良スワップを採用。改善なければ停止。
            guard let (k1, k2) = bestPair else { break }
            KeyRelocationSimulator.applySwap(key1: k1, key2: k2, to: &currentMap)
            currentScore -= bestReduction
            result.append(KeySwap(from: k1, to: k2, projectedSFBReduction: bestReduction))
        }

        return result
    }

    // MARK: - Private helpers

    /// Extracts all unique key names that appear in bigram frequency data.
    /// ビグラム頻度データに含まれる全ユニークキー名を抽出する。
    private func keysInBigrams(_ bigramCounts: [String: Int]) -> Set<String> {
        var keys = Set<String>()
        for bigram in bigramCounts.keys {
            guard let b = Bigram.parse(bigram) else { continue }
            keys.insert(b.from)
            keys.insert(b.to)
        }
        return keys
    }

    /// Returns the candidate keys from the top-K highest-cost SFB bigrams.
    /// Candidates are limited to swappable keys to avoid proposing fixed-key swaps.
    ///
    /// 上位KのSFBビグラムから候補キーのセットを返す。スワップ可能なキーのみ含む。
    private func topKCandidateKeys(
        bigramCounts: [String: Int],
        layout: any KeyboardLayout,
        swappable: Set<String>
    ) -> Set<String> {
        // Score each same-finger bigram by count × penalty.
        var scored: [(key1: String, key2: String, weight: Double)] = []
        for (bigram, count) in bigramCounts where count > 0 {
            guard let b = Bigram.parse(bigram) else { continue }
            let k1 = b.from, k2 = b.to
            guard let f1 = layout.finger(for: k1),
                  let f2 = layout.finger(for: k2),
                  f1 == f2,
                  let h1 = layout.hand(for: k1),
                  let h2 = layout.hand(for: k2),
                  h1 == h2 else { continue }
            guard let p1 = layout.position(for: k1),
                  let p2 = layout.position(for: k2) else { continue }
            let fw = engine.fingerWeights.weight(for: f1)
            let w = Double(count) * engine.penalty.penalty(from: p1, to: p2, fingerWeight: fw)
            scored.append((k1, k2, w))
        }

        // Take top-K and collect their swappable keys.
        let top = scored.sorted { $0.weight > $1.weight }.prefix(topK)
        var candidates = Set<String>()
        for item in top {
            if swappable.contains(item.key1) { candidates.insert(item.key1) }
            if swappable.contains(item.key2) { candidates.insert(item.key2) }
        }
        return candidates
    }
}
