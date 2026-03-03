// RemappedLayout.swift
// A KeyboardLayout wrapper that applies a key-swap relocation map on top of any base layout.
// 任意のベースレイアウトにキースワップを重ねて適用するラッパー。
//
// ## How it works
//
// A relocation map encodes bidirectional key swaps as a dictionary:
//   relocationMap["a"] = "b"  →  key "a" now occupies "b"'s physical position
//   relocationMap["b"] = "a"  →  key "b" now occupies "a"'s physical position
//
// When RemappedLayout resolves finger/hand/position for key "a", it transparently
// delegates to the base layout using "b" as the lookup key. This correctly returns
// "b"'s ergonomic data for any key that has been relocated there.
//
// ## Composing multiple swaps
//
// Use KeyRelocationSimulator.applySwap(key1:key2:to:) to accumulate multiple swaps
// into a single relocation map. The composition rule preserves correctness:
//
//   Before: map = {}                   (identity — no swaps)
//   Swap A↔B: map = ["a":"b","b":"a"]
//   Swap B↔C: map = ["a":"b","b":"c","c":"a"]  (B is now at A's original position)
//
// リロケーションマップの合成は KeyRelocationSimulator.applySwap を使って行う。
// 複数スワップを1つのマップに正確に畳み込める。

import CoreGraphics

// MARK: - RemappedLayout

/// A keyboard layout that overrides ergonomic lookups for relocated keys.
///
/// Given `relocationMap = ["a": "b", "b": "a"]`:
///   - `finger(for: "a")` → returns the finger that presses "b" on the base layout
///   - `position(for: "b")` → returns the grid position of "a" on the base layout
///
/// This models the physical reality: the key labelled "a" now sits where "b" used to be.
/// "a" のキーキャップが "b" の物理位置に移動した状態を表現する。
public struct RemappedLayout: KeyboardLayout {
    public let name: String
    private let base: any KeyboardLayout
    /// Maps key name → physical position key name to inherit from.
    /// キー名 → 委譲先の物理位置キー名。
    private let relocationMap: [String: String]

    public init(base: any KeyboardLayout, relocationMap: [String: String]) {
        self.base = base
        self.relocationMap = relocationMap
        self.name = relocationMap.isEmpty ? base.name : "\(base.name)(remapped)"
    }

    // Resolve: if this key has been relocated, look up using the physical position key.
    // 移動済みキーは物理位置キー名で委譲先を解決する。
    private func resolve(_ keyName: String) -> String {
        relocationMap[keyName] ?? keyName
    }

    public func position(for keyCode: CGKeyCode) -> KeyPosition? {
        base.position(for: keyCode)
    }

    public func hand(for keyName: String) -> Hand? {
        base.hand(for: resolve(keyName))
    }

    public func finger(for keyName: String) -> Finger? {
        base.finger(for: resolve(keyName))
    }

    public func position(for keyName: String) -> KeyPosition? {
        base.position(for: resolve(keyName))
    }
}

// MARK: - KeyRelocationSimulator

/// Builds RemappedLayouts and accumulates key swaps into a relocation map.
///
/// Usage:
/// ```swift
/// var map: [String: String] = [:]
/// KeyRelocationSimulator.applySwap(key1: "f", key2: "j", to: &map)
/// let simulated = KeyRelocationSimulator.layout(applying: map, over: ANSILayout())
/// ```
/// 使い方は上記の通り。applySwap でスワップを蓄積し、layout でシミュレーション用レイアウトを生成。
public struct KeyRelocationSimulator {

    public init() {}

    /// Returns a RemappedLayout with the accumulated relocation map applied.
    /// 蓄積されたリロケーションマップを適用した RemappedLayout を返す。
    public static func layout(
        applying relocationMap: [String: String],
        over base: any KeyboardLayout
    ) -> RemappedLayout {
        RemappedLayout(base: base, relocationMap: relocationMap)
    }

    /// Applies a bidirectional key swap to an accumulated relocation map.
    ///
    /// This function correctly handles chains: swapping a key that was already relocated
    /// will update the map so the composition remains valid.
    ///
    /// 双方向スワップをリロケーションマップに適用する。既にスワップ済みのキーも正しく合成される。
    public static func applySwap(
        key1: String,
        key2: String,
        to map: inout [String: String]
    ) {
        let phys1 = map[key1] ?? key1
        let phys2 = map[key2] ?? key2
        map[key1] = phys2
        map[key2] = phys1
        // Remove identity entries to keep the map minimal.
        // 恒等マッピングを削除してマップを最小化する。
        if map[key1] == key1 { map.removeValue(forKey: key1) }
        if map[key2] == key2 { map.removeValue(forKey: key2) }
    }
}
