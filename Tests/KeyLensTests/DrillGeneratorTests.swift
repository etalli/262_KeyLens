import XCTest
@testable import KeyLensCore

// Tests for the bigram drill generator (Issue #83).
//
// DrillGenerator converts ranked BigramScore lists into DrillSequence values.
// Two patterns: repeated ("th th th") and alternating ("th he th he").

final class DrillGeneratorTests: XCTestCase {

    // MARK: - Helpers

    private func score(_ key: String, iki: Double = 100, count: Int = 10) -> BigramScore {
        BigramScore(bigram: key, meanIKI: iki, count: count)
    }

    // MARK: - Empty / invalid input

    func test_generate_emptyInput_returnsEmpty() {
        let result = DrillGenerator.generate(from: [])
        XCTAssertTrue(result.isEmpty)
    }

    func test_generate_unparseableKey_isSkipped() {
        let bad = score("INVALID")  // no "→" separator
        let result = DrillGenerator.generate(from: [bad])
        XCTAssertTrue(result.isEmpty)
    }

    func test_generate_mixedValidAndInvalid_skipsInvalid() {
        let inputs = [score("t→h"), score("BAD"), score("e→r")]
        let result = DrillGenerator.generate(from: inputs)
        // Only 2 valid bigrams → 2 repeated drills, 1 alternating drill
        let repeated = result.filter { $0.kind == .repeated }
        XCTAssertEqual(repeated.count, 2)
    }

    // MARK: - Repeated drills

    func test_generate_singleBigram_producesOneRepeatedDrill() {
        let result = DrillGenerator.generate(from: [score("t→h")], repetitions: 5)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].kind, .repeated)
        XCTAssertEqual(result[0].targets, ["th"])
    }

    func test_repeatedDrill_text_hasCorrectRepetitions() {
        let result = DrillGenerator.generate(from: [score("t→h")], repetitions: 4)
        let drill = result.first { $0.kind == .repeated }!
        XCTAssertEqual(drill.text, "th th th th")
    }

    func test_repeatedDrill_text_singleRepetition() {
        let result = DrillGenerator.generate(from: [score("a→s")], repetitions: 1)
        XCTAssertEqual(result[0].text, "as")
    }

    func test_repeatedDrill_zeroRepetitions_clampsToOne() {
        let result = DrillGenerator.generate(from: [score("t→h")], repetitions: 0)
        XCTAssertEqual(result[0].text, "th")
    }

    func test_repeatedDrill_negativeRepetitions_clampsToOne() {
        let result = DrillGenerator.generate(from: [score("t→h")], repetitions: -3)
        XCTAssertEqual(result[0].text, "th")
    }

    func test_repeatedDrill_targets_containsSingleBigram() {
        let result = DrillGenerator.generate(from: [score("e→r")], repetitions: 3)
        XCTAssertEqual(result[0].targets, ["er"])
    }

    // MARK: - Alternating drills

    func test_generate_twoBigrams_producesOneAlternatingDrill() {
        let inputs = [score("t→h"), score("h→e")]
        let result = DrillGenerator.generate(from: inputs, repetitions: 3)
        let alt = result.filter { $0.kind == .alternating }
        XCTAssertEqual(alt.count, 1)
    }

    func test_alternatingDrill_text_alternatesBothBigrams() {
        let inputs = [score("t→h"), score("h→e")]
        let result = DrillGenerator.generate(from: inputs, repetitions: 3)
        let alt = result.first { $0.kind == .alternating }!
        XCTAssertEqual(alt.text, "th he th he th he")
    }

    func test_alternatingDrill_targets_containsBothBigrams() {
        let inputs = [score("t→h"), score("h→e")]
        let result = DrillGenerator.generate(from: inputs, repetitions: 2)
        let alt = result.first { $0.kind == .alternating }!
        XCTAssertEqual(alt.targets, ["th", "he"])
    }

    func test_generate_threeBigrams_oneAlternatingDrill() {
        // 3 bigrams → pair (0,1) only (odd bigram has no partner)
        let inputs = [score("t→h"), score("h→e"), score("e→r")]
        let result = DrillGenerator.generate(from: inputs, repetitions: 2)
        let alt = result.filter { $0.kind == .alternating }
        XCTAssertEqual(alt.count, 1)
        XCTAssertEqual(alt[0].targets, ["th", "he"])
    }

    func test_generate_fourBigrams_twoAlternatingDrills() {
        let inputs = [score("t→h"), score("h→e"), score("e→r"), score("r→s")]
        let result = DrillGenerator.generate(from: inputs, repetitions: 2)
        let alt = result.filter { $0.kind == .alternating }
        XCTAssertEqual(alt.count, 2)
        XCTAssertEqual(alt[0].targets, ["th", "he"])
        XCTAssertEqual(alt[1].targets, ["er", "rs"])
    }

    // MARK: - Output ordering

    func test_generate_repeatedDrillsBeforeAlternating() {
        let inputs = [score("t→h"), score("h→e")]
        let result = DrillGenerator.generate(from: inputs, repetitions: 2)
        let firstAlt = result.firstIndex { $0.kind == .alternating }!
        let lastRep  = result.lastIndex  { $0.kind == .repeated }!
        XCTAssertLessThan(lastRep, firstAlt)
    }

    // MARK: - Multi-character keys

    func test_generate_multiCharKey_displaysAsFromPlusTo() {
        // Keys like "Space→t" or modifier combos
        let input = score("Space→t")
        let result = DrillGenerator.generate(from: [input], repetitions: 2)
        XCTAssertEqual(result[0].targets, ["Spacet"])
    }

    // MARK: - Repetitions count

    func test_generate_defaultRepetitions_isFive() {
        let result = DrillGenerator.generate(from: [score("t→h")])
        let words = result[0].text.split(separator: " ")
        XCTAssertEqual(words.count, 5)
    }

    func test_alternating_repetitions_producesCorrectWordCount() {
        let inputs = [score("t→h"), score("h→e")]
        let result = DrillGenerator.generate(from: inputs, repetitions: 4)
        let alt = result.first { $0.kind == .alternating }!
        // 4 repetitions × 2 bigrams = 8 words
        let words = alt.text.split(separator: " ")
        XCTAssertEqual(words.count, 8)
    }
}
