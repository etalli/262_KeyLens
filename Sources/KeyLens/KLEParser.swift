import Foundation

// MARK: - KLEAbsoluteKey

/// A keyboard key with absolute position computed from the KLE coordinate system.
struct KLEAbsoluteKey: Codable {
    let x: Double       // absolute x in KLE units
    let y: Double       // absolute y in KLE units
    let w: Double       // width in KLE units (1.0 = standard key)
    let label: String   // display label
    let keyName: String // key used to look up counts (matches KeyCountStore keys)
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

/// Parses a keyboard-layout-editor.com JSON file into a flat list of keys with
/// absolute (x, y) positions.
///
/// Supports standard and staggered non-rotated keyboards. Rotation (r/rx/ry) is
/// accepted but ignored in the current v1 implementation.
///
/// Algorithm per KLE spec:
///   - Each top-level JSON array = one "row frame".
///   - `y` in a property object adds to the current row's vertical offset.
///   - `x` in a property object adds a gap before the next key.
///   - `w` sets the width of the next key (resets to 1.0 after each key).
///   - After processing a row frame, `currentBaseY += 1 + rowDeltaY`.
struct KLEParser {

    // MARK: - Public API

    static func parse(_ data: Data) throws -> [KLEAbsoluteKey] {
        let normalised = try normalise(data)
        guard let outer = try? JSONSerialization.jsonObject(with: normalised) as? [Any] else {
            throw KLEParseError.invalidFormat
        }

        var keys: [KLEAbsoluteKey] = []
        var currentBaseY: Double = 0

        for element in outer {
            // Skip top-level metadata dicts
            guard let kleRow = element as? [Any] else { continue }

            var currentX: Double = 0
            var currentW: Double = 1.0
            var rowDeltaY: Double = 0  // accumulated y offset for this row

            for item in kleRow {
                if let props = item as? [String: Any] {
                    rowDeltaY += doubleValue(props["y"])
                    currentX  += doubleValue(props["x"])
                    if let w = props["w"] { currentW = doubleValue(w) }
                } else if let rawLabel = item as? String {
                    let cleaned   = cleanLabel(rawLabel)
                    let firstLine = cleaned.components(separatedBy: "\n").first ?? ""
                    let trimmed   = firstLine.trimmingCharacters(in: .whitespaces)

                    let label   = trimmed.isEmpty ? firstLine : trimmed
                    let keyName = trimmed.isEmpty ? "_spacer_" : trimmed

                    // Only emit real keys; silently drop empty/spacer slots
                    if keyName != "_spacer_" {
                        keys.append(KLEAbsoluteKey(
                            x: currentX,
                            y: currentBaseY + rowDeltaY,
                            w: currentW,
                            label: label,
                            keyName: keyName
                        ))
                    }

                    currentX += currentW
                    currentW  = 1.0  // reset after consuming
                }
            }

            currentBaseY += 1.0 + rowDeltaY
        }

        if keys.isEmpty { throw KLEParseError.emptyLayout }
        return keys
    }

    // MARK: - Preprocessing

    /// Normalise KLE text so JSONSerialization can parse it:
    ///   1. Quote bare identifier keys: {w:1.25} → {"w":1.25}
    ///   2. Wrap bare rows in an outer array when the file has no top-level [...]
    private static func normalise(_ data: Data) throws -> Data {
        guard var text = String(data: data, encoding: .utf8) else {
            throw KLEParseError.invalidFormat
        }

        // Quote unquoted property names: {w: → {"w":
        // Only matches bare word chars after { or , (not already-quoted keys)
        let keyRegex = try! NSRegularExpression(
            pattern: #"([{,]\s*)([A-Za-z_][A-Za-z0-9_]*)(\s*:)"#)
        let range = NSRange(text.startIndex..., in: text)
        text = keyRegex.stringByReplacingMatches(
            in: text, range: range, withTemplate: #"$1"$2"$3"#)

        // Try parsing as-is first (handles already-wrapped files)
        if let fixedData = text.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: fixedData)) != nil {
            return fixedData
        }

        // File is bare rows (no outer [...]): wrap it, then validate
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = trimmed.hasSuffix(",") ? String(trimmed.dropLast()) : trimmed
        text = "[\(stripped)]"

        guard let result = text.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: result)) != nil else {
            throw KLEParseError.invalidFormat
        }
        return result
    }

    /// Replace HTML markup inside KLE labels with plain-text equivalents.
    private static func cleanLabel(_ raw: String) -> String {
        raw.replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
           .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
    }

    /// Extract Double from Any (JSONSerialization gives Int or Double for numbers).
    private static func doubleValue(_ v: Any?) -> Double {
        switch v {
        case let d as Double: return d
        case let i as Int:    return Double(i)
        default:              return 0
        }
    }
}
