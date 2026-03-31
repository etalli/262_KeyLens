import Foundation
import IOKit.hid
import KeyLensCore

// MARK: - KeyboardDeviceInfo

/// IOHIDManager を使って現在接続中のキーボードデバイス名・種別を取得するユーティリティ
enum KeyboardDeviceInfo {

    /// Returns connected keyboard product names deduplicated and sorted (legacy API).
    /// 接続中のキーボード製品名を重複除去・昇順で返す（後方互換用）。
    static func connectedNames() -> [String] {
        connectedDevices().map(\.name)
    }

    /// Returns connected keyboard devices with name and kind (internal vs. external).
    ///
    /// Detection rules:
    /// - Transport key == "SPI"  → `.internal`  (Apple Silicon built-in keyboard)
    /// - Product name contains "internal" (case-insensitive) → `.internal`
    /// - Otherwise → `.external`
    ///
    /// 接続中キーボードの名前と種別（内蔵/外付け）を返す。
    static func connectedDevices() -> [(name: String, kind: KeyboardKind)] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey:     kHIDUsage_GD_Keyboard,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        return connectedDevices(copyingFrom: manager)
    }

    /// Returns connected devices from an existing, run-loop-scheduled IOHIDManager.
    /// Use this overload inside hot-plug callbacks — the scheduled manager has already
    /// processed the removal event, so its device set is authoritative and up-to-date.
    /// ランループにスケジュール済みの IOHIDManager からデバイス一覧を返す。
    /// ホットプラグコールバック内では、このオーバーロードを使うこと。
    static func connectedDevices(using manager: IOHIDManager) -> [(name: String, kind: KeyboardKind)] {
        connectedDevices(copyingFrom: manager)
    }

    // Shared implementation: copies and parses the device set from any manager.
    private static func connectedDevices(copyingFrom manager: IOHIDManager) -> [(name: String, kind: KeyboardKind)] {
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return []
        }

        var seen = Set<String>()
        var result: [(name: String, kind: KeyboardKind)] = []

        for device in devices {
            guard let name = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String,
                  !name.isEmpty else { continue }

            guard seen.insert(name).inserted else { continue }

            let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String ?? ""
            let kind: KeyboardKind
            if transport == "SPI" || name.lowercased().contains("internal") {
                kind = .internal
            } else {
                kind = .external
            }

            result.append((name: name, kind: kind))
        }

        return result.sorted { $0.name < $1.name }
    }
}
