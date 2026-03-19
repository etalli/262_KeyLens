import Foundation

// MARK: - SessionConfig

/// Parameters that control how a training session is built.
///
/// Tier boundaries split the selected targets into priority groups.
/// Higher-priority targets receive more repetitions.
///
/// Default (Normal):
///   Rank 1–2  → highReps  (5) — hardest, needs most practice
///   Rank 3    → midReps   (3)
public struct SessionConfig: Equatable {
    /// Maximum number of target bigrams in one session.
    public let maxTargets: Int
    /// Repetitions for rank 1–highTierSize bigrams.
    public let highReps: Int
    /// Repetitions for the next midTierSize bigrams.
    public let midReps: Int
    /// Repetitions for the remaining bigrams.
    public let lowReps: Int
    /// Number of bigrams in the high-priority tier.
    public let highTierSize: Int
    /// Number of bigrams in the mid-priority tier.
    public let midTierSize: Int
    /// Whether to append alternating drills between consecutive pairs.
    public let includeAlternating: Bool

    public init(
        maxTargets: Int = 3,
        highReps: Int = 5,
        midReps: Int = 3,
        lowReps: Int = 2,
        highTierSize: Int = 2,
        midTierSize: Int = 1,
        includeAlternating: Bool = true
    ) {
        self.maxTargets        = max(1, maxTargets)
        self.highReps          = max(1, highReps)
        self.midReps           = max(1, midReps)
        self.lowReps           = max(1, lowReps)
        self.highTierSize      = max(0, highTierSize)
        self.midTierSize       = max(0, midTierSize)
        self.includeAlternating = includeAlternating
    }

    /// Default session configuration (Normal length).
    public static let `default` = SessionConfig()
}

// MARK: - SessionLength

/// User-selectable session length presets.
///
/// | Length | Targets | ~Words |
/// |--------|---------|--------|
/// | short  |    2    |    6   |
/// | normal |    3    |   23   |
/// | long   |    5    |   55   |
public enum SessionLength: String, CaseIterable {
    case short  = "Short"
    case normal = "Normal"
    case long   = "Long"

    public var config: SessionConfig {
        switch self {
        case .short:
            return SessionConfig(maxTargets: 2, highReps: 3, midReps: 2, lowReps: 2,
                                 highTierSize: 2, midTierSize: 0, includeAlternating: false)
        case .normal:
            return SessionConfig()   // matches SessionConfig.default
        case .long:
            return SessionConfig(maxTargets: 5, highReps: 8, midReps: 5, lowReps: 3,
                                 highTierSize: 2, midTierSize: 2, includeAlternating: true)
        }
    }
}

// MARK: - TrainingSession

/// A complete training session derived from ranked bigram data.
///
/// - `targets`: the bigrams selected for this session, ordered by priority (highest first).
/// - `drills`:  the ordered sequence of drills the user should type through.
/// - `config`:  the configuration that produced this session.
public struct TrainingSession: Equatable {
    public let targets: [BigramScore]
    public let drills:  [DrillSequence]
    public let config:  SessionConfig

    public init(targets: [BigramScore], drills: [DrillSequence], config: SessionConfig) {
        self.targets = targets
        self.drills  = drills
        self.config  = config
    }

    /// Total number of words the user needs to type across all drills.
    public var totalWords: Int {
        drills.reduce(0) { $0 + $1.text.split(separator: " ").count }
    }
}

// MARK: - SessionBuilder

/// Constructs a `TrainingSession` from a ranked list of bigrams.
///
/// Building rules
/// ──────────────
/// 1. Select the top `config.maxTargets` bigrams (already ranked by `rankedBigramsForTraining`).
/// 2. Assign each target to a tier based on its rank:
///      rank 1 … highTierSize          → highReps
///      rank highTierSize+1 … +midTierSize → midReps
///      remainder                       → lowReps
/// 3. Generate one repeated drill per target with tier-appropriate repetitions.
/// 4. If `includeAlternating`, append one alternating drill per consecutive pair
///    within each tier block.
/// 5. Order: high-tier drills first, then mid-tier, then low-tier.
///    Rationale: harder combinations get full attention before fatigue sets in.
public enum SessionBuilder {

    /// Builds a training session from the given ranked bigrams.
    ///
    /// - Parameters:
    ///   - scores: Bigrams ranked by training priority (highest score first).
    ///             Typically the output of `KeyCountStore.rankedBigramsForTraining()`.
    ///   - config: Session parameters. Defaults to `SessionConfig.default`.
    /// - Returns: A `TrainingSession`. Returns an empty session if `scores` is empty
    ///            or no bigram keys can be parsed.
    public static func build(
        from scores: [BigramScore],
        config: SessionConfig = .default
    ) -> TrainingSession {
        let selected = Array(scores.prefix(config.maxTargets))
        guard !selected.isEmpty else {
            return TrainingSession(targets: [], drills: [], config: config)
        }

        // Assign tiers.
        let tiers = makeTiers(from: selected, config: config)

        // Build drills in tier order (high → mid → low).
        var drills: [DrillSequence] = []
        for tier in tiers {
            drills += drillsForTier(tier.scores, reps: tier.reps, includeAlternating: config.includeAlternating)
        }

        return TrainingSession(targets: selected, drills: drills, config: config)
    }

    // MARK: - Private helpers

    private struct Tier {
        let scores: [BigramScore]
        let reps: Int
    }

    private static func makeTiers(from selected: [BigramScore], config: SessionConfig) -> [Tier] {
        var result: [Tier] = []
        var remaining = selected

        // High tier
        let highSlice = Array(remaining.prefix(config.highTierSize))
        remaining = Array(remaining.dropFirst(config.highTierSize))
        if !highSlice.isEmpty {
            result.append(Tier(scores: highSlice, reps: config.highReps))
        }

        // Mid tier
        let midSlice = Array(remaining.prefix(config.midTierSize))
        remaining = Array(remaining.dropFirst(config.midTierSize))
        if !midSlice.isEmpty {
            result.append(Tier(scores: midSlice, reps: config.midReps))
        }

        // Low tier (remainder)
        if !remaining.isEmpty {
            result.append(Tier(scores: remaining, reps: config.lowReps))
        }

        return result
    }

    private static func drillsForTier(
        _ scores: [BigramScore],
        reps: Int,
        includeAlternating: Bool
    ) -> [DrillSequence] {
        var drills: [DrillSequence] = []

        // One repeated drill per bigram.
        let repeated = DrillGenerator.generate(from: scores, repetitions: reps)
            .filter { $0.kind == .repeated }
        drills += repeated

        // One alternating drill per consecutive pair within the tier.
        if includeAlternating && scores.count >= 2 {
            let alternating = DrillGenerator.generate(from: scores, repetitions: reps)
                .filter { $0.kind == .alternating }
            drills += alternating
        }

        return drills
    }
}
