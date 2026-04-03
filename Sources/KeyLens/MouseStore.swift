import Foundation
import GRDB

/// SQLite-backed store for mouse movement metrics.
/// Accumulates movement in-memory and flushes to disk every 30 seconds.
/// Keyboard data (counts.json) is unaffected by this store.
///
/// マウス移動メトリクスを SQLite に保存するストア。
/// 移動量はメモリ内で蓄積し、30秒ごとにディスクへフラッシュする。
/// キーボードデータ (counts.json) には影響しない。
///
/// Database file: ~/Library/Application Support/KeyLens/mouse.db
final class MouseStore {
    static let shared = MouseStore()

    private var dbQueue: DatabaseQueue?
    private let queue = DispatchQueue(label: "com.keylens.mousestore", qos: .utility)

    // In-memory accumulators — protected by `queue`
    private var pendingDistance: Double = 0
    private var pendingDxPos: Double = 0   // rightward sum
    private var pendingDxNeg: Double = 0   // leftward sum (positive value)
    private var pendingDyPos: Double = 0   // downward sum
    private var pendingDyNeg: Double = 0   // upward sum (positive value)

    // Grid accumulator for heatmap — key: gridX * 100 + gridY → hit count
    private var pendingGrid: [Int: Int] = [:]

    private var flushTimer: DispatchSourceTimer?

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private init() {
        setupDatabase()
        startFlushTimer()
    }

    // MARK: - Setup

    private func setupDatabase() {
        do {
            let dir = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("KeyLens")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dbPath = dir.appendingPathComponent("mouse.db").path

            let db = try DatabaseQueue(path: dbPath)

            var migrator = DatabaseMigrator()
            migrator.registerMigration("v1") { db in
                // Daily aggregates: total distance + directional breakdown
                // 日次集計: 総移動距離 + 方向別内訳
                try db.create(table: "mouse_daily", ifNotExists: true) { t in
                    t.primaryKey("date", .text)
                    t.column("distance_pts", .double).notNull().defaults(to: 0)
                    t.column("dx_pos", .double).notNull().defaults(to: 0)
                    t.column("dx_neg", .double).notNull().defaults(to: 0)
                    t.column("dy_pos", .double).notNull().defaults(to: 0)
                    t.column("dy_neg", .double).notNull().defaults(to: 0)
                }
                // Hourly aggregates: for time-of-day breakdown
                // 時間別集計: 時間帯分析用
                try db.create(table: "mouse_hourly", ifNotExists: true) { t in
                    t.column("date", .text).notNull()
                    t.column("hour", .integer).notNull()
                    t.column("distance_pts", .double).notNull().defaults(to: 0)
                    t.primaryKey(["date", "hour"])
                }
            }
            migrator.registerMigration("v2_heatmap") { db in
                try db.create(table: "mouse_grid", ifNotExists: true) { t in
                    t.column("grid_x", .integer).notNull()
                    t.column("grid_y", .integer).notNull()
                    t.column("hits", .integer).notNull().defaults(to: 0)
                    t.primaryKey(["grid_x", "grid_y"])
                }
            }
            try migrator.migrate(db)

            dbQueue = db
            KeyLens.log("MouseStore: database ready at \(dbPath)")
        } catch {
            KeyLens.log("MouseStore: failed to initialize database: \(error)")
        }
    }

    // MARK: - Accumulation

    /// Accumulate a single mouse movement event.
    /// Hot path: addition only, zero disk I/O.
    ///
    /// マウス移動イベントを蓄積する（ホットパス: 加算のみ、ディスクI/Oなし）。
    func addMovement(dx: Double, dy: Double) {
        queue.async { [self] in
            let dist = (dx * dx + dy * dy).squareRoot()
            pendingDistance += dist
            if dx > 0 { pendingDxPos += dx  } else { pendingDxNeg += -dx }
            if dy > 0 { pendingDyPos += dy  } else { pendingDyNeg += -dy }
        }
    }

    /// Accumulate a cursor position sample for the heatmap grid.
    /// Hot path: normalises to 0–99 grid, no disk I/O.
    func addPosition(x: CGFloat, y: CGFloat, screenSize: CGSize) {
        guard screenSize.width > 0, screenSize.height > 0 else { return }
        let gx = min(99, max(0, Int(x / screenSize.width  * 100)))
        let gy = min(99, max(0, Int(y / screenSize.height * 100)))
        let key = gx * 100 + gy
        queue.async { [self] in
            pendingGrid[key, default: 0] += 1
        }
    }

    // MARK: - Flush

    private func startFlushTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + AppConfiguration.flushIntervalSecs, repeating: AppConfiguration.flushIntervalSecs)
        timer.setEventHandler { [weak self] in self?.flushLocked() }
        timer.resume()
        flushTimer = timer
    }

    /// Flush pending data to SQLite. Must be called on `queue`.
    /// 保留中のデータを SQLite へフラッシュする。`queue` 上で呼ぶこと。
    private func flushLocked() {
        guard let db = dbQueue else { return }

        let dist  = pendingDistance
        let dxPos = pendingDxPos
        let dxNeg = pendingDxNeg
        let dyPos = pendingDyPos
        let dyNeg = pendingDyNeg
        let grid  = pendingGrid
        pendingDistance = 0; pendingDxPos = 0; pendingDxNeg = 0
        pendingDyPos    = 0; pendingDyNeg = 0; pendingGrid = [:]

        let dateStr = Self.dayFormatter.string(from: Date())
        let hour    = Calendar.current.component(.hour, from: Date())

        do {
            try db.write { db in
                if dist > 0 {
                    try db.execute(sql: """
                        INSERT INTO mouse_daily (date, distance_pts, dx_pos, dx_neg, dy_pos, dy_neg)
                        VALUES (?, ?, ?, ?, ?, ?)
                        ON CONFLICT(date) DO UPDATE SET
                            distance_pts = distance_pts + excluded.distance_pts,
                            dx_pos       = dx_pos       + excluded.dx_pos,
                            dx_neg       = dx_neg       + excluded.dx_neg,
                            dy_pos       = dy_pos       + excluded.dy_pos,
                            dy_neg       = dy_neg       + excluded.dy_neg
                        """, arguments: [dateStr, dist, dxPos, dxNeg, dyPos, dyNeg])

                    try db.execute(sql: """
                        INSERT INTO mouse_hourly (date, hour, distance_pts)
                        VALUES (?, ?, ?)
                        ON CONFLICT(date, hour) DO UPDATE SET
                            distance_pts = distance_pts + excluded.distance_pts
                        """, arguments: [dateStr, hour, dist])
                }

                for (key, hits) in grid {
                    let gx = key / 100
                    let gy = key % 100
                    try db.execute(sql: """
                        INSERT INTO mouse_grid (grid_x, grid_y, hits)
                        VALUES (?, ?, ?)
                        ON CONFLICT(grid_x, grid_y) DO UPDATE SET
                            hits = hits + excluded.hits
                        """, arguments: [gx, gy, hits])
                }
            }
        } catch {
            KeyLens.log("MouseStore: flush error: \(error)")
        }
    }

    /// Synchronous flush — call on app termination to avoid data loss.
    func flushSync() {
        queue.sync { flushLocked() }
    }

    // MARK: - Queries

    /// Total mouse travel distance for today in points (screen coordinates).
    /// Returns nil if no data has been recorded yet.
    /// Includes in-memory pending distance not yet flushed to disk.
    func distanceToday() -> Double? {
        queue.sync {
            let dateStr = Self.dayFormatter.string(from: Date())
            var stored: Double = 0
            if let db = dbQueue {
                stored = (try? db.read { db in
                    try Double.fetchOne(db, sql: "SELECT distance_pts FROM mouse_daily WHERE date = ?",
                                        arguments: [dateStr])
                }) ?? 0
            }
            let total = stored + pendingDistance
            return total > 0 ? total : nil
        }
    }

    /// Daily mouse travel for the last N days, oldest first.
    func dailyDistances(days: Int = 30) -> [(date: String, distancePts: Double)] {
        queue.sync {
            guard let db = dbQueue else { return [] }
            let rows = (try? db.read { db in
                try Row.fetchAll(db, sql: """
                    SELECT date, distance_pts FROM mouse_daily
                    ORDER BY date DESC LIMIT ?
                    """, arguments: [days])
            }) ?? []
            return rows.map { (date: $0["date"] as String? ?? "", distancePts: $0["distance_pts"] as Double? ?? 0) }
                       .reversed()
        }
    }

    /// Mouse movement summed by hour of day (0–23) across all recorded days.
    func hourlyDistributionMouse() -> [(hour: Int, distancePts: Double)] {
        queue.sync {
            guard let db = dbQueue else { return [] }
            let rows = (try? db.read { db in
                try Row.fetchAll(db, sql: """
                    SELECT hour, SUM(distance_pts) AS total
                    FROM mouse_hourly
                    GROUP BY hour
                    ORDER BY hour
                    """)
            }) ?? []
            return rows.map { (hour: $0["hour"] as Int? ?? 0, distancePts: $0["total"] as Double? ?? 0) }
        }
    }

    /// Per-day directional breakdown for the last N days, most recent first.
    func dailyDirectionBreakdown(days: Int = 30) -> [(date: String, dxPos: Double, dxNeg: Double, dyPos: Double, dyNeg: Double)] {
        queue.sync {
            guard let db = dbQueue else { return [] }
            let rows = (try? db.read { db in
                try Row.fetchAll(db, sql: """
                    SELECT date, dx_pos, dx_neg, dy_pos, dy_neg
                    FROM mouse_daily
                    ORDER BY date DESC LIMIT ?
                    """, arguments: [days])
            }) ?? []
            return rows.map { (
                date:  $0["date"]   as String? ?? "",
                dxPos: $0["dx_pos"] as Double? ?? 0,
                dxNeg: $0["dx_neg"] as Double? ?? 0,
                dyPos: $0["dy_pos"] as Double? ?? 0,
                dyNeg: $0["dy_neg"] as Double? ?? 0
            )}
        }
    }

    /// All grid cells with at least one hit, for the heatmap.
    func heatmapGrid() -> [(gridX: Int, gridY: Int, hits: Int)] {
        queue.sync {
            guard let db = dbQueue else { return [] }
            let rows = (try? db.read { db in
                try Row.fetchAll(db, sql: "SELECT grid_x, grid_y, hits FROM mouse_grid")
            }) ?? []
            return rows.map { (gridX: $0["grid_x"] as Int? ?? 0,
                               gridY: $0["grid_y"] as Int? ?? 0,
                               hits:  $0["hits"]   as Int? ?? 0) }
        }
    }

    /// All-time directional movement totals: right, left, down, up (all non-negative).
    func directionBreakdown() -> (right: Double, left: Double, down: Double, up: Double) {
        queue.sync {
            guard let db = dbQueue else { return (0, 0, 0, 0) }
            let row = try? db.read { db in
                try Row.fetchOne(db, sql: """
                    SELECT SUM(dx_pos) AS r, SUM(dx_neg) AS l,
                           SUM(dy_pos) AS d, SUM(dy_neg) AS u
                    FROM mouse_daily
                    """)
            }
            guard let r = row else { return (0, 0, 0, 0) }
            return (
                right: r["r"] as Double? ?? 0,
                left:  r["l"] as Double? ?? 0,
                down:  r["d"] as Double? ?? 0,
                up:    r["u"] as Double? ?? 0
            )
        }
    }
}
