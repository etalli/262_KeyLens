import Foundation

// MARK: - Export
// Methods for exporting keystroke data to CSV format.

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
}
