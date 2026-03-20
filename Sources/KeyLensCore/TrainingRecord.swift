import Foundation

/// A single completed training session persisted to SQLite.
///
/// Stores enough data to evaluate whether training is helping over time:
/// which bigrams/trigrams were targeted, how accurately they were typed, how fast,
/// and how long the session lasted.
public struct TrainingRecord: Identifiable, Equatable {
    public let id: Int64
    /// When the session was completed.
    public let completedAt: Date
    /// Raw bigram keys that were targeted, e.g. ["t→h", "h→e"].
    public let targets: [String]
    /// Raw trigram keys that were targeted, e.g. ["t→h→e"] (Issue #193).
    /// Empty for records created before this field was added.
    public let trigramTargets: [String]
    /// Session length label: "Short", "Normal", or "Long".
    public let sessionLength: String
    /// Accuracy as a percentage (0–100).
    public let accuracy: Int
    /// Words per minute achieved during the session.
    public let wpm: Int
    /// Total elapsed time in seconds (first keystroke → last drill complete).
    public let durationSeconds: Double
    /// Total keystrokes typed (including incorrect ones).
    public let totalTyped: Int
    /// Correctly typed keystrokes.
    public let totalCorrect: Int
    /// Mean IKI (ms) for each target bigram at the time of training (Issue #84).
    /// Key: raw bigram key (e.g. "t→h"). Empty for records created before this field was added.
    public let beforeIKI: [String: Double]

    public init(
        id: Int64,
        completedAt: Date,
        targets: [String],
        trigramTargets: [String] = [],
        sessionLength: String,
        accuracy: Int,
        wpm: Int,
        durationSeconds: Double,
        totalTyped: Int,
        totalCorrect: Int,
        beforeIKI: [String: Double] = [:]
    ) {
        self.id              = id
        self.completedAt     = completedAt
        self.targets         = targets
        self.trigramTargets  = trigramTargets
        self.sessionLength   = sessionLength
        self.accuracy        = accuracy
        self.wpm             = wpm
        self.durationSeconds = durationSeconds
        self.totalTyped      = totalTyped
        self.totalCorrect    = totalCorrect
        self.beforeIKI       = beforeIKI
    }

    /// Bigram keys converted to display strings, e.g. "t→h" → "th".
    public var targetDisplayStrings: [String] {
        targets.map { key in
            let parts = key.components(separatedBy: "→")
            guard parts.count == 2 else { return key }
            return parts[0] + parts[1]
        }
    }

    /// Trigram keys converted to display strings, e.g. "t→h→e" → "the" (Issue #193).
    public var trigramDisplayStrings: [String] {
        trigramTargets.map { key in
            let parts = key.components(separatedBy: "→")
            guard parts.count == 3 else { return key }
            return parts[0] + parts[1] + parts[2]
        }
    }

    /// All practiced targets as display strings: bigrams first, then trigrams.
    public var allTargetDisplayStrings: [String] {
        targetDisplayStrings + trigramDisplayStrings
    }
}
