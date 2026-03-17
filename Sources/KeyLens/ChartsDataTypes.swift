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

/// Layout efficiency comparison entry (Issue #61).
/// One row per keyboard layout: shows same-finger bigram rate and hand-alternation rate
/// computed from the user's actual bigram frequency distribution.
/// レイアウト効率比較の1行：ユーザーの実打鍵ビグラムに基づく同指率・交互打鍵率。
struct LayoutEfficiencyEntry: Identifiable {
    let id: String          // layout name e.g. "QWERTY"
    let name: String
    let sameFingerRate: Double      // lower is better
    let handAlternationRate: Double // higher is better
    let totalBigrams: Int
    init(name: String, sameFingerRate: Double, handAlternationRate: Double, totalBigrams: Int) {
        id = name
        self.name = name
        self.sameFingerRate = sameFingerRate
        self.handAlternationRate = handAlternationRate
        self.totalBigrams = totalBigrams
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
