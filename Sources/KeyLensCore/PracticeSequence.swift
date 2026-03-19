import Foundation

// MARK: - PracticeStep

/// A single token the user should type during a practice session.
///
/// Each step corresponds to one space-separated word in a drill (e.g. "th").
/// Steps are ordered so the UI can advance linearly through the sequence.
public struct PracticeStep: Equatable {
    /// The text the user must type (e.g. "th", "he").
    public let text: String
    /// Index of the `DrillSequence` this step belongs to.
    public let drillIndex: Int
    /// Position of this step within its drill (0-based).
    public let stepIndex: Int

    public init(text: String, drillIndex: Int, stepIndex: Int) {
        self.text       = text
        self.drillIndex = drillIndex
        self.stepIndex  = stepIndex
    }
}

// MARK: - PracticeSequence

/// A complete, linear sequence of steps derived from a `TrainingSession`.
///
/// The UI iterates through `steps` in order, showing `steps[cursor].text`
/// as the next token to type. When `cursor` reaches `steps.endIndex` the
/// session is complete.
public struct PracticeSequence: Equatable {
    /// All steps in order, ready for linear playback.
    public let steps: [PracticeStep]
    /// The session that produced this sequence.
    public let session: TrainingSession

    public init(steps: [PracticeStep], session: TrainingSession) {
        self.steps   = steps
        self.session = session
    }

    /// Total number of tokens to type.
    public var count: Int { steps.count }

    /// True when the sequence contains no steps.
    public var isEmpty: Bool { steps.isEmpty }
}

// MARK: - PracticeSequenceGenerator

/// Converts a `TrainingSession` into a flat, linear `PracticeSequence`.
///
/// Each drill's text is split on spaces; every token becomes one `PracticeStep`.
/// Steps preserve drill order (high-tier first) as established by `SessionBuilder`.
public enum PracticeSequenceGenerator {

    /// Generates a practice sequence from the given session.
    ///
    /// - Parameter session: A session produced by `SessionBuilder.build(from:config:)`.
    /// - Returns: A `PracticeSequence` with one step per typeable token.
    ///            Returns an empty sequence if the session has no drills.
    public static func generate(from session: TrainingSession) -> PracticeSequence {
        var steps: [PracticeStep] = []

        for (drillIndex, drill) in session.drills.enumerated() {
            let tokens = drill.text.split(separator: " ", omittingEmptySubsequences: true)
            for (stepIndex, token) in tokens.enumerated() {
                steps.append(PracticeStep(
                    text:       String(token),
                    drillIndex: drillIndex,
                    stepIndex:  stepIndex
                ))
            }
        }

        return PracticeSequence(steps: steps, session: session)
    }
}
