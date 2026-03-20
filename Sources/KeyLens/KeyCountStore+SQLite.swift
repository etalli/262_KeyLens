import Foundation
import GRDB

// MARK: - In-memory accumulator (flushed to SQLite every 30 seconds)
// All fields are deltas since the last flush. Protected by KeyCountStore.queue.

struct PendingStore {
    var dailyKeys:     [String: [String: Int]] = [:]  // date → key → delta
    var dailyBigrams:  [String: [String: Int]] = [:]  // date → bigram → delta
    var dailyTrigrams: [String: [String: Int]] = [:]  // date → trigram → delta
    var dailyApps:     [String: [String: Int]] = [:]  // date → app → delta
    var dailyDevices:  [String: [String: Int]] = [:]  // date → device → delta
    var hourly:        [String: [Int: Int]]    = [:]  // date → hour → delta
    var bigramIKI:     [String: (sum: Double, count: Int)] = [:]
    var ikiBuckets:    [String: [Int: Int]]    = [:]  // date → bucket → delta
    // Issue #60: completed typing sessions waiting to be flushed to SQLite
    var pendingSessions: [SessionRecord]       = []
    // Issue #63: hourly fatigue data (IKI + ergonomics per hour)
    var hourlySlices:  [String: [Int: HourlySlice]] = [:]  // date → hour → slice

    struct SessionRecord {
        var date: String        // yyyy-MM-dd of sessionStart
        var startTime: Double   // Unix timestamp
        var endTime: Double     // Unix timestamp
        var keystrokeCount: Int
    }

    /// Per-hour accumulator for fatigue detection (Issue #63).
    struct HourlySlice {
        var ikiSum:   Double = 0   // sum of IKI samples (ms) in this hour
        var ikiCount: Int    = 0   // number of IKI samples in this hour
        var ergTotal: Int    = 0   // total bigrams in this hour
        var ergSF:    Int    = 0   // same-finger bigrams in this hour
        var ergHS:    Int    = 0   // high-strain bigrams in this hour
    }

    var isEmpty: Bool {
        dailyKeys.isEmpty && dailyBigrams.isEmpty && dailyTrigrams.isEmpty &&
        dailyApps.isEmpty && dailyDevices.isEmpty && hourly.isEmpty &&
        bigramIKI.isEmpty && ikiBuckets.isEmpty && pendingSessions.isEmpty &&
        hourlySlices.isEmpty
    }
}

// MARK: - IKI bucket constants

extension KeyCountStore {
    /// Returns the histogram bucket index (0–6) for a given IKI value in ms.
    /// Buckets: 0=0–50ms, 1=50–100ms, ..., 5=250–300ms, 6=300+ms
    static func ikiBucket(for ms: Double) -> Int { min(Int(ms / 50.0), 6) }
    static let ikiBucketLabels = ["0–50", "50–100", "100–150", "150–200", "200–250", "250–300", "300+"]
}

// MARK: - SQLite setup & flush

extension KeyCountStore {

    static let dbFileName = "keylens.db"

    func setupDatabase() {
        do {
            let dir = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("KeyLens")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dbPath = dir.appendingPathComponent(Self.dbFileName).path

            let db = try DatabaseQueue(path: dbPath)

            var migrator = DatabaseMigrator()
            migrator.registerMigration("v1") { db in
                try db.create(table: "daily_keys", ifNotExists: true) { t in
                    t.column("date", .text).notNull()
                    t.column("key", .text).notNull()
                    t.column("count", .integer).notNull().defaults(to: 0)
                    t.primaryKey(["date", "key"])
                }
                try db.create(table: "daily_bigrams", ifNotExists: true) { t in
                    t.column("date", .text).notNull()
                    t.column("bigram", .text).notNull()
                    t.column("count", .integer).notNull().defaults(to: 0)
                    t.primaryKey(["date", "bigram"])
                }
                try db.create(table: "daily_trigrams", ifNotExists: true) { t in
                    t.column("date", .text).notNull()
                    t.column("trigram", .text).notNull()
                    t.column("count", .integer).notNull().defaults(to: 0)
                    t.primaryKey(["date", "trigram"])
                }
                try db.create(table: "daily_apps", ifNotExists: true) { t in
                    t.column("date", .text).notNull()
                    t.column("app", .text).notNull()
                    t.column("count", .integer).notNull().defaults(to: 0)
                    t.primaryKey(["date", "app"])
                }
                try db.create(table: "daily_devices", ifNotExists: true) { t in
                    t.column("date", .text).notNull()
                    t.column("device", .text).notNull()
                    t.column("count", .integer).notNull().defaults(to: 0)
                    t.primaryKey(["date", "device"])
                }
                try db.create(table: "hourly_counts", ifNotExists: true) { t in
                    t.column("date", .text).notNull()
                    t.column("hour", .integer).notNull()
                    t.column("count", .integer).notNull().defaults(to: 0)
                    t.primaryKey(["date", "hour"])
                }
                try db.create(table: "bigram_iki", ifNotExists: true) { t in
                    t.primaryKey("bigram", .text)
                    t.column("iki_sum", .double).notNull().defaults(to: 0)
                    t.column("iki_count", .integer).notNull().defaults(to: 0)
                }
                // IKI histogram: bucket 0=0–50ms … 6=300+ms
                try db.create(table: "iki_buckets", ifNotExists: true) { t in
                    t.column("date", .text).notNull()
                    t.column("bucket", .integer).notNull()
                    t.column("count", .integer).notNull().defaults(to: 0)
                    t.primaryKey(["date", "bucket"])
                }
            }
            // Issue #60: typing session records
            migrator.registerMigration("v2") { db in
                try db.create(table: "sessions", ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("id")
                    t.column("date", .text).notNull()
                    t.column("start_time", .double).notNull()
                    t.column("end_time", .double).notNull()
                    t.column("keystroke_count", .integer).notNull().defaults(to: 0)
                }
                try db.create(index: "sessions_date_idx", on: "sessions", columns: ["date"], ifNotExists: true)
            }
            // Issue #88: training result history
            migrator.registerMigration("v3") { db in
                try db.create(table: "training_results", ifNotExists: true) { t in
                    t.autoIncrementedPrimaryKey("id")
                    t.column("completed_at", .double).notNull()
                    t.column("targets", .text).notNull()          // JSON array of raw bigram keys
                    t.column("session_length", .text).notNull()   // "Short" / "Normal" / "Long"
                    t.column("accuracy", .integer).notNull()
                    t.column("wpm", .integer).notNull()
                    t.column("duration_seconds", .double).notNull()
                    t.column("total_typed", .integer).notNull()
                    t.column("total_correct", .integer).notNull()
                }
                try db.create(index: "training_results_date_idx",
                              on: "training_results", columns: ["completed_at"], ifNotExists: true)
            }
            // Issue #84: store pre-training IKI for before/after comparison
            migrator.registerMigration("v4") { db in
                try db.alter(table: "training_results") { t in
                    t.add(column: "before_iki_json", .text).notNull().defaults(to: "{}")
                }
            }
            // Issue #193: store trigram targets alongside bigram targets
            migrator.registerMigration("v5.1") { db in
                try db.alter(table: "training_results") { t in
                    t.add(column: "trigram_targets_json", .text).notNull().defaults(to: "[]")
                }
            }
            // Issue #63: per-hour fatigue data (IKI + ergonomic rates)
            migrator.registerMigration("v5") { db in
                try db.create(table: "hourly_ergonomics", ifNotExists: true) { t in
                    t.column("date",      .text).notNull()
                    t.column("hour",      .integer).notNull()
                    t.column("iki_sum",   .double).notNull().defaults(to: 0)
                    t.column("iki_count", .integer).notNull().defaults(to: 0)
                    t.column("erg_total", .integer).notNull().defaults(to: 0)
                    t.column("erg_sf",    .integer).notNull().defaults(to: 0)
                    t.column("erg_hs",    .integer).notNull().defaults(to: 0)
                    t.primaryKey(["date", "hour"])
                }
            }
            try migrator.migrate(db)

            dbQueue = db
            KeyLens.log("KeyCountStore: SQLite ready at \(dbPath)")
        } catch {
            KeyLens.log("KeyCountStore: SQLite init failed: \(error)")
        }
    }

    func startFlushTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 30, repeating: 30)
        timer.setEventHandler { [weak self] in self?.flushLocked() }
        timer.resume()
        flushTimer = timer
    }

    /// Flush pending deltas to SQLite. Must be called on `queue`.
    func flushLocked() {
        guard !pending.isEmpty, let db = dbQueue else { return }
        let p = pending
        pending = PendingStore()

        do {
            try db.write { db in
                for (date, keys) in p.dailyKeys {
                    for (key, delta) in keys where delta > 0 {
                        try db.execute(sql: """
                            INSERT INTO daily_keys (date, key, count) VALUES (?, ?, ?)
                            ON CONFLICT(date, key) DO UPDATE SET count = count + excluded.count
                            """, arguments: [date, key, delta])
                    }
                }
                for (date, bigrams) in p.dailyBigrams {
                    for (bigram, delta) in bigrams where delta > 0 {
                        try db.execute(sql: """
                            INSERT INTO daily_bigrams (date, bigram, count) VALUES (?, ?, ?)
                            ON CONFLICT(date, bigram) DO UPDATE SET count = count + excluded.count
                            """, arguments: [date, bigram, delta])
                    }
                }
                for (date, trigrams) in p.dailyTrigrams {
                    for (trigram, delta) in trigrams where delta > 0 {
                        try db.execute(sql: """
                            INSERT INTO daily_trigrams (date, trigram, count) VALUES (?, ?, ?)
                            ON CONFLICT(date, trigram) DO UPDATE SET count = count + excluded.count
                            """, arguments: [date, trigram, delta])
                    }
                }
                for (date, apps) in p.dailyApps {
                    for (app, delta) in apps where delta > 0 {
                        try db.execute(sql: """
                            INSERT INTO daily_apps (date, app, count) VALUES (?, ?, ?)
                            ON CONFLICT(date, app) DO UPDATE SET count = count + excluded.count
                            """, arguments: [date, app, delta])
                    }
                }
                for (date, devices) in p.dailyDevices {
                    for (device, delta) in devices where delta > 0 {
                        try db.execute(sql: """
                            INSERT INTO daily_devices (date, device, count) VALUES (?, ?, ?)
                            ON CONFLICT(date, device) DO UPDATE SET count = count + excluded.count
                            """, arguments: [date, device, delta])
                    }
                }
                for (date, hours) in p.hourly {
                    for (hour, delta) in hours where delta > 0 {
                        try db.execute(sql: """
                            INSERT INTO hourly_counts (date, hour, count) VALUES (?, ?, ?)
                            ON CONFLICT(date, hour) DO UPDATE SET count = count + excluded.count
                            """, arguments: [date, hour, delta])
                    }
                }
                for (bigram, (sum, count)) in p.bigramIKI where count > 0 {
                    try db.execute(sql: """
                        INSERT INTO bigram_iki (bigram, iki_sum, iki_count) VALUES (?, ?, ?)
                        ON CONFLICT(bigram) DO UPDATE SET
                            iki_sum   = iki_sum   + excluded.iki_sum,
                            iki_count = iki_count + excluded.iki_count
                        """, arguments: [bigram, sum, count])
                }
                for (date, buckets) in p.ikiBuckets {
                    for (bucket, delta) in buckets where delta > 0 {
                        try db.execute(sql: """
                            INSERT INTO iki_buckets (date, bucket, count) VALUES (?, ?, ?)
                            ON CONFLICT(date, bucket) DO UPDATE SET count = count + excluded.count
                            """, arguments: [date, bucket, delta])
                    }
                }
                // Issue #63: flush hourly fatigue slices
                for (date, hours) in p.hourlySlices {
                    for (hour, sl) in hours where sl.ikiCount > 0 || sl.ergTotal > 0 {
                        try db.execute(sql: """
                            INSERT INTO hourly_ergonomics
                                (date, hour, iki_sum, iki_count, erg_total, erg_sf, erg_hs)
                            VALUES (?, ?, ?, ?, ?, ?, ?)
                            ON CONFLICT(date, hour) DO UPDATE SET
                                iki_sum   = iki_sum   + excluded.iki_sum,
                                iki_count = iki_count + excluded.iki_count,
                                erg_total = erg_total + excluded.erg_total,
                                erg_sf    = erg_sf    + excluded.erg_sf,
                                erg_hs    = erg_hs    + excluded.erg_hs
                            """, arguments: [date, hour, sl.ikiSum, sl.ikiCount,
                                             sl.ergTotal, sl.ergSF, sl.ergHS])
                    }
                }
                // Issue #60: flush completed typing sessions
                for s in p.pendingSessions where s.endTime > s.startTime && s.keystrokeCount > 0 {
                    try db.execute(sql: """
                        INSERT INTO sessions (date, start_time, end_time, keystroke_count)
                        VALUES (?, ?, ?, ?)
                        """, arguments: [s.date, s.startTime, s.endTime, s.keystrokeCount])
                }
            }
        } catch {
            pending = mergePending(p, into: pending)
            KeyLens.log("KeyCountStore: SQLite flush error: \(error)")
        }
    }

    /// Synchronous flush — call on app termination to avoid data loss.
    func flushSync() {
        queue.sync { flushLocked() }
    }

    private func mergePending(_ source: PendingStore, into target: PendingStore) -> PendingStore {
        var r = target
        for (d, keys)    in source.dailyKeys     { for (k,v) in keys    { r.dailyKeys[d,    default:[:]][k, default:0] += v } }
        for (d, bigrams) in source.dailyBigrams  { for (b,v) in bigrams { r.dailyBigrams[d, default:[:]][b, default:0] += v } }
        for (d, tris)    in source.dailyTrigrams { for (t,v) in tris    { r.dailyTrigrams[d,default:[:]][t, default:0] += v } }
        for (d, apps)    in source.dailyApps     { for (a,v) in apps    { r.dailyApps[d,    default:[:]][a, default:0] += v } }
        for (d, devs)    in source.dailyDevices  { for (x,v) in devs    { r.dailyDevices[d, default:[:]][x, default:0] += v } }
        for (d, hrs)     in source.hourly        { for (h,v) in hrs     { r.hourly[d,       default:[:]][h, default:0] += v } }
        for (bigram, (sum, cnt)) in source.bigramIKI {
            let e = r.bigramIKI[bigram] ?? (0, 0)
            r.bigramIKI[bigram] = (e.sum + sum, e.count + cnt)
        }
        for (d, bkts) in source.ikiBuckets { for (b,v) in bkts { r.ikiBuckets[d, default:[:]][b, default:0] += v } }
        r.pendingSessions.append(contentsOf: source.pendingSessions)
        for (d, hours) in source.hourlySlices {
            for (h, sl) in hours {
                var e = r.hourlySlices[d, default: [:]][h, default: PendingStore.HourlySlice()]
                e.ikiSum   += sl.ikiSum;   e.ikiCount += sl.ikiCount
                e.ergTotal += sl.ergTotal; e.ergSF    += sl.ergSF; e.ergHS += sl.ergHS
                r.hourlySlices[d, default: [:]][h] = e
            }
        }
        return r
    }
}

// MARK: - SQL helpers (must be called inside queue.sync)

extension KeyCountStore {

    /// Per-key counts for a date: SQLite + pending merged.
    func dailyKeyCountsLocked(for date: String) -> [String: Int] {
        var result: [String: Int] = [:]
        if let db = dbQueue,
           let rows = try? db.read({ db in try Row.fetchAll(db, sql: "SELECT key, count FROM daily_keys WHERE date = ?", arguments: [date]) }) {
            for row in rows { result[row["key"], default: 0] += (row["count"] as Int) }
        }
        for (k, v) in pending.dailyKeys[date, default: [:]] { result[k, default: 0] += v }
        return result
    }

    /// Total keystrokes for a date: SQLite + pending merged.
    func dailyTotalLocked(for date: String) -> Int {
        var total = 0
        if let db = dbQueue {
            total = (try? db.read { db in
                try Int.fetchOne(db, sql: "SELECT COALESCE(SUM(count),0) FROM daily_keys WHERE date = ?", arguments: [date])
            }) ?? 0
        }
        total += pending.dailyKeys[date, default: [:]].values.reduce(0, +)
        return total
    }

    /// All distinct dates that have keystroke data in SQLite.
    func allDatesLocked() -> [String] {
        guard let db = dbQueue else { return [] }
        return (try? db.read { db in
            try String.fetchAll(db, sql: "SELECT DISTINCT date FROM daily_keys ORDER BY date")
        }) ?? []
    }
}

// MARK: - IKI histogram query

extension KeyCountStore {

    /// IKI histogram entries combining all-time SQLite data + unflushed pending.
    func ikiHistogramEntries() -> [IKIHistogramEntry] {
        queue.sync {
            var buckets = [Int](repeating: 0, count: 7)
            if let db = dbQueue,
               let rows = try? db.read({ db in
                   try Row.fetchAll(db, sql: "SELECT bucket, SUM(count) as total FROM iki_buckets GROUP BY bucket")
               }) {
                for row in rows {
                    let b: Int = row["bucket"]
                    if b < 7 { buckets[b] += (row["total"] as Int) }
                }
            }
            for (_, dateBuckets) in pending.ikiBuckets {
                for (b, v) in dateBuckets where b < 7 { buckets[b] += v }
            }
            let total = buckets.reduce(0, +)
            return Self.ikiBucketLabels.enumerated().map { i, label in
                IKIHistogramEntry(
                    bucket: label,
                    count: buckets[i],
                    percentage: total > 0 ? Double(buckets[i]) / Double(total) * 100.0 : 0
                )
            }
        }
    }
}

// MARK: - Issue #60: Session query

extension KeyCountStore {

    /// Returns per-day session summaries (count, total minutes, longest session) from SQLite.
    /// Must NOT be called on `queue` to avoid deadlock.
    func allSessionSummaries() -> [DailySessionSummary] {
        guard let db = dbQueue else { return [] }
        let rows = (try? db.read { db in
            try Row.fetchAll(db, sql: """
                SELECT date,
                       COUNT(*) AS session_count,
                       SUM(end_time - start_time) / 60.0 AS total_minutes,
                       MAX(end_time - start_time) / 60.0 AS longest_minutes
                FROM sessions
                WHERE end_time > start_time AND keystroke_count > 0
                GROUP BY date
                ORDER BY date
                """)
        }) ?? []
        return rows.map { row in
            let date: String = row["date"]
            return DailySessionSummary(
                id: date,
                date: date,
                sessionCount: row["session_count"],
                totalMinutes: row["total_minutes"] ?? 0,
                longestMinutes: row["longest_minutes"] ?? 0
            )
        }
    }
}
