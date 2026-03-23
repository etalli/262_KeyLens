import Foundation
import GRDB

// MARK: - One-time migration: counts.json → keylens.db
// Reads legacy fields from counts.json and bulk-inserts them into SQLite.
// Runs once on first launch after update; guarded by a UserDefaults flag.

extension KeyCountStore {

    private static let migrationFlagKey = "com.keylens.sqliteMigrationV1"

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.migrationFlagKey) else { return }
        guard let db = dbQueue else {
            KeyLens.log("KeyCountStore: migration skipped — no database")
            return
        }

        guard let jsonData = try? Data(contentsOf: saveURL) else {
            // No counts.json → fresh install, nothing to migrate
            UserDefaults.standard.set(true, forKey: Self.migrationFlagKey)
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let legacy = try? decoder.decode(LegacyCounts.self, from: jsonData) else {
            KeyLens.log("KeyCountStore: migration failed — could not decode counts.json")
            UserDefaults.standard.set(true, forKey: Self.migrationFlagKey)
            return
        }

        var totalRows = 0

        do {
            try db.write { db in
                // daily_keys
                for (date, keyCounts) in legacy.dailyCounts {
                    for (key, count) in keyCounts where count > 0 {
                        try db.execute(sql: """
                            INSERT INTO daily_keys (date, key, count) VALUES (?, ?, ?)
                            ON CONFLICT(date, key) DO UPDATE SET count = count + excluded.count
                            """, arguments: [date, key, count])
                        totalRows += 1
                    }
                }
                // daily_bigrams
                for (date, bigramCounts) in legacy.dailyBigramCounts {
                    for (bigram, count) in bigramCounts where count > 0 {
                        try db.execute(sql: """
                            INSERT INTO daily_bigrams (date, bigram, count) VALUES (?, ?, ?)
                            ON CONFLICT(date, bigram) DO UPDATE SET count = count + excluded.count
                            """, arguments: [date, bigram, count])
                        totalRows += 1
                    }
                }
                // daily_trigrams
                for (date, trigramCounts) in legacy.dailyTrigramCounts {
                    for (trigram, count) in trigramCounts where count > 0 {
                        try db.execute(sql: """
                            INSERT INTO daily_trigrams (date, trigram, count) VALUES (?, ?, ?)
                            ON CONFLICT(date, trigram) DO UPDATE SET count = count + excluded.count
                            """, arguments: [date, trigram, count])
                        totalRows += 1
                    }
                }
                // daily_apps
                for (date, appCounts) in legacy.dailyAppCounts {
                    for (app, count) in appCounts where count > 0 {
                        try db.execute(sql: """
                            INSERT INTO daily_apps (date, app, count) VALUES (?, ?, ?)
                            ON CONFLICT(date, app) DO UPDATE SET count = count + excluded.count
                            """, arguments: [date, app, count])
                        totalRows += 1
                    }
                }
                // daily_devices
                for (date, deviceCounts) in legacy.dailyDeviceCounts {
                    for (device, count) in deviceCounts where count > 0 {
                        try db.execute(sql: """
                            INSERT INTO daily_devices (date, device, count) VALUES (?, ?, ?)
                            ON CONFLICT(date, device) DO UPDATE SET count = count + excluded.count
                            """, arguments: [date, device, count])
                        totalRows += 1
                    }
                }
                // hourly_counts — legacy key format: "yyyy-MM-dd-HH"
                for (hourKey, count) in legacy.hourlyCounts where count > 0 {
                    let parts = hourKey.split(separator: "-")
                    guard parts.count == 4, let hour = Int(parts[3]) else { continue }
                    let date = "\(parts[0])-\(parts[1])-\(parts[2])"
                    try db.execute(sql: """
                        INSERT INTO hourly_counts (date, hour, count) VALUES (?, ?, ?)
                        ON CONFLICT(date, hour) DO UPDATE SET count = count + excluded.count
                        """, arguments: [date, hour, count])
                    totalRows += 1
                }
                // bigram_iki
                for (bigram, sum) in legacy.bigramIKISum {
                    let count = legacy.bigramIKICount[bigram] ?? 0
                    guard sum > 0, count > 0 else { continue }
                    try db.execute(sql: """
                        INSERT INTO bigram_iki (bigram, iki_sum, iki_count) VALUES (?, ?, ?)
                        ON CONFLICT(bigram) DO UPDATE SET
                            iki_sum   = iki_sum   + excluded.iki_sum,
                            iki_count = iki_count + excluded.iki_count
                        """, arguments: [bigram, sum, count])
                    totalRows += 1
                }
            }

            UserDefaults.standard.set(true, forKey: Self.migrationFlagKey)
            KeyLens.log("KeyCountStore: migration complete — \(totalRows) rows imported to keylens.db")

        } catch {
            // Do not set the flag — will retry on next launch
            KeyLens.log("KeyCountStore: migration error: \(error)")
        }
    }

    // MARK: - One-time migration: counts.json scalars → keylens.db scalars table

    private static let scalarsV1Key = "com.keylens.scalarsV1"

    func migrateScalarsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.scalarsV1Key) else { return }
        guard let db = dbQueue else {
            UserDefaults.standard.set(true, forKey: Self.scalarsV1Key)
            return
        }

        guard let jsonData = try? Data(contentsOf: saveURL) else {
            // No counts.json → fresh install, nothing to migrate
            UserDefaults.standard.set(true, forKey: Self.scalarsV1Key)
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let legacy = try? decoder.decode(CountData.self, from: jsonData) else {
            KeyLens.log("KeyCountStore: scalars migration failed — could not decode counts.json")
            UserDefaults.standard.set(true, forKey: Self.scalarsV1Key)
            return
        }

        do {
            try db.write { db in
                for (key, value) in legacy.toScalars() {
                    try db.execute(
                        sql: "INSERT OR REPLACE INTO scalars (key, value) VALUES (?, ?)",
                        arguments: [key, value])
                }
            }
            UserDefaults.standard.set(true, forKey: Self.scalarsV1Key)
            KeyLens.log("KeyCountStore: scalars migration complete")
        } catch {
            // Do not set the flag — will retry on next launch
            KeyLens.log("KeyCountStore: scalars migration error: \(error)")
        }
    }
}

// MARK: - Legacy JSON model (only used during migration)

private struct LegacyCounts: Decodable {
    var dailyCounts:      [String: [String: Int]] = [:]
    var dailyBigramCounts: [String: [String: Int]] = [:]
    var dailyTrigramCounts:[String: [String: Int]] = [:]
    var dailyAppCounts:   [String: [String: Int]] = [:]
    var dailyDeviceCounts:[String: [String: Int]] = [:]
    var hourlyCounts:     [String: Int]           = [:]
    var bigramIKISum:     [String: Double]        = [:]
    var bigramIKICount:   [String: Int]           = [:]

    enum CodingKeys: String, CodingKey {
        case dailyCounts, dailyBigramCounts, dailyTrigramCounts
        case dailyAppCounts, dailyDeviceCounts
        case hourlyCounts, bigramIKISum, bigramIKICount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dailyCounts       = (try? c.decode([String: [String: Int]].self, forKey: .dailyCounts))       ?? [:]
        dailyBigramCounts  = (try? c.decode([String: [String: Int]].self, forKey: .dailyBigramCounts))  ?? [:]
        dailyTrigramCounts = (try? c.decode([String: [String: Int]].self, forKey: .dailyTrigramCounts)) ?? [:]
        dailyAppCounts     = (try? c.decode([String: [String: Int]].self, forKey: .dailyAppCounts))     ?? [:]
        dailyDeviceCounts  = (try? c.decode([String: [String: Int]].self, forKey: .dailyDeviceCounts))  ?? [:]
        hourlyCounts   = (try? c.decode([String: Int].self,    forKey: .hourlyCounts))   ?? [:]
        bigramIKISum   = (try? c.decode([String: Double].self, forKey: .bigramIKISum))   ?? [:]
        bigramIKICount = (try? c.decode([String: Int].self,    forKey: .bigramIKICount)) ?? [:]
    }
}
