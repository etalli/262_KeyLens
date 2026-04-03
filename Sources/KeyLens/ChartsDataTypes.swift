import SwiftUI
import KeyLensCore

// MARK: - Chart data types

struct TopKeyEntry: Identifiable {
    let id: String
    let key: String
    let count: Int
    init(_ t: (key: String, count: Int)) { id = t.key; key = t.key; count = t.count }
}

struct DailyTotalEntry: Identifiable {
    let id: String
    let date: String
    let total: Int
    init(_ t: (date: String, total: Int)) { id = t.date; date = t.date; total = t.total }
}

struct CategoryEntry: Identifiable {
    var id: String { type.rawValue }
    let type: KeyType
    let count: Int
    init(_ t: (type: KeyType, count: Int)) { type = t.type; count = t.count }
}

struct DailyKeyEntry: Identifiable {
    let id = UUID()
    let date: String
    let key: String
    let count: Int
    init(_ t: (date: String, key: String, count: Int)) { date = t.date; key = t.key; count = t.count }
}

struct ShortcutEntry: Identifiable {
    let id: String
    let key: String
    let count: Int
    init(_ t: (key: String, count: Int)) { id = t.key; key = t.key; count = t.count }
}

struct BigramEntry: Identifiable {
    let id: String
    let pair: String
    let count: Int
    init(_ t: (pair: String, count: Int)) { id = t.pair; pair = t.pair; count = t.count }
}

struct AppEntry: Identifiable {
    let id: String
    let app: String
    let count: Int
    init(_ t: (app: String, count: Int)) { id = t.app; app = t.app; count = t.count }
}

struct AppErgScoreEntry: Identifiable {
    let id: String
    let app: String
    let score: Double
    let keystrokes: Int
    init(_ t: (app: String, score: Double, keystrokes: Int)) {
        id = t.app; app = t.app; score = t.score; keystrokes = t.keystrokes
    }
}

struct DeviceEntry: Identifiable {
    let id: String
    let device: String
    let count: Int
    init(_ t: (device: String, count: Int)) { id = t.device; device = t.device; count = t.count }
}

struct DeviceErgScoreEntry: Identifiable {
    let id: String
    let device: String
    let score: Double
    let keystrokes: Int
    init(_ t: (device: String, score: Double, keystrokes: Int)) {
        id = t.device; device = t.device; score = t.score; keystrokes = t.keystrokes
    }
}

// Issue #5: Hourly distribution entry (for Chart)
// 時間帯別打鍵数チャート用エントリ
struct HourEntry: Identifiable {
    let id: Int
    let hour: Int
    let count: Int
    var hourLabel: String { String(format: "%02d:00", hour) }
    var isWorkHour: Bool { hour >= 9 && hour < 18 }
    init(hour: Int, count: Int) { id = hour; self.hour = hour; self.count = count }
}

// Issue #5: Monthly total entry
// 月別打鍵数合計エントリ
struct MonthlyTotalEntry: Identifiable {
    let id: String
    let month: String
    let total: Int
    init(_ t: (month: String, total: Int)) { id = t.month; month = t.month; total = t.total }
}

// MARK: - Issue #65: Daily Backspace Rate entry (for Accuracy chart)
// 日別 BS 率エントリ（タイピング精度チャート用）
struct DailyAccuracyEntry: Identifiable {
    let id: String
    let date: String
    let rate: Double  // backspace rate (%), lower is better / 低いほど精度が高い
    init(_ t: (date: String, rate: Double)) { id = t.date; date = t.date; rate = t.rate }
}

// MARK: - Issue #59 Phase 2: Daily WPM entry (for Typing Speed chart)
// 日別推定 WPM エントリ（タイピング速度チャート用）
struct DailyWPMEntry: Identifiable {
    let id: String
    let date: String
    let wpm: Double
    init(_ t: (date: String, wpm: Double)) { id = t.date; date = t.date; wpm = t.wpm }
}

// MARK: - Phase 3 data types

/// One data point in the Learning Curve chart: a rate value for a given date and metric series.
/// 学習曲線チャートの1点：指定日・指標系列の比率値。
struct DailyErgonomicEntry: Identifiable {
    let id = UUID()
    let date: String
    let series: String   // "Same-finger" | "Alternation" | "High-strain"
    let rate: Double
}

/// One entry in the live IKI bar chart: a recent keystroke with its inter-keystroke interval.
/// リアルタイムIKIバーチャートの1エントリ：直近打鍵のキー間隔（ms）。
struct RecentIKIEntry: Identifiable {
    let id: Int       // position index (0 = oldest)
    let key: String
    let iki: Double   // inter-keystroke interval in ms; 0 = anchor (first key, no prior interval)
    /// True for the first keystroke in a session burst (no IKI measured).
    var isAnchor: Bool { iki == 0 }
    /// Color tier: fast <150ms, slow >400ms, medium otherwise.
    var isFast: Bool { !isAnchor && iki < 150 }
    var isSlow: Bool { iki > 400 }
    /// Chart display value: anchors use a small stub; slow values are capped at 300 (the Y-axis max).
    var chartIKI: Double { isAnchor ? 20 : min(iki, 300) }
}

/// One row in the Weekly Delta table: a metric compared across two consecutive 7-day windows.
/// 週次デルタ表の1行：連続する2つの7日間ウィンドウで比較した指標。
struct WeeklyDeltaRow: Identifiable {
    let id = UUID()
    let metric: String
    let thisWeek: Double
    let lastWeek: Double
    let lowerIsBetter: Bool
    var delta: Double { thisWeek - lastWeek }
}

/// One bucket in the IKI histogram (Issue #102).
/// IKIヒストグラムの1バケット。
struct IKIHistogramEntry: Identifiable {
    let id = UUID()
    let bucket: String      // label e.g. "0–50", "50–100", …, "300+"
    let count: Int          // total keystrokes whose IKI fell in this bucket
    let percentage: Double  // count / total * 100
}

struct FingerIKIEntry: Identifiable {
    let id: String          // finger raw value e.g. "index"
    let finger: String      // display label e.g. "Index"
    let avgIKI: Double      // average inter-key interval in ms
    init(_ t: (finger: String, avgIKI: Double)) {
        id     = t.finger
        finger = t.finger.prefix(1).uppercased() + t.finger.dropFirst()
        avgIKI = t.avgIKI
    }
}

struct SlowBigramEntry: Identifiable {
    let id: String          // bigram key e.g. "t→h"
    let bigram: String
    let avgIKI: Double      // average inter-key interval in ms
    init(_ t: (bigram: String, avgIKI: Double)) { id = t.bigram; bigram = t.bigram; avgIKI = t.avgIKI }
}

/// Layout efficiency comparison entry (Issues #61, #72).
/// One row per keyboard layout: shows SFB rate, hand-alternation rate, ergonomic score,
/// and estimated finger travel distance computed from the user's actual typing data.
/// レイアウト効率比較の1行：ユーザーの実打鍵データに基づく同指率・交互打鍵率・エルゴスコア・移動距離。
struct LayoutEfficiencyEntry: Identifiable {
    let id: String          // layout name e.g. "QWERTY"
    let name: String
    let sameFingerRate: Double      // lower is better
    let handAlternationRate: Double // higher is better
    let ergonomicScore: Double      // higher is better [0, 100]
    let travelDistance: Double      // lower is better (grid units)
    let totalBigrams: Int
    let isUserLayout: Bool          // true for the "Your Layout" baseline entry
    init(name: String, sameFingerRate: Double, handAlternationRate: Double,
         ergonomicScore: Double, travelDistance: Double, totalBigrams: Int,
         isUserLayout: Bool = false) {
        id = name
        self.name = name
        self.sameFingerRate = sameFingerRate
        self.handAlternationRate = handAlternationRate
        self.ergonomicScore = ergonomicScore
        self.travelDistance = travelDistance
        self.totalBigrams = totalBigrams
        self.isUserLayout = isUserLayout
    }
}

/// One row in the Key Transition analysis chart (Issue #98).
/// キー遷移分析チャートの1行。
struct KeyTransitionEntry: Identifiable {
    let id: String          // bigram key e.g. "d→f"
    let bigram: String      // display label
    let avgIKI: Double      // average inter-key interval in ms
    let count: Int          // number of samples
    init(_ t: (bigram: String, avgIKI: Double, count: Int)) {
        id = t.bigram; bigram = t.bigram; avgIKI = t.avgIKI; count = t.count
    }
}

// MARK: - Issue #60: Session detection data types

/// Per-day summary of detected typing sessions.
/// 日別タイピングセッションの集計。
struct DailySessionSummary: Identifiable {
    let id: String            // date key (yyyy-MM-dd)
    let date: String
    let sessionCount: Int
    let totalMinutes: Double
    let longestMinutes: Double
    var avgMinutes: Double { sessionCount > 0 ? totalMinutes / Double(sessionCount) : 0 }
}

// MARK: - Issue #168: Mouse tab data types

struct MouseDailyEntry: Identifiable {
    let id: String
    let date: String
    let distancePts: Double
    init(_ t: (date: String, distancePts: Double)) { id = t.date; date = t.date; distancePts = t.distancePts }
}

struct MouseHourEntry: Identifiable {
    let id: Int
    let hour: Int
    let distancePts: Double
    var hourLabel: String { String(format: "%02d:00", hour) }
    init(hour: Int, distancePts: Double) { id = hour; self.hour = hour; self.distancePts = distancePts }
}

struct MouseDirectionEntry: Identifiable {
    let id: String
    let direction: String
    let distancePts: Double
}

struct MouseDailyDirectionEntry: Identifiable {
    let id: String       // date string
    let date: String
    let right: Double    // dx_pos
    let left: Double     // dx_neg
    let down: Double     // dy_pos
    let up: Double       // dy_neg
}

struct MouseKeyboardBalanceEntry: Identifiable {
    let id: String       // date string
    let date: String
    let distancePts: Double
    let keystrokes: Int
}

// MARK: - Issue #292: Session Rhythm Heatmap

/// One cell in the 7×24 session rhythm heatmap: session count and average duration for a (weekday, hour) pair.
/// セッションリズムヒートマップの1セル：曜日×時刻ごとのセッション数・平均時間。
struct SessionHeatmapCell: Identifiable {
    let id: Int                    // weekday * 24 + hour
    let weekday: Int               // 0 = Sunday … 6 = Saturday
    let hour: Int                  // 0–23
    let avgCount: Double           // average session count across all matching weekday+hour slots
    let avgDurationMinutes: Double // average session duration in minutes
}

// MARK: - Issue #78: Weekly Activity Heatmap

/// One cell in the 7×24 weekly heatmap: average keystrokes and optional WPM for a (weekday, hour) pair.
/// 週間ヒートマップの1セル：曜日×時刻ごとの平均打鍵数・平均WPM。
struct HeatmapCell: Identifiable {
    let id: Int           // weekday * 24 + hour
    let weekday: Int      // 0 = Sunday … 6 = Saturday
    let hour: Int         // 0–23
    let avgCount: Double  // average keystrokes across all matching dates
    let avgWPM: Double?   // average WPM for this cell, nil if no IKI data
    init(_ t: (weekday: Int, hour: Int, avgCount: Double, avgWPM: Double?)) {
        id       = t.weekday * 24 + t.hour
        weekday  = t.weekday
        hour     = t.hour
        avgCount = t.avgCount
        avgWPM   = t.avgWPM
    }
}

// MARK: - Issue #63: Hourly fatigue entry

/// One data point in the Fatigue Curve chart: per-hour WPM and ergonomic rates for today.
struct HourlyFatigueEntry: Identifiable {
    let id: Int          // hour 0–23
    let hour: Int
    let wpm: Double?             // estimated WPM (nil if no IKI samples this hour)
    let sameFingerRate: Double?  // same-finger bigram rate (nil if no bigrams this hour)
    let highStrainRate: Double?  // high-strain bigram rate (nil if no bigrams this hour)

    var hourLabel: String { String(format: "%02d:00", hour) }
}
