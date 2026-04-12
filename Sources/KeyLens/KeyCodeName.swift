import Foundation

/// Maps Key(N) raw keycode strings to human-readable display names.
/// Display-only — stored key names are never modified.
///
/// Usage:
///   KeyCodeName.display(for: "⌘Key(119)")  // → "⌘End"
///   KeyCodeName.display(for: "Key(102)")   // → "英数"
enum KeyCodeName {

    // kVK_* values from Carbon HIToolbox/Events.h
    static let table: [UInt16: String] = [
        // Navigation keys
        115: "Home",
        119: "End",
        116: "PageUp",
        121: "PageDown",
        117: "⌦",       // Forward Delete
        114: "Help",

        // JIS IME keys
        102: "英数",     // kVK_JIS_Eisu
        104: "かな",     // kVK_JIS_Kana
        93:  "¥",       // kVK_JIS_Yen

        // Function keys
        122: "F1",
        120: "F2",
        99:  "F3",
        118: "F4",
        96:  "F5",
        97:  "F6",
        98:  "F7",
        100: "F8",
        101: "F9",
        109: "F10",
        103: "F11",
        111: "F12",
        105: "F13",
        107: "F14",
        113: "F15",
        106: "F16",

        // Other unnamed keys
        50:  "`",        // Grave / backtick
        72:  "VolUp",
        73:  "VolDown",
        74:  "Mute",
    ]

    /// Replaces any Key(N) pattern in the string with a human-readable name.
    /// Returns the original string unchanged if no Key(N) is found or the code is unknown.
    static func display(for raw: String) -> String {
        guard let range = raw.range(of: #"Key\(\d+\)"#, options: .regularExpression) else {
            return raw
        }
        let keyStr = String(raw[range])
        let numStr = keyStr.dropFirst(4).dropLast()
        guard let code = UInt16(numStr), let name = table[code] else { return raw }
        return raw.replacingCharacters(in: range, with: name)
    }
}
