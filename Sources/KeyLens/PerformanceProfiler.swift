import Foundation

/// Opt-in performance profiler for low-overhead aggregated measurements.
/// Disabled by default and enabled via UserDefaults:
/// `defaults write com.etalli.keylens perfProfilingEnabled -bool true`
final class PerformanceProfiler {
    static let shared = PerformanceProfiler()

    private struct Stats {
        var count: Int = 0
        var totalMs: Double = 0
        var minMs: Double = .greatestFiniteMagnitude
        var maxMs: Double = 0
        var samples: [Double] = []

        mutating func add(_ ms: Double, keepSamples: Bool) {
            count += 1
            totalMs += ms
            minMs = min(minMs, ms)
            maxMs = max(maxMs, ms)
            if keepSamples { samples.append(ms) }
        }

        var meanMs: Double { count > 0 ? totalMs / Double(count) : 0 }
    }

    private let queue = DispatchQueue(label: "com.keylens.perf-profiler")
    private var statsByMetric: [String: Stats] = [:]
    private var lastFlush = Date()
    private var enabledCached: Bool?
    private var enabledCacheAt = Date.distantPast

    private init() {}

    var isEnabled: Bool {
        // Cache for 3 seconds to avoid hot-path UserDefaults reads.
        let now = Date()
        if let enabledCached, now.timeIntervalSince(enabledCacheAt) < 3 {
            return enabledCached
        }
        let enabled = UserDefaults.standard.bool(forKey: UDKeys.perfProfilingEnabled)
        enabledCached = enabled
        enabledCacheAt = now
        return enabled
    }

    func measure<T>(_ metric: String, _ block: () -> T) -> T {
        let start = CFAbsoluteTimeGetCurrent()
        let result = block()
        record(metric: metric, ms: (CFAbsoluteTimeGetCurrent() - start) * 1000)
        return result
    }

    func record(metric: String, ms: Double) {
        guard isEnabled else { return }
        queue.async {
            var stats = self.statsByMetric[metric] ?? Stats()
            stats.add(ms, keepSamples: stats.samples.count < AppConfiguration.perfSampleCapPerMetric)
            self.statsByMetric[metric] = stats
            self.maybeFlushLocked()
        }
    }

    private func maybeFlushLocked() {
        let now = Date()
        guard now.timeIntervalSince(lastFlush) >= AppConfiguration.perfLogIntervalSecs else { return }
        lastFlush = now
        flushLocked()
    }

    private func flushLocked() {
        guard !statsByMetric.isEmpty else { return }
        for (metric, stats) in statsByMetric.sorted(by: { $0.key < $1.key }) where stats.count > 0 {
            let p95 = percentile95(samples: stats.samples)
            KeyLens.log("[perf] metric=\(metric) n=\(stats.count) mean=\(fmt(stats.meanMs))ms p95=\(fmt(p95))ms min=\(fmt(stats.minMs))ms max=\(fmt(stats.maxMs))ms")
        }
        statsByMetric.removeAll(keepingCapacity: true)
    }

    private func percentile95(samples: [Double]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let sorted = samples.sorted()
        let idx = Int((Double(sorted.count - 1) * 0.95).rounded(.toNearestOrAwayFromZero))
        return sorted[max(0, min(idx, sorted.count - 1))]
    }

    private func fmt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
