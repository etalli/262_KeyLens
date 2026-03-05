import Foundation

/// Defines detected typing fatigue risk levels.
/// 蓄積されたデータから推定されるタイピング疲労リスク。
public enum FatigueLevel: String, Codable, CaseIterable {
    /// Normal typing state.
    /// 正常。
    case low
    
    /// Signs of slight slowdown or increased strain patterns.
    /// 注意。わずかな速度低下や負荷パターンの増加。
    case moderate
    
    /// Significant slowdown or high repetitive strain detected.
    /// 警告。大幅な速度低下や反復負荷の検出。
    case high
}

/// Analyzes typing speed and strain trends to estimate fatigue risk.
/// 打鍵速度の変化や負荷傾向から疲労リスクを推定するエンジン。
public struct FatigueRiskModel {
    
    public init() {}
    
    /// Analyzes fatigue risk by comparing recent metrics against a base level.
    /// 直近の指標をベースラインと比較して疲労リスクを判定する。
    public func analyze(
        currentAvgIntervalMs: Double?,
        baselineAvgIntervalMs: Double?,
        currentHighStrainRate: Double,
        baselineHighStrainRate: Double
    ) -> FatigueLevel {
        
        var points = 0
        
        // 1. Typing speed slowdown (Speed decrease often correlates with fatigue)
        // 打鍵速度の低下（疲労によるパフォーマンス低下の指標）
        if let current = currentAvgIntervalMs, let base = baselineAvgIntervalMs, base > 0 {
            let slowdown = (current - base) / base
            if slowdown > 0.25 {
                points += 2 // Severe slowdown
            } else if slowdown > 0.10 {
                points += 1 // Moderate slowdown
            }
        }
        
        // 2. Increase in high-strain patterns
        // 高負荷パターンの占有率上昇
        if currentHighStrainRate > baselineHighStrainRate * 1.5 {
            points += 2
        } else if currentHighStrainRate > baselineHighStrainRate * 1.2 {
            points += 1
        }
        
        // 3. Absolute strain threshold
        // 絶対的な負荷閾値
        if currentHighStrainRate > 0.05 { // 5% of bigrams are high-strain
            points += 1
        }
        
        if points >= 3 {
            return .high
        } else if points >= 1 {
            return .moderate
        } else {
            return .low
        }
    }
}
