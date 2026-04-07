import Foundation
import KeyLensCore

/// AI プロンプトの永続化と取得を管理するシングルトン
final class AIPromptStore {
    static let shared = AIPromptStore()
    private init() {}

    private static let defaults: [Language: String] = [
        .english: """
You are a keyboard layout optimization analyst.

Using the provided key input log:

1. Compute:
   - Total key frequency
   - Bigram and trigram frequency
   - Same-finger repetition rate
   - Hand alternation rate
   - Temporal change of frequency (learning/adaptation trend)
   - Inferred typing style (code/prose/chat)
   - Detected fatigue risk level

2. Identify:
   - Keys that cause high ergonomic load
   - Keys that would benefit from relocation to thumbs
   - Frequently combined key pairs suitable for thumb modifiers

3. Assume:
   - Split keyboard
   - 4 thumb keys per hand
   - Minimize finger travel and same-finger repetition

Output:
- Data summary table
- Optimization reasoning
- Recommended thumb assignments
- Expected ergonomic improvement estimate
""",
        .japanese: """
あなたはキーボードレイアウト最適化の専門家です。

以下のキー入力ログを分析してください：

1. 計算してください：
   - キーごとの使用頻度
   - バイグラム・トライグラム頻度
   - 同指連続入力率
   - 左右交互打鍵率
   - 頻度の時系列変化（学習・適応トレンド）
   - 推定タイピングスタイル（開発/執筆/チャット）
   - 推定される疲労リスクレベル

2. 特定してください：
   - 人間工学的負荷が高いキー
   - 親指キーに移動すると効果的なキー
   - 親指モディファイアに適したキーの組み合わせ

3. 前提条件：
   - 分割キーボード
   - 片手4つの親指キー
   - 指の移動距離と同指連続入力を最小化

出力：
- データサマリー表
- 最適化の根拠
- 推奨親指キー割り当て
- 期待される人間工学的改善効果の推定
"""
    ]

    private static func key(for lang: Language) -> String {
        "aiPrompt_\(lang.rawValue)"
    }

    /// Builds a layout context block describing the active keyboard's key→finger/hand mapping.
    /// Used as a preamble so the AI receives accurate ergonomic context for custom split keyboards.
    private func layoutPreamble() -> String {
        let registry = LayoutRegistry.shared
        let layout = registry.current

        // Collect all key names known to the active layout via ANSILayout as a baseline,
        // then resolve each through the registry (respects splitConfig overrides).
        let keyNames = ANSILayout.handTable.keys.sorted()

        var thumbKeys: [String] = []
        var rows: [String] = []

        for name in keyNames {
            guard let finger = layout.finger(for: name),
                  let hand   = registry.hand(for: name) else { continue }
            rows.append("  \(name): \(hand.rawValue) \(finger.rawValue)")
            if finger == .thumb { thumbKeys.append(name) }
        }

        var block = "## Active keyboard layout: \(registry.currentDeviceLabel)\n"
        block += "Key → finger assignments:\n"
        block += rows.joined(separator: "\n")
        if !thumbKeys.isEmpty {
            block += "\n\nThumb-assigned keys: \(thumbKeys.joined(separator: ", "))"
        }
        block += "\n\n---\n\n"
        return block
    }

    /// 現在の言語に対応するプロンプトを返す（カスタム保存済みがあればそれを優先）
    /// A layout preamble is always prepended so the AI uses the correct finger assignments.
    var currentPrompt: String {
        let lang = L10n.shared.resolved
        let base = UserDefaults.standard.string(forKey: Self.key(for: lang))
            ?? Self.defaults[lang]
            ?? Self.defaults[.english]!
        return layoutPreamble() + base
    }

    /// 現在の言語に対応するプロンプトを保存する
    func save(_ prompt: String) {
        let lang = L10n.shared.resolved
        UserDefaults.standard.set(prompt, forKey: Self.key(for: lang))
    }
}
