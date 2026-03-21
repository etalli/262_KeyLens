import AppKit
import Foundation
import KeyLensCore

// MARK: - Language

enum Language: String, CaseIterable {
    case system   = "system"
    case english  = "en"
    case japanese = "ja"

    var displayName: String {
        switch self {
        case .system:   return "Auto"
        case .english:  return "English"
        case .japanese: return "日本語"
        }
    }
}

// MARK: - L10n

/// アプリ内のローカライズ文字列を一元管理するシングルトン
/// 言語設定は UserDefaults に永続化し、再起動後も保持される
final class L10n {
    static let shared = L10n()
    private let defaultsKey = "appLanguage"

    private init() {}

    /// 現在の言語設定（system / en / ja）
    var language: Language {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? Language.system.rawValue
            return Language(rawValue: raw) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    /// 実際に使用する言語（system の場合は Locale から解決）
    var resolved: Language {
        guard language == .system else { return language }
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return code == "ja" ? .japanese : .english
    }

    // MARK: - Strings

    var totalFormat: String {
        ja("合計: %@ 入力", en: "Total: %@ inputs")
    }

    var todayFormat: String {
        ja("本日: %@ 入力", en: "Today: %@ inputs")
    }

    var noInput: String {
        ja("（まだ入力なし）", en: "(no input yet)")
    }

    var monitoringActive: String {
        ja("● 記録中", en: "● Recording")
    }

    var monitoringStopped: String {
        ja("● 停止中 — クリックして設定を開く", en: "● Stopped — click to open Settings")
    }

    var restartTitle: String {
        ja("再起動が必要です", en: "Restart Required")
    }

    var restartMessage: String {
        ja(
            "アクセシビリティ権限は付与されましたが、有効にするには KeyLens の再起動が必要です。",
            en: "Accessibility permission was granted, but KeyLens must restart to activate monitoring."
        )
    }

    var restartNow: String {
        ja("今すぐ再起動", en: "Restart Now")
    }

    var openSaveFolder: String {
        ja("保存先を開く", en: "Open Log Folder")
    }

    var launchAtLogin: String {
        ja("ログイン時に起動", en: "Launch at Login")
    }

    var resetMenuItem: String {
        ja("リセット…", en: "Reset…")
    }

    var resetAlertTitle: String {
        ja("カウントをリセットしますか？", en: "Reset all counts?")
    }

    var resetAlertMessage: String {
        ja(
            "すべてのキーカウントと記録開始日が本日にリセットされます。この操作は取り消せません。",
            en: "All key counts and the start date will be reset to today. This cannot be undone."
        )
    }

    var resetConfirmButton: String {
        ja("リセット", en: "Reset")
    }

    var cancel: String {
        ja("キャンセル", en: "Cancel")
    }

    var quit: String {
        ja("終了", en: "Quit")
    }

    var dataMenuTitle: String {
        ja("データ…", en: "Data…")
    }

    var settingsMenuTitle: String {
        ja("設定…", en: "Settings…")
    }

    var aboutMenuItem: String {
        ja("KeyLens について", en: "About KeyLens")
    }

    var checkForUpdatesMenuItem: String {
        ja("アップデートを確認…", en: "Check for Updates…")
    }

    var updateAvailableTitle: String {
        ja("アップデートがあります", en: "Update Available")
    }

    func updateAvailableMessage(current: String, latest: String) -> String {
        ja("現在のバージョン: \(current)\n最新バージョン: \(latest)\n\nGitHub Releases からダウンロードできます。",
           en: "Current version: \(current)\nLatest version: \(latest)\n\nDownload the latest release from GitHub.")
    }

    var updateUpToDateTitle: String {
        ja("最新バージョンです", en: "Up to Date")
    }

    func updateUpToDateMessage(version: String) -> String {
        ja("KeyLens \(version) は最新バージョンです。", en: "KeyLens \(version) is the latest version.")
    }

    var updateCheckFailedTitle: String {
        ja("確認できませんでした", en: "Check Failed")
    }

    var updateCheckFailedMessage: String {
        ja("アップデートの確認中にエラーが発生しました。ネットワーク接続を確認してください。",
           en: "Could not check for updates. Please check your network connection.")
    }

    var downloadButton: String {
        ja("ダウンロード", en: "Download")
    }

    var close: String {
        ja("閉じる", en: "Close")
    }

    var heatmapLow: String {
        ja("少", en: "Low")
    }

    var heatmapHigh: String {
        ja("多", en: "High")
    }

    var heatmapMouse: String {
        ja("マウス", en: "Mouse")
    }

    var languageMenuTitle: String {
        ja("言語", en: "Language")
    }

    var accessibilityTitle: String {
        ja("アクセシビリティ権限が必要です", en: "Accessibility Permission Required")
    }

    var accessibilityMessage: String {
        ja(
            "キー入力を監視するには、アクセシビリティ権限が必要です。\n「システム設定 → プライバシーとセキュリティ → アクセシビリティ」で\nKeyLens を許可してください。",
            en: "KeyLens needs Accessibility permission to monitor keystrokes.\nGo to System Settings > Privacy & Security > Accessibility\nand enable KeyLens."
        )
    }

    var openSystemSettings: String {
        ja("システム設定を開く", en: "Open System Settings")
    }

    var later: String {
        ja("あとで", en: "Later")
    }

    var showAllMenuItem: String {
        ja("全件表示…", en: "Show All…")
    }

    var chartsMenuItem: String {
        ja("グラフ表示…", en: "Show Charts…")
    }

    var last7Days: String {
        ja("直近7日間", en: "Last 7 Days")
    }

    var overlayMenuItem: String {
        ja("キーオーバーレイ", en: "Keystroke Overlay")
    }

    var overlaySettingsMenuItem: String {
        ja("オーバーレイ設定…", en: "Overlay Settings…")
    }

    var overlaySettingsWindowTitle: String {
        ja("キーオーバーレイ設定", en: "Keystroke Overlay Settings")
    }

    var overlaySettingsPosition: String {
        ja("表示位置", en: "Position")
    }

    var overlayPositionTopLeft: String {
        ja("左上", en: "Top Left")
    }

    var overlayPositionTopRight: String {
        ja("右上", en: "Top Right")
    }

    var overlayPositionBottomLeft: String {
        ja("左下", en: "Bottom Left")
    }

    var overlayPositionBottomRight: String {
        ja("右下", en: "Bottom Right")
    }

    var overlaySettingsFadeDelay: String {
        ja("フェード持続時間", en: "Fade Delay")
    }

    func overlayFadeDelayLabel(_ sec: Double) -> String {
        let s = Int(sec)
        return ja("\(s)秒", en: "\(s)s")
    }

    var overlaySettingsOpacity: String {
        ja("背景の不透明度", en: "Background Opacity")
    }

    var overlaySettingsFontColor: String {
        ja("文字の色", en: "Font Color")
    }

    var overlaySettingsBackgroundColor: String {
        ja("背景の色", en: "Background Color")
    }

    var overlaySettingsCornerRadius: String {
        ja("角の丸み", en: "Corner Radius")
    }

    var overlaySettingsFontSize: String {
        ja("フォントサイズ", en: "Font Size")
    }

    var overlaySizeSmall: String {
        ja("小", en: "Small")
    }

    var overlaySizeMedium: String {
        ja("中", en: "Medium")
    }

    var overlaySizeLarge: String {
        ja("大", en: "Large")
    }

    var overlaySizeExtraLarge: String {
        ja("特大", en: "Extra Large")
    }

    var overlaySettingsPreview: String {
        ja("プレビュー", en: "Preview")
    }

    var overlaySettingsShowKeyCode: String {
        ja("キーコードを表示", en: "Show Key Code")
    }

    var overlaySettingsShortcut: String {
        ja("ショートカット", en: "Shortcut")
    }

    var overlaySettingsChangeShortcut: String {
        ja("ショートカットを変更", en: "Change Shortcut")
    }

    var overlaySettingsRecording: String {
        ja("キーを押してください…", en: "Press a key…")
    }

    var avgIntervalFormat: String {
        ja("平均間隔: %.0f ms", en: "Avg interval: %.0f ms")
    }

    var minIntervalFormat: String {
        ja("最小間隔: %.0f ms", en: "Min interval: %.0f ms")
    }

    var estimatedWPMFormat: String {
        ja("速度: %.0f WPM", en: "Speed: %.0f WPM")
    }

    var backspaceRateFormat: String {
        ja("Delete使用率: %.1f%%", en: "Delete: %.1f%%")
    }

    var chartTitleBackspaceRate: String {
        ja("Delete キー使用率（%）", en: "Delete Key Usage (%)")
    }

    var helpBackspaceRate: String {
        ja(
            "日別の Delete（⌫）キー使用率を表示します。全打鍵数に対する割合（%）です。\n\n注: Mac の「Delete」キーは Windows の「Backspace」と同じキーです。文字削除だけでなく、文章編集のための使用も含まれます。\n\n過去データも利用可能（counts.json の dailyCounts から直接算出）。",
            en: "Daily Delete (⌫) key usage as a percentage of total keystrokes.\n\nNote: On Mac, the 'Delete' key is the same as 'Backspace' on Windows/Linux. This metric includes both typo corrections and intentional editing — so a higher value does not necessarily mean more errors.\n\nHistorical data is available immediately (derived from existing dailyCounts in counts.json)."
        )
    }

    var chartTitleTypingSpeed: String {
        ja("タイピング速度 (WPM)", en: "Typing Speed (WPM)")
    }

    var helpTypingSpeed: String {
        ja(
            "日別の推定タイピング速度（WPM）を表示します。\n\n算出方法: 1000ms 以内のキーストローク間隔のみを Welford オンライン平均で集計し、WPM = 60,000 ÷ (平均間隔ms × 5) で換算します（1ワード = 5打鍵の標準定義）。\n\n注意: このデータはこのバージョンから蓄積を開始します。過去データは表示されません。",
            en: "Daily estimated typing speed in WPM.\n\nCalculation: Only inter-keystroke intervals ≤ 1,000 ms are included in a Welford online average. WPM = 60,000 ÷ (avg interval ms × 5), using the standard definition of 1 word = 5 keystrokes.\n\nNote: Data accumulates from this version onward. No historical data is available."
        )
    }

    var exportCSVMenuItem: String {
        ja("CSV 書き出し…", en: "Export CSV…")
    }

    var exportSummaryCardMenuItem: String {
        ja("週次サマリーカードを書き出し…", en: "Export Weekly Summary Card…")
    }

    var weeklySummaryCardTitle: String {
        ja("週次サマリー", en: "Weekly Summary")
    }

    var weeklySummaryCardTotalKeys: String {
        ja("総打鍵数", en: "Total Keystrokes")
    }

    var weeklySummaryCardTopKeys: String {
        ja("よく使うキー TOP 5", en: "Top 5 Keys")
    }

    var weeklySummaryCardErgonomicScore: String {
        ja("エルゴノミクススコア", en: "Ergonomic Score")
    }

    var weeklySummaryCardStreak: String {
        ja("継続日数", en: "Streak")
    }

    var weeklySummaryCardWPM: String {
        ja("推定 WPM", en: "Est. WPM")
    }

    var weeklySummaryCardAutoSaved: String {
        ja("週次サマリーカードを保存しました", en: "Weekly summary card saved")
    }

    var weeklySummaryCardSaveFailed: String {
        ja("週次サマリーカードの保存に失敗しました", en: "Failed to save weekly summary card")
    }

    var exportSQLiteMenuItem: String {
        ja("SQLite 書き出し…", en: "Export SQLite…")
    }

    var exportSQLiteSaveButton: String {
        ja("保存", en: "Save")
    }

    var exportSQLiteFailedAlert: String {
        ja("SQLite の書き出しに失敗しました", en: "Failed to export SQLite database")
    }

    var exportHeatmap: String {
        ja("ヒートマップを保存", en: "Save Heatmap")
    }

    var exportSuccess: String {
        ja("保存しました", en: "Saved successfully")
    }

    var exportError: String {
        ja("保存に失敗しました", en: "Failed to save")
    }

    var exportCSVSaveButton: String {
        ja("ここに保存", en: "Save Here")
    }

    var exportObsidianMenuItem: String {
        ja("Obsidian デイリーノートに書き出し", en: "Export to Obsidian Daily Note")
    }

    var changeObsidianFolderMenuItem: String {
        ja("Obsidian フォルダを変更…", en: "Change Obsidian Folder…")
    }

    var obsidianFolderPickerTitle: String {
        ja("Obsidian Vault フォルダを選択", en: "Select Obsidian Vault Folder")
    }

    var obsidianFolderPickerButton: String {
        ja("このフォルダを使用", en: "Use This Folder")
    }

    var obsidianExportSuccess: String {
        ja("Obsidian デイリーノートに書き出しました", en: "Exported to Obsidian daily note")
    }

    var obsidianExportFailed: String {
        ja("Obsidian への書き出しに失敗しました", en: "Failed to export to Obsidian")
    }

    var backupMenuItem: String {
        ja("バックアップを保存…", en: "Save Backup…")
    }

    var restoreMenuItem: String {
        ja("バックアップから復元…", en: "Restore from Backup…")
    }

    var restoreAlertTitle: String {
        ja("バックアップから復元しますか？", en: "Restore from backup?")
    }

    var restoreAlertMessage: String {
        ja(
            "現在のすべてのデータがバックアップファイルの内容に置き換えられます。この操作は取り消せません。",
            en: "All current data will be replaced with the contents of the backup file. This cannot be undone."
        )
    }

    var restoreConfirmButton: String {
        ja("復元", en: "Restore")
    }

    var copyDataMenuItem: String {
        ja("データをコピー", en: "Copy Data to Clipboard")
    }

    var copyHeatmap: String {
        ja("画像をコピー", en: "Copy Image")
    }

    var copiedConfirmation: String {
        ja("コピーしました！", en: "Copied!")
    }

    var saveChartAsImage: String {
        ja("画像として保存", en: "Save as Image")
    }

    var savedConfirmation: String {
        ja("保存しました！", en: "Saved!")
    }

    var heatmapLayoutLabel: String {
        ja("レイアウト", en: "Layout")
    }

    var importKLEButton: String {
        ja("レイアウトをインポート…", en: "Import Layout…")
    }

    var kleParseErrorTitle: String {
        ja("インポート失敗", en: "Import Failed")
    }

    var kleParseErrorInvalid: String {
        ja("ファイルを KLE JSON として解析できませんでした。keyboard-layout-editor.com からエクスポートした有効な JSON ファイルを選択してください。",
           en: "The file could not be parsed as KLE JSON. Select a valid JSON file exported from keyboard-layout-editor.com.")
    }

    var kleParseErrorEmpty: String {
        ja("レイアウトにキーが見つかりませんでした。",
           en: "No keys were found in the layout.")
    }

    var kleCustomNoData: String {
        ja("カスタムレイアウトが未インポートです。\n「レイアウトをインポート…」をクリックして KLE JSON ファイルを読み込んでください。",
           en: "No custom layout imported yet.\nClick \"Import Layout…\" to load a KLE JSON file.")
    }

    var helpKLECustom: String {
        ja(
            """
            カスタムレイアウトを使うには:
            1. keyboard-layout-editor.com にアクセスする
            2. キーボードレイアウトを作成または読み込む
            3. 「Raw data」タブをクリックして JSON をコピーする
            4. テキストエディタに貼り付けて .json 形式で保存する
            5. 「レイアウトをインポート…」ボタンで保存したファイルを選択する
            """,
            en: """
            To use a custom layout:
            1. Go to keyboard-layout-editor.com
            2. Design or load your keyboard layout
            3. Click the "Raw data" tab and copy the JSON
            4. Paste it into a text editor and save with a .json extension
            5. Click "Import Layout…" and select the saved file
            """
        )
    }

    // MARK: - Issue #176: Custom layout keyword matching

    var kleKeywordsLabel: String {
        ja("デバイスキーワード:", en: "Device keywords:")
    }

    var kleKeywordsPlaceholder: String {
        ja("例: corne, my keyboard", en: "e.g. corne, my keyboard")
    }

    func autoMatchedCustom(_ name: String) -> String {
        ja("↳ カスタムがマッチ — \"\(name)\"", en: "↳ Custom matched — \"\(name)\"")
    }

    var editPromptMenuItem: String {
        ja("AIプロンプトを編集…", en: "Edit AI Prompt…")
    }

    var editPromptTitle: String {
        ja("AIプロンプト", en: "AI Prompt")
    }

    var notificationIntervalMenuTitle: String {
        ja("通知間隔", en: "Notify Every")
    }

    func notificationIntervalLabel(_ n: Int) -> String {
        ja("\(n.formatted()) 回ごと", en: "Every \(n.formatted()) presses")
    }

    var editPromptSave: String {
        ja("保存", en: "Save")
    }

    func statsWindowHeader(since: String, today: String, total: String) -> String {
        ja(
            "\(since) から記録中  |  本日: \(today) 入力  |  合計: \(total) 入力",
            en: "Since \(since)  |  Today: \(today) inputs  |  Total: \(total) inputs"
        )
    }

    func notificationBody(key: String, count: Int) -> String {
        ja(
            "「\(key)」が \(count.formatted()) 回に達しました！",
            en: "\"\(key)\" has reached \(count.formatted()) presses!"
        )
    }

    static let dateFormatterJa: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        f.locale = Locale(identifier: "ja_JP"); return f
    }()
    static let dateFormatterEn: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        f.locale = Locale(identifier: "en_US"); return f
    }()

    /// 記録開始日を表示する文字列を返す
    func recordingSince(_ date: Date) -> String {
        let fmt = resolved == .japanese ? Self.dateFormatterJa : Self.dateFormatterEn
        let dateStr = fmt.string(from: date)
        return ja("\(dateStr) から記録中", en: "Since \(dateStr)")
    }

    // MARK: - Help popover strings

    var helpHeatmapFrequency: String {
        ja("頻度モード：各キーの合計打鍵数に応じて色付けされます。赤いキーが最もよく押されたキーです。",
           en: "Frequency mode: each key is colored by total keystroke count. Red = most pressed.")
    }

    var helpHeatmapStrain: String {
        ja("負荷モード：高負荷ビグラム（同指かつ1行以上をまたぐ連続打鍵）に含まれる頻度で各キーを色付けします。赤いキーが最も疲労しやすいキーです。",
           en: "Strain mode: each key is colored by how often it appears in high-strain bigrams — same finger, spanning ≥1 keyboard row. Red keys are frequent culprits; dark keys are rarely involved.")
    }

    var helpHeatmapStrainLegend: String {
        ja("高負荷とは、同指かつ1行以上をまたぐビグラム（例：F→R、J→U）に頻繁に登場するキーのことです。生体力学的に最も負担の大きい打鍵パターンです。",
           en: "High strain: key appears frequently in same-finger bigrams that span ≥1 row (e.g. F→R, J→U). These are the most biomechanically taxing sequences.")
    }

    func heatmapCountTooltip(_ count: Int) -> String {
        ja("打鍵数: \(count.formatted())", en: "Count: \(count.formatted())")
    }

    func heatmapStrainTooltip(_ score: Int) -> String {
        ja("負荷スコア: \(score.formatted())", en: "Strain: \(score.formatted())")
    }

    var heatmapSpeedLow: String {
        ja("速い", en: "Fast")
    }

    var heatmapSpeedHigh: String {
        ja("遅い", en: "Slow")
    }

    var helpHeatmapSpeed: String {
        ja("速度モード：ビグラムIKI（キー間隔）の平均値に基づいて各キーを色付けします。赤いキーが最も遅いキーです（3ビグラム以上のデータが必要）。",
           en: "Speed mode: each key is colored by its average inter-keystroke interval (IKI) across related bigrams. Red = slowest key. Requires at least 3 bigrams of data per key.")
    }

    func heatmapSpeedTooltip(_ ms: Double) -> String {
        ja(String(format: "平均IKI: %.0f ms", ms), en: String(format: "Avg IKI: %.0f ms", ms))
    }

    var slowBigramKeyFilterPlaceholder: String {
        ja("キーで絞り込む (例: e)", en: "Filter by key (e.g. e)")
    }

    // MARK: - Fatigue Detection (Issue #63)

    var fatigueCurveTitle: String {
        ja("本日の疲労カーブ", en: "Today's Fatigue Curve")
    }

    var helpFatigueCurve: String {
        ja(
            "本日の時間別タイピング速度 (WPM) と人間工学的指標の推移を表示します。\n\n" +
            "WPM (青)：その時間帯の推定打鍵速度。下降傾向は疲労を示します。\n" +
            "同指率 (オレンジ)：同じ指で連続するキーペアの割合。疲労すると増加します。\n" +
            "高負荷率 (赤)：高負荷バイグラムの割合。疲労すると増加します。\n\n" +
            "【表示までの目安】このビルド以降のデータのみ蓄積されます。" +
            "数秒間タイピングすると最初のデータ点が表示されます。" +
            "チャートは10秒ごとに自動更新されます。",
            en: "Shows hourly typing speed (WPM) and ergonomic metrics for today.\n\n" +
            "WPM (blue): estimated typing speed per hour. A downward trend indicates fatigue.\n" +
            "Same-finger (orange): fraction of same-finger keypairs. Increases with fatigue.\n" +
            "High-strain (red): fraction of high-strain bigrams. Increases with fatigue.\n\n" +
            "Note: only keystrokes typed after this build are recorded. " +
            "A few seconds of typing is enough to show the first data point. " +
            "The chart auto-refreshes every 10 seconds."
        )
    }

    var fatigueNoData: String {
        ja("本日のデータがまだありません。タイピング開始後に表示されます。",
           en: "No data for today yet. Appears after you start typing.")
    }

    var helpLearningCurve: String {
        ja(
            "3つの人間工学的指標の日次推移を示します。\n\n同指率（オレンジ）：同じ指で連続して打鍵されるペアの割合。低いほど優れています。\n\n交互打鍵率（緑）：左右の手が交互に打鍵する割合。高いほど優れています。\n\n高負荷率（赤）：1行以上をまたぐ同指ビグラムの割合。低いほど優れています。\n\n傾向が改善方向に推移している場合、打鍵習慣が人間工学的に最適化されています。",
            en: "Shows daily trends for three ergonomic metrics.\n\nSame-finger (orange): fraction of consecutive keypairs pressed by the same finger. Lower is better.\n\nAlternation (teal): fraction of keypairs that alternate between hands. Higher is better.\n\nHigh-strain (red): fraction of same-finger bigrams that span ≥1 keyboard row. Lower is better.\n\nImproving trends indicate your typing habits are becoming more ergonomic over time."
        )
    }

    var helpActivityCalendar: String {
        ja(
            "過去365日の日別打鍵数をカレンダーヒートマップで表示します。セルが濃いほど打鍵数が多い日です。\n\n縦軸は曜日（上から日〜土）、横軸は週（左が古く、右が最新）です。",
            en: "Calendar heatmap of daily keystroke counts over the past year. Darker cells indicate more keystrokes.\n\nRows represent days of the week (Sun at top, Sat at bottom). Columns represent weeks, with the most recent week on the right."
        )
    }

    var chartTitleRecentIKI: String {
        ja("直近20打鍵のタイミング", en: "Recent 20 Keystrokes — Timing")
    }

    var helpRecentIKI: String {
        ja(
            "直近20打鍵のキー間隔 (IKI: Inter-Keystroke Interval) をリアルタイムで表示します。緑＝高速 (<150ms)、黄＝中速、赤＝低速 (>400ms)。チャートウィンドウを開いた状態でタイピングすると更新されます。",
            en: "Real-time inter-keystroke intervals (IKI) for the last 20 keystrokes. Green = fast (<150ms), yellow = medium, red = slow (>400ms). Type with this window open to see it update."
        )
    }

    // MARK: - Speedometer (Issue #115)

    var chartTitleSpeedometer: String {
        ja("タイピングスピードメーター", en: "Typing Speedometer")
    }

    var helpSpeedometer: String {
        ja(
            "キーを押すたびにメーターが即時更新されます。直近5秒間のキー入力からWPM(1分あたりの単語数)を計算します。2秒間入力がないと速度はゼロに戻ります。赤いマーカーはセッション中の最高速度を記録します。",
            en: "The needle responds to every keystroke in real time. WPM is computed from keystrokes in the last 5 seconds. Speed drops to zero after 2 seconds of inactivity. The red marker holds the session peak speed."
        )
    }

    var speedometerWPMLabel: String {
        ja("WPM", en: "WPM")
    }

    func speedometerPeakLabel(_ wpm: Int) -> String {
        ja("最高: \(wpm) WPM", en: "Peak: \(wpm) WPM")
    }

    // MARK: - Manual WPM Measurement (Issue #150)

    var wpmMeasureTitle: String {
        ja("WPM 計測", en: "WPM Measurement")
    }

    var wpmMeasureStart: String {
        ja("計測開始", en: "Start")
    }

    var wpmMeasureStop: String {
        ja("計測停止", en: "Stop")
    }

    var wpmMeasureHint: String {
        ja("「計測開始」を押してからタイピングし、「計測停止」を押すとWPMが表示されます。",
           en: "Press Start, type freely, then press Stop to see your WPM.")
    }

    func wpmMeasureResult(wpm: Double, duration: TimeInterval, keystrokes: Int) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        let timeStr = mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
        return ja(
            String(format: "%.0f WPM  (%d打鍵 / %@)", wpm, keystrokes, timeStr),
            en: String(format: "%.0f WPM  (%d keystrokes / %@)", wpm, keystrokes, timeStr)
        )
    }

    var wpmHotkeyLabel: String {
        ja("ショートカット:", en: "Hotkey:")
    }

    var wpmHotkeyRecord: String {
        ja("変更…", en: "Change…")
    }

    var wpmHotkeyRecording: String {
        ja("キーを押してください…", en: "Press a key combo…")
    }

    var chartTitleIKIHistogram: String {
        ja("IKI分布ヒストグラム", en: "IKI Distribution Histogram")
    }

    var helpIKIHistogram: String {
        ja(
            "全打鍵データのキー間隔 (IKI) 分布を50ms刻みのバケットで表示します。緑＝高速 (0–100ms)、橙＝中速、赤＝低速 (300ms+)。タイピングリズムの全体的な傾向を把握できます。",
            en: "Distribution of inter-keystroke intervals (IKI) across all recorded keystrokes, grouped in 50ms buckets. Green = fast (0–100ms), orange = medium, red = slow (300ms+). Shows your overall typing rhythm profile."
        )
    }

    var helpHourlyDistribution: String {
        ja(
            "全記録セッションを通じた、時刻（0〜23時）ごとの累積打鍵数を表示します。",
            en: "Total keystrokes by hour of day across all recorded sessions."
        )
    }

    var helpLayoutComparison: String {
        ja(
            "実際の打鍵データを用いて、現行レイアウトとSFB最適化提案レイアウトを人間工学スコアで比較します。",
            en: "Compares your current layout against an SFB-optimised layout using your actual typing data."
        )
    }

    var helpBigrams: String {
        ja(
            "ビグラムとは、連続する2回の打鍵のペアです。グラフは最も頻度の高い20ペアを表示します。\n\n同指率：同じ指で連続して打鍵されるペアの割合。低いほど人間工学的に優れています。同指連打は生体力学的に最も負荷が高い動作です。\n\n交互打鍵率：左右の手が交互に打鍵するペアの割合。高いほど優れています。交互打鍵は速度と持久性を同時に高めます。",
            en: "A bigram is any two consecutive keystrokes. The chart shows your 20 most frequent pairs.\n\nSame-finger rate: how often both keys in a pair are pressed by the same finger. Lower is better — same-finger repetition is biomechanically taxing.\n\nAlternation rate: how often keystrokes alternate between left and right hands. Higher is better — alternation allows one hand to prepare while the other types."
        )
    }

    var slowBigramsTitle: String {
        ja("遅いキーペア (平均 IKI)", en: "Slow Bigrams (Avg IKI)")
    }

    var helpSlowBigrams: String {
        ja(
            "IKI (Inter-Key Interval) とは、2つのキーを連続して押したときの時間間隔 (ms) です。\n\nこのグラフは平均IKIが最も長いキーペア (ビグラム) を表示します。値が大きいほど打鍵が遅い組み合わせです。\n\nタイピング練習のターゲットとして活用できます。サンプル数が少ないビグラムは除外されています。",
            en: "IKI (Inter-Key Interval) is the time in milliseconds between two consecutive keystrokes.\n\nThis chart shows the bigrams with the highest average IKI — the key pairs where your transitions are slowest.\n\nUse this to target slow combinations in typing practice. Bigrams with fewer than 5 samples are excluded."
        )
    }

    var fingerIKITitle: String {
        ja("指ごとの平均 IKI", en: "Avg IKI per Finger")
    }

    var helpFingerIKI: String {
        ja(
            "各指の平均 IKI (Inter-Key Interval) を示します。値が大きいほど、その指が次のキーを押すまでに時間がかかっています。\n\n集計方法: ビグラムの「受け取り側」の指に IKI を帰属させています。例えば「a→s」の IKI は中指 (s) に計上されます。\n\n練習のターゲットとして活用できます。",
            en: "Shows the average IKI (Inter-Key Interval) for each finger. A higher value means that finger takes longer to engage as the receiving key in a transition.\n\nAggregation: IKI is attributed to the finger of the destination key in each bigram (e.g. the IKI of \"a→s\" is counted for the finger that presses \"s\").\n\nUse this to identify which fingers are slowest to respond."
        )
    }

    var fingerIKINoData: String {
        ja("データなし — しばらく入力すると指ごとの IKI データが蓄積されます。",
           en: "No data yet — type for a while to accumulate per-finger IKI data.")
    }

    var slowBigramsNoData: String {
        ja("データなし — しばらく入力するとビグラムIKIデータが蓄積されます。",
           en: "No data yet — type for a while to accumulate bigram IKI data.")
    }

    // MARK: - Issue #98: Key Transition Analysis

    // MARK: - Issue #61: Layout Efficiency Score

    var layoutEfficiencyTitle: String {
        ja("レイアウト効率比較", en: "Layout Efficiency Comparison")
    }

    var helpLayoutEfficiency: String {
        ja(
            "あなたの実際の打鍵ビグラムデータを使い、QWERTY / Colemak / Dvorak それぞれで「同指率」と「交互打鍵率」を計算します。\n\n同指率が低いほど、交互打鍵率が高いほど効率的なレイアウトです。\n\n※ あなたが実際に使っているレイアウトで記録されたビグラムを各レイアウトの指割り当てに当てはめた推定値です。",
            en: "Applies your actual bigram frequencies to the finger assignments of QWERTY, Colemak, and Dvorak to estimate same-finger bigram rate (SFB) and hand-alternation rate for each layout.\n\nLower SFB and higher alternation = more efficient layout for your typing patterns.\n\nNote: these are estimates based on remapping your recorded bigrams to each layout's finger assignments."
        )
    }

    var layoutEfficiencyNoData: String {
        ja("データなし — しばらく入力するとビグラムデータが蓄積されます。",
           en: "No data yet — type for a while to accumulate bigram data.")
    }

    var layoutEfficiencySFBHeader: String {
        ja("同指率 (低いほど良い)", en: "Same-Finger Rate (lower = better)")
    }

    var layoutEfficiencyAltHeader: String {
        ja("交互打鍵率 (高いほど良い)", en: "Hand Alternation (higher = better)")
    }

    // MARK: - Issue #98: Key Transition Analysis

    var keyTransitionTitle: String {
        ja("キー遷移分析", en: "Key Transition Analysis")
    }

    var helpKeyTransition: String {
        ja(
            "調べたいキーを入力すると、そのキーへの遷移 (*→K) とそのキーからの遷移 (K→*) を平均IKI順で表示します。\n\n値が大きいほど遅い組み合わせです。タイピング練習のターゲット発見に活用できます。サンプル数が少ない遷移は除外されます。",
            en: "Enter a key to inspect its incoming (*→K) and outgoing (K→*) transitions, ranked by average IKI.\n\nHigher values mean slower transitions. Use this to find specific key pairs to target in practice. Transitions with fewer than 3 samples are excluded."
        )
    }

    var keyTransitionPlaceholder: String {
        ja("キーを入力 (例: f)", en: "Type a key (e.g. f)")
    }

    func keyTransitionIncomingTitle(_ key: String) -> String {
        ja("→ \(key) への遷移 (遅い順)", en: "Incoming → \(key) (slowest first)")
    }

    func keyTransitionOutgoingTitle(_ key: String) -> String {
        ja("\(key) → からの遷移 (遅い順)", en: "Outgoing \(key) → (slowest first)")
    }

    var keyTransitionNoData: String {
        ja("該当する遷移データがありません。サンプル数が少ない場合は除外されます。",
           en: "No transition data found. Transitions with fewer than 3 samples are excluded.")
    }

    func topAppTodayFormat(_ app: String, _ count: String) -> String {
        ja("🖥 \(app)  \(count)", en: "🖥 \(app)  \(count)")
    }

    var appsAllTime: String {
        ja("アプリ別打鍵数 — 累計", en: "Top Apps — All Time")
    }

    var appsToday: String {
        ja("アプリ別打鍵数 — 本日", en: "Top Apps — Today")
    }

    var helpApps: String {
        ja(
            "フォアグラウンドで動作していたアプリごとの打鍵数を表示します。どのアプリで最も多くタイプしているかを把握できます。",
            en: "Keystroke counts grouped by the frontmost application. Shows which apps you type in most."
        )
    }

    var devicesAllTime: String {
        ja("デバイス別打鍵数 — 累計", en: "Top Devices — All Time")
    }

    var devicesToday: String {
        ja("デバイス別打鍵数 — 本日", en: "Top Devices — Today")
    }

    var helpDevices: String {
        ja(
            "検出されたキーボードデバイス名ごとに打鍵数を表示します。内蔵キーボードと外付けキーボードでの使用傾向を比較できます。",
            en: "Keystroke counts grouped by detected keyboard device name. Useful for comparing built-in and external keyboard usage."
        )
    }

    var appErgScoreSection: String {
        ja("アプリ別エルゴノミクススコア", en: "Ergonomic Score by App")
    }

    var helpAppErgScore: String {
        ja(
            "100打鍵以上のアプリについて、実際の打鍵データから算出したエルゴノミクススコア（0〜100）を表示します。スコアが高いほど、同指率・高負荷率が低く、左右交互打鍵率が高い優れた状態です。",
            en: "Ergonomic score (0–100) computed from actual typing data for apps with ≥100 keystrokes. Higher is better: lower same-finger and high-strain rates, higher hand alternation."
        )
    }

    var appErgScoreAppHeader: String {
        ja("アプリ", en: "App")
    }

    var appErgScoreKeysHeader: String {
        ja("打鍵数", en: "Keystrokes")
    }

    var appErgScoreScoreHeader: String {
        ja("スコア", en: "Score")
    }

    var deviceErgScoreSection: String {
        ja("デバイス別エルゴノミクススコア", en: "Ergonomic Score by Device")
    }

    var helpDeviceErgScore: String {
        ja(
            "100打鍵以上のデバイスについて、実際の打鍵データから算出したエルゴノミクススコア（0〜100）を表示します。スコアが高いほど、同指率・高負荷率が低く、左右交互打鍵率が高い状態です。",
            en: "Ergonomic score (0–100) computed from actual typing data for devices with ≥100 keystrokes. Higher is better: lower same-finger and high-strain rates, higher hand alternation."
        )
    }

    var deviceErgScoreDeviceHeader: String {
        ja("デバイス", en: "Device")
    }

    var deviceErgScoreKeysHeader: String {
        ja("打鍵数", en: "Keystrokes")
    }

    var deviceErgScoreScoreHeader: String {
        ja("スコア", en: "Score")
    }

    var helpWeeklyReport: String {
        ja(
            "今週と先週の主要指標を比較します。Δ列は変化量を示し、改善は緑、悪化は赤で表示されます。\n\n表示には最低2週間分のデータが必要です。",
            en: "Compares key metrics between this week and last week. The Δ column shows the change — green means improvement, red means regression.\n\nRequires at least two weeks of data to display."
        )
    }

    var helpDailyTotals: String {
        ja(
            "日別の総打鍵数を棒グラフで表示します。曜日ごとの入力量の傾向や、作業が多い日・少ない日を把握できます。",
            en: "Total keystrokes per day shown as a bar chart. Useful for spotting your busiest and lightest days, and weekly patterns."
        )
    }

    var helpMonthlyTotals: String {
        ja(
            "月別の総打鍵数を棒グラフで表示します。長期的な入力量のトレンドや季節的な変動を確認できます。",
            en: "Total keystrokes per month. Useful for tracking long-term trends in typing volume over weeks and months."
        )
    }

    var helpKeyboardHeatmap: String {
        ja(
            "キーボード上の各キーの使用頻度を色の濃さで表示します。よく使うキーほど濃い色になります。\n\n負荷ビューに切り替えると、同指連続入力（高負荷バイグラム）が多いキーを確認できます。",
            en: "Visualizes keystroke frequency across the keyboard — darker keys are used more often.\n\nSwitch to the Strain view to highlight keys involved in high-strain same-finger bigrams."
        )
    }

    var helpTopKeys: String {
        ja(
            "累計打鍵数の多いキー上位20件をランキング表示します。最も頻繁に使うキーを把握できます。\n\nソートボタンで昇順・降順を切り替えられます。",
            en: "The 20 most-pressed keys ranked by total count. Shows which keys you rely on most.\n\nUse the sort button to toggle ascending/descending order."
        )
    }

    var helpKeyCategories: String {
        ja(
            "打鍵をキーの種類（アルファベット・数字・記号・修飾キー・ナビゲーション・スペースなど）ごとに集計した円グラフです。\n\nタイピング用途（執筆・開発・チャット）の傾向が読み取れます。",
            en: "Pie chart breaking down keystrokes by key type: alphabet, numbers, symbols, modifiers, navigation, space, and more.\n\nThe distribution reflects your typical typing context — prose, coding, or chat."
        )
    }

    var helpTopKeysPerDay: String {
        ja(
            "日ごとに最も多く押されたキー上位10件を積み上げ棒グラフで表示します。日によって使用キーの傾向がどう変わるかを確認できます。",
            en: "Top 10 keys per day shown as a stacked bar chart. Reveals how your key usage distribution shifts from day to day."
        )
    }

    var helpAppsToday: String {
        ja(
            "本日のアプリ別打鍵数を表示します。今日どのアプリで最も多くタイプしているかをリアルタイムで確認できます。",
            en: "Today's keystroke counts grouped by application. Shows which apps you have been typing in most so far today."
        )
    }

    var helpDevicesToday: String {
        ja(
            "本日のデバイス別打鍵数を表示します。内蔵キーボードと外付けキーボードの使用割合を今日の分だけ確認できます。",
            en: "Today's keystroke counts grouped by keyboard device. Useful for checking how much you have used each keyboard today."
        )
    }

    var helpShortcuts: String {
        ja(
            "⌘ を含むキーボードショートカットの使用頻度ランキングを表示します。よく使うショートカットや偏りを把握できます。\n\nソートボタンで昇順・降順を切り替えられます。",
            en: "Ranking of keyboard shortcuts that include ⌘. Shows which shortcuts you use most often.\n\nUse the sort button to toggle ascending/descending order."
        )
    }

    var helpAllCombos: String {
        ja(
            "修飾キー（⌘ ⌥ ⌃ ⇧）を含むすべてのキーコンビネーションの使用頻度を表示します。ショートカットの全体像を把握できます。\n\nソートボタンで昇順・降順を切り替えられます。",
            en: "All recorded key combinations involving modifiers (⌘ ⌥ ⌃ ⇧), ranked by frequency. Gives a complete picture of your shortcut usage.\n\nUse the sort button to toggle ascending/descending order."
        )
    }

    var intelligenceSection: String {
        ja("タイピング診断", en: "Typing Profile")
    }

    var helpIntelligence: String {
        ja(
            "キー頻度パターンから推定した2つの指標を表示します。\n\n推定スタイル: よく使うキーの分布からタイピング用途を推定します。文字・スペース中心 → 執筆、記号・修飾キー多用 → 開発、短いパターン多用 → チャット。\n\n疲労リスク: 同一指で1行以上離れたキーを連続入力する「高負荷バイグラム」の割合で判定します。\n低（緑）: 2%以下 / 中（橙）: 2〜5% / 高（赤）: 5%超",
            en: "Two metrics inferred from your keystroke patterns.\n\nInferred Style: estimated from key frequency distribution. High letters/Space → Prose; high symbols/modifiers → Code; frequent short patterns → Chat.\n\nFatigue Risk: based on the high-strain bigram rate — same-finger keypairs spanning ≥1 keyboard row (e.g. F→R, J→U).\nLow (green): ≤2% / Moderate (orange): 2–5% / High (red): >5%"
        )
    }

    var inferredStyle: String {
        ja("推定スタイル", en: "Inferred Style")
    }

    var fatigueRisk: String {
        ja("疲労リスク", en: "Fatigue Risk")
    }

    func typingStyleLabel(_ style: TypingStyle) -> String {
        switch style {
        case .prose:   return ja("執筆", en: "Prose")
        case .code:    return ja("開発", en: "Code")
        case .chat:    return ja("チャット", en: "Chat")
        case .unknown: return ja("不明", en: "Unknown")
        }
    }

    func fatigueLevelLabel(_ level: FatigueLevel) -> String {
        switch level {
        case .low:      return ja("低", en: "Low")
        case .moderate: return ja("中", en: "Moderate")
        case .high:     return ja("高", en: "High")
        }
    }

    // MARK: - Menu Customization

    var customizeMenuMenuItem: String {
        ja("メニューをカスタマイズ…", en: "Customize Menu…")
    }

    var customizeMenuTitle: String {
        ja("メニュー表示のカスタマイズ", en: "Customize Menu Display")
    }

    var customizeMenuHint: String {
        ja("表示する項目を選択し、ドラッグで並び替えできます。", en: "Toggle items to show or hide, and drag to reorder.")
    }

    var customizeMenuReset: String {
        ja("デフォルトに戻す", en: "Reset to Default")
    }

    func widgetDisplayName(_ widget: MenuWidget) -> String {
        switch widget {
        case .recordingSince: return ja("記録開始日", en: "Recording Since")
        case .todayTotal:     return ja("本日 / 合計", en: "Today / Total")
        case .avgInterval:    return ja("平均打鍵間隔", en: "Avg Interval")
        case .estimatedWPM:   return ja("推定WPM", en: "Estimated WPM")
        case .backspaceRate:  return ja("Delete使用率", en: "Delete Usage")
        case .miniChart:      return ja("直近7日グラフ", en: "Last 7 Days Chart")
        case .streak:               return ja("ストリーク", en: "Streak")
        case .shortcutEfficiency:   return ja("ショートカット効率", en: "Shortcut Efficiency")
        case .mouseDistance:        return ja("マウス移動距離", en: "Mouse Distance")
        }
    }

    // MARK: - Break Reminder

    var breakReminderMenuTitle: String {
        ja("休憩リマインダー", en: "Break Reminder")
    }

    var breakReminderTitle: String {
        ja("☕ 休憩しましょう", en: "☕ Time for a break")
    }

    func breakReminderBody(minutes: Int) -> String {
        ja("\(minutes)分間タイピングが続いています。少し休憩しませんか？",
           en: "You've been typing for \(minutes) minutes. Consider taking a short break.")
    }

    func breakReminderIntervalLabel(_ minutes: Int) -> String {
        ja("\(minutes)分ごと", en: "Every \(minutes) min")
    }

    var breakReminderOff: String {
        ja("オフ", en: "Off")
    }

    // MARK: - Streak & Daily Goal

    /// Shown when no daily goal is configured — streak cannot be tracked.
    var streakNoGoalHint: String {
        ja("🔥 目標打鍵数を設定するとStreakが始まります", en: "🔥 Set a daily goal to start your streak")
    }

    /// Streak display string. n=0 shows a "no streak" placeholder.
    func streakDisplay(_ n: Int) -> String {
        n > 0
            ? ja("🔥 \(n)日連続達成中", en: "🔥 \(n)-day streak")
            : ja("🔥 ストリークなし", en: "🔥 No streak yet")
    }

    /// Today's progress toward the daily goal as a formatted string.
    func goalProgress(today: Int, goal: Int) -> String {
        let pct = goal > 0 ? min(100, today * 100 / goal) : 0
        return ja("今日: \(today.formatted()) / \(goal.formatted()) (\(pct)%)",
                  en: "Today: \(today.formatted()) / \(goal.formatted()) (\(pct)%)")
    }

    var goalReachedTitle: String {
        ja("🎉 目標達成！", en: "🎉 Daily goal reached!")
    }

    func goalReachedBody(streak: Int) -> String {
        ja("今日の打鍵目標を達成しました。\(streak)日連続達成！",
           en: "You've hit today's keystroke goal — \(streak)-day streak!")
    }

    var dailyGoalMenuTitle: String {
        ja("1日の目標打鍵数", en: "Daily Keystroke Goal")
    }

    var dailyGoalOff: String {
        ja("オフ", en: "Off")
    }

    func dailyGoalLabel(_ count: Int) -> String {
        ja("\(count.formatted())打鍵/日", en: "\(count.formatted()) keys/day")
    }

    // MARK: - Shortcut Efficiency

    /// Shortcut efficiency score display (e.g. "⌨️ Shortcut efficiency: 42%").
    func shortcutEfficiencyDisplay(_ pct: Double) -> String {
        ja("⌨️ ショートカット効率: \(Int(pct))%", en: "⌨️ Shortcut efficiency: \(Int(pct))%")
    }

    var shortcutEfficiencyNoData: String {
        ja("⌨️ ショートカットデータなし", en: "⌨️ No shortcut data yet")
    }

    // MARK: - Mouse Distance

    /// Mouse distance display string. Shows raw screen points and physical distance.
    /// Physical distance uses NSScreen.main for accuracy, falling back to 96 dpi baseline.
    func mouseDistanceDisplay(_ pts: Double) -> String {
        // Derive mm/pt from screen DPI; fall back to 96 dpi baseline (0.264 mm/pt)
        let mmPerPt: Double
        if let screen = NSScreen.main,
           let res = screen.deviceDescription[NSDeviceDescriptionKey("NSDeviceResolution")] as? NSSize,
           res.width > 0 {
            mmPerPt = 25.4 / res.width  // 25.4 mm per inch / dpi
        } else {
            mmPerPt = 0.264
        }

        let meters = pts * mmPerPt / 1000.0
        let pxFormatted = NumberFormatter.localizedString(from: NSNumber(value: Int(pts)), number: .decimal)

        let distStr: String
        if meters >= 1000 {
            distStr = String(format: "%.2f km", meters / 1000)
        } else {
            distStr = String(format: "%.0f m", meters)
        }

        return ja("🖱 移動距離: \(pxFormatted) px (\(distStr))",
                  en: "🖱 Travel: \(pxFormatted) px (\(distStr))")
    }

    var mouseDistanceNoData: String {
        ja("🖱 移動距離データなし", en: "🖱 No mouse distance data yet")
    }

    // MARK: - Mouse Tab (Charts window)

    var chartTitleMouseDailyDistance: String {
        ja("日別マウス移動距離（直近30日）", en: "Daily Mouse Travel (Last 30 Days)")
    }

    var helpMouseDailyDistance: String {
        ja(
            "直近30日間の日別マウス移動距離を棒グラフで表示します。単位はスクリーンポイント（px）です。",
            en: "Daily mouse travel distance over the last 30 days. Values are in screen points (px)."
        )
    }

    var chartTitleMouseHourly: String {
        ja("時間帯別マウス活動量", en: "Hourly Mouse Activity")
    }

    var helpMouseHourly: String {
        ja(
            "全期間のデータを時間帯ごとに集計したマウス移動量です。マウスを最もよく使う時間帯が分かります。",
            en: "Total mouse movement aggregated by hour of day across all recorded days. Shows your most active hours for mouse usage."
        )
    }

    var chartTitleMouseDirection: String {
        ja("移動方向の内訳", en: "Direction Breakdown")
    }

    var helpMouseDirection: String {
        ja(
            "上下左右それぞれのマウス移動量の累計です。右利き・左利き傾向やモニター配置の影響が読み取れます。",
            en: "Cumulative mouse movement split by direction: right, left, down, up. Reflects handedness and monitor layout tendencies."
        )
    }

    var chartTitleMouseDailyDirection: String {
        ja("日別方向内訳", en: "Daily Direction Breakdown")
    }

    var helpMouseDailyDirection: String {
        ja(
            "日別の上下左右マウス移動量です。右 (→) と左 (←) はほぼ同量になりますが、わずかな差が利き手傾向を示します。",
            en: "Per-day mouse movement by direction. Right and left are naturally close, but small differences reveal handedness or monitor bias."
        )
    }

    var mouseColRight: String { ja("右 →",  en: "Right →") }
    var mouseColLeft:  String { ja("左 ←",  en: "Left ←") }
    var mouseColDown:  String { ja("下 ↓",  en: "Down ↓") }
    var mouseColUp:    String { ja("上 ↑",  en: "Up ↑") }
    var dateLabel:     String { ja("日付",   en: "Date") }

    var chartTitleMouseKeyboardBalance: String {
        ja("マウス vs キーボード バランス", en: "Mouse vs Keyboard Balance")
    }

    var helpMouseKeyboardBalance: String {
        ja(
            "1日あたりのマウス移動量 (px) とキー入力数を重ねて表示します。マウス寄りの日とキーボード寄りの日のパターンを把握できます。",
            en: "Daily mouse distance (px) and keystroke count overlaid. Reveals whether you lean toward mouse or keyboard on a given day."
        )
    }

    var mouseKeyboardBalanceMouseLabel: String { ja("マウス", en: "Mouse") }
    var mouseKeyboardBalanceKeysLabel:  String { ja("キーボード", en: "Keyboard") }
    var mouseKeyboardBalanceBalanced:   String { ja("均等", en: "Balanced") }

    var chartTitleMouseClickCount: String {
        ja("マウスクリック数", en: "Mouse Click Count")
    }

    var helpMouseClickCount: String {
        ja("左・中・右ボタンのクリック総数を表示します。",
           en: "Total click counts for left, middle, and right mouse buttons.")
    }

    // MARK: - Issue #60: Session detection

    var chartTitleSessions: String {
        ja("セッション", en: "Sessions")
    }

    var helpSessions: String {
        ja(
            "5分以上キー入力がなかった場合にセッションの区切りとして検出します。セッション数・最長セッション時間・平均セッション時間を日別に表示します。",
            en: "A session boundary is detected when there is no keystroke for 5 or more minutes. Shows daily session count, longest session duration, and average session duration."
        )
    }

    var sessionsPerDay: String {
        ja("日別セッション数", en: "Sessions per Day")
    }

    var longestSessionLabel: String {
        ja("最長セッション (分)", en: "Longest Session (min)")
    }

    var avgSessionLabel: String {
        ja("平均セッション (分)", en: "Avg Session (min)")
    }

    // MARK: - Training Tab

    var trainingTargetsTitle: String {
        ja("練習対象バイグラム", en: "Training Targets")
    }

    var practiceDrillsTitle: String {
        ja("ドリル", en: "Practice Drills")
    }

    var helpTrainingTargets: String {
        ja("打鍵速度が遅く頻出するバイグラムを優先度スコア順に表示します。スコア = 平均IKI × log2(出現回数 + 1)。",
           en: "Bigrams ranked by training priority: score = mean IKI × log2(count + 1). Slower and more frequent combinations rank higher.")
    }

    var helpPracticeDrills: String {
        ja("生成されたドリルを上から順に打鍵してください。高優先度のバイグラムほど多くの繰り返しが割り当てられます。",
           en: "Type each drill line from top to bottom. High-priority bigrams get more repetitions.")
    }

    var trainingNoData: String {
        ja("データ不足 — 各バイグラムに5回以上の入力が必要です。",
           en: "Not enough data — bigrams need at least 5 observations each.")
    }

    var trainingColumnBigram: String   { ja("バイグラム", en: "Bigram") }
    var trainingColumnIKI: String      { ja("平均 IKI (ms)", en: "Avg IKI (ms)") }
    var trainingColumnCount: String    { ja("出現回数", en: "Count") }

    // Trigram training (Issue #89)
    var trainingTrigramTargetsTitle: String {
        ja("練習対象トライグラム", en: "Trigram Training Targets")
    }
    var helpTrainingTrigrams: String {
        ja("3キー列の推定レイテンシ (構成バイグラム IKI の合計) を基にランク付けします。スコア = 推定 IKI × log2(出現回数 + 1)。",
           en: "3-key sequences ranked by estimated latency: sum of the two constituent bigram IKIs. Score = estimated IKI × log2(count + 1).")
    }
    var trainingColumnTrigram: String  { ja("トライグラム", en: "Trigram") }
    var trainingColumnEstIKI: String   { ja("推定 IKI (ms)", en: "Est. IKI (ms)") }
    var trainingNoTrigramData: String {
        ja("トライグラムデータがまだありません。バイグラム IKI が蓄積されると表示されます。",
           en: "No trigram data yet. Appears once bigram IKI data has accumulated.")
    }
    var trainingColumnTier: String     { ja("優先度", en: "Priority") }
    /// Column header for the training history annotation in the targets table.
    var trainingColumnHistory: String  { ja("練習前→Δ", en: "Prior→Δ") }
    /// Tooltip for the history annotation cell. Arguments: beforeIKI, currentIKI, date string.
    var trainingHistoryAnnotationHelp: String {
        ja("練習前: %.0f ms → 現在: %.0f ms (最終練習: %@)",
           en: "Before: %.0f ms → Now: %.0f ms (last trained: %@)")
    }

    var trainingTierHigh: String  { ja("高", en: "High") }
    var trainingTierMid: String   { ja("中", en: "Mid") }
    var trainingTierLow: String   { ja("低", en: "Low") }

    var trainingDrillRepeated: String    { ja("繰り返し", en: "Repeated") }
    var trainingDrillAlternating: String { ja("交互", en: "Alternating") }

    var trainingRegenerateButton: String { ja("セッションを更新", en: "New Session") }

    var trainingHistoryTitle: String { ja("トレーニング履歴", en: "Training History") }
    var helpTrainingHistory: String {
        ja("過去のトレーニングセッションの結果を新しい順に表示します。",
           en: "Past training session results, newest first.")
    }
    var trainingHistoryEmpty: String {
        ja("まだ完了したセッションがありません。", en: "No completed sessions yet.")
    }
    var trainingHistoryDate: String    { ja("日時", en: "Date") }
    var trainingHistoryTargets: String { ja("対象", en: "Targets") }
    var trainingHistoryLength: String  { ja("長さ", en: "Length") }
    var trainingHistoryBefore: String  { ja("練習前 IKI", en: "Before IKI") }
    var trainingHistoryDelta: String   { ja("改善", en: "Δ IKI") }
    var trainingHistoryClear: String   { ja("履歴をリセット", en: "Reset History") }
    var trainingHistoryClearConfirm: String {
        ja("すべてのトレーニング履歴を削除しますか?この操作は取り消せません。",
           en: "Delete all training history? This cannot be undone.")
    }

    // Interactive practice UI strings
    var trainingColumnDrill: String    { ja("ドリル", en: "Drill") }
    var trainingDrillProgress: String  { ja("ドリル %d / %d", en: "Drill %d of %d") }
    var trainingDrillAccuracy: String  { ja("正確さ: %d%%", en: "Accuracy: %d%%") }
    var trainingDrillSkip: String      { ja("スキップ", en: "Skip") }
    var trainingDrillHint: String {
        ja("上のテキストをクリックしてフォーカスし、入力を開始してください",
           en: "Click the text above to focus, then start typing")
    }
    var trainingSessionComplete: String  { ja("セッション完了!", en: "Session Complete!") }
    var trainingResultAccuracy: String   { ja("正確さ", en: "Accuracy") }
    var trainingResultWPM: String        { ja("WPM", en: "WPM") }
    var trainingResultTime: String       { ja("時間", en: "Time") }
    var trainingAccuracyHelp: String     { ja("正確さ %", en: "Accuracy %") }

    // MARK: - Chart Axis Labels

    var axisLabelKeys: String     { ja("キー数", en: "Keys") }
    var axisLabelWPM: String      { ja("WPM", en: "WPM") }
    var axisLabelPercent: String  { ja("%", en: "%") }
    var axisLabelSessions: String { ja("セッション数", en: "Sessions") }
    var axisLabelMinutes: String  { ja("分", en: "min") }

    // MARK: - Chart Theme

    var chartThemeMenuTitle: String { ja("チャートテーマ", en: "Chart Theme") }

    func chartThemeDisplayName(_ theme: ChartTheme) -> String {
        switch theme {
        case .blue:   return ja("ブルー", en: "Blue")
        case .teal:   return ja("ティール", en: "Teal")
        case .purple: return ja("パープル", en: "Purple")
        case .orange: return ja("オレンジ", en: "Orange")
        case .green:  return ja("グリーン", en: "Green")
        case .pink:   return ja("ピンク", en: "Pink")
        }
    }

    // MARK: - Helper

    private func ja(_ japanese: String, en english: String) -> String {
        resolved == .japanese ? japanese : english
    }
}
