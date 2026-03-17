import Foundation

// MARK: - KeyDef Codable

extension KeyDef: Codable {
    enum CodingKeys: String, CodingKey { case label, keyName, widthRatio }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            try c.decode(String.self, forKey: .label),
            try c.decode(String.self, forKey: .keyName),
            try c.decode(Double.self, forKey: .widthRatio)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(label,      forKey: .label)
        try c.encode(keyName,    forKey: .keyName)
        try c.encode(widthRatio, forKey: .widthRatio)
    }
}

// MARK: - KLE parse errors

enum KLEParseError: LocalizedError {
    case invalidFormat
    case emptyLayout

    var errorDescription: String? {
        switch self {
        case .invalidFormat: return L10n.shared.kleParseErrorInvalid
        case .emptyLayout:   return L10n.shared.kleParseErrorEmpty
        }
    }
}

// MARK: - KLEParser

/// Parses a keyboard-layout-editor.com JSON file into rows of KeyDef.
///
/// Supports standard, non-rotated keyboards. Each top-level JSON array element
/// that is itself an array is treated as one keyboard row. Property-only dict
/// elements (KLE metadata) at the top level are skipped.
///
/// Within a row, object elements accumulate `x` (pre-key gap) and `w` (key width)
/// that apply to the next string element (key label). After each key is consumed,
/// `w` resets to 1.0 and `x` resets to 0. The first `\n`-separated legend line
/// is used as both the display label and the keyName (matched against KeyCountStore
/// counts keys).
struct KLEParser {

    static func parse(_ data: Data) throws -> [[KeyDef]] {
        guard let outer = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            throw KLEParseError.invalidFormat
        }

        var rows: [[KeyDef]] = []

        for element in outer {
            // Top-level dicts are KLE metadata — skip them.
            guard let kleRow = element as? [Any] else { continue }

            var row: [KeyDef] = []
            var pendingX: Double = 0.0  // gap to insert as spacer before next key
            var currentW: Double = 1.0  // width of next key

            for item in kleRow {
                if let props = item as? [String: Any] {
                    pendingX += doubleValue(props["x"])
                    if let w = props["w"] { currentW = doubleValue(w) }
                } else if let rawLabel = item as? String {
                    // First legend line = primary label / keyName
                    let firstLine = rawLabel.components(separatedBy: "\n").first ?? ""
                    let trimmed   = firstLine.trimmingCharacters(in: .whitespaces)

                    // Insert invisible spacer key for the x gap
                    if pendingX > 0.01 {
                        row.append(KeyDef("", "_spacer_", pendingX))
                        pendingX = 0
                    }

                    let label   = trimmed.isEmpty ? firstLine : trimmed
                    let keyName = trimmed.isEmpty ? "_spacer_" : trimmed
                    row.append(KeyDef(label, keyName, currentW))

                    currentW = 1.0  // reset for next key
                    pendingX = 0
                }
            }

            if !row.isEmpty { rows.append(row) }
        }

        if rows.isEmpty { throw KLEParseError.emptyLayout }
        return rows
    }

    // Extract Double from Any (JSON gives Int or Double for numeric values)
    private static func doubleValue(_ v: Any?) -> Double {
        switch v {
        case let d as Double: return d
        case let i as Int:    return Double(i)
        default:              return 0
        }
    }
}
