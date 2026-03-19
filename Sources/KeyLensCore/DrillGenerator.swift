import Foundation

// MARK: - DrillKind

/// The structural pattern of a generated typing drill.
public enum DrillKind: Equatable {
    /// Repeated pairs: "th th th th th"
    case repeated
    /// Alternating pairs: "th he th he th he"
    case alternating
}

// MARK: - DrillSequence

/// A single generated drill with target bigrams and the text to type.
public struct DrillSequence: Equatable {
    /// The bigram strings used in this drill, e.g. ["th"] or ["th", "he"].
    public let targets: [String]
    /// The text the user should type.
    public let text: String
    /// The structural pattern of this drill.
    public let kind: DrillKind

    public init(targets: [String], text: String, kind: DrillKind) {
        self.targets = targets
        self.text    = text
        self.kind    = kind
    }
}

// MARK: - DrillGenerator

/// Converts a ranked list of bigrams into structured typing drills.
///
/// Phase 1 output (Issue #83):
/// - One repeated drill per bigram:     "th th th th th"
/// - One alternating drill per pair:    "th he th he th he"
///
/// Bigram keys use the "a→s" format from `Bigram.key`.
/// Keys that cannot be parsed are silently skipped.
public enum DrillGenerator {

    /// Generates drills from the given ranked bigrams.
    ///
    /// - Parameters:
    ///   - scores:      Bigrams ranked by training priority (highest first).
    ///   - repetitions: How many cycles each pattern repeats (default: 5).
    /// - Returns: Repeated drills for each bigram, followed by alternating drills
    ///            for each consecutive pair.
    public static func generate(
        from scores: [BigramScore],
        repetitions: Int = 5
    ) -> [DrillSequence] {
        let reps = max(1, repetitions)

        // Parse "t→h" → "th", skip unparseable keys.
        let displays: [String] = scores.compactMap { display(for: $0.bigram) }
        guard !displays.isEmpty else { return [] }

        var drills: [DrillSequence] = []

        // Repeated drills — one per bigram.
        for d in displays {
            let text = Array(repeating: d, count: reps).joined(separator: " ")
            drills.append(DrillSequence(targets: [d], text: text, kind: .repeated))
        }

        // Alternating drills — one per consecutive pair.
        for i in stride(from: 0, through: displays.count - 2, by: 2) {
            let a = displays[i]
            let b = displays[i + 1]
            let cycle = [a, b]
            let words = (0..<reps).flatMap { _ in cycle }
            let text  = words.joined(separator: " ")
            drills.append(DrillSequence(targets: [a, b], text: text, kind: .alternating))
        }

        return drills
    }

    // MARK: - Private helpers

    /// Converts a stored bigram key ("t→h") to a typeable display string ("th").
    private static func display(for key: String) -> String? {
        guard let bigram = Bigram.parse(key) else { return nil }
        // Skip bigrams involving special keys (e.g. "Delete", "Return") — they are
        // not typeable in a drill and would produce misleading text like "eDelete".
        guard bigram.from.count == 1, bigram.to.count == 1 else { return nil }
        return bigram.from + bigram.to
    }
}
