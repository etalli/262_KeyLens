import AppKit

// MARK: - KeystrokeEvent

struct KeystrokeEvent {
    let displayName: String
    let keyCode: UInt16
    let flags: CGEventFlags
    let isNumpad: Bool
    /// True when the key is a standalone modifier (Shift, Cmd, etc.) with no other key.
    /// The overlay skips these; the inspector shows them.
    let isModifierOnly: Bool
}

// MARK: - Dependency protocols

protocol KeyEventHandling {
    @discardableResult
    func increment(key: String, at timestamp: Date, appName: String?) -> (count: Int, milestone: Bool)
    func recordSlowEvent()
    func incrementModified(key: String)
}

protocol BreakReminderManaging {
    func didType()
}

protocol NotificationManaging {
    func notify(key: String, count: Int)
}

// MARK: - Protocol conformances

extension KeyCountStore: KeyEventHandling {}
extension BreakReminderManager: BreakReminderManaging {}
extension NotificationManager: NotificationManaging {}

/// Threshold in milliseconds above which handleEvent is considered slow.
/// この値を超えた場合、app.log に警告を記録し slowEventCount をインクリメントする。
private let kHandleEventSlowThresholdMs: Double = 5.0

/// CGEventTap でグローバルキー入力を監視するクラス
final class KeyboardMonitor {
    private(set) var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let store: KeyEventHandling
    private let breakManager: BreakReminderManaging
    private let notificationManager: NotificationManaging

    init(
        store: KeyEventHandling = KeyCountStore.shared,
        breakManager: BreakReminderManaging = BreakReminderManager.shared,
        notificationManager: NotificationManaging = NotificationManager.shared
    ) {
        self.store = store
        self.breakManager = breakManager
        self.notificationManager = notificationManager
    }

    /// 現在監視中かどうか
    var isRunning: Bool {
        guard let tap = eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    /// 監視開始。アクセシビリティ権限がない場合は false を返す
    @discardableResult
    func start() -> Bool {
        let trusted = AXIsProcessTrusted()
        KeyLens.log("start() called — AXIsProcessTrusted: \(trusted)")
        guard trusted else { return false }

        // 既存タップの再有効化を先に試みる（権限再付与後の高速復帰）
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            if CGEvent.tapIsEnabled(tap: tap) {
                KeyLens.log("Existing tap re-enabled successfully")
                return true
            }
            // 再有効化できなかった場合は破棄して新規作成
            KeyLens.log("Existing tap could not be re-enabled — recreating")
            stop()
        }

        var mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        mask |= CGEventMask(1 << CGEventType.keyUp.rawValue)
        mask |= CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
        mask |= CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
        mask |= CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
        mask |= CGEventMask(1 << CGEventType.mouseMoved.rawValue)

        // .listenOnly + .tailAppendEventTap = 最小権限での監視
        // userInfo に self を渡すことで、コールバックが AppDelegate に依存せず tap を再有効化できる
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: inputTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        KeyLens.log("CGEvent.tapCreate result: \(tap != nil ? "success" : "nil (FAILED)")")
        guard let tap else { return false }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        KeyLens.log("Monitoring started successfully")
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    /// CGKeyCode → 表示用キー名
    static func keyName(for code: CGKeyCode) -> String {
        let map: [CGKeyCode: String] = [
            0: "a",   1: "s",   2: "d",   3: "f",   4: "h",   5: "g",
            6: "z",   7: "x",   8: "c",   9: "v",   11: "b",  12: "q",
            13: "w",  14: "e",  15: "r",  16: "y",  17: "t",
            18: "1",  19: "2",  20: "3",  21: "4",  22: "6",  23: "5",
            24: "=",  25: "9",  26: "7",  27: "-",  28: "8",  29: "0",
            30: "]",  31: "o",  32: "u",  33: "[",  34: "i",  35: "p",
            36: "Return", 37: "l", 38: "j", 39: "'", 40: "k", 41: ";",
            42: "\\", 43: ",",  44: "/",  45: "n",  46: "m",  47: ".",
            48: "Tab", 49: "Space", 51: "Delete", 53: "Escape",
            55: "⌘Cmd", 56: "⇧Shift", 57: "CapsLock",
            58: "⌥Option", 59: "⌃Ctrl", 76: "Enter(Num)",
            96: "F5",  97: "F6",  98: "F7",  99: "F3",  100: "F8",
            101: "F9", 103: "F11", 109: "F10", 111: "F12",
            118: "F4", 120: "F2", 122: "F1",
            117: "⌦FwdDel",
            123: "←",  124: "→",  125: "↓",  126: "↑",
        ]
        return map[code] ?? "Key(\(code))"
    }

    /// CGEventFlags から修飾キープレフィックス文字列を返す（macOS 慣例の ⌃⌥⇧⌘ 順）
    static func modifierPrefix(for flags: CGEventFlags) -> String {
        var prefix = ""
        if flags.contains(.maskControl)   { prefix += "⌃" }
        if flags.contains(.maskAlternate) { prefix += "⌥" }
        if flags.contains(.maskShift)     { prefix += "⇧" }
        if flags.contains(.maskCommand)   { prefix += "⌘" }
        return prefix
    }

    /// キー名 → 表示シンボルの共通マップ（OverlayViewModel と共有）
    static let symbolMap: [String: String] = [
        "Return":     "↵",
        "Delete":     "⌫",
        "Space":      "⎵",
        "Tab":        "⇥",
        "Escape":     "⎋",
        "Enter(Num)": "↵",
        "⌦FwdDel":   "⌦",
        "⌘Cmd":      "⌘",
        "⇧Shift":    "⇧",
        "⌥Option":   "⌥",
        "⌃Ctrl":     "⌃",
        "CapsLock":   "⇪",
    ]

    /// オーバーレイ表示用: 修飾キーをプレフィックスとして結合した表示文字列を返す
    /// 例: Shift+A → "⇧A"、Cmd+C → "⌘C"、Cmd+Shift+Z → "⇧⌘Z"、Return → "Return"（変換はOverlayViewModelに委譲）
    static func overlayDisplayName(for event: CGEvent, keyName: String) -> String {
        let modPrefix = modifierPrefix(for: event.flags)

        guard !modPrefix.isEmpty else { return keyName }  // 修飾なし: OverlayViewModelのsymbol()に委譲

        // 修飾あり: 特殊キーをシンボルに変換し、文字キーを大文字にする
        let base: String
        if let sym = symbolMap[keyName] {
            base = sym
        } else if keyName.count == 1, keyName.first?.isLetter == true {
            base = keyName.uppercased()
        } else {
            base = keyName
        }
        return modPrefix + base
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let keystrokeInput    = Notification.Name("com.keylens.keystrokeInput")
    static let keystrokeReleased = Notification.Name("com.keylens.keystrokeReleased")
}

// MARK: - CGEventTap コールバック
// @convention(c) 互換にするためグローバル関数として定義。
// All logic is delegated to KeyboardMonitor.handleEvent(proxy:type:event:) via refcon.
// すべての処理は refcon 経由でインスタンスメソッドに委譲する。
private func inputTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passRetained(event) }
    return Unmanaged<KeyboardMonitor>.fromOpaque(refcon)
        .takeUnretainedValue()
        .handleEvent(proxy: proxy, type: type, event: event)
}

// MARK: - KeyboardMonitor event handling

extension KeyboardMonitor {
    /// Handles a single CGEventTap event. Called from the global trampoline via refcon.
    /// グローバルトランポリンから refcon 経由で呼ばれるイベントハンドラ。
    func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // タイムアウトで無効化された場合は即座に再有効化
        if type == .tapDisabledByTimeout {
            KeyLens.log("CGEventTap disabled by timeout — re-enabling")
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return nil
        }

        // keyUp: notify inspector so it can remove the key from the held-keys list.
        if type == .keyUp {
            let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .keystrokeReleased, object: code)
            }
            return Unmanaged.passRetained(event)
        }

        // Mouse movement: accumulate distance only, no keystroke recording
        // マウス移動: 距離を蓄積するのみ、キーストローク記録には含めない
        if type == .mouseMoved {
            let dx = event.getDoubleValueField(.mouseEventDeltaX)
            let dy = event.getDoubleValueField(.mouseEventDeltaY)
            MouseStore.shared.addMovement(dx: dx, dy: dy)
            return Unmanaged.passRetained(event)
        }

        let name: String
        switch type {
        case .keyDown:
            let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            name = KeyboardMonitor.keyName(for: code)
        case .leftMouseDown:
            name = "🖱Left"
        case .rightMouseDown:
            name = "🖱Right"
        case .otherMouseDown:
            // ボタン番号 2 = 中ボタン、それ以外は番号で識別
            let btn = event.getIntegerValueField(.mouseEventButtonNumber)
            name = btn == 2 ? "🖱Middle" : "🖱Button\(btn)"
        default:
            return Unmanaged.passRetained(event)
        }

        // Check WPM hotkey before recording the keystroke (Issue #151)
        if type == .keyDown, WPMHotkeyManager.shared.matches(event: event) {
            DispatchQueue.main.async { WPMHotkeyManager.shared.toggle() }
        }

        // Check Overlay hotkey (Issue #179)
        if type == .keyDown, OverlayHotkeyManager.shared.matches(event: event) {
            OverlayHotkeyManager.shared.toggle()
        }

        let now = Date()
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName
        let incrementStart = Date()
        let result = store.increment(key: name, at: now, appName: appName)
        let elapsedMs = Date().timeIntervalSince(incrementStart) * 1000
        if elapsedMs > kHandleEventSlowThresholdMs {
            KeyLens.log("[perf] handleEvent slow: \(String(format: "%.1f", elapsedMs))ms (key: \(name))")
            store.recordSlowEvent()
        }
        breakManager.didType()

        if result.milestone {
            // 通知はメインスレッドで発行
            DispatchQueue.main.async {
                self.notificationManager.notify(key: name, count: result.count)
            }
        }

        if type == .keyDown {
            let modifierKeyCodes: Set<CGKeyCode> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let isModifierOnly = modifierKeyCodes.contains(code)

            if !isModifierOnly {
                // Record modifier+key combinations (⌃⌥⇧⌘ prefix order)
                // 修飾キー+キーの組み合わせを記録（⌃⌥⇧⌘ 順プレフィックス）
                let activeFlags = event.flags.intersection([.maskControl, .maskAlternate, .maskShift, .maskCommand])
                if !activeFlags.isEmpty {
                    let prefix = KeyboardMonitor.modifierPrefix(for: activeFlags)
                    store.incrementModified(key: "\(prefix)\(name)")
                }
            }

            // Always post keystrokeInput so the inspector receives modifier-only keys too.
            // isModifierOnly lets the overlay skip them while the inspector shows them.
            let displayName = KeyboardMonitor.overlayDisplayName(for: event, keyName: name)
            let isNumpad = event.flags.contains(.maskNumericPad)
            let evt = KeystrokeEvent(
                displayName: displayName,
                keyCode: code,
                flags: event.flags,
                isNumpad: isNumpad,
                isModifierOnly: isModifierOnly
            )
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .keystrokeInput, object: evt)
            }
        }
        return Unmanaged.passRetained(event)
    }
}
