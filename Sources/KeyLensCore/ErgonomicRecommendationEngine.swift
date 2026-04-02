// ErgonomicRecommendationEngine.swift
// Rule-based ergonomic recommendations from snapshot metrics.
// スナップショット指標からルールベースの改善提案を生成する。

import Foundation

// MARK: - ErgonomicRecommendationSeverity

/// Relative urgency of a recommendation.
/// 提案の優先度。
public enum ErgonomicRecommendationSeverity: Int, Equatable {
    case low = 1
    case medium = 2
    case high = 3
}

// MARK: - ErgonomicRecommendation

/// One actionable ergonomic suggestion generated from a snapshot.
/// スナップショットから生成される1件の改善提案。
public struct ErgonomicRecommendation: Equatable {
    /// Stable identifier for this recommendation rule.
    /// 提案ルールの安定ID。
    public let id: String

    /// L10n key for short title (UI string lives in app target).
    /// 短いタイトル表示用のL10nキー。
    public let titleKey: String

    /// L10n key for detail/help text.
    /// 詳細説明用のL10nキー。
    public let detailKey: String

    /// Relative urgency.
    /// 優先度。
    public let severity: ErgonomicRecommendationSeverity

    /// Confidence in [0, 1].
    /// 推定信頼度（0〜1）。
    public let confidence: Double

    /// Estimated score gain if the recommendation is addressed.
    /// 対応した場合の推定スコア改善幅。
    public let estimatedScoreGain: Double
}

// MARK: - ErgonomicRecommendationEngine

/// Generates top ergonomic recommendations from `ErgonomicSnapshot`.
/// `ErgonomicSnapshot` から改善提案の上位結果を生成する。
public struct ErgonomicRecommendationEngine {
    public let topK: Int
    public let minimumSampleCount: Int
    public let weights: ErgonomicScoreWeights

    // Rule thresholds
    public let sameFingerRateThreshold: Double
    public let highStrainRateThreshold: Double
    public let handAlternationFloor: Double
    public let rowReachThreshold: Double

    public init(
        topK: Int = 3,
        minimumSampleCount: Int = 120,
        weights: ErgonomicScoreWeights = .default,
        sameFingerRateThreshold: Double = 0.08,
        highStrainRateThreshold: Double = 0.04,
        handAlternationFloor: Double = 0.45,
        rowReachThreshold: Double = 0.32
    ) {
        self.topK = max(1, topK)
        self.minimumSampleCount = max(1, minimumSampleCount)
        self.weights = weights
        self.sameFingerRateThreshold = sameFingerRateThreshold
        self.highStrainRateThreshold = highStrainRateThreshold
        self.handAlternationFloor = handAlternationFloor
        self.rowReachThreshold = rowReachThreshold
    }

    public static let `default` = ErgonomicRecommendationEngine()

    /// Returns ranked recommendations.
    ///
    /// - Parameters:
    ///   - snapshot: Current ergonomic snapshot.
    ///   - sampleCount: Number of analyzed bigrams/key transitions.
    /// - Returns: Top-K recommendations sorted by severity/confidence/gain/id.
    public func topRecommendations(
        from snapshot: ErgonomicSnapshot,
        sampleCount: Int
    ) -> [ErgonomicRecommendation] {
        guard sampleCount >= minimumSampleCount else { return [] }

        let sampleConfidence = min(Double(sampleCount) / Double(minimumSampleCount * 4), 1.0)
        var recs: [ErgonomicRecommendation] = []

        if snapshot.sameFingerRate > sameFingerRateThreshold {
            let exceed = snapshot.sameFingerRate - sameFingerRateThreshold
            let gain = min(exceed * weights.sameFingerPenalty * 100.0, 12.0)
            recs.append(
                ErgonomicRecommendation(
                    id: "same_finger_repetition",
                    titleKey: "ergoRec.sameFinger.title",
                    detailKey: "ergoRec.sameFinger.detail",
                    severity: severity(for: exceed, high: 0.07, medium: 0.03),
                    confidence: calibratedConfidence(exceed: exceed, span: 0.12, sampleConfidence: sampleConfidence),
                    estimatedScoreGain: gain
                )
            )
        }

        if snapshot.highStrainRate > highStrainRateThreshold {
            let exceed = snapshot.highStrainRate - highStrainRateThreshold
            let gain = min(exceed * weights.highStrainPenalty * 100.0, 10.0)
            recs.append(
                ErgonomicRecommendation(
                    id: "outer_column_load",
                    titleKey: "ergoRec.outerColumn.title",
                    detailKey: "ergoRec.outerColumn.detail",
                    severity: severity(for: exceed, high: 0.06, medium: 0.025),
                    confidence: calibratedConfidence(exceed: exceed, span: 0.10, sampleConfidence: sampleConfidence),
                    estimatedScoreGain: gain
                )
            )
        }

        if snapshot.handAlternationRate < handAlternationFloor {
            let exceed = handAlternationFloor - snapshot.handAlternationRate
            let gain = min(exceed * weights.alternationReward * 100.0, 8.0)
            recs.append(
                ErgonomicRecommendation(
                    id: "weak_hand_alternation",
                    titleKey: "ergoRec.alternation.title",
                    detailKey: "ergoRec.alternation.detail",
                    severity: severity(for: exceed, high: 0.20, medium: 0.10),
                    confidence: calibratedConfidence(exceed: exceed, span: 0.35, sampleConfidence: sampleConfidence),
                    estimatedScoreGain: gain
                )
            )
        }

        if snapshot.rowReachScore > rowReachThreshold {
            let exceed = snapshot.rowReachScore - rowReachThreshold
            let gain = min(exceed * weights.rowReachPenalty * 100.0, 9.0)
            recs.append(
                ErgonomicRecommendation(
                    id: "high_row_reach",
                    titleKey: "ergoRec.rowReach.title",
                    detailKey: "ergoRec.rowReach.detail",
                    severity: severity(for: exceed, high: 0.18, medium: 0.08),
                    confidence: calibratedConfidence(exceed: exceed, span: 0.28, sampleConfidence: sampleConfidence),
                    estimatedScoreGain: gain
                )
            )
        }

        return recs
            .sorted {
                if $0.severity.rawValue != $1.severity.rawValue {
                    return $0.severity.rawValue > $1.severity.rawValue
                }
                if $0.confidence != $1.confidence {
                    return $0.confidence > $1.confidence
                }
                if $0.estimatedScoreGain != $1.estimatedScoreGain {
                    return $0.estimatedScoreGain > $1.estimatedScoreGain
                }
                return $0.id < $1.id
            }
            .prefix(topK)
            .map { $0 }
    }

    private func severity(
        for exceed: Double,
        high: Double,
        medium: Double
    ) -> ErgonomicRecommendationSeverity {
        if exceed >= high { return .high }
        if exceed >= medium { return .medium }
        return .low
    }

    private func calibratedConfidence(
        exceed: Double,
        span: Double,
        sampleConfidence: Double
    ) -> Double {
        guard span > 0 else { return 0.0 }
        let signal = min(max(exceed / span, 0.0), 1.0)
        return min(max(0.35 + signal * 0.65, 0.0), 1.0) * sampleConfidence
    }
}
