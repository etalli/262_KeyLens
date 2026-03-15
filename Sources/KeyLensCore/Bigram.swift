/// A typed value representing a two-key sequence (bigram).
///
/// Bigrams are stored in dictionaries using `key` (e.g. `"a→s"`) for JSON
/// compatibility. Use `Bigram.parse(_:)` to recover the struct from a stored key.
public struct Bigram: Hashable, Codable {
    public let from: String
    public let to: String

    public init(from: String, to: String) {
        self.from = from
        self.to   = to
    }

    /// Stable string key used for dictionary storage (matches the on-disk format).
    public var key: String { "\(from)→\(to)" }

    /// Parses a stored bigram key (e.g. `"a→s"`) into a `Bigram`.
    /// Returns `nil` if the string does not contain exactly one `→` separator.
    public static func parse(_ key: String) -> Bigram? {
        let parts = key.components(separatedBy: "→")
        guard parts.count == 2 else { return nil }
        return Bigram(from: parts[0], to: parts[1])
    }
}
