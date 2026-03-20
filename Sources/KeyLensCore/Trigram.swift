/// A typed value representing a three-key sequence (trigram).
///
/// Trigrams are stored in dictionaries using `key` (e.g. `"t→h→e"`) for JSON
/// compatibility. Use `Trigram.parse(_:)` to recover the struct from a stored key.
public struct Trigram: Hashable, Codable {
    public let first: String
    public let second: String
    public let third: String

    public init(first: String, second: String, third: String) {
        self.first  = first
        self.second = second
        self.third  = third
    }

    /// Stable string key used for dictionary storage (matches the on-disk format).
    public var key: String { "\(first)→\(second)→\(third)" }

    /// Typeable display string (e.g. `"the"`).
    public var display: String { first + second + third }

    /// The leading bigram key: `"first→second"`.
    public var leadingBigram: String  { "\(first)→\(second)" }

    /// The trailing bigram key: `"second→third"`.
    public var trailingBigram: String { "\(second)→\(third)" }

    /// Parses a stored trigram key (e.g. `"t→h→e"`) into a `Trigram`.
    /// Returns `nil` if the string does not contain exactly two `→` separators.
    public static func parse(_ key: String) -> Trigram? {
        let parts = key.components(separatedBy: "→")
        guard parts.count == 3 else { return nil }
        return Trigram(first: parts[0], second: parts[1], third: parts[2])
    }
}
