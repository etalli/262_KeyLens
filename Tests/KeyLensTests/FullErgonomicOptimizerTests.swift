import XCTest
@testable import KeyLensCore

final class FullErgonomicOptimizerTests: XCTestCase {

    private let layout = LayoutRegistry.shared
    private let optimizer = FullErgonomicOptimizer(candidateLimit: 10)

    // MARK: - 1. Basic properties

    func test_optimize_emptyInput_returnsEmpty() {
        let result = optimizer.optimize(bigramCounts: [:], keyCounts: [:])
        XCTAssertTrue(result.isEmpty)
    }

    func test_optimize_maxSwapsZero_returnsEmpty() {
        let counts: [String: Int] = ["f→r": 1000]
        let result = optimizer.optimize(bigramCounts: counts, keyCounts: [:], maxSwaps: 0)
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - 2. Optimization Logic

    func test_optimize_highSFB_improvesScore() {
        // "f" and "r" are left-index in ANSI.
        // Heavy SFB load that can be relieved by swapping "f" with "k" (right middle).
        let bigramCounts = [
            "f→r": 1000,
            "r→f": 1000
        ]
        let keyCounts = [
            "f": 1000,
            "r": 1000,
            "k": 50 // Candidate for swap
        ]
        
        let baselineScore = ErgonomicSnapshot.capture(
            bigramCounts: bigramCounts,
            keyCounts: keyCounts,
            layout: layout
        ).ergonomicScore
        
        let swaps = optimizer.optimize(
            bigramCounts: bigramCounts,
            keyCounts: keyCounts,
            layout: layout,
            constraints: .none,
            maxSwaps: 1
        )
        
        XCTAssertFalse(swaps.isEmpty, "Optimizer should find at least one improvement")
        guard let swap = swaps.first else { return }
        
        XCTAssertGreaterThan(swap.projectedImprovement, 0.0)
        
        // Verify actual improvement
        var map: [String: String] = [:]
        KeyRelocationSimulator.applySwap(key1: swap.from, key2: swap.to, to: &map)
        let simLayout = KeyRelocationSimulator.layout(applying: map, over: layout.current)
        let simRegistry = LayoutRegistry.forSimulation(layout: simLayout, base: layout)
        let newScore = ErgonomicSnapshot.capture(
            bigramCounts: bigramCounts,
            keyCounts: keyCounts,
            layout: simRegistry
        ).ergonomicScore
        
        XCTAssertGreaterThan(newScore, baselineScore)
        XCTAssertEqual(newScore - baselineScore, swap.projectedImprovement, accuracy: 1e-9)
    }

    func test_optimize_respectsConstraints() {
        // Heavy "f→r" load. Lock "f".
        let bigramCounts = ["f→r": 1000]
        let keyCounts = ["f": 1000, "r": 1000, "k": 100]
        let constraints = LayoutConstraints(fixedKeys: ["f"])
        
        let swaps = optimizer.optimize(
            bigramCounts: bigramCounts,
            keyCounts: keyCounts,
            layout: layout,
            constraints: constraints,
            maxSwaps: 5
        )
        
        for swap in swaps {
            XCTAssertNotEqual(swap.from, "f")
            XCTAssertNotEqual(swap.to, "f")
        }
    }

    func test_optimize_stopsWhenNoImprovement() {
        // Input that is already perfect or has no relocatable improvements.
        // "f→j" is hand-alternating, no SFB.
        let bigramCounts = ["f→j": 1000]
        let keyCounts = ["f": 500, "j": 500]
        
        let swaps = optimizer.optimize(
            bigramCounts: bigramCounts,
            keyCounts: keyCounts,
            layout: layout,
            maxSwaps: 10
        )
        
        // It might find sub-improvement (travel distance, etc) but if it's already good,
        // it should stop early or produce no swaps if no swap yields > 0.001 improvement.
        XCTAssertLessThan(swaps.count, 10)
    }

    func test_optimize_chainedSwaps_scoreIncreases() {
        let bigramCounts = [
            "f→r": 1000,
            "j→u": 1000,
            "k→i": 1000
        ]
        let keyCounts = ["f": 500, "r": 500, "j": 500, "u": 500, "k": 500, "i": 500, "a": 10, "s": 10, "d": 10, "l": 10, "m": 10, "n": 10]
        
        let swaps = optimizer.optimize(
            bigramCounts: bigramCounts,
            keyCounts: keyCounts,
            layout: layout,
            constraints: .none, // Allow swapping with any key
            maxSwaps: 3
        )
        
        // As long as score improves and we found at least 2 swaps to fix all SFBs, it's successful.
        XCTAssertGreaterThanOrEqual(swaps.count, 2)
        XCTAssertGreaterThan(swaps[0].projectedImprovement, 0.0)
    }

    func test_optimize_thumbRelocation_improvesScore() {
        // "e" is very frequent but on middle finger.
        // Moving it to a thumb key (e.g. swapping with Cmd) should improve Thumb Efficiency.
        // Using constraints.none to allow swapping Cmd.
        let bigramCounts: [String: Int] = ["e→a": 100, "a→e": 100]
        let keyCounts = ["e": 5000, "a": 500, "⌘Cmd": 10]
        
        let baseline = ErgonomicSnapshot.capture(
            bigramCounts: bigramCounts,
            keyCounts: keyCounts,
            layout: layout
        ).ergonomicScore
        
        let swaps = optimizer.optimize(
            bigramCounts: bigramCounts,
            keyCounts: keyCounts,
            layout: layout,
            constraints: .none,
            maxSwaps: 1
        )
        
        XCTAssertFalse(swaps.isEmpty)
        if let swap = swaps.first {
            XCTAssertTrue(swap.from == "e" || swap.to == "e")
            XCTAssertGreaterThan(swap.projectedImprovement, 0.0)
        }
    }
}
