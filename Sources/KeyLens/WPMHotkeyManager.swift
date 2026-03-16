import AppKit
import KeyLensCore

/// Manages the global hotkey for toggling manual WPM measurement (Issue #151).
///
/// The hotkey is checked inside the existing CGEventTap (KeyboardMonitor)
/// to avoid requiring an additional global event monitor.
/// Default hotkey: ⌃⌥M (Control+Option+M).
final class WPMHotkeyManager {
    static let shared = WPMHotkeyManager()

    private static let keyCodeKey   = "wpmHotkeyKeyCode"
    private static let modifiersKey = "wpmHotkeyModifiers"

    // Default: ⌃⌥M
    private static let defaultKeyCode: UInt16 = 46  // 'm'
    private static let defaultModifiers: CGEventFlags = [.maskControl, .maskAlternate]

    var keyCode: UInt16 {
        get {
            let v = UserDefaults.standard.integer(forKey: Self.keyCodeKey)
            return v > 0 ? UInt16(v) : Self.defaultKeyCode
        }
        set { UserDefaults.standard.set(Int(newValue), forKey: Self.keyCodeKey) }
    }

    var modifierFlags: CGEventFlags {
        get {
            let v = UserDefaults.standard.integer(forKey: Self.modifiersKey)
            return v != 0 ? CGEventFlags(rawValue: UInt64(v)) : Self.defaultModifiers
        }
        set { UserDefaults.standard.set(Int(newValue.rawValue), forKey: Self.modifiersKey) }
    }

    private init() {}

    // MARK: - Hotkey matching

    /// Returns true if the given CGEvent matches the configured hotkey.
    func matches(event: CGEvent) -> Bool {
        let code = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard code == keyCode else { return false }
        let relevant: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
        return event.flags.intersection(relevant) == modifierFlags.intersection(relevant)
    }

    // MARK: - Toggle

    /// Toggles WPM measurement and posts the appropriate notification.
    func toggle() {
        let store = KeyCountStore.shared
        if store.isWPMMeasuring {
            let result = store.stopWPMMeasurement()
            NotificationCenter.default.post(name: .wpmMeasurementStopped, object: result)
        } else {
            store.startWPMMeasurement()
            NotificationCenter.default.post(name: .wpmMeasurementStarted, object: nil)
        }
    }

    // MARK: - Display

    /// Human-readable hotkey string, e.g. "⌃⌥M".
    var displayString: String {
        var s = ""
        let f = modifierFlags
        if f.contains(.maskControl)   { s += "⌃" }
        if f.contains(.maskAlternate) { s += "⌥" }
        if f.contains(.maskShift)     { s += "⇧" }
        if f.contains(.maskCommand)   { s += "⌘" }
        s += KeyboardMonitor.keyName(for: keyCode).uppercased()
        return s
    }

    // MARK: - Hotkey recording

    /// Records the next key event from a local NSEvent monitor and saves it as the new hotkey.
    /// Calls `completion` on the main thread when done.
    func recordNextHotkey(completion: @escaping (String) -> Void) {
        var monitor: Any?
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let relevant = NSEvent.ModifierFlags([.control, .option, .shift, .command])
            guard !event.modifierFlags.intersection(relevant).isEmpty else { return event }

            self.keyCode = event.keyCode

            var cgFlags = CGEventFlags()
            if event.modifierFlags.contains(.control) { cgFlags.insert(.maskControl) }
            if event.modifierFlags.contains(.option)  { cgFlags.insert(.maskAlternate) }
            if event.modifierFlags.contains(.shift)   { cgFlags.insert(.maskShift) }
            if event.modifierFlags.contains(.command) { cgFlags.insert(.maskCommand) }
            self.modifierFlags = cgFlags

            if let m = monitor { NSEvent.removeMonitor(m) }
            DispatchQueue.main.async { completion(self.displayString) }
            return nil  // consume the event
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let wpmMeasurementStarted = Notification.Name("com.keylens.wpmMeasurementStarted")
    static let wpmMeasurementStopped = Notification.Name("com.keylens.wpmMeasurementStopped")
}
