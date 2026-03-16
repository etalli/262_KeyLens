// AlternativeLayouts.swift
// Static finger/hand assignments for Colemak and Dvorak layouts (Issue #61).
//
// Both structs implement KeyboardLayout using output-character → (hand, finger) tables.
// The tables are derived from the physical key positions on a standard ANSI board:
//   a character's hand/finger is determined by WHICH PHYSICAL KEY produces it in that layout.
//
// Only alpha keys and common punctuation are mapped; modifier keys, numbers,
// and function keys use the same assignments as QWERTY (not remapped by these layouts).
//
// Colemak と Dvorak の静的フィンガー/ハンドマップ。
// 各文字がどの物理キー (= どの指) で打鍵されるかを表す。

import CoreGraphics

// MARK: - ColemakLayout

/// Standard Colemak layout (17 alpha keys differ from QWERTY).
/// Colemak 標準レイアウト (QWERTY から 17 キーが変更)。
public struct ColemakLayout: KeyboardLayout {
    public let name = "Colemak"
    public init() {}

    // CGKeyCode-based lookup is not used; return nil.
    public func position(for keyCode: CGKeyCode) -> KeyPosition? { nil }

    public func hand(for keyName: String) -> Hand? {
        ColemakLayout.handTable[keyName]
    }

    public func finger(for keyName: String) -> Finger? {
        ColemakLayout.fingerTable[keyName]
    }

    // MARK: - Hand table
    // Keys that stay on the same hand as QWERTY are omitted and fall through to nil;
    // callers that need a complete mapping should fall back to ANSILayout for those keys.
    // Changed: d→L, e→R, f→L, i→R, j→R, k→R, l→R, n→R, o→R, p→L, r→L, s→L, t→L, u→R, y→R
    public static let handTable: [String: Hand] = {
        var t: [String: Hand] = [:]

        // Left hand alpha (changed from QWERTY)
        for k in ["d","f","p","r","s","t"] { t[k] = .left }
        // Left hand alpha (unchanged from QWERTY)
        for k in ["a","b","c","g","q","v","w","x","z"] { t[k] = .left }

        // Right hand alpha (changed from QWERTY)
        for k in ["e","i","j","k","l","n","o","u","y"] { t[k] = .right }
        // Right hand alpha (unchanged from QWERTY)
        for k in ["h","m"] { t[k] = .right }

        // Number row — same as QWERTY
        for k in ["`","1","2","3","4","5"] { t[k] = .left }
        for k in ["6","7","8","9","0","-","="] { t[k] = .right }

        // Symbol keys
        for k in ["[","]","\\",";","'",",",".","/"] { t[k] = .right }

        // Named keys
        for k in ["Escape","Tab","CapsLock","⇧Shift","⌃Ctrl","⌥Option","⌘Cmd","Space"] { t[k] = .left }
        for k in ["Return","Delete","⌦FwdDel","Enter(Num)"] { t[k] = .right }
        for k in ["←","→","↑","↓"] { t[k] = .right }

        return t
    }()

    // MARK: - Finger table
    // Physical key position → output char → finger assignment in Colemak.
    //
    // Colemak remapping (QWERTY physical pos → Colemak output char → finger from that physical pos):
    //   E pos (L-middle, top)  → f   (was e/L-middle)
    //   R pos (L-index, top)   → p   (was r/L-index)
    //   T pos (L-index, top)   → g   (was t/L-index)   same finger!
    //   Y pos (R-index, top)   → j   (was y/R-index)   same finger!
    //   U pos (R-index, top)   → l   (was u/R-index)   same finger!
    //   I pos (R-middle, top)  → u   (was i/R-middle)
    //   O pos (R-ring, top)    → y   (was o/R-ring)
    //   S pos (L-ring, home)   → r   (was s/L-ring)    same finger!
    //   D pos (L-middle, home) → s   (was d/L-middle)  same finger!
    //   F pos (L-index, home)  → t   (was f/L-index)   same finger!
    //   G pos (L-index, home)  → d   (was g/L-index)   same finger!
    //   J pos (R-index, home)  → n   (was j/R-index)   same finger!
    //   K pos (R-middle, home) → e   (was k/R-middle)
    //   L pos (R-ring, home)   → i   (was l/R-ring)
    //   ; pos (R-pinky, home)  → o   (was ;/R-pinky)
    //   N pos (R-index, bot)   → k   (was n/R-index)   same finger!
    public static let fingerTable: [String: Finger] = {
        var t: [String: Finger] = [:]

        // Pinky
        for k in ["Escape","`","1","Tab","q","a","z","CapsLock","⇧Shift","⌃Ctrl","F1"] { t[k] = .pinky }
        for k in ["0","-","=","Delete","⌦FwdDel",
                  "[","]","\\","o","'","Return","/","←","Enter(Num)",
                  "F10","F11","F12"] { t[k] = .pinky }
        // Note: 'o' in Colemak is at the ';' physical key → R-pinky

        // Ring
        for k in ["2","w","r","x","F2"] { t[k] = .ring }
        // 'r' in Colemak is at 's' physical key → L-ring
        for k in ["9","y","i",".","→","F9"] { t[k] = .ring }
        // 'y' at 'o' pos → R-ring; 'i' at 'l' pos → R-ring

        // Middle
        for k in ["3","f","s","c","F3"] { t[k] = .middle }
        // 'f' at 'e' pos → L-middle; 's' at 'd' pos → L-middle
        for k in ["8","u","e",",","↓","↑","F8"] { t[k] = .middle }
        // 'u' at 'i' pos → R-middle; 'e' at 'k' pos → R-middle

        // Index
        for k in ["4","5","p","g","t","d","v","b","F4","F5"] { t[k] = .index }
        // 'p' at 'r' pos → L-index; 'g' at 't' pos → L-index
        // 't' at 'f' pos → L-index; 'd' at 'g' pos → L-index
        for k in ["6","7","j","l","h","n","k","m","F6","F7"] { t[k] = .index }
        // 'j' at 'y' pos → R-index; 'l' at 'u' pos → R-index
        // 'n' at 'j' pos → R-index; 'k' at 'n' pos → R-index

        // Thumb
        for k in ["Space","⌘Cmd","⌥Option"] { t[k] = .thumb }

        return t
    }()
}

// MARK: - DvorakLayout

/// Standard Dvorak Simplified Keyboard layout.
/// Dvorak 標準レイアウト。
public struct DvorakLayout: KeyboardLayout {
    public let name = "Dvorak"
    public init() {}

    public func position(for keyCode: CGKeyCode) -> KeyPosition? { nil }

    public func hand(for keyName: String) -> Hand? {
        DvorakLayout.handTable[keyName]
    }

    public func finger(for keyName: String) -> Finger? {
        DvorakLayout.fingerTable[keyName]
    }

    // MARK: - Hand table
    // Dvorak physical layout (output char → hand):
    //   Top row L: ' , . p y   Top row R: f g c r l
    //   Home row L: a o e u i  Home row R: d h t n s
    //   Bottom row L: ; q j k x  Bottom row R: b m w v z
    public static let handTable: [String: Hand] = {
        var t: [String: Hand] = [:]

        // Left hand alpha
        for k in ["a","e","i","j","k","o","p","q","u","x","y"] { t[k] = .left }
        // (includes ';' as punctuation — skip for alpha-only analysis)

        // Right hand alpha
        for k in ["b","c","d","f","g","h","l","m","n","r","s","t","v","w","z"] { t[k] = .right }

        // Number row — same as QWERTY
        for k in ["`","1","2","3","4","5"] { t[k] = .left }
        for k in ["6","7","8","9","0","-","="] { t[k] = .right }

        // Symbol keys (mostly right hand in Dvorak, simplify to QWERTY convention)
        for k in ["[","]","\\",";","'",",",".","/"] { t[k] = .right }

        // Named keys
        for k in ["Escape","Tab","CapsLock","⇧Shift","⌃Ctrl","⌥Option","⌘Cmd","Space"] { t[k] = .left }
        for k in ["Return","Delete","⌦FwdDel","Enter(Num)"] { t[k] = .right }
        for k in ["←","→","↑","↓"] { t[k] = .right }

        return t
    }()

    // MARK: - Finger table
    // Physical key position (QWERTY) → Dvorak output char → finger:
    //   Q pos (L-pinky, top)   → '   (skip punctuation)
    //   W pos (L-ring, top)    → ,   (skip punctuation)
    //   E pos (L-middle, top)  → .   (skip punctuation)
    //   R pos (L-index, top)   → p
    //   T pos (L-index, top)   → y
    //   Y pos (R-index, top)   → f
    //   U pos (R-index, top)   → g
    //   I pos (R-middle, top)  → c
    //   O pos (R-ring, top)    → r
    //   P pos (R-pinky, top)   → l
    //   A pos (L-pinky, home)  → a
    //   S pos (L-ring, home)   → o
    //   D pos (L-middle, home) → e
    //   F pos (L-index, home)  → u
    //   G pos (L-index, home)  → i
    //   H pos (R-index, home)  → d
    //   J pos (R-index, home)  → h
    //   K pos (R-middle, home) → t
    //   L pos (R-ring, home)   → n
    //   ; pos (R-pinky, home)  → s
    //   Z pos (L-pinky, bot)   → ;  (skip)
    //   X pos (L-ring, bot)    → q
    //   C pos (L-middle, bot)  → j
    //   V pos (L-index, bot)   → k
    //   B pos (L-index, bot)   → x
    //   N pos (R-index, bot)   → b
    //   M pos (R-index, bot)   → m
    //   , pos (R-middle, bot)  → w
    //   . pos (R-ring, bot)    → v
    //   / pos (R-pinky, bot)   → z
    public static let fingerTable: [String: Finger] = {
        var t: [String: Finger] = [:]

        // Pinky
        for k in ["Escape","`","1","Tab","a","CapsLock","⇧Shift","⌃Ctrl","F1"] { t[k] = .pinky }
        // 'a' stays at A pos → L-pinky
        for k in ["0","-","=","Delete","⌦FwdDel",
                  "l","s","Return","z","←","Enter(Num)",
                  "F10","F11","F12"] { t[k] = .pinky }
        // 'l' at P pos → R-pinky; 's' at ; pos → R-pinky; 'z' at / pos → R-pinky

        // Ring
        for k in ["2","o","q","F2"] { t[k] = .ring }
        // 'o' at S pos → L-ring; 'q' at X pos → L-ring
        for k in ["9","r","n","v","→","F9"] { t[k] = .ring }
        // 'r' at O pos → R-ring; 'n' at L pos → R-ring; 'v' at . pos → R-ring

        // Middle
        for k in ["3","e","j","F3"] { t[k] = .middle }
        // 'e' at D pos → L-middle; 'j' at C pos → L-middle
        for k in ["8","c","t","w","↓","↑","F8"] { t[k] = .middle }
        // 'c' at I pos → R-middle; 't' at K pos → R-middle; 'w' at , pos → R-middle

        // Index
        for k in ["4","5","p","y","u","i","k","x","F4","F5"] { t[k] = .index }
        // 'p' at R pos → L-index; 'y' at T pos → L-index
        // 'u' at F pos → L-index; 'i' at G pos → L-index
        // 'k' at V pos → L-index; 'x' at B pos → L-index
        for k in ["6","7","f","g","d","h","b","m","F6","F7"] { t[k] = .index }
        // 'f' at Y pos → R-index; 'g' at U pos → R-index
        // 'd' at H pos → R-index; 'h' at J pos → R-index
        // 'b' at N pos → R-index; 'm' at M pos → R-index

        // Thumb
        for k in ["Space","⌘Cmd","⌥Option"] { t[k] = .thumb }

        return t
    }()
}
