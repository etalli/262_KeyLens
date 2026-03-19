import Foundation
import GRDB
import KeyLensCore

// MARK: - Training result persistence (Issue #88)

extension KeyCountStore {

    /// Persists a completed training session result to SQLite.
    ///
    /// Runs the INSERT on `queue` (serial, background) and calls `completion`
    /// on the main thread once the write is done, so callers can safely
    /// trigger a UI reload immediately after.
    ///
    /// - Parameters:
    ///   - targets:       Raw bigram keys that were practiced, e.g. ["t→h", "h→e"].
    ///   - sessionLength: The session length label ("Short", "Normal", "Long").
    ///   - accuracy:      Percentage of correct keystrokes (0–100).
    ///   - wpm:           Words per minute during the session.
    ///   - duration:      Elapsed seconds from first keystroke to session end.
    ///   - totalTyped:    Total keystrokes typed.
    ///   - totalCorrect:  Correct keystrokes typed.
    ///   - completion:    Called on main thread after the write completes.
    func saveTrainingResult(
        targets: [String],
        sessionLength: String,
        accuracy: Int,
        wpm: Int,
        duration: Double,
        totalTyped: Int,
        totalCorrect: Int,
        completion: @escaping () -> Void = {}
    ) {
        queue.async { [weak self] in
            guard let self, let db = self.dbQueue else {
                DispatchQueue.main.async { completion() }
                return
            }
            let targetsJSON = (try? JSONSerialization.data(withJSONObject: targets))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            let now = Date().timeIntervalSince1970
            try? db.write { db in
                try db.execute(
                    sql: """
                        INSERT INTO training_results
                            (completed_at, targets, session_length,
                             accuracy, wpm, duration_seconds, total_typed, total_correct)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [now, targetsJSON, sessionLength,
                                accuracy, wpm, duration, totalTyped, totalCorrect]
                )
            }
            DispatchQueue.main.async { completion() }
        }
    }

    /// Returns the most recent training results, newest first.
    ///
    /// - Parameter limit: Maximum number of records to return (default: 20).
    func trainingHistory(limit: Int = 20) -> [TrainingRecord] {
        queue.sync {
            guard let db = dbQueue else { return [] }
            let rows = (try? db.read { db in
                try Row.fetchAll(db, sql: """
                    SELECT id, completed_at, targets, session_length,
                           accuracy, wpm, duration_seconds, total_typed, total_correct
                    FROM training_results
                    ORDER BY completed_at DESC
                    LIMIT ?
                    """, arguments: [limit])
            }) ?? []

            return rows.compactMap { row -> TrainingRecord? in
                let id: Int64           = row["id"]
                let completedAt: Double = row["completed_at"]
                let targetsJSON: String = row["targets"]
                let sessionLength: String = row["session_length"]
                let accuracy: Int       = row["accuracy"]
                let wpm: Int            = row["wpm"]
                let duration: Double    = row["duration_seconds"]
                let totalTyped: Int     = row["total_typed"]
                let totalCorrect: Int   = row["total_correct"]

                let targets = (try? JSONSerialization.jsonObject(with: Data(targetsJSON.utf8)))
                    .flatMap { $0 as? [String] } ?? []

                return TrainingRecord(
                    id: id,
                    completedAt: Date(timeIntervalSince1970: completedAt),
                    targets: targets,
                    sessionLength: sessionLength,
                    accuracy: accuracy,
                    wpm: wpm,
                    durationSeconds: duration,
                    totalTyped: totalTyped,
                    totalCorrect: totalCorrect
                )
            }
        }
    }
}
