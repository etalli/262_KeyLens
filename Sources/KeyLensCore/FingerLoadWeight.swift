// FingerLoadWeight.swift
// Per-finger load weights for ergonomic scoring.
// 指ごとの負荷重みテーブル。エルゴノミクススコアの基盤となる。
//
// ## Purpose
// Each finger has a different strength and mobility profile.
// Treating all fingers equally when counting keystrokes hides the real ergonomic cost:
// 1000 presses on the pinky is far more fatiguing than 1000 presses on the index finger.
//
// FingerLoadWeight assigns a relative capability score (0 < weight ≤ 1.0) to each finger.
// Downstream scorers multiply keystroke counts by the *inverse* of the weight to get load:
//
//   load(key) = keyCount / weight(finger)
//
// A pinky key (weight 0.5) therefore contributes twice as much load as the same count
// on an index key (weight 1.0).
//
// ## Tests (FingerLoadWeightTests)
// The tests verify three things:
//   1. Default values — each finger matches the Carpalx / Kim et al. reference numbers.
//   2. Custom values — arbitrary tables work and missing fingers fall back to 1.0 safely.
//   3. End-to-end lookup — LayoutRegistry.loadWeight(for keyName:) correctly chains
//      key name → finger → weight, and returns nil for unknown keys.
//
// 各指の強さの差を数値化する。小指（0.5）の打鍵は人差し指（1.0）の2倍の負荷として扱われる。
// Phase 1 のエルゴノミクススコア計算（Issue #29）の土台となる型。

/// Per-finger relative load weights based on natural strength and lateral reach.
///
/// A weight of 1.0 represents the strongest finger (index). Lower weights indicate
/// fingers that tire more easily per keystroke, and are used to amplify their
/// contribution to the overall ergonomic load score.
///
/// Default values are derived from Carpalx (Krzywinski, 2006) and empirical
/// measurements in Kim et al. (2014).
public struct FingerLoadWeight: Equatable {

    /// The weight table, keyed by Finger.
    public let weights: [Finger: Double]

    /// Returns the load weight for a given finger.
    /// Always returns a value — falls back to 1.0 if the finger is not in the table.
    /// 指定した指の重みを返す。テーブルにない場合は 1.0 を返す。
    public func weight(for finger: Finger) -> Double {
        weights[finger] ?? 1.0
    }

    /// Creates a weight table with fully custom values.
    public init(weights: [Finger: Double]) {
        self.weights = weights
    }

    // MARK: - Default

    /// Default weights based on Carpalx / Kim et al. 2014.
    ///
    /// | Finger | Weight | Rationale |
    /// |--------|--------|-----------|
    /// | index  | 1.0    | Baseline — strongest, widest reach |
    /// | middle | 0.9    | Strong, good independence |
    /// | thumb  | 0.8    | Strong but limited to few keys |
    /// | ring   | 0.6    | Shares tendons with middle/pinky, limited independence |
    /// | pinky  | 0.5    | Weakest, shortest reach |
    public static let `default` = FingerLoadWeight(weights: [
        .index:  1.0,
        .middle: 0.9,
        .thumb:  0.8,
        .ring:   0.6,
        .pinky:  0.5,
    ])
}
