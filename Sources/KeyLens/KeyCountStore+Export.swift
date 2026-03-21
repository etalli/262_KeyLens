import Foundation
import GRDB

// MARK: - Export
// Methods for exporting keystroke data to CSV and SQLite formats.

extension KeyCountStore {

    /// Summary CSV (rank, key, total) — all-time cumulative counts.
    func exportSummaryCSV() -> String {
        queue.sync {
            var lines = ["rank,key,total"]
            for (i, (key, total)) in store.counts.sorted(by: { $0.value > $1.value }).enumerated() {
                let escaped = key.contains(",") ? "\"\(key)\"" : key
                lines.append("\(i + 1),\(escaped),\(total)")
            }
            return lines.joined(separator: "\n")
        }
    }

    /// Daily CSV (date, key, count) — per-day breakdown sorted by date and count.
    func exportDailyCSV() -> String {
        // Flush pending data first so the export is complete.
        flushSync()
        return queue.sync {
            guard let db = dbQueue else { return "date,key,count\n" }
            var lines = ["date,key,count"]
            let rows = (try? db.read { db in
                try Row.fetchAll(db, sql: """
                    SELECT date, key, count FROM daily_keys ORDER BY date, count DESC
                    """)
            }) ?? []
            for row in rows {
                let key: String = row["key"]
                let escaped = key.contains(",") ? "\"\(key)\"" : key
                lines.append("\(row["date"] as String),\(escaped),\(row["count"] as Int)")
            }
            return lines.joined(separator: "\n")
        }
    }

    /// Generates a Markdown block suitable for appending to an Obsidian daily note.
    /// Includes today's keystroke count, estimated WPM, backspace rate, and ergonomic score.
    func exportObsidianMarkdown(date: String) -> String {
        let store = KeyCountStore.shared
        let todayKeys = store.todayCount
        let wpm = store.estimatedWPM.map { String(format: "%.1f", $0) } ?? "—"
        let bsRate = store.todayBackspaceRate.map { String(format: "%.1f%%", $0) } ?? "—"
        let ergo = String(format: "%.0f", store.currentErgonomicScore)
        let sfRate = store.todaySameFingerRate.map { String(format: "%.1f%%", $0 * 100) } ?? "—"
        let altRate = store.todayHandAlternationRate.map { String(format: "%.1f%%", $0 * 100) } ?? "—"

        return """

## KeyLens · \(date)

| Metric | Value |
|--------|-------|
| Today's Keystrokes | \(todayKeys.formatted()) |
| Estimated WPM | \(wpm) |
| Backspace Rate | \(bsRate) |
| Ergonomic Score | \(ergo) / 100 |
| Same-Finger Bigrams | \(sfRate) |
| Hand Alternation | \(altRate) |
"""
    }

    /// Export all keystroke data to a SQLite database at the given URL.
    /// Uses GRDB backup to safely copy the live keylens.db to the destination.
    func exportSQLite(to url: URL) throws {
        // Flush pending so the copy is up-to-date.
        flushSync()
        guard let src = dbQueue else { return }
        // Remove any existing file at the destination.
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        let dest = try DatabaseQueue(path: url.path)
        try src.backup(to: dest)
    }
}
