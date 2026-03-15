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

    var isEmpty: Bool {
        dailyKeys.isEmpty && dailyBigrams.isEmpty && dailyTrigrams.isEmpty &&
        dailyApps.isEmpty && dailyDevices.isEmpty && hourly.isEmpty &&
        bigramIKI.isEmpty && ikiBuckets.isEmpty
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
