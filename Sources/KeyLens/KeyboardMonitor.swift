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
    /// Raw CGEventFlags bitmask — useful for firmware-level debugging.
    let rawFlags: UInt64
    /// USB HID usage page and usage ID derived from macOS keycode.
    /// page 0x07 = Keyboard/Keypad page (most keys). nil if the keycode is not in the table.
    let hidUsage: (page: UInt8, usage: UInt8)?
}

// MARK: - HID Usage Table (USB HID spec page 0x07 — Keyboard/Keypad)
// Maps macOS CGKeyCode → USB HID usage ID on page 0x07.
// Source: USB HID Usage Tables 1.3, Section 10.
private let hidUsageTable: [UInt16: UInt8] = [
    // Letters a–z
    0: 0x04, 11: 0x05, 8: 0x06, 2: 0x07, 14: 0x08, 3: 0x09, 5: 0x0A, 4: 0x0B,
    34: 0x0C, 38: 0x0D, 40: 0x0E, 37: 0x0F, 46: 0x10, 45: 0x11, 31: 0x12, 35: 0x13,
    12: 0x14, 15: 0x15, 1: 0x16, 17: 0x17, 32: 0x18, 9: 0x19, 13: 0x1A, 7: 0x1B,
    16: 0x1C, 6: 0x1D,
    // Digits 1–0
    18: 0x1E, 19: 0x1F, 20: 0x20, 21: 0x21, 23: 0x22, 22: 0x23,
    26: 0x24, 28: 0x25, 25: 0x26, 29: 0x27,
    // Symbol row: - = [ ] \ ; ' ` , . /
    27: 0x2D, 24: 0x2E, 33: 0x2F, 30: 0x30, 42: 0x31,
    41: 0x33, 39: 0x34, 50: 0x35, 43: 0x36, 47: 0x37, 44: 0x38,
    // Control keys
    36: 0x28, 76: 0x58, 53: 0x29, 51: 0x2A, 48: 0x2B, 49: 0x2C,
    // Arrow keys
    123: 0x50, 124: 0x4F, 125: 0x51, 126: 0x52,
    // Modifier keys
    56: 0xE1, 60: 0xE5, 55: 0xE3, 54: 0xE7, 58: 0xE2, 61: 0xE6, 59: 0xE0, 62: 0xE4,
    // CapsLock, F-keys
    57: 0x39, 122: 0x3A, 120: 0x3B, 99: 0x3C, 118: 0x3D, 96: 0x3E, 97: 0x3F,
    98: 0x40, 100: 0x41, 101: 0x42, 109: 0x43, 103: 0x44, 111: 0x45,
    // Navigation
    114: 0x49, 117: 0x4C, 115: 0x4A, 119: 0x4D, 116: 0x4B, 121: 0x4E,
    // ISO § key (international keyboards only)
    10: 0x64,
]

// MARK: - Dependency protocols

protocol KeyEventHandling {
    func increment(key: String, at timestamp: Date, appName: String?, completion: ((_ count: Int, _ milestone: Bool) -> Void)?)
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

    // Dedicated background thread and its run loop for the CGEventTap.
    // Isolates the tap from all main-thread work (SwiftUI renders, timers) so
    // macOS never disables it due to the ~1 s tapDisabledByTimeout threshold.
    private var tapThread: Thread?
    private var tapRunLoop: CFRunLoop?

    // Thread-safe cached app name: written on main (workspace notification),
    // read on the tap background thread.
    private let appNameLock = NSLock()
    private var _cachedAppName: String?
    private var cachedAppName: String? {
        get { appNameLock.withLock { _cachedAppName } }
        set { appNameLock.withLock { _cachedAppName = newValue } }
    }

    // Observer token to avoid duplicate workspace registrations across start() calls.
    private var appNameObserver: Any?

    /// Counter for throttling heatmap position sampling (sample every 5th mouseMoved event).
    private var mouseSampleCounter: Int = 0

    private let store: KeyEventHandling
    private let breakManager: BreakReminderManaging
    private let notificationManager: NotificationManaging

    /// Counts consecutive tapDisabledByTimeout events for exponential backoff.
    private var consecutiveTapTimeouts = 0

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

        // Fast path: re-enable an existing tap without recreating the thread.
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
            if CGEvent.tapIsEnabled(tap: tap) {
                KeyLens.log("Existing tap re-enabled successfully")
                return true
            }
            KeyLens.log("Existing tap could not be re-enabled — recreating")
            stop()
        }

        // Seed app name cache (main thread; safe here since tap thread not yet running).
        _cachedAppName = NSWorkspace.shared.frontmostApplication?.localizedName

        // Register workspace observer once; keep token to avoid duplicates.
        if appNameObserver == nil {
            appNameObserver = NotificationCenter.default.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: NSWorkspace.shared,
                queue: .main
            ) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                self?.cachedAppName = app?.localizedName
            }
        }

        // Build event mask once so the closure captures only a value type.
        var mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        mask |= CGEventMask(1 << CGEventType.keyUp.rawValue)
        mask |= CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
        mask |= CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
        mask |= CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
        mask |= CGEventMask(1 << CGEventType.mouseMoved.rawValue)

        // Semaphore to wait for the background thread to finish tap setup.
        let setupDone = DispatchSemaphore(value: 0)
        var tapCreated = false

        let thread = Thread { [weak self] in
            guard let self else { setupDone.signal(); return }

            // Capture this thread's run loop before signalling.
            let rl = CFRunLoopGetCurrent()!
            self.tapRunLoop = rl

            // Create and attach the tap here so its run loop source lives on this thread.
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .tailAppendEventTap,
                options: .listenOnly,
                eventsOfInterest: mask,
                callback: inputTapCallback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
            KeyLens.log("CGEvent.tapCreate result: \(tap != nil ? "success" : "nil (FAILED)")")

            if let tap {
                self.eventTap = tap
                let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
                self.runLoopSource = source
                CFRunLoopAddSource(rl, source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
                tapCreated = true
            }
            setupDone.signal()

            // Run the run loop until stop() calls CFRunLoopStop.
            if tapCreated { CFRunLoopRun() }

            self.tapRunLoop = nil
        }
        thread.name = "com.keylens.eventtap"
        thread.qualityOfService = .userInteractive
        tapThread = thread
        thread.start()

        // Block until tap is set up (or fails). 2 s timeout is generous for system calls.
        let waitResult = setupDone.wait(timeout: .now() + 2.0)
        if waitResult == .timedOut {
            KeyLens.log("⚠️ Tap thread setup timed out")
            return false
        }

        if tapCreated {
            KeyLens.log("Monitoring started successfully")
        }
        return tapCreated
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource, let rl = tapRunLoop {
            CFRunLoopRemoveSource(rl, src, .commonModes)
        }
        if let rl = tapRunLoop {
            CFRunLoopStop(rl)
        }
        eventTap = nil
        runLoopSource = nil
        // tapRunLoop is cleared by the background thread after CFRunLoopRun() returns.
        tapThread = nil
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
    static let keystrokeInput         = Notification.Name("com.keylens.keystrokeInput")
    static let keystrokeReleased      = Notification.Name("com.keylens.keystrokeReleased")
    static let keyboardDevicesChanged = Notification.Name("com.keylens.keyboardDevicesChanged")
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
    /// Runs on the dedicated tap background thread — never on the main thread.
    func handleEvent(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        let handlerStartedAt = CFAbsoluteTimeGetCurrent()
        // Tap disabled by macOS timeout: re-enable with exponential backoff after repeated failures.
        if type == .tapDisabledByTimeout {
            store.recordSlowEvent()
            consecutiveTapTimeouts += 1
            let delayMs = min(100 * consecutiveTapTimeouts, 2000)
            KeyLens.log("⚠️ CGEventTap disabled by timeout — re-enabling in \(delayMs)ms (attempt \(consecutiveTapTimeouts))")
            if let tap = eventTap {
                if delayMs <= 100 {
                    CGEvent.tapEnable(tap: tap, enable: true)
                } else {
                    // Use a global queue — no longer safe to dispatch to main for tap re-enable.
                    DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + .milliseconds(delayMs)) { [weak self] in
                        guard let tap = self?.eventTap else { return }
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                }
            }
            return nil
        }

        // keyUp: notify inspector so it can remove the key from the held-keys list.
        // Posted asynchronously so the tap callback returns before observers run.
        if type == .keyUp {
            let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .keystrokeReleased, object: code)
            }
            return Unmanaged.passRetained(event)
        }

        // Mouse movement: accumulate distance and sample position for heatmap.
        // Position is sampled every 5th event to keep overhead minimal.
        // NSScreen.screens must be called on the main thread — dispatch the lookup async.
        if type == .mouseMoved {
            let dx = event.getDoubleValueField(.mouseEventDeltaX)
            let dy = event.getDoubleValueField(.mouseEventDeltaY)
            MouseStore.shared.addMovement(dx: dx, dy: dy)

            mouseSampleCounter += 1
            if mouseSampleCounter >= 5 {
                mouseSampleCounter = 0
                let loc = event.location
                DispatchQueue.main.async {
                    if let screen = NSScreen.screens.first(where: { $0.frame.contains(loc) }) {
                        let frame = screen.frame
                        let relX = loc.x - frame.minX
                        let relY = frame.maxY - loc.y
                        MouseStore.shared.addPosition(x: relX, y: relY, screenSize: frame.size)
                    }
                }
            }
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

        // Check Overlay hotkey (Issue #179); toggle() already dispatches to main internally.
        if type == .keyDown, OverlayHotkeyManager.shared.matches(event: event) {
            OverlayHotkeyManager.shared.toggle()
        }

        let now = Date()
        let appName = cachedAppName
        let captureName = name
        store.increment(key: captureName, at: now, appName: appName) { [weak self] count, milestone in
            guard let self, milestone else { return }
            self.notificationManager.notify(key: captureName, count: count)
        }

        // BreakReminderManager accesses its own internal state; dispatch to main for safety.
        let bm = breakManager
        DispatchQueue.main.async { bm.didType() }

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
                isModifierOnly: isModifierOnly,
                rawFlags: event.flags.rawValue,
                hidUsage: hidUsageTable[code].map { (page: 0x07, usage: $0) }
            )
            // Posted asynchronously so the tap callback returns before observers run.
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .keystrokeInput, object: evt)
            }
        }
        consecutiveTapTimeouts = 0
        let handlerMs = (CFAbsoluteTimeGetCurrent() - handlerStartedAt) * 1000
        if handlerMs > kHandleEventSlowThresholdMs {
            KeyLens.log("⚠️ handleEvent took \(String(format: "%.1f", handlerMs))ms — exceeds \(kHandleEventSlowThresholdMs)ms threshold")
            store.recordSlowEvent()
        }
        PerformanceProfiler.shared.record(metric: "event.handle.total", ms: handlerMs)
        return Unmanaged.passRetained(event)
    }
}
