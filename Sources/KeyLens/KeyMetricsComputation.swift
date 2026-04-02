import Foundation
import KeyLensCore

// KeyMetricsComputation.swift
// Pure computation helpers extracted from KeyCountStore.
// No side effects, no access to shared state — all inputs are explicit parameters.
// 副作用なし・共有状態へのアクセスなし。すべての入力を明示的な引数として受け取る純粋計算ヘルパー。

enum KeyMetricsComputation {

    // MARK: - WPM

    /// Estimated typing speed in words per minute.
    /// Uses the standard definition: 1 word = 5 keystrokes.
    /// Capped at 300 WPM to suppress spikes from key-repeat or system-generated events.
    /// - Parameter avgIntervalMs: Average inter-keystroke interval in milliseconds.
    /// 標準定義（1ワード = 5キーストローク）に基づく推定タイピング速度（WPM）。
    /// キーリピートやシステム生成イベントによるスパイクを抑制するため 300 WPM に上限を設定。
    static let maxWPM: Double = 300
    static func wpm(avgIntervalMs: Double) -> Double {
        min(60_000.0 / (avgIntervalMs * 5.0), maxWPM)
    }

    // MARK: - Ergonomic score

    /// Unified ergonomic score (0–100) from raw bigram counters and key counts.
    /// Higher is better. Returns 100.0 if bigramCount is zero (no data).
    /// 生ビグラムカウントとキーカウントから統合エルゴノミクススコア（0〜100）を算出する。高いほど良好。
    static func ergonomicScore(
        sfCount:     Int,
        hsCount:     Int,
        altCount:    Int,
        bigramCount: Int,
        keyCounts:   [String: Int]? = nil,
        layout:      LayoutRegistry = .shared
    ) -> Double {
        guard bigramCount > 0 else { return 100.0 }
        let engine = layout.ergonomicScoreEngine
        let tiRatio = keyCounts.flatMap {
            layout.thumbImbalanceDetector.imbalanceRatio(counts: $0, layout: layout)
        } ?? 0.0
        let teCoeff = keyCounts.flatMap {
            layout.thumbEfficiencyCalculator.coefficient(counts: $0, layout: layout)
        } ?? 0.0
        // Frequency-weighted mean row distance from home row (row 2), normalised to [0, 1].
        var reachSum   = 0.0
        var reachTotal = 0
        if let kc = keyCounts {
            for (key, count) in kc where count > 0 {
                guard let pos = layout.current.position(for: key) else { continue }
                reachSum   += Double(abs(pos.row - 2) * count)
                reachTotal += count
            }
        }
        let rowReach = reachTotal > 0 ? min(reachSum / Double(reachTotal) / 2.0, 1.0) : 0.0
        return engine.score(
            sameFingerRate:             Double(sfCount)  / Double(bigramCount),
            highStrainRate:             Double(hsCount)  / Double(bigramCount),
            thumbImbalanceRatio:        tiRatio,
            rowReachScore:              rowReach,
            handAlternationRate:        Double(altCount) / Double(bigramCount),
            thumbEfficiencyCoefficient: teCoeff
        )
    }
}
