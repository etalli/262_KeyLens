import Foundation

/// Defines common typing contexts detected by KeyLens.
/// 打鍵パターンから推定された利用シーン。
public enum TypingStyle: String, Codable, CaseIterable {
    /// Natural language writing (articles, emails, etc.).
    /// 自然言語の執筆（記事、メール等）。
    case prose
    
    /// Software development (high use of symbols and specific keywords).
    /// ソフトウェア開発（記号や特定キーワードの多用）。
    case code
    
    /// Instant messaging or terminal usage (frequent Return/Enter).
    /// チャットやターミナル操作（頻繁な改行）。
    case chat
    
    /// Insufficient data or mixed usage.
    /// 判定不可または混合。
    case unknown
}

/// Analyzes keystroke distributions to infer the active typing style.
/// 打鍵分布からタイピングのスタイルを分析するエンジン。
public struct TypingStyleAnalyzer {
    
    public init() {}
    
    /// Infers the typing style from cumulative or windowed key counts.
    /// 累積または期間内のキーカウントからスタイルを推定する。
    public func analyze(keyCounts: [String: Int]) -> TypingStyle {
        let total = keyCounts.values.reduce(0, +)
        guard total > 50 else { return .unknown } // Need a minimum sample size
        
        var categoryCounts: [KeyCategory: Int] = [:]
        for (key, count) in keyCounts {
            let cat = KeyCategory.classify(key)
            categoryCounts[cat, default: 0] += count
        }
        
        let letterRatio = Double(categoryCounts[.letter, default: 0]) / Double(total)
        let symbolRatio = Double(categoryCounts[.symbol, default: 0]) / Double(total)
        let returnCount = keyCounts["Return", default: 0] + keyCounts["Enter(Num)", default: 0]
        let returnRatio = Double(returnCount) / Double(total)
        
        // Code usually has a significantly higher proportion of symbols compared to prose.
        // 日本語入力の場合、記号率は低い傾向にあるため、閾値は慎重に設定。
        if symbolRatio > 0.08 {
            return .code
        }
        
        // Chat or CLI usage often involves frequent Return presses.
        if returnRatio > 0.05 {
            return .chat
        }
        
        // Prose is dominated by letters.
        if letterRatio > 0.70 {
            return .prose
        }
        
        return .unknown
    }
}
