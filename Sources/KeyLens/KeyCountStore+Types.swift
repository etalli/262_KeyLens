import Foundation

// MARK: - Data model sub-structs

/// Inter-keystroke interval and WPM tracking state.
struct ActivityData {
    var lastInputTime: Date?
    var avgIntervalMs: Double = 0          // Welford moving average (ms)
    var avgIntervalCount: Int = 0          // Welford sample count
    var dailyMinIntervalMs: [String: Double] = [:]  // "yyyy-MM-dd" -> daily min IKI (ms, ≤1000ms)
    var dailyAvgIntervalMs: [String: Double] = [:]  // Daily Welford average interval (Issue #59 Phase 2)
    var dailyAvgIntervalCount: [String: Int] = [:]
}

/// Same-finger, alternation, high-strain, bigram/trigram ergonomic data.
struct ErgonomicsData {
    var sameFingerCount: Int = 0
    var totalBigramCount: Int = 0
    var dailySameFingerCount: [String: Int] = [:]
    var dailyTotalBigramCount: [String: Int] = [:]
    var handAlternationCount: Int = 0
    var dailyHandAlternationCount: [String: Int] = [:]
    var bigramCounts: [String: Int] = [:]   // all-time bigram frequency (small enough to stay in JSON)
    var trigramCounts: [String: Int] = [:]  // all-time trigram frequency
    var alternationRewardScore: Double = 0  // Issue #25
    var highStrainBigramCount: Int = 0      // Issue #28
    var dailyHighStrainBigramCount: [String: Int] = [:]
    var highStrainTrigramCount: Int = 0
    var dailyHighStrainTrigramCount: [String: Int] = [:]
}

/// Per-app and per-device keystroke and ergonomic counters.
struct AppTrackerData {
    var appCounts: [String: Int] = [:]
    var deviceCounts: [String: Int] = [:]
    var appSameFingerCount: [String: Int] = [:]
    var appTotalBigramCount: [String: Int] = [:]
    var appHandAlternationCount: [String: Int] = [:]
    var appHighStrainBigramCount: [String: Int] = [:]
    var deviceSameFingerCount: [String: Int] = [:]
    var deviceTotalBigramCount: [String: Int] = [:]
    var deviceHandAlternationCount: [String: Int] = [:]
    var deviceHighStrainBigramCount: [String: Int] = [:]
}

/// Modifier+key shortcut tracking (Issue #66).
struct ShortcutData {
    var modifiedCounts: [String: Int] = [:]     // "⌘c", "⇧a" modifier+key combos
    var dailyModifiedCount: [String: Int] = [:]
}
