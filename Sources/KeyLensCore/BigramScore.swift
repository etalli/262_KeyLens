import Foundation

/// Scoring model for ranking bigrams by typing difficulty.
///
/// Formula (v1):
///   score = meanIKI × log2(count + 1)
///
/// - `meanIKI`  : mean inter-key interval in ms (proxy for P75 until raw samples are collected)
/// - `log2(count + 1)` : log-scaled frequency weight — common bigrams score higher than rare ones
///   without letting frequency dominate over latency.
///
/// Note: P75 would be more robust than mean but requires raw IKI sample storage.
/// This formula uses mean as a stand-in. Revisit after collecting a few days of data.
public struct BigramScore: Equatable {
    public let bigram: String
    /// Mean inter-key interval in milliseconds.
    public let meanIKI: Double
    /// Total number of times this bigram was observed.
    public let count: Int

    public init(bigram: String, meanIKI: Double, count: Int) {
        self.bigram  = bigram
        self.meanIKI = meanIKI
        self.count   = count
    }

    /// Training priority score. Higher = more important to practise.
    public var score: Double {
        meanIKI * log2(Double(count) + 1)
    }

    /// True when both keys of the bigram are single printable ASCII characters (U+0020–U+007E).
    /// Excludes special keys (Delete, Return, Space stored as "Space") and non-ASCII keys
    /// like arrow keys (↑ U+2191, ↓ U+2193, ← U+2190) which cannot be typed in a drill.
    public var isTypeable: Bool {
        guard let b = Bigram.parse(bigram) else { return false }
        return isPrintableASCII(b.from) && isPrintableASCII(b.to)
    }

    private func isPrintableASCII(_ s: String) -> Bool {
        guard s.count == 1, let scalar = s.unicodeScalars.first else { return false }
        return scalar.value >= 0x20 && scalar.value <= 0x7E
    }
}

// MARK: - Ranking

extension BigramScore {
    /// Returns the top-k bigrams ranked for training.
    ///
    /// - Parameters:
    ///   - candidates: All bigrams with their IKI and frequency data.
    ///   - minCount:   Minimum observation count; bigrams below this threshold are excluded
    ///                 because their latency estimates are unreliable (default: 5).
    ///   - topK:       Maximum number of results to return (default: 10).
    /// - Returns: Candidates sorted descending by score; ties broken by higher count.
    public static func topCandidates(
        _ candidates: [BigramScore],
        minCount: Int = 5,
        topK: Int = 10
    ) -> [BigramScore] {
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
