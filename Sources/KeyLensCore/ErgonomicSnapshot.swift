// ErgonomicSnapshot.swift
// A point-in-time aggregate of ergonomic metrics for a (layout, dataset) pair.
// レイアウトとデータセットの組み合わせに対するエルゴノミクス指標のスナップショット。
//
// ## Design
//
// ErgonomicSnapshot is the value type that Phase 2 optimizers produce and compare.
// It grows as new Phase 2 metrics are implemented:
//
//   - estimatedTravelDistance   (Issue #40 — implemented)
//   - sfbScore                  (planned, Issue #29)
//   - alternationRewardScore    (planned, Issue #29)
//
// Each field represents the metric evaluated on a specific (layout, bigramCounts) pair.
// The snapshot is immutable; create a new instance after each key relocation simulation.
//
// 各フィールドは特定の（レイアウト, バイグラムカウント）ペアに対する評価値。
// スナップショットは不変。キー移動シミュレーションのたびに新しいインスタンスを生成する。
//
// ## Phase
// Phase 2 – Optimization Engine (Issues #38–#40)

import Foundation

/// A point-in-time snapshot of ergonomic metrics for a (layout, dataset) pair.
/// レイアウトとデータセットの組み合わせに対するエルゴノミクス指標のスナップショット。
public struct ErgonomicSnapshot: Equatable {

    /// Estimated total finger travel distance (in grid units).
    /// Lower is better — indicates keys are arranged to minimise finger movement.
    /// 総指移動距離の推定値（グリッド単位）。小さいほど指の移動が少ない。
    public let estimatedTravelDistance: Double

    public init(estimatedTravelDistance: Double) {
        self.estimatedTravelDistance = estimatedTravelDistance
    }

    // MARK: - Factory

    /// Builds a snapshot by computing all metrics for the given layout and bigram data.
    ///
    /// - Parameters:
    ///   - counts: Bigram frequency map from KeyCountStore ("k1→k2" format).
    ///   - layout: The keyboard layout to evaluate.
    ///   - estimator: Travel distance estimator (defaults to `.default`).
    /// - Returns: A fully populated ErgonomicSnapshot.
    ///
    /// 指定レイアウトとバイグラムデータから全指標を計算してスナップショットを生成する。
    public static func capture(
        counts: [String: Int],
        layout: any KeyboardLayout,
        estimator: TravelDistanceEstimator = .default
    ) -> ErgonomicSnapshot {
        ErgonomicSnapshot(
            estimatedTravelDistance: estimator.totalTravel(counts: counts, layout: layout)
        )
    }
}
