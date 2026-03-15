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
        queue.sync {
            var lines = ["date,key,count"]
            for date in store.dailyCounts.keys.sorted() {
                let dayCounts = store.dailyCounts[date] ?? [:]
                for (key, count) in dayCounts.sorted(by: { $0.value > $1.value }) {
                    let escaped = key.contains(",") ? "\"\(key)\"" : key
                    lines.append("\(date),\(escaped),\(count)")
                }
            }
            return lines.joined(separator: "\n")
        }
    }

    /// Export all keystroke data to a SQLite database at the given URL.
    /// Tables created:
    ///   key_counts    — all-time total per key
    ///   daily_counts  — per-day count per key
    ///   hourly_counts — per-hour total keystrokes (key = "yyyy-MM-dd HH")
    ///   bigram_counts — all-time bigram (two-key sequence) totals
    func exportSQLite(to url: URL) throws {
        // Snapshot data under the serial queue to avoid holding it during DB writes.
        let (counts, dailyCounts, hourlyCounts, bigramCounts): (
            [String: Int], [String: [String: Int]], [String: Int], [String: Int]
        ) = queue.sync {
            (store.counts, store.dailyCounts, store.hourlyCounts, store.bigramCounts)
        }

        let db = try DatabaseQueue(path: url.path)
        try db.write { db in
            // key_counts
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS key_counts (
                    key   TEXT PRIMARY KEY,
                    total INTEGER NOT NULL
                )
            """)
            for (key, total) in counts {
                try db.execute(sql: "INSERT OR REPLACE INTO key_counts (key, total) VALUES (?, ?)",
                               arguments: [key, total])
            }

            // daily_counts
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS daily_counts (
                    date  TEXT NOT NULL,
                    key   TEXT NOT NULL,
                    count INTEGER NOT NULL,
                    PRIMARY KEY (date, key)
                )
            """)
            for (date, dayCounts) in dailyCounts {
                for (key, count) in dayCounts {
                    try db.execute(sql: "INSERT OR REPLACE INTO daily_counts (date, key, count) VALUES (?, ?, ?)",
                                   arguments: [date, key, count])
                }
            }

            // hourly_counts
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS hourly_counts (
                    hour  TEXT PRIMARY KEY,
                    count INTEGER NOT NULL
                )
            """)
            for (hour, count) in hourlyCounts {
                try db.execute(sql: "INSERT OR REPLACE INTO hourly_counts (hour, count) VALUES (?, ?)",
                               arguments: [hour, count])
            }

            // bigram_counts
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS bigram_counts (
                    bigram TEXT PRIMARY KEY,
                    count  INTEGER NOT NULL
                )
            """)
            for (bigram, count) in bigramCounts {
                try db.execute(sql: "INSERT OR REPLACE INTO bigram_counts (bigram, count) VALUES (?, ?)",
                               arguments: [bigram, count])
            }
        }
    }
}
