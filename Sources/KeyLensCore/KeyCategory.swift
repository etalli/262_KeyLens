import Foundation

/// Defines high-level categories for keys, used for usage style analysis.
/// 統計・スタイル分析に使用するキーの分類。
public enum KeyCategory: String, CaseIterable, Codable {
    case letter
    case number
    case symbol
    case control
    case function
    case nav        // Arrows, PageUp/Down, etc.
    case mouse
    case other

    /// Classifies a key name into a KeyCategory.
    /// キー名をカテゴリに分類する。
    public static func classify(_ key: String) -> KeyCategory {
        if key.hasPrefix("🖱") { return .mouse }

        if key.count == 1, let scalar = key.unicodeScalars.first {
            let v = scalar.value
            if (v >= 97 && v <= 122) || (v >= 65 && v <= 90) { return .letter } // a–z, A-Z
            if v >= 48 && v <= 57 { return .number } // 0–9
            
            // Symbols: things like !@#$%^&*()_+{}|:"<>?~`-=[]\(punctuation)
            let symbolScalars: CharacterSet = .punctuationCharacters.union(.symbols)
            if symbolScalars.contains(scalar) { return .symbol }
        }

        if ["←", "→", "↑", "↓"].contains(key) { return .nav }

        let controlKeys: Set<String> = [
            "Return", "Tab", "Space", "Delete", "Escape",
            "⌘Cmd", "⇧Shift", "CapsLock", "⌥Option", "⌃Ctrl",
            "Enter(Num)", "⌦FwdDel"
        ]
        if controlKeys.contains(key) { return .control }

        // F1–F12
        if key.count >= 2 && key.hasPrefix("F"), Int(key.dropFirst()) != nil { return .function }

        return .other
    }
}
