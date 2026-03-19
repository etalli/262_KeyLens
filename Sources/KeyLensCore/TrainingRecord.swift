import Foundation

/// A single completed training session persisted to SQLite.
///
/// Stores enough data to evaluate whether training is helping over time:
/// which bigrams were targeted, how accurately they were typed, how fast,
/// and how long the session lasted.
public struct TrainingRecord: Identifiable, Equatable {
    public let id: Int64
    /// When the session was completed.
    public let completedAt: Date
    /// Raw bigram keys that were targeted, e.g. ["t→h", "h→e"].
    public let targets: [String]
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

    public init(
        id: Int64,
        completedAt: Date,
        targets: [String],
        sessionLength: String,
        accuracy: Int,
        wpm: Int,
        durationSeconds: Double,
        totalTyped: Int,
        totalCorrect: Int
    ) {
        self.id              = id
        self.completedAt     = completedAt
        self.targets         = targets
        self.sessionLength   = sessionLength
        self.accuracy        = accuracy
        self.wpm             = wpm
        self.durationSeconds = durationSeconds
        self.totalTyped      = totalTyped
        self.totalCorrect    = totalCorrect
    }

    /// Bigram keys converted to display strings, e.g. "t→h" → "th".
    public var targetDisplayStrings: [String] {
        targets.map { key in
            let parts = key.components(separatedBy: "→")
            guard parts.count == 2 else { return key }
            return parts[0] + parts[1]
        }
    }
}
