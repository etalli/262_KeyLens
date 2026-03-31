import Foundation
import KeyLensCore

// MARK: - HeatmapViewModel (Issue #270)
//
// Owns strainScores and speedScores, computing them asynchronously on a
// background queue so the main thread is never blocked during SwiftUI renders.
// Previously these were computed properties on KeyboardHeatmapView that issued
// a queue.sync + full SQLite read on every body evaluation.

@MainActor
final class HeatmapViewModel: ObservableObject {
    @Published private(set) var strainScores: [String: Int] = [:]
    @Published private(set) var speedScores: [String: Double] = [:]

    private var reloadTask: Task<Void, Never>?

    /// Recompute scores in the background and publish the result on the main actor.
    /// Cancels any in-flight reload before starting a new one.
    /// Uses Task (inherits @MainActor) + async let over Task.detached to avoid
    /// the "captured var self in concurrently-executing code" error in strict concurrency.
    func reload() {
        reloadTask?.cancel()
        reloadTask = Task {
            async let strain = Task.detached(priority: .userInitiated) { Self.computeStrainScores() }.value
            async let speed  = Task.detached(priority: .userInitiated) { Self.computeSpeedScores() }.value
            let (s, sp) = await (strain, speed)
            guard !Task.isCancelled else { return }
            strainScores = s
            speedScores  = sp
        }
    }

    // MARK: - Background computation

    private nonisolated static func computeStrainScores() -> [String: Int] {
        var scores: [String: Int] = [:]
        for (pair, count) in KeyCountStore.shared.topHighStrainBigrams(limit: 1000) {
            guard let b = Bigram.parse(pair) else { continue }
            scores[b.from, default: 0] += count
            scores[b.to,   default: 0] += count
        }
        return scores
    }

    private nonisolated static func computeSpeedScores() -> [String: Double] {
        let bigramIKI = KeyCountStore.shared.allBigramIKI()
        var acc: [String: (sum: Double, count: Int)] = [:]
        for (bigram, avgIKI) in bigramIKI {
            guard let b = Bigram.parse(bigram) else { continue }
            for key in [b.from, b.to] {
                let e = acc[key] ?? (sum: 0, count: 0)
                acc[key] = (sum: e.sum + avgIKI, count: e.count + 1)
            }
        }
        return acc.compactMapValues { d -> Double? in
            guard d.count >= 3 else { return nil }
            return d.sum / Double(d.count)
        }
    }
}
