// LayoutConstraints.swift
// Declares which keys the optimization engine must not relocate.
// オプティマイザが移動を禁止するキーを定義する構造体。
//
// ## Purpose
// Some keys cannot safely be relocated:
//   - System shortcuts that users rely on muscle memory for (⌘Q, ⌘C, ⌘V …)
//   - Hardware-fixed keys (Escape, Return, Tab)
//   - Application-specific bindings
//
// LayoutConstraints is passed to every optimizer so they can skip fixed keys
// before proposing any relocation.
//
// 固定キーはオプティマイザに渡され、移動候補から除外される。
// ショートカットや固定キーを誤って移動しないようにするための安全機構。

import Foundation

/// Specifies keys the optimization engine must preserve in place.
/// オプティマイザが位置を変えてはならないキーを指定する。
public struct LayoutConstraints: Equatable {

    /// Keys that must not be relocated by any optimizer.
    /// いかなるオプティマイザも移動してはならないキー集合。
    public var fixedKeys: Set<String>

    public init(fixedKeys: Set<String> = []) {
        self.fixedKeys = fixedKeys
    }

    // MARK: - Presets

    /// Locks common macOS system shortcut keys and essential structural keys.
    ///
    /// Includes: ⌘Q/W/A/S/C/V/X/Z (system shortcuts), Tab, Escape, Return, Delete,
    /// and the standard modifier keys.
    ///
    /// macOS システムショートカット・必須構造キーをすべてロックするプリセット。
    public static let macOSDefaults = LayoutConstraints(fixedKeys: [
        // Command shortcuts — moving these breaks muscle memory for system operations.
        // システムショートカット — 移動すると操作の筋肉記憶が壊れる。
        "q", "w", "a", "s", "c", "v", "x", "z",
        // Structural keys — essential navigation / editing keys that must stay fixed.
        // 構造キー — ナビゲーション・編集に必須。
        "Space", "Return", "Tab", "Escape", "Delete",
        // Modifier keys
        "⌘Cmd", "⌥Option", "⌃Ctrl", "⇧Shift",
    ])

    /// No constraints — every key in the layout is a candidate for relocation.
    /// 制約なし — すべてのキーが移動候補になる。
    public static let none = LayoutConstraints(fixedKeys: [])
}
