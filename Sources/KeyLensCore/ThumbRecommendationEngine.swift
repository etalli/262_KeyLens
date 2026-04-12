// ThumbRecommendationEngine.swift
// Recommends which high-burden keys should be relocated to thumb positions.
// 高負荷キーを親指ポジションに移すべきかを提案するエンジン。
//
// ## Motivation
//
// Thumb keys are uniquely high-value real estate on split keyboards.
// ThumbImbalanceDetector (#26) and ThumbEfficiencyCalculator (#27) measure
// existing thumb usage, but do not tell the user *what to do*.
// This engine turns those signals into actionable relocation proposals.
//
// ## Algorithm
//
//   burden(key) = count / fingerLoadWeight(finger)
//
// Moving a key from a weak finger (e.g. pinky, weight=0.5) to a thumb (weight=0.8)
// yields a burden reduction:
//
//   burdenReduction = count × (1/fingerWeight − 1/thumbWeight)
//
// This is positive only when the original finger is weaker than the thumb
// (pinky: 0.5, ring: 0.6). Index and middle finger keys are never recommended.
//
// Slot assignment corrects thumb imbalance (#26): if the left thumb currently
// handles more load than the right, right-side slots are preferred first.
//
// ピンキー(0.5)やリング(0.6)など親指より弱い指のキーのみ推薦対象となる。
// スロット割り当ては親指の偏りを補正する方向で交互に割り当てる。
//
// ## Phase
// Phase 2 – Optimization Engine (Issue #37)

import Foundation

// MARK: - ThumbSlot

/// Identifies which hand's thumb cluster should receive a relocated key.
/// 移動先の親指クラスターを表す。
public enum ThumbSlot: String, CaseIterable, Equatable {
    /// Left thumb cluster (e.g. left Cmd / Option position on a split keyboard).
    /// 左親指クラスター（例：スプリットキーボードの左 Cmd / Option ポジション）。
    case left

    /// Right thumb cluster (e.g. right Cmd / Option position on a split keyboard).
    /// 右親指クラスター（例：スプリットキーボードの右 Cmd / Option ポジション）。
    case right
}

// MARK: - ThumbRecommendation

/// A single relocation proposal produced by ThumbRecommendationEngine.
/// ThumbRecommendationEngine が生成する1件の移動提案。
public struct ThumbRecommendation: Equatable {

    /// The key that should be relocated to a thumb position.
    /// 親指ポジションへ移動すべきキー。
    public let key: String

    /// The thumb cluster that would best receive this key (imbalance-corrected).
    /// このキーの移動先として最適な親指クラスター（偏り補正済み）。
    public let suggestedSlot: ThumbSlot

    /// Estimated burden reduction if this key is moved to the suggested slot.
    ///
    /// `burdenReduction = count × (1/fingerWeight − 1/thumbWeight)`
    ///
    /// A larger value means a greater ergonomic benefit from the relocation.
    /// 正の値が大きいほど移動による負荷軽減効果が高い。
    public let burdenReduction: Double
}

// MARK: - ThumbRecommendationEngine

/// Generates ranked recommendations for relocating high-burden keys to thumb positions.
///
/// Usage:
/// ```swift
/// let engine = ThumbRecommendationEngine()
/// let recs = engine.topRecommendations(from: store.allCounts, layout: LayoutRegistry.shared)
/// // → [ThumbRecommendation(key: ";", suggestedSlot: .right, burdenReduction: 750.0), …]
/// ```
/// 使い方は上記参照。allCounts と LayoutRegistry を渡すと推薦リストが返る。
public struct ThumbRecommendationEngine {

    /// Per-finger load weight table used to compute burden scores.
    /// バーデンスコア計算に使う指負荷重みテーブル。
    public let fingerWeights: FingerLoadWeight

    /// Keys that must not be relocated (e.g. system shortcuts, structural keys).
    /// 移動禁止キー（システムショートカット・構造キー等）。
    public let constraints: LayoutConstraints

    /// Maximum number of recommendations to return.
    /// 返す推薦件数の上限。
    public let topK: Int

    public init(
        fingerWeights: FingerLoadWeight = .default,
        constraints: LayoutConstraints = .macOSDefaults,
        topK: Int = 5
    ) {
        self.fingerWeights = fingerWeights
        self.constraints   = constraints
        self.topK          = topK
    }

    // MARK: - Default

    /// Default configuration: standard finger weights, macOS constraints, top 5 results.
    /// デフォルト設定：標準指重み・macOS制約・上位5件。
    public static let `default` = ThumbRecommendationEngine()

    // MARK: - Core

    /// Returns the top recommendations for thumb relocation, sorted by burden reduction.
    ///
    /// Keys are excluded if they are:
    ///   - Already assigned to the thumb finger in the layout.
    ///   - Listed in `constraints.fixedKeys`.
    ///   - On an index or middle finger (moving them to thumb would increase burden).
    ///
    /// The `suggestedSlot` alternates between left and right, starting with the side
    /// that has less current thumb load (to correct thumb imbalance).
    ///
    /// すでに親指キー・固定キー・人差し指/中指キーは除外される。
    /// suggestedSlot は現在の親指負荷が少ない側から交互に割り当てる。
    public func topRecommendations(
        from counts: [String: Int],
        layout: LayoutRegistry
    ) -> [ThumbRecommendation] {
        let thumbWeight = fingerWeights.weight(for: .thumb)

        // Step 1: Compute current thumb load per hand to determine preferred slot order.
        // 現在の親指負荷を左右で集計し、補正方向を決める。
        var leftThumbCount  = 0
        var rightThumbCount = 0
        for (key, count) in counts {
            guard layout.finger(for: key) == .thumb else { continue }
            switch layout.hand(for: key) {
            case .left:  leftThumbCount  += count
            case .right: rightThumbCount += count
            case .none:  break
            }
        }
        // Prefer the less-loaded side first to correct imbalance.
        // 負荷の少ない側を優先して偏りを補正する。
        let preferredSlots: [ThumbSlot] = leftThumbCount <= rightThumbCount
            ? [.left, .right]
            : [.right, .left]

        // Step 2: Build and rank candidates by burden reduction.
        // 候補を burdenReduction の降順で並べる。
        struct Candidate {
            let key: String
            let burdenReduction: Double
        }

        let candidates: [Candidate] = counts.compactMap { key, count -> Candidate? in
            guard count > 0 else { return nil }
            guard !constraints.fixedKeys.contains(key) else { return nil }
            guard let finger = layout.finger(for: key) else { return nil }
            guard finger != .thumb else { return nil }  // already a thumb key

            let w = fingerWeights.weight(for: finger)
            let reduction = Double(count) * (1.0 / w - 1.0 / thumbWeight)
            guard reduction > 0 else { return nil }     // only beneficial moves

            return Candidate(key: key, burdenReduction: reduction)
        }.sorted { $0.burdenReduction > $1.burdenReduction }

        // Step 3: Assign slots alternately, starting with the imbalance-preferred side.
        // 補正方向から交互にスロットを割り当てる。
        return candidates.prefix(topK).enumerated().map { index, candidate in
            ThumbRecommendation(
                key: candidate.key,
                suggestedSlot: preferredSlots[index % 2],
                burdenReduction: candidate.burdenReduction
            )
        }
    }
}
