import Foundation

/// Scoring model for ranking trigrams by estimated typing difficulty.
///
/// Formula (v1):
///   score = estimatedIKI × log2(count + 1)
///
/// - `estimatedIKI`: sum of the two constituent bigram mean IKIs in milliseconds.
///                   Approximates total latency for the three-key transition.
/// - `log2(count + 1)`: log-scaled frequency weight — common trigrams score higher
///                       without letting frequency dominate over latency.
///
/// Note: Real trigram IKI collection would give more accurate ranking, but this
/// approximation is sufficient for Phase 2 (Issue #89). Revisit after raw trigram
/// samples are collected.
public struct TrigramScore: Equatable {
    public let trigram: String
    /// Estimated inter-key latency: IKI(first→second) + IKI(second→third), in ms.
    public let estimatedIKI: Double
    /// Total number of times this trigram was observed.
    public let count: Int

    public init(trigram: String, estimatedIKI: Double, count: Int) {
        self.trigram      = trigram
        self.estimatedIKI = estimatedIKI
        self.count        = count
    }

    /// Training priority score. Higher = more important to practise.
    public var score: Double {
        estimatedIKI * log2(Double(count) + 1)
    }

    /// True when all three keys are single printable ASCII characters (U+0020–U+007E).
    /// Excludes special keys and non-ASCII keys that cannot be typed in a drill.
    public var isTypeable: Bool {
        guard let t = Trigram.parse(trigram) else { return false }
        return isPrintableASCII(t.first) && isPrintableASCII(t.second) && isPrintableASCII(t.third)
    }

    private func isPrintableASCII(_ s: String) -> Bool {
        guard s.count == 1, let scalar = s.unicodeScalars.first else { return false }
        return scalar.value >= 0x20 && scalar.value <= 0x7E
    }
}

// MARK: - Ranking

extension TrigramScore {
    /// Returns the top-k trigrams ranked for training.
    ///
    /// - Parameters:
    ///   - candidates: All trigrams with their estimated IKI and frequency data.
    ///   - minCount:   Minimum observation count; trigrams below this threshold are excluded
    ///                 because frequency estimates are unreliable (default: 5).
    ///   - topK:       Maximum number of results to return (default: 10).
    /// - Returns: Candidates sorted descending by score; ties broken by higher count.
    public static func topCandidates(
        _ candidates: [TrigramScore],
        minCount: Int = 5,
        topK: Int = 10
    ) -> [TrigramScore] {
        candidates
            .filter { $0.count >= minCount && $0.isTypeable }
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.count > $1.count
            }
            .prefix(topK)
            .map { $0 }
    }
}
