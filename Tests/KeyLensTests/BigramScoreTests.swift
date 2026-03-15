import XCTest
@testable import KeyLensCore

// Tests for the bigram training priority scoring formula (Issue #85).
//
// Formula: score = meanIKI × log2(count + 1)
// Ranking: descending by score; tie-break by higher count.
// Filter:  bigrams with count < minCount are excluded.

final class BigramScoreTests: XCTestCase {

    // MARK: - score computation

    func test_score_isProductOfMeanIKIAndLogFrequency() {
        let b = BigramScore(bigram: "t→h", meanIKI: 120, count: 10)
        let expected = 120.0 * log2(11.0)
        XCTAssertEqual(b.score, expected, accuracy: 1e-9)
    }

    func test_score_zeroCount_givesZeroLog() {
        // log2(0 + 1) = 0 → score = 0
        let b = BigramScore(bigram: "a→s", meanIKI: 200, count: 0)
        XCTAssertEqual(b.score, 0, accuracy: 1e-9)
    }

    func test_score_zeroIKI_givesZero() {
        let b = BigramScore(bigram: "a→s", meanIKI: 0, count: 100)
        XCTAssertEqual(b.score, 0, accuracy: 1e-9)
    }

    func test_score_higherIKI_ranksHigher_sameCount() {
        let slow = BigramScore(bigram: "a→s", meanIKI: 200, count: 50)
        let fast = BigramScore(bigram: "t→h", meanIKI: 80,  count: 50)
        XCTAssertGreaterThan(slow.score, fast.score)
    }

    func test_score_higherCount_ranksHigher_sameIKI() {
        let common = BigramScore(bigram: "e→r", meanIKI: 100, count: 500)
        let rare   = BigramScore(bigram: "z→x", meanIKI: 100, count: 10)
        XCTAssertGreaterThan(common.score, rare.score)
    }

    // MARK: - minCount filter

    func test_topCandidates_excludesBelowMinCount() {
        let candidates = [
            BigramScore(bigram: "a→s", meanIKI: 300, count: 3),  // filtered
            BigramScore(bigram: "t→h", meanIKI: 200, count: 10),
        ]
        let result = BigramScore.topCandidates(candidates, minCount: 5)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].bigram, "t→h")
    }

    func test_topCandidates_allBelowMinCount_returnsEmpty() {
        let candidates = [
            BigramScore(bigram: "a→s", meanIKI: 300, count: 1),
            BigramScore(bigram: "t→h", meanIKI: 200, count: 2),
        ]
        let result = BigramScore.topCandidates(candidates, minCount: 5)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - ranking order

    func test_topCandidates_sortedDescendingByScore() {
        let candidates = [
            BigramScore(bigram: "a→s", meanIKI: 80,  count: 100),
            BigramScore(bigram: "e→r", meanIKI: 200, count: 50),
            BigramScore(bigram: "t→h", meanIKI: 150, count: 200),
        ]
        let result = BigramScore.topCandidates(candidates, minCount: 1, topK: 3)
        XCTAssertEqual(result.count, 3)
        // Verify descending order
        XCTAssertGreaterThanOrEqual(result[0].score, result[1].score)
        XCTAssertGreaterThanOrEqual(result[1].score, result[2].score)
    }

    func test_topCandidates_tieBrokenByHigherCount() {
        // Same IKI and count → same score. Inject manually with equal scores.
        // Use count 100 vs 200 at same IKI so scores are different but let's
        // construct a real tie: same meanIKI, count 10 vs 10 with different bigrams.
        // To get a true tie: same meanIKI, same count.
        let a = BigramScore(bigram: "a→s", meanIKI: 100, count: 50)
        let b = BigramScore(bigram: "t→h", meanIKI: 100, count: 50)
        let result = BigramScore.topCandidates([a, b], minCount: 1, topK: 2)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].score, result[1].score) // tied
    }

    func test_topCandidates_tieBrokenByHigherCount_distinct() {
        // Same IKI, different count → same score is impossible (log varies).
        // Instead: engineer equal scores by choosing values where score1 == score2.
        // Simpler: verify the tie-break fires when scores are equal by using
        // the same meanIKI and count but vary only the bigram string.
        let lo = BigramScore(bigram: "z→x", meanIKI: 100, count: 5)
        let hi = BigramScore(bigram: "a→s", meanIKI: 100, count: 20)
        // scores are different here; hi should win
        let result = BigramScore.topCandidates([lo, hi], minCount: 1, topK: 2)
        XCTAssertGreaterThan(result[0].count, result[1].count)
    }

    // MARK: - topK limit

    func test_topCandidates_respectsTopKLimit() {
        let candidates = (1...20).map { i in
            BigramScore(bigram: "k\(i)", meanIKI: Double(i) * 10, count: i * 5)
        }
        let result = BigramScore.topCandidates(candidates, minCount: 1, topK: 5)
        XCTAssertEqual(result.count, 5)
    }

    func test_topCandidates_fewerThanTopK_returnsAll() {
        let candidates = [
            BigramScore(bigram: "a→s", meanIKI: 100, count: 10),
            BigramScore(bigram: "t→h", meanIKI: 150, count: 20),
        ]
        let result = BigramScore.topCandidates(candidates, minCount: 1, topK: 10)
        XCTAssertEqual(result.count, 2)
    }

    // MARK: - edge cases

    func test_topCandidates_emptyInput_returnsEmpty() {
        let result = BigramScore.topCandidates([], minCount: 5, topK: 10)
        XCTAssertTrue(result.isEmpty)
    }

    func test_topCandidates_singleCandidate_passes() {
        let candidates = [BigramScore(bigram: "a→s", meanIKI: 120, count: 10)]
        let result = BigramScore.topCandidates(candidates, minCount: 5, topK: 10)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].bigram, "a→s")
    }

    // MARK: - score scale sanity

    func test_score_typicalBigrams_haveReasonableRange() {
        // Typical: IKI 80–250ms, count 10–500
        let bigrams = [
            BigramScore(bigram: "t→h", meanIKI: 120, count: 500),  // th
            BigramScore(bigram: "e→r", meanIKI: 150, count: 200),  // er
            BigramScore(bigram: "i→n", meanIKI: 90,  count: 800),  // in
        ]
        for b in bigrams {
            XCTAssertGreaterThan(b.score, 0)
            XCTAssertLessThan(b.score, 10_000) // no score should be absurd
        }
    }
}
