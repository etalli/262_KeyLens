import CoreGraphics

// MARK: - Hand / Finger

/// Which hand is used to press a key.
public enum Hand: String, Equatable, CaseIterable {
    case left
    case right
}

/// Which finger is used to press a key (standard touch-typing assignment).
public enum Finger: String, Equatable, CaseIterable {
    case pinky
    case ring
    case middle
    case index
    case thumb
}

// MARK: - KeyPosition

/// Physical position and ergonomic metadata for a single key.
///
/// Row conventions (top-to-bottom):
///   5 = function key row  (F1–F12)
///   0 = number row        (Esc  `  1  2  3  4  5  6  7  8  9  0  -  =  Delete)
///   1 = top alpha row     (Tab  Q  W  E  R  T  Y  U  I  O  P  [  ]  \)
///   2 = home row          (CapsLock  A  S  D  F  G  H  J  K  L  ;  '  Return)
///   3 = bottom row        (Shift  Z  X  C  V  B  N  M  ,  .  /  Shift)
///   4 = thumb / space row (Ctrl  Option  Cmd  Space  Cmd  Option  Ctrl)
///
/// Column 0 = leftmost key in the row.
public struct KeyPosition: Equatable {
    public let row: Int
    public let column: Int
    public let hand: Hand
    public let finger: Finger

    public init(row: Int, column: Int, hand: Hand, finger: Finger) {
        self.row = row; self.column = column; self.hand = hand; self.finger = finger
    }
}

// MARK: - Protocol

/// Abstracts a physical keyboard layout, mapping keys to logical positions and hands.
///
/// CGKeyCode is used as the source of truth for physical location because it is a
/// hardware scan code — it identifies which physical key was pressed regardless of
/// the software input method (ANSI, JIS, Dvorak, custom remapping, etc.).
///
/// Key name strings (e.g. "a", "Space", "⌘Cmd") match the values stored in
/// KeyCountStore, enabling ergonomic analysis without changing the data layer.
public protocol KeyboardLayout {
    /// Human-readable layout name (e.g. "ANSI", "JIS").
    var name: String { get }

    /// Returns the ergonomic position for a hardware key code, or nil if not mapped.
    func position(for keyCode: CGKeyCode) -> KeyPosition?

    /// Returns the hand assignment for a key name string, or nil if not mapped.
    /// Key names must match the strings produced by KeyboardMonitor (e.g. "a", "Space", "⌘Cmd").
    func hand(for keyName: String) -> Hand?

    /// Returns the finger assignment for a key name string, or nil if not mapped.
    /// The returned Finger is hand-agnostic; combine with hand(for:) for full ergonomic data.
    /// e.g. finger(for: "j") → .index, hand(for: "j") → .right  ⟹  right index
    func finger(for keyName: String) -> Finger?
}

// MARK: - ANSI Layout

/// Standard US ANSI keyboard layout.
///
/// Finger assignments follow conventional touch-typing standards.
/// Modifier keys (Cmd, Shift, Ctrl, Option) are included because they
/// contribute to finger load and ergonomic analysis.
public struct ANSILayout: KeyboardLayout {
    public let name = "ANSI"
    public init() {}

    public func position(for keyCode: CGKeyCode) -> KeyPosition? {
        ANSILayout.table[keyCode]
    }

    public func hand(for keyName: String) -> Hand? {
        // Direct string lookup
        if let hand = ANSILayout.handTable[keyName] { return hand }

        // Fallback: "Key(N)" format for keys not in KeyboardMonitor's named map
        // (e.g. "Key(60)" = Right Shift, "Key(54)" = Right Cmd)
        if keyName.hasPrefix("Key("), keyName.hasSuffix(")"),
           let code = UInt16(keyName.dropFirst(4).dropLast()) {
            return ANSILayout.table[code]?.hand
        }

        return nil
    }

    public func finger(for keyName: String) -> Finger? {
        // Direct string lookup
        if let finger = ANSILayout.fingerTable[keyName] { return finger }

        // Fallback: "Key(N)" format (e.g. "Key(60)" = Right Shift → pinky)
        if keyName.hasPrefix("Key("), keyName.hasSuffix(")"),
           let code = UInt16(keyName.dropFirst(4).dropLast()) {
            return ANSILayout.table[code]?.finger
        }

        return nil
    }

    // MARK: - Static lookup: CGKeyCode -> KeyPosition
    // Derived from the CoreGraphics key code values observed on standard Apple keyboards.
    public static let table: [CGKeyCode: KeyPosition] = {
        func p(_ row: Int, _ col: Int, _ hand: Hand, _ finger: Finger) -> KeyPosition {
            KeyPosition(row: row, column: col, hand: hand, finger: finger)
        }

        return [
            // MARK: Row 0 — Number / Escape row
            // Esc ` 1 2 3 4 5 | 6 7 8 9 0 - = Delete
            53:  p(0,  0, .left,  .pinky),  // Escape
            50:  p(0,  1, .left,  .pinky),  // `
            18:  p(0,  2, .left,  .pinky),  // 1
            19:  p(0,  3, .left,  .ring),   // 2
            20:  p(0,  4, .left,  .middle), // 3
            21:  p(0,  5, .left,  .index),  // 4
            23:  p(0,  6, .left,  .index),  // 5
            22:  p(0,  7, .right, .index),  // 6
            26:  p(0,  8, .right, .index),  // 7
            28:  p(0,  9, .right, .middle), // 8
            25:  p(0, 10, .right, .ring),   // 9
            29:  p(0, 11, .right, .pinky),  // 0
            27:  p(0, 12, .right, .pinky),  // -
            24:  p(0, 13, .right, .pinky),  // =
            51:  p(0, 14, .right, .pinky),  // Delete
            117: p(0, 15, .right, .pinky),  // ⌦ Forward Delete

            // MARK: Row 1 — Top alpha row
            // Tab Q W E R T | Y U I O P [ ] \
            48:  p(1,  0, .left,  .pinky),  // Tab
            12:  p(1,  1, .left,  .pinky),  // Q
            13:  p(1,  2, .left,  .ring),   // W
            14:  p(1,  3, .left,  .middle), // E
            15:  p(1,  4, .left,  .index),  // R
            17:  p(1,  5, .left,  .index),  // T
            16:  p(1,  6, .right, .index),  // Y
            32:  p(1,  7, .right, .index),  // U
            34:  p(1,  8, .right, .middle), // I
            31:  p(1,  9, .right, .ring),   // O
            35:  p(1, 10, .right, .pinky),  // P
            33:  p(1, 11, .right, .pinky),  // [
            30:  p(1, 12, .right, .pinky),  // ]
            42:  p(1, 13, .right, .pinky),  // \

            // MARK: Row 2 — Home row
            // CapsLock A S D F G | H J K L ; ' Return
            57:  p(2,  0, .left,  .pinky),  // CapsLock
             0:  p(2,  1, .left,  .pinky),  // A
             1:  p(2,  2, .left,  .ring),   // S
             2:  p(2,  3, .left,  .middle), // D
             3:  p(2,  4, .left,  .index),  // F
             5:  p(2,  5, .left,  .index),  // G
             4:  p(2,  6, .right, .index),  // H
            38:  p(2,  7, .right, .index),  // J
            40:  p(2,  8, .right, .middle), // K
            37:  p(2,  9, .right, .ring),   // L
            41:  p(2, 10, .right, .pinky),  // ;
            39:  p(2, 11, .right, .pinky),  // '
            36:  p(2, 12, .right, .pinky),  // Return
            126: p(2, 13, .right, .middle), // ↑ (above ↓ in arrow cluster)

            // MARK: Row 3 — Bottom row
            // Shift Z X C V B | N M , . / Shift  [← ↓ →]
            56:  p(3,  0, .left,  .pinky),  // Left Shift
             6:  p(3,  1, .left,  .pinky),  // Z
             7:  p(3,  2, .left,  .ring),   // X
             8:  p(3,  3, .left,  .middle), // C
             9:  p(3,  4, .left,  .index),  // V
            11:  p(3,  5, .left,  .index),  // B
            45:  p(3,  6, .right, .index),  // N
            46:  p(3,  7, .right, .index),  // M
            43:  p(3,  8, .right, .middle), // ,
            47:  p(3,  9, .right, .ring),   // .
            44:  p(3, 10, .right, .pinky),  // /
            60:  p(3, 11, .right, .pinky),  // Right Shift
            123: p(3, 12, .right, .index),  // ←
            125: p(3, 13, .right, .middle), // ↓
            124: p(3, 14, .right, .ring),   // →

            // MARK: Row 4 — Thumb / space row
            // Ctrl Option Cmd Space | Cmd Option Ctrl  [Enter(Num)]
            59:  p(4,  0, .left,  .pinky),  // Left Ctrl
            58:  p(4,  1, .left,  .thumb),  // Left Option
            55:  p(4,  2, .left,  .thumb),  // Left Cmd
            49:  p(4,  3, .left,  .thumb),  // Space
            54:  p(4,  4, .right, .thumb),  // Right Cmd
            61:  p(4,  5, .right, .thumb),  // Right Option
            62:  p(4,  6, .right, .pinky),  // Right Ctrl
            76:  p(4,  7, .right, .pinky),  // Enter (Numpad)

            // MARK: Row 5 — Function key row
            // F1 F2 F3 F4 F5 | F6 F7 F8 F9 F10 F11 F12
            122: p(5,  1, .left,  .pinky),  // F1
            120: p(5,  2, .left,  .ring),   // F2
             99: p(5,  3, .left,  .middle), // F3
            118: p(5,  4, .left,  .index),  // F4
             96: p(5,  5, .left,  .index),  // F5
             97: p(5,  6, .right, .index),  // F6
             98: p(5,  7, .right, .index),  // F7
            100: p(5,  8, .right, .middle), // F8
            101: p(5,  9, .right, .ring),   // F9
            109: p(5, 10, .right, .pinky),  // F10
            103: p(5, 11, .right, .pinky),  // F11
            111: p(5, 12, .right, .pinky),  // F12
        ]
    }()

    // MARK: - Static lookup: key name String -> Hand
    // Key name strings match the values produced by KeyboardMonitor.keyName(for:)
    // and stored in KeyCountStore.
    public static let handTable: [String: Hand] = {
        var t: [String: Hand] = [:]

        // Left hand — alpha
        for k in ["q","w","e","r","t","a","s","d","f","g","z","x","c","v","b"] { t[k] = .left }
        // Right hand — alpha
        for k in ["y","u","i","o","p","h","j","k","l","n","m"]                 { t[k] = .right }

        // Left hand — number row
        for k in ["`","1","2","3","4","5"] { t[k] = .left }
        // Right hand — number row
        for k in ["6","7","8","9","0","-","="] { t[k] = .right }

        // Right hand — symbol keys
        for k in ["[","]","\\",";","'",",",".","/"] { t[k] = .right }

        // Left hand — named keys
        for k in ["Escape","Tab","CapsLock","⇧Shift","⌃Ctrl","⌥Option","⌘Cmd","Space"] { t[k] = .left }
        // Right hand — named keys
        for k in ["Return","Delete","⌦FwdDel","Enter(Num)"] { t[k] = .right }

        // Right hand — arrows
        for k in ["←","→","↑","↓"] { t[k] = .right }

        // Left hand — function keys
        for k in ["F1","F2","F3","F4","F5"] { t[k] = .left }
        // Right hand — function keys
        for k in ["F6","F7","F8","F9","F10","F11","F12"] { t[k] = .right }

        return t
    }()

    // MARK: - Static lookup: key name String -> Finger
    // Hand-agnostic: combine with handTable to get the full assignment.
    // e.g. fingerTable["j"] = .index, handTable["j"] = .right  ⟹  right index finger
    public static let fingerTable: [String: Finger] = {
        var t: [String: Finger] = [:]

        // Pinky keys (left & right — same finger type, hand determined by handTable)
        // Left pinky: Esc ` 1  Tab Q A Z  CapsLock ⇧Shift ⌃Ctrl  F1
        for k in ["Escape","`","1","Tab","q","a","z","CapsLock","⇧Shift","⌃Ctrl","F1"] { t[k] = .pinky }
        // Right pinky: 0 - = Delete ⌦FwdDel  P [ ] \  ; '  Return  / ←  Enter(Num)  F10 F11 F12
        for k in ["0","-","=","Delete","⌦FwdDel",
                  "p","[","]","\\",";","'","Return","/","←","Enter(Num)",
                  "F10","F11","F12"] { t[k] = .pinky }

        // Ring keys
        // Left ring: 2  W S X  F2
        for k in ["2","w","s","x","F2"] { t[k] = .ring }
        // Right ring: 9  O L .  →  F9
        for k in ["9","o","l",".","→","F9"] { t[k] = .ring }

        // Middle keys
        // Left middle: 3  E D C  F3
        for k in ["3","e","d","c","F3"] { t[k] = .middle }
        // Right middle: 8  I K ,  ↓ ↑  F8
        for k in ["8","i","k",",","↓","↑","F8"] { t[k] = .middle }

        // Index keys
        // Left index: 4 5  R T F G V B  F4 F5
        for k in ["4","5","r","t","f","g","v","b","F4","F5"] { t[k] = .index }
        // Right index: 6 7  Y U H J N M  F6 F7
        for k in ["6","7","y","u","h","j","n","m","F6","F7"] { t[k] = .index }

        // Thumb keys
        // Left thumb: Space ⌘Cmd ⌥Option
        for k in ["Space","⌘Cmd","⌥Option"] { t[k] = .thumb }
        // Right thumb: Right Cmd / Option appear as "Key(N)" — resolved via table fallback

        return t
    }()
}

// MARK: - SplitKeyboardConfig

/// Represents the physical left/right key assignment for a split keyboard.
///
/// Split keyboard users can override the default ANSI hand assignment by setting
/// a SplitKeyboardConfig in LayoutRegistry. Key names must match the strings
/// produced by KeyboardMonitor (e.g. "a", "Space", "⌘Cmd").
///
/// Use `standardSplit` for typical center-split keyboards (same split point as
/// ANSI touch-typing convention). For non-standard splits, initialize directly
/// with custom leftKeys / rightKeys sets.
public struct SplitKeyboardConfig {
    public let name: String
    public let leftKeys: Set<String>
    public let rightKeys: Set<String>

    public init(name: String, leftKeys: Set<String>, rightKeys: Set<String>) {
        self.name = name; self.leftKeys = leftKeys; self.rightKeys = rightKeys
    }

    public func hand(for keyName: String) -> Hand? {
        if leftKeys.contains(keyName)  { return .left }
        if rightKeys.contains(keyName) { return .right }
        return nil
    }

    /// Standard center-split preset: same hand boundary as the ANSI touch-typing convention.
    /// Suitable for most symmetric split keyboards (e.g. 60%, 65%, ortholinear splits).
    public static var standardSplit: SplitKeyboardConfig {
        let left  = Set(ANSILayout.handTable.filter { $0.value == .left  }.keys)
        let right = Set(ANSILayout.handTable.filter { $0.value == .right }.keys)
        return SplitKeyboardConfig(name: "Standard Split", leftKeys: left, rightKeys: right)
    }
}

// MARK: - LayoutRegistry

/// Holds the active keyboard layout and optional split configuration.
///
/// Resolution order for `hand(for:)`:
///   1. splitConfig (if set) — for split keyboard users who override hand assignment
///   2. current layout's hand(for:) — default ANSI or custom layout
///
/// Downstream features (hand alternation, thumb imbalance, ergonomic scoring)
/// should call `LayoutRegistry.shared.hand(for:)` rather than querying the
/// layout directly, to respect any split config the user has set.
public final class LayoutRegistry {
    public static let shared = LayoutRegistry()

    public var current: any KeyboardLayout = ANSILayout()

    /// Set to override hand assignment for split keyboard users. nil = use layout default.
    public var splitConfig: SplitKeyboardConfig? = nil

    /// Returns the hand for a key name, respecting split config if set.
    public func hand(for keyName: String) -> Hand? {
        splitConfig?.hand(for: keyName) ?? current.hand(for: keyName)
    }

    private init() {}
}
