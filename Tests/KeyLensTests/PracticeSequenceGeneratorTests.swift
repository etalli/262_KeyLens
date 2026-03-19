import XCTest
@testable import KeyLensCore

// Tests for PracticeSequenceGenerator (Issue #87).
//
// PracticeSequenceGenerator flattens a TrainingSession into an ordered list
// of PracticeStep values — one per typeable token — for linear UI playback.

final class PracticeSequenceGeneratorTests: XCTestCase {

    // MARK: - Helpers

    private func score(_ key: String, iki: Double = 150, count: Int = 20) -> BigramScore {
        BigramScore(bigram: key, meanIKI: iki, count: count)
    }

    private func makeSession(scores: [BigramScore], config: SessionConfig) -> TrainingSession {
        SessionBuilder.build(from: scores, config: config)
    }

    // MARK: - Empty input

    func test_generate_emptySession_returnsEmptySequence() {
        let session  = SessionBuilder.build(from: [])
        let sequence = PracticeSequenceGenerator.generate(from: session)
        XCTAssertTrue(sequence.isEmpty)
        XCTAssertEqual(sequence.count, 0)
    }

    // MARK: - Step count matches total words

    func test_generate_stepCount_matchesSessionTotalWords() {
        let config  = SessionConfig(maxTargets: 3, highReps: 4, midReps: 3, lowReps: 2,
                                    highTierSize: 2, midTierSize: 1, includeAlternating: false)
        let session  = makeSession(scores: [score("t→h"), score("h→e"), score("e→r")],
                                   config: config)
        let sequence = PracticeSequenceGenerator.generate(from: session)
        XCTAssertEqual(sequence.count, session.totalWords)
    }

    // MARK: - Step text correctness

    func test_generate_singleBigram_stepsContainCorrectToken() {
        let config  = SessionConfig(maxTargets: 1, highReps: 3, highTierSize: 1,
                                    midTierSize: 0, includeAlternating: false)
        let session  = makeSession(scores: [score("t→h")], config: config)
        let sequence = PracticeSequenceGenerator.generate(from: session)

        XCTAssertFalse(sequence.isEmpty)
        XCTAssertTrue(sequence.steps.allSatisfy { $0.text == "th" })
    }

    func test_generate_steps_onlyContainParsedTokens() {
        let config  = SessionConfig(maxTargets: 2, highReps: 2, highTierSize: 2,
                                    midTierSize: 0, includeAlternating: false)
        let session  = makeSession(scores: [score("a→s"), score("t→h")], config: config)
        let sequence = PracticeSequenceGenerator.generate(from: session)

        let valid = Set(["as", "th"])
        XCTAssertTrue(sequence.steps.allSatisfy { valid.contains($0.text) })
    }

    // MARK: - drillIndex

    func test_generate_drillIndex_incrementsPerDrill() {
        let config  = SessionConfig(maxTargets: 2, highReps: 2, highTierSize: 2,
                                    midTierSize: 0, includeAlternating: false)
        let session  = makeSession(scores: [score("t→h"), score("h→e")], config: config)
        let sequence = PracticeSequenceGenerator.generate(from: session)

        // First drill's steps have drillIndex 0, second drill's steps have drillIndex 1.
        let drill0Steps = sequence.steps.filter { $0.drillIndex == 0 }
        let drill1Steps = sequence.steps.filter { $0.drillIndex == 1 }
        XCTAssertFalse(drill0Steps.isEmpty)
        XCTAssertFalse(drill1Steps.isEmpty)
    }

    func test_generate_drillIndex_neverExceedsDrillCount() {
        let config  = SessionConfig(maxTargets: 3, highReps: 2, highTierSize: 2,
                                    midTierSize: 1, includeAlternating: false)
        let session  = makeSession(scores: [score("t→h"), score("h→e"), score("e→r")],
                                   config: config)
        let sequence = PracticeSequenceGenerator.generate(from: session)
        let drillCount = session.drills.count
        XCTAssertTrue(sequence.steps.allSatisfy { $0.drillIndex < drillCount })
    }

    // MARK: - stepIndex

    func test_generate_stepIndex_startsAtZeroPerDrill() {
        let config  = SessionConfig(maxTargets: 2, highReps: 3, highTierSize: 2,
                                    midTierSize: 0, includeAlternating: false)
        let session  = makeSession(scores: [score("t→h"), score("h→e")], config: config)
        let sequence = PracticeSequenceGenerator.generate(from: session)

        // First step of drill 0 and drill 1 both have stepIndex 0.
        let firstOfDrill0 = sequence.steps.first { $0.drillIndex == 0 }!
        let firstOfDrill1 = sequence.steps.first { $0.drillIndex == 1 }!
        XCTAssertEqual(firstOfDrill0.stepIndex, 0)
        XCTAssertEqual(firstOfDrill1.stepIndex, 0)
    }

    func test_generate_stepIndex_incrementsWithinDrill() {
        let config  = SessionConfig(maxTargets: 1, highReps: 4, highTierSize: 1,
                                    midTierSize: 0, includeAlternating: false)
        let session  = makeSession(scores: [score("t→h")], config: config)
        let sequence = PracticeSequenceGenerator.generate(from: session)

        let indices = sequence.steps.map { $0.stepIndex }
        XCTAssertEqual(indices, [0, 1, 2, 3])
    }

    // MARK: - Order preservation

    func test_generate_stepsPreserveDrillOrder() {
        // High-tier drill (drillIndex 0) steps must all appear before mid-tier (drillIndex 1).
        let config  = SessionConfig(maxTargets: 2, highReps: 2, midReps: 2,
                                    highTierSize: 1, midTierSize: 1, includeAlternating: false)
        let session  = makeSession(scores: [score("t→h", iki: 200), score("h→e", iki: 150)],
                                   config: config)
        let sequence = PracticeSequenceGenerator.generate(from: session)

        var lastDrillIndex = -1
        for step in sequence.steps {
            XCTAssertGreaterThanOrEqual(step.drillIndex, lastDrillIndex)
            lastDrillIndex = step.drillIndex
        }
    }

    // MARK: - Session back-reference

    func test_generate_sequenceStoresSession() {
        let config  = SessionConfig(maxTargets: 1, highTierSize: 1, midTierSize: 0)
        let session  = makeSession(scores: [score("t→h")], config: config)
        let sequence = PracticeSequenceGenerator.generate(from: session)
        XCTAssertEqual(sequence.session, session)
    }

    // MARK: - Alternating drills included

    func test_generate_includesAlternatingDrillSteps() {
        let config  = SessionConfig(maxTargets: 2, highReps: 2, highTierSize: 2,
                                    midTierSize: 0, includeAlternating: true)
        let session  = makeSession(scores: [score("t→h"), score("h→e")], config: config)
        let sequence = PracticeSequenceGenerator.generate(from: session)

        // Session has 2 repeated drills + 1 alternating drill.
        // Alternating drill has 2 reps × 2 bigrams = 4 tokens.
        // Total steps = 2×2 + 2×2 + 4 = 12.
        XCTAssertEqual(sequence.count, session.totalWords)
        XCTAssertGreaterThan(sequence.count, 8) // more than just the repeated drills
    }

    // MARK: - count / isEmpty

    func test_count_matchesStepsArrayCount() {
        let config  = SessionConfig(maxTargets: 2, highReps: 3, highTierSize: 2,
                                    midTierSize: 0, includeAlternating: false)
        let session  = makeSession(scores: [score("t→h"), score("h→e")], config: config)
        let sequence = PracticeSequenceGenerator.generate(from: session)
        XCTAssertEqual(sequence.count, sequence.steps.count)
    }

    func test_isEmpty_falseWhenStepsExist() {
        let config  = SessionConfig(maxTargets: 1, highTierSize: 1, midTierSize: 0)
        let session  = makeSession(scores: [score("t→h")], config: config)
        let sequence = PracticeSequenceGenerator.generate(from: session)
        XCTAssertFalse(sequence.isEmpty)
    }
}
