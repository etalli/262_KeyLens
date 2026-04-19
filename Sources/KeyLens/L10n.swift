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
        ja("本日: %@", en: "Today: %@")
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

    var resetUndoAlertTitle: String {
        ja("リセットが完了しました", en: "Reset complete")
    }

    var resetUndoAlertMessage: String {
        ja("元に戻す場合は「元に戻す」を押してください。", en: "Press Undo to restore the previous data.")
    }

    var resetUndoButton: String {
        ja("元に戻す", en: "Undo")
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

    var helpMenuItem: String {
        ja("ヘルプ", en: "Help")
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
        ja("グラフ…", en: "Charts…")
    }

    var last7Days: String {
        ja("直近7日間", en: "Last 7 Days")
    }

    var overlayMenuItem: String {
        ja("オーバーレイ", en: "Overlay")
    }

    var overlaySettingsMenuItem: String {
        ja("オーバーレイ設定…", en: "Overlay Settings…")
    }

    var overlaySettingsWindowTitle: String {
        ja("キーオーバーレイ設定", en: "Keystroke Overlay Settings")
    }

    var wpmGaugeMenuItem: String {
        ja("WPM 速度計", en: "WPM SpeedoMeter")
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

    var allTimeTotalLabel: String {
        ja("全期間の打鍵数", en: "All-Time Total")
    }

    var allTimeTodayLabel: String {
        ja("本日", en: "Today")
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

    var exportYearInReviewMenuItem: String {
        ja("年間サマリーを書き出し…", en: "Export Year in Review…")
    }

    var yearInReviewTitle: String {
        ja("年間サマリー", en: "Year in Review")
    }

    var yearInReviewDailyAvg: String {
        ja("1日平均", en: "Daily Avg")
    }

    var yearInReviewActiveDays: String {
        ja("入力日数", en: "Active Days")
    }

    var yearInReviewBestMonth: String {
        ja("最多月", en: "Best Month")
    }

    var yearInReviewMonthlyChart: String {
        ja("月別打鍵数", en: "Monthly Keystrokes")
    }

    var yearInReviewSaveFailed: String {
        ja("年間サマリーの保存に失敗しました", en: "Failed to save year in review")
    }

    // MARK: - Period Comparison Tab (Issue #62)

    var comparisonTabTitle: String {
        ja("比較", en: "Compare")
    }

    var comparisonBefore: String {
        ja("前", en: "Before")
    }

    var comparisonAfter: String {
        ja("後", en: "After")
    }

    var comparisonPresetLast7: String {
        ja("直近7日 vs 前7日", en: "Last 7 days vs Prior 7 days")
    }

    var comparisonPresetThisMonth: String {
        ja("今月 vs 先月", en: "This Month vs Last Month")
    }

    var comparisonCompareButton: String {
        ja("比較する", en: "Compare")
    }

    var comparisonMetricLabel: String {
        ja("指標", en: "Metric")
    }

    var comparisonMetricKeystrokes: String {
        ja("打鍵数 (合計)", en: "Total Keystrokes")
    }

    var comparisonMetricDailyAvg: String {
        ja("1日平均打鍵数", en: "Daily Average")
    }

    var comparisonMetricActiveDays: String {
        ja("入力日数", en: "Active Days")
    }

    var comparisonMetricSameFinger: String {
        ja("同指連打率", en: "Same-Finger Rate")
    }

    var comparisonMetricAlteration: String {
        ja("手交互率", en: "Alternation Rate")
    }

    var comparisonMetricAvgWPM: String {
        ja("平均WPM", en: "Avg WPM")
    }

    var helpComparison: String {
        ja(
            """
            2つの期間を並べてタイピング統計を比較します。

            • 範囲A — ベースライン（古い期間）
            • 範囲B — 比較対象（新しい期間）

            各指標の説明:
            • 打鍵数 (合計) — 期間中の総キーストローク数
            • 1日平均打鍵数 — 入力があった日の1日あたり平均
            • 入力日数 — 1回以上入力した日数
            • 平均WPM — キーストローク間隔から推定した平均タイピング速度
            • 同指連打率 — 同じ指で連続して打鍵した割合（低いほど良い）
            • 手交互率 — 左右交互に打鍵した割合（高いほど良い）

            Δ列の色: 緑 = 改善、赤 = 低下
            pp (パーセンテージポイント) — 2つのパーセント値の絶対差。例: 10% → 12% = +2 pp
            """,
            en: """
            Compare keystroke statistics across two date ranges side by side.

            • Range A — baseline (the earlier period)
            • Range B — comparison (the more recent period)

            Metrics:
            • Total Keystrokes — total key presses in the period
            • Daily Average — average keystrokes per active day
            • Active Days — days with at least one keystroke
            • Avg WPM — estimated typing speed from inter-keystroke intervals
            • Same-Finger Rate — consecutive presses on the same finger (lower is better)
            • Alternation Rate — left/right hand alternation (higher is better)

            Δ column: green = improvement, red = regression
            pp (percentage points) — absolute difference between two percentages. e.g. 10% → 12% = +2 pp
            """
        )
    }

    var comparisonNoData: String {
        ja("この期間のデータはありません", en: "No data for this period")
    }

    var comparisonStart: String {
        ja("開始日", en: "Start")
    }

    var comparisonEnd: String {
        ja("終了日", en: "End")
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

    var exportSuccess: String {
        ja("保存しました", en: "Saved successfully")
    }

    var exportError: String {
        ja("保存に失敗しました", en: "Failed to save")
    }

    var exportCSVSaveButton: String {
        ja("ここに保存", en: "Save Here")
    }

    var exportDailyNoteMenuItem: String {
        ja("Markdown デイリーノートに書き出し", en: "Export to Markdown Daily Note")
    }

    var changeDailyNoteFolderMenuItem: String {
        ja("デイリーノートフォルダを変更…", en: "Change Daily Note Folder…")
    }

    var dailyNoteFolderPickerTitle: String {
        ja("デイリーノートフォルダを選択", en: "Select Daily Note Folder")
    }

    var dailyNoteFolderPickerButton: String {
        ja("このフォルダを使用", en: "Use This Folder")
    }

    var dailyNoteExportSuccess: String {
        ja("Markdown デイリーノートに書き出しました", en: "Exported to Markdown daily note")
    }

    var dailyNoteExportFailed: String {
        ja("Markdown デイリーノートへの書き出しに失敗しました", en: "Failed to export to Markdown daily note")
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

    var restoreFailedAlert: String {
        ja("バックアップからの復元に失敗しました", en: "Failed to restore from backup")
    }

    var copyDataMenuItem: String {
        ja("データをコピー", en: "Copy Data to Clipboard")
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

    var sectionCollapse: String {
        ja("セクションを折りたたむ", en: "Collapse section")
    }

    var sectionExpand: String {
        ja("セクションを展開する", en: "Expand section")
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

    // MARK: - Issue #317: URL-based KLE import

    var kleUseConnectedKeyboard: String {
        ja("接続中のキーボードを使用", en: "Use connected keyboard")
    }

    var kleStatusConnected: String {
        ja("接続中:", en: "Connected:")
    }

    var kleStatusLayout: String {
        ja("レイアウト:", en: "Layout:")
    }

    var kleURLPlaceholder: String {
        ja("例: https://raw.githubusercontent.com/…/layout.json",
           en: "e.g. https://raw.githubusercontent.com/…/layout.json")
    }

    var kleURLLoadButton: String {
        ja("読み込む", en: "Load")
    }

    var kleURLReloadButton: String {
        ja("再読み込み", en: "Reload")
    }

    var kleURLLoadError: String {
        ja("URLからのKLE読み込みに失敗しました。", en: "Failed to load KLE from URL.")
    }

    // MARK: - Issue #318: Multiple KLE profiles

    var kleProfileLabel: String {
        ja("プロファイル:", en: "Profile:")
    }

    var kleProfileAdd: String {
        ja("プロファイルを追加", en: "Add profile")
    }

    var kleProfileRename: String {
        ja("プロファイル名を変更", en: "Rename profile")
    }

    var kleProfileRenameConfirm: String {
        ja("変更", en: "Rename")
    }

    var kleProfileDelete: String {
        ja("プロファイルを削除", en: "Delete profile")
    }

    var kleProfileNewName: String {
        ja("新しいプロファイル", en: "New Profile")
    }

    var kleProfileNamePlaceholder: String {
        ja("プロファイル名", en: "Profile name")
    }

    // MARK: - Issue #323: Profile summary table column headers

    var kleTableColProfile: String {
        ja("プロファイル", en: "Profile")
    }

    var kleTableColKeywords: String {
        ja("キーワード", en: "Keywords")
    }

    var kleTableColFile: String {
        ja("レイアウトファイル", en: "Layout file")
    }

    func autoMatchedCustom(_ name: String) -> String {
        ja("↳ カスタムがマッチ — \"\(name)\"", en: "↳ Custom matched — \"\(name)\"")
    }

    // Issue #284: toast shown when Auto mode switches to a non-ANSI layout
    func heatmapAutoSwitched(layout: String, device: String) -> String {
        device.isEmpty
            ? ja("レイアウトを \(layout) に切り替えました", en: "Layout switched to \(layout)")
            : ja("レイアウトを \(layout) に切り替えました — \(device) を検出", en: "Switched to \(layout) — \(device) detected")
    }

    // Issue #288: toast and caption when Auto selects Custom because KLE is imported + split device
    func heatmapAutoSwitchedToKLE(device: String, fileName: String) -> String {
        ja("KLE レイアウトを読み込みました — \(device) / \(fileName)",
           en: "Custom KLE loaded — \(device) / \(fileName)")
    }

    func kleAutoMatchedCaption(device: String, fileName: String) -> String {
        ja("↳ \(device) → \(fileName)", en: "↳ \(device) → \(fileName)")
    }

    var heatmapAutoSwitchedToANSI: String {
        ja("キーボードが取り外されました — ANSI レイアウトに戻しました", en: "Keyboard disconnected — switched back to ANSI")
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

    var hideSpeedometer: String {
        ja("速度計を非表示", en: "Hide Speedometer")
    }

    var speedometerSizeMenuTitle: String {
        ja("サイズ", en: "Size")
    }

    var speedometerSizeSmall: String {
        ja("小", en: "Small")
    }

    var speedometerSizeMedium: String {
        ja("中", en: "Medium")
    }

    var speedometerSizeLarge: String {
        ja("大", en: "Large")
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
    var manageDevices: String        { ja("デバイスを管理", en: "Manage Devices") }
    var deleteDeviceTitle: String    { ja("デバイスを削除", en: "Delete Device") }
    var deleteDeviceMessage: String  { ja("このデバイスのすべての打鍵データが削除されます。この操作は取り消せません。", en: "All keystroke data for this device will be permanently deleted. This cannot be undone.") }
    var deleteDeviceConfirm: String  { ja("削除", en: "Delete") }

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

    var helpKeyAccumulation: String {
        ja(
            "日別打鍵数の累計（ランニングトータル）を折れ線グラフで表示します。打鍵数の節目（100万回など）の達成時期を確認できます。",
            en: "Running total of all keystrokes over time. Shows when you hit major milestones such as 1 million keypresses."
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
            "打鍵パターンから推定した3つの指標とアドバイスを表示します。\n\n推定スタイル: よく使うキーの分布からタイピング用途を推定します。文字・スペース中心 → 執筆、記号・修飾キー多用 → 開発、短いパターン多用 → チャット。\n\n疲労リスク: 同一指で1行以上離れたキーを連続入力する「高負荷バイグラム」の割合で判定します。\n低（緑）: 2%以下 / 中（橙）: 2〜5% / 高（赤）: 5%超\n\nタイピングリズム: 直近50打鍵のキー間隔(IKI)の変動係数(σ/μ)で判定します。\nバースト（紫）: 集中打鍵と休止が交互 / バランス（青）: 中間 / 定常（緑青）: 一定ペース\n\nアドバイス: スタイル・リズム・疲労の組み合わせから最適な改善提案を表示します。",
            en: "Three metrics inferred from your keystroke patterns, plus a personalized tip.\n\nInferred Style: estimated from key frequency distribution. High letters/Space → Prose; high symbols/modifiers → Code; frequent short patterns → Chat.\n\nFatigue Risk: based on the high-strain bigram rate — same-finger keypairs spanning ≥1 keyboard row (e.g. F→R, J→U).\nLow (green): ≤2% / Moderate (orange): 2–5% / High (red): >5%\n\nTyping Rhythm: classified from the coefficient of variation (σ/μ) of the last 50 IKIs.\nBurst (purple): intense spurts with long pauses / Balanced (blue): mixed / Steady Flow (teal): even cadence\n\nInsight: a personalized suggestion based on the combination of your style, rhythm, and fatigue level."
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

    var typingRhythm: String {
        ja("タイピングリズム", en: "Typing Rhythm")
    }

    func typingRhythmLabel(_ rhythm: TypingRhythm) -> String {
        switch rhythm {
        case .burst:      return ja("バースト", en: "Burst")
        case .steadyFlow: return ja("定常", en: "Steady Flow")
        case .balanced:   return ja("バランス", en: "Balanced")
        case .unknown:    return ja("計測中…", en: "Measuring…")
        }
    }

    var typingInsightLabel: String {
        ja("アドバイス", en: "Insight")
    }

    /// Returns a personalized tip based on the combination of style, rhythm, and fatigue.
    func typingInsight(style: TypingStyle, rhythm: TypingRhythm, fatigue: FatigueLevel) -> String {
        // Fatigue is the highest priority signal.
        if fatigue == .high {
            switch rhythm {
            case .burst:
                return ja("バースト打鍵と高負荷バイグラムが重なっています。休憩を取るか、打鍵ペースを落としましょう。",
                          en: "Burst rhythm combined with high strain — consider a break or slow your pace.")
            default:
                return ja("高負荷バイグラムが多く検出されています。キーボードの配置やストレッチで負荷を分散させましょう。",
                          en: "High-strain bigrams detected. Try redistributing load via layout adjustments or stretching.")
            }
        }

        // Moderate fatigue + burst = actionable advice.
        if fatigue == .moderate && rhythm == .burst {
            return ja("断続的な集中打鍵が疲労を蓄積させる可能性があります。意識的にペースを一定に保ちましょう。",
                      en: "Intermittent bursts may be building fatigue. Try maintaining a more even pace.")
        }

        // Style-specific tips for normal fatigue.
        switch (style, rhythm) {
        case (.code, .burst):
            return ja("コーディング中のバースト打鍵は記号入力のミスを増やす傾向があります。ゆっくり確実に入力しましょう。",
                      en: "Burst typing during coding increases symbol errors. Slow down for accuracy.")
        case (.code, .steadyFlow):
            return ja("安定したリズムでコードを入力しています。このペースを維持しましょう。",
                      en: "Steady rhythm while coding — great for accuracy. Keep it up.")
        case (.prose, .burst):
            return ja("執筆中のバースト打鍵はバックスペースを増やす傾向があります。文章を頭の中で組み立ててから入力しましょう。",
                      en: "Burst typing during writing leads to more corrections. Think ahead before typing.")
        case (.prose, .steadyFlow):
            return ja("執筆に適した安定したリズムです。",
                      en: "Steady flow suits your writing style well.")
        case (.chat, .burst):
            return ja("チャットのバースト打鍵は自然なパターンです。ただし長時間続く場合は手首を休めましょう。",
                      en: "Burst rhythm is natural for chat. If sustained, rest your wrists periodically.")
        case (.chat, _):
            return ja("短いメッセージを頻繁に送信しています。まとめて入力するとキーストローク数を減らせます。",
                      en: "Frequent short messages detected. Batching thoughts reduces total keystrokes.")
        // Rhythm is known but style hasn't resolved yet — give rhythm-based tip.
        case (_, .burst):
            return ja("バースト打鍵が検出されました。集中的な打鍵の後は短い休憩を入れると疲労を防げます。",
                      en: "Burst rhythm detected. Short pauses between bursts help prevent fatigue.")
        case (_, .steadyFlow):
            return ja("安定したリズムで入力しています。このペースを維持しましょう。",
                      en: "Steady rhythm detected — great consistency. Keep it up.")
        case (_, .balanced):
            return ja("バランスの良いリズムです。スタイルに合わせてさらに最適化できます。",
                      en: "Balanced rhythm detected. More data will refine your personalized tip.")
        default:
            return ja("まだ分析データが蓄積中です。しばらく入力を続けてください。",
                      en: "Still gathering data. Keep typing to unlock personalized insights.")
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
        case .todayTotal:     return ja("本日", en: "Today")
        case .avgInterval:    return ja("平均打鍵間隔", en: "Avg Interval")
        case .estimatedWPM:   return ja("WPM", en: "WPM")
        case .miniChart:      return ja("直近7日グラフ", en: "Last 7 Days Chart")
        case .streak:                     return ja("ストリーク", en: "Streak")
        case .shortcutEfficiency:         return ja("ショートカット効率", en: "Shortcut Efficiency")
        case .mouseDistance:              return ja("マウス移動距離", en: "Mouse Distance")
        case .slowEvents:                 return ja("低速イベント数", en: "Slow Events")
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

    /// Compact single-line streak + goal progress for the menu.
    func streakCompact(streak: Int, today: Int, goal: Int) -> String {
        let pct = goal > 0 ? min(100, today * 100 / goal) : 0
        let streakPart = streak > 0
            ? ja("🔥 \(streak)日", en: "🔥 \(streak)-day")
            : ja("🔥 0日", en: "🔥 0-day")
        let goalPart = ja("\(today.formatted())/\(goal.formatted()) (\(pct)%)",
                          en: "\(today.formatted())/\(goal.formatted()) (\(pct)%)")
        return "\(streakPart)  \(goalPart)"
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

        let distStr: String
        if meters >= 1000 {
            distStr = String(format: "%.2f km", meters / 1000)
        } else {
            distStr = String(format: "%.0f m", meters)
        }

        return ja("🖱 本日: \(distStr)",
                  en: "🖱 Today: \(distStr)")
    }

    var mouseDistanceNoData: String {
        ja("🖱 移動距離データなし", en: "🖱 No mouse distance data yet")
    }

    // MARK: - Slow Events

    func slowEventsDisplay(_ count: Int) -> String {
        ja("低速イベント: \(count)件", en: "Slow events: \(count)")
    }

    var slowEventsNone: String {
        ja("低速イベント: なし", en: "Slow events: none")
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

    // MARK: - Issue #217: Mouse Position Heatmap

    var chartTitleMouseHeatmap: String {
        ja("マウス位置ヒートマップ", en: "Mouse Position Heatmap")
    }

    var helpMouseHeatmap: String {
        ja("画面上のマウス移動をグリッドで可視化します。赤いほど頻繁に通過した領域です。",
           en: "Visualises where on screen your mouse travels most. Red cells indicate the most visited areas.")
    }

    // MARK: - Issue #78: Weekly Activity Heatmap

    var chartTitleWeeklyHeatmap: String {
        ja("週間活動ヒートマップ", en: "Weekly Activity Heatmap")
    }

    var helpWeeklyHeatmap: String {
        ja(
            "曜日 (列) と時刻 (行) ごとの平均打鍵数を色の濃さで表します。濃いほど入力量が多い時間帯です。全記録期間の平均値を表示します。",
            en: "Average keystrokes per hour for each day of the week, across all recorded dates. Darker cells indicate more typing activity."
        )
    }

    /// Weekday abbreviations ordered Sunday–Saturday (index 0–6).
    /// 曜日略称、日〜土 (添字 0–6)。
    var weekdayAbbrs: [String] {
        resolved == .japanese
            ? ["日", "月", "火", "水", "木", "金", "土"]
            : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    }

    /// Full weekday names ordered Sunday–Saturday (index 0–6).
    /// 曜日フル名称、日〜土 (添字 0–6)。
    var weekdayFullNames: [String] {
        resolved == .japanese
            ? ["日曜", "月曜", "火曜", "水曜", "木曜", "金曜", "土曜"]
            : ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    }

    /// Tooltip label for heatmap cell: "avg N keys" / "平均 N キー".
    func heatmapAvgLabel(_ count: Int) -> String {
        ja("平均 \(count) キー", en: "avg \(count) keys")
    }

    var heatmapMetricKeys: String {
        ja("打鍵数", en: "Keystrokes")
    }

    var heatmapMetricWPM: String {
        ja("WPM", en: "WPM")
    }

    var heatmapNoWPMData: String {
        ja("—", en: "—")
    }

    // Issue #292: Session Rhythm Heatmap
    var chartTitleSessionRhythm: String {
        ja("セッションリズム", en: "Session Rhythm")
    }
    var helpSessionRhythm: String {
        ja("曜日×時刻ごとのセッション数・平均時間を表示します。ピークタイムや習慣的な作業パターンを把握できます。",
           en: "Shows session count and average duration broken down by day-of-week × hour. Reveals your peak times and habitual work patterns.")
    }
    var sessionRhythmMetricCount: String {
        ja("セッション数", en: "Count")
    }
    var sessionRhythmMetricDuration: String {
        ja("平均時間", en: "Duration")
    }
    func sessionRhythmTooltip(day: String, hour: Int, count: Int, durationMin: Double) -> String {
        let hourStr = String(format: "%02d:00", hour)
        let dur = String(format: "%.0f", durationMin)
        return ja("\(day) \(hourStr)  ·  \(count)セッション  ·  平均\(dur)分",
                  en: "\(day) \(hourStr)  ·  \(count) sessions  ·  avg \(dur) min")
    }

    var calendarLegendLow: String {
        ja("少", en: "Low")
    }

    var calendarLegendHigh: String {
        ja("多", en: "High")
    }

    // MARK: - Issue #60: Session detection

    var chartTitleSessions: String {
        ja("セッション", en: "Sessions")
    }

    var helpSessions: String {
        ja(
            "5分以上キー入力がなかった場合にセッションの区切りとして検出します。セッション数・最長セッション時間・平均セッション時間を日別に表示します。連続アクティブ日数 (Streak) は、少なくとも1回セッションが記録された日が何日連続しているかを示します。",
            en: "A session boundary is detected when there is no keystroke for 5 or more minutes. Shows daily session count, longest session duration, and average session duration. The streak counter shows how many consecutive days have had at least one recorded session."
        )
    }

    // Issue #290: session streak
    var sessionStreakTitle: String {
        ja("連続アクティブ日数", en: "Active Day Streak")
    }

    func sessionStreakDisplay(_ n: Int) -> String {
        n > 0
            ? ja("🔥 \(n)日連続", en: "🔥 \(n)-day streak")
            : ja("ストリークなし", en: "No streak yet")
    }

    // Issue #291: outlier annotation label shown on session chart bars that exceed mean + 1.5×stddev
    var outlierLabel: String {
        ja("↑ ピーク", en: "↑ Peak")
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

    // Drill speed threshold filter (Issue #231)
    var drillSpeedThresholdLabel: String { ja("スピード閾値:", en: "Speed threshold:") }
    var drillSpeedThresholdOff: String   { ja("オフ (全バイグラム)", en: "Off (all bigrams)") }
    func drillSpeedThresholdValue(_ ms: Int) -> String {
        ja("≥ \(ms) ms のみ", en: "≥ \(ms) ms only")
    }
    var drillSpeedThresholdReset: String { ja("リセット", en: "Reset") }

    // MARK: - Chart Axis Labels

    var axisLabelKeys: String     { ja("キー数", en: "Keys") }
    var axisLabelWPM: String      { ja("WPM", en: "WPM") }
    var axisLabelPercent: String  { ja("%", en: "%") }
    var axisLabelSessions: String { ja("セッション数", en: "Sessions") }
    var axisLabelMinutes: String  { ja("分", en: "min") }
    var axisLabelDate: String     { ja("日付", en: "Date") }
    var axisLabelHourOfDay: String { ja("時間帯", en: "Hour of Day") }

    // MARK: - Chart Theme

    var chartThemeMenuTitle: String { ja("チャートテーマ", en: "Chart Theme") }

    var appearanceMenuTitle: String { ja("外観", en: "Appearance") }

    func appearanceDisplayName(_ appearance: AppAppearance) -> String {
        switch appearance {
        case .system: return ja("システム", en: "System")
        case .light:  return ja("ライト",   en: "Light")
        case .dark:   return ja("ダーク",   en: "Dark")
        }
    }

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

    // MARK: - Modifier Finger Analysis (Issue #334)

    var modifierFingerTitle: String {
        ja("モディファイアキーの指別分析", en: "Modifier Keys by Finger")
    }

    var modifierFingerHelp: String {
        ja("各モディファイアキー (⌘⇧⌥⌃) が何の指で押されているかを示します。親指クラスターに移動したキーは「Thumb」として表示されます。",
           en: "Shows which finger presses each modifier key (⌘⇧⌥⌃). Keys moved to a thumb cluster appear as Thumb.")
    }

    var modifierFingerNoData: String {
        ja("モディファイアキーのデータなし", en: "No modifier key data yet")
    }

    func modifierFingerSummary(thumbPct: Int, pinkyPct: Int) -> String {
        ja("親指 \(thumbPct)%  /  小指 \(pinkyPct)%",
           en: "Thumb \(thumbPct)%  /  Pinky \(pinkyPct)%")
    }

    // MARK: - Thumb Cluster Config (Issue #333)

    var thumbClusterConfigTitle: String {
        ja("親指クラスター設定", en: "Thumb Cluster Config")
    }

    var thumbClusterConfigHelp: String {
        ja("DIYキーボードで親指クラスターに割り当てたキーを選択してください。選択したキーはすべてのエルゴノミクス分析で親指として扱われます。",
           en: "Select keys that are physically on your thumb cluster. These keys will be treated as thumb-assigned in all ergonomic analysis.")
    }

    var thumbClusterConfigNone: String {
        ja("親指クラスターキーなし (標準配列)", en: "No thumb cluster keys (standard layout)")
    }

    var thumbClusterConfigActive: String {
        ja("親指クラスター: ", en: "Thumb cluster: ")
    }

    var thumbClusterConfigDone: String {
        ja("完了", en: "Done")
    }

    var thumbClusterConfigPresetCommon: String {
        ja("基本 (Delete + Return)", en: "Common (Delete + Return)")
    }

    var thumbClusterConfigPresetExtended: String {
        ja("拡張 (Delete, Return, Tab, Escape, CapsLock)", en: "Extended (Delete, Return, Tab, Escape, CapsLock)")
    }

    var thumbClusterConfigPresetNone: String {
        ja("なし", en: "None")
    }

    var thumbClusterConfigPresetLabel: String {
        ja("プリセット", en: "Preset")
    }

    // MARK: - Thumb Optimization (Issue #208)

    var handLeft:  String { ja("左", en: "Left") }
    var handRight: String { ja("右", en: "Right") }

    var thumbOptimizationToggle: String {
        ja("親指キー最適化を有効にする（スプリットキーボード向け）",
           en: "Enable Thumb Key Optimization (for split keyboards)")
    }

    var thumbSuggestionsHeader: String {
        ja("親指キー提案", en: "Thumb Key Suggestions")
    }

    var thumbSuggestionsEmpty: String {
        ja("現在のデータでは親指キーへの移動提案はありません",
           en: "No thumb key relocation suggestions with current data")
    }

    func thumbSuggestionRow(key: String, slot: String, reduction: Double) -> String {
        ja("「\(key)」→ \(slot)親指クラスター（負荷軽減 \(String(format: "%.0f", reduction))）",
           en: "\"\(key)\" → \(slot) thumb cluster (burden reduction \(String(format: "%.0f", reduction)))")
    }

    // MARK: - Activity Calendar Accessibility

    func calendarDayAccessibilityLabel(dateLabel: String, count: Int) -> String {
        count == 0
            ? ja("\(dateLabel)、打鍵なし", en: "\(dateLabel), no keystrokes")
            : ja("\(dateLabel)、\(count)打鍵", en: "\(dateLabel), \(count) keystrokes")
    }

    var calendarLegendAccessibility: String {
        ja("打鍵強度の凡例：少ない から 多い", en: "Keystroke intensity legend, from less to more")
    }

    // MARK: - Weekly Heatmap Accessibility (Issue #344)

    func heatmapCellAccessibilityLabel(weekday: String, hour: Int, avgCount: Double, avgWPM: Double?) -> String {
        let hourStr = String(format: "%02d:00", hour)
        let countPart: String = avgCount < 0.5
            ? ja("打鍵なし", en: "no keystrokes")
            : ja("平均 \(Int(avgCount.rounded()))打鍵", en: "avg \(Int(avgCount.rounded())) keystrokes")
        if let wpm = avgWPM, wpm >= 0.5 {
            let wpmStr = String(format: "%.0f", wpm)
            return ja("\(weekday) \(hourStr)、\(countPart)、\(wpmStr) WPM",
                      en: "\(weekday) \(hourStr), \(countPart), \(wpmStr) WPM")
        }
        return ja("\(weekday) \(hourStr)、\(countPart)", en: "\(weekday) \(hourStr), \(countPart)")
    }

    // MARK: - Layer Mapping (Issue #209)

    var layerMappingMenuTitle: String {
        ja("レイヤーキー設定…", en: "Layer Key Mapping…")
    }

    var layerMappingWindowTitle: String {
        ja("レイヤーキーマッピング", en: "Layer Key Mapping")
    }

    var layerMappingLayerKeysSection: String {
        ja("レイヤーキー", en: "Layer Keys")
    }

    var layerMappingOutputKeysSection: String {
        ja("出力キー → 物理キー", en: "Output Key → Physical Key")
    }

    var layerMappingAddLayerKey: String {
        ja("レイヤーキーを追加", en: "Add Layer Key")
    }

    var layerMappingAddMapping: String {
        ja("マッピングを追加", en: "Add Mapping")
    }

    var layerMappingLayerKeyName: String {
        ja("名前 (例: Lower)", en: "Name (e.g. Lower)")
    }

    var layerMappingFinger: String {
        ja("担当指", en: "Finger")
    }

    var layerMappingOutputKey: String {
        ja("出力キー (例: ←)", en: "Output key (e.g. ←)")
    }

    var layerMappingBaseKey: String {
        ja("ベースキー (例: J)", en: "Base key (e.g. J)")
    }

    var layerMappingEmpty: String {
        ja("まだ設定がありません", en: "No mappings configured")
    }

    var layerMappingNoLayerKeys: String {
        ja("まずレイヤーキーを追加してください", en: "Add a layer key first")
    }

    var layerEfficiencyTitle: String {
        ja("レイヤー効率", en: "Layer Efficiency")
    }

    var layerEfficiencyHelp: String {
        ja(
            "ファームウェアレイヤーキー (Lower, Raise など) の使用回数、担当指の負荷、および同指率・交互打鍵率・高負荷率を表示します。レイヤーキーマッピングを設定すると有効になります。",
            en: "Shows usage count, finger assignment, and ergonomic rates (same-finger, hand alternation, high-strain) for firmware layer keys (Lower, Raise, etc.). Requires Layer Key Mapping to be configured."
        )
    }

    // Issue #236: per-layer ergonomic rate labels
    var layerErgSF: String { ja("同指", en: "SF") }
    var layerErgHA: String { ja("交互", en: "HA") }
    var layerErgHS: String { ja("高負荷", en: "HS") }

    var layerEfficiencyNoData: String {
        ja("レイヤーキーマッピングが未設定です", en: "No layer key mappings configured")
    }

    var layerEfficiencyPresses: String {
        ja("回", en: "presses")
    }

    // MARK: - Bigram IKI Heatmap (#238)

    var bigramIKIHeatmapTitle: String {
        ja("バイグラムIKIヒートマップ", en: "Bigram IKI Heatmap")
    }

    var helpBigramIKIHeatmap: String {
        ja(
            "キーペア（バイグラム）ごとの平均キー間隔 (IKI) を2次元マトリクスで表示します。行が「打鍵元」、列が「打鍵先」のキーです。\n\n色の意味: 緑=速い（低IKI）、赤=遅い（高IKI）。灰色=データなし。\n\nN個のピッカーで軸に表示するキー数（打鍵頻度上位N個）を変更できます。セルにカーソルを合わせると正確なms値が表示されます。\n\n遅いバイグラムはタイピング改善のトレーニング候補です。",
            en: "A matrix of average inter-keystroke interval (IKI) for each key pair (bigram). Rows = 'from' key, columns = 'to' key.\n\nColor: green = fast (low IKI), red = slow (high IKI). Gray = no data recorded.\n\nUse the N picker to change how many keys (top-N by frequency) appear on each axis. Hover a cell to see the exact millisecond value.\n\nSlow bigrams are good candidates for typing practice."
        )
    }

    var bigramHeatmapTop: String  { ja("上位", en: "Top") }
    var bigramHeatmapKeys: String { ja("キー", en: "keys") }
    var bigramHeatmapFast: String { ja("速い", en: "Fast") }
    var bigramHeatmapSlow: String { ja("遅い", en: "Slow") }

    var bigramHeatmapNoData: String {
        ja("バイグラムIKIデータがまだありません。しばらくタイピングすると表示されます。",
           en: "No bigram IKI data yet. Type for a while and the heatmap will appear.")
    }

    var bigramHeatmapHoverHint: String {
        ja("セルにカーソルを合わせると詳細を表示", en: "Hover a cell to see details")
    }

    // MARK: - Key Inspector (#246)

    var tabInspector: String { ja("インスペクタ", en: "Inspector") }

    var keyInspectorSection: String {
        ja("キーイベント検査", en: "Key Event Inspector")
    }

    var helpKeyInspector: String {
        ja(
            "打鍵ごとのイベント詳細をリアルタイムで表示します。\n\n• キー: 論理キー名 (表示文字)\n• コード: 物理キーコード (CGKeyCode)\n• 場所: Standard (通常) / Left / Right / Numpad\n• フラグ: 同時に押されている修飾キーの記号\n• 押下時間: キーダウンからキーアップまでの時間 (ms) — デバウンス閾値の調整に役立ちます\n• フラグ(生): CGEventFlags の生ビットマスク (64ビット16進数)。修飾キーのピル (⌘ ⌥ ⌃ ⇧) はどのキーかのみ示し左右の区別はできません。生値はその区別を示します — 例: 左Shift = 0x00020002、右Shift = 0x00020004。ファームウェアやリマッピングツールのデバッグに役立ちます。\n• HID: USB HID 使用ページ / 使用ID (16進数) — QMK・ZMK 等のファームウェアのキーコードと直接対応します\n\n「現在押中のキー」は実際に押し続けているキーをリアルタイムで表示します。",
            en: "Shows detailed event information for each keystroke in real time.\n\n• Key: logical key name\n• Code: physical key code (CGKeyCode)\n• Location: Standard / Left / Right / Numpad\n• Flags: modifier symbols active at the time of the keypress\n• Hold: duration from keydown to keyup in ms — useful for tuning debounce thresholds\n• Raw Flags: the raw CGEventFlags bitmask (64-bit hex). The modifier pills (⌘ ⌥ ⌃ ⇧) show which modifier is active but not which side. The raw value distinguishes them — e.g. Left Shift = 0x00020002, Right Shift = 0x00020004. Useful for debugging firmware or remapping tools.\n• HID: USB HID usage page / usage ID in hex — maps to the hardware key code used in QMK, ZMK, and other firmware.\n\n\"Held Keys\" shows all keys physically held down right now."
        )
    }

    var inspectorFieldKey: String      { ja("キー",  en: "Key") }
    var inspectorFieldCode: String     { ja("コード", en: "Code") }
    var inspectorFieldLocation: String { ja("場所",  en: "Location") }
    var inspectorFieldFlags: String    { ja("修飾",  en: "Flags") }
    var inspectorFieldHold: String     { ja("押下時間", en: "Hold") }
    var inspectorFieldRawFlags: String { ja("フラグ(生)", en: "Raw Flags") }
    var inspectorFieldHID: String      { ja("HID", en: "HID") }
    var inspectorFieldHIDName: String  { ja("キー名", en: "Name") }

    var inspectorLocationStandard: String { ja("Standard", en: "Standard") }
    var inspectorLocationLeft: String     { ja("Left",     en: "Left") }
    var inspectorLocationRight: String    { ja("Right",    en: "Right") }
    var inspectorLocationNumpad: String   { ja("Numpad",   en: "Numpad") }

    var inspectorWaiting: String {
        ja("キーを押すとここに詳細が表示されます", en: "Press any key to see event details here.")
    }

    var inspectorNoHeldKeys: String {
        ja("現在押中のキーなし", en: "No keys currently held")
    }

    var inspectorHeldKeys: String {
        ja("現在押中のキー", en: "Held Keys")
    }

    // MARK: - Training Progress (Issue #233)

    var trainingProgressTitle: String { ja("トレーニング進捗", en: "Training Progress") }
    var helpTrainingProgress: String {
        ja("直近20セッション分の IKI 推移を可視化します。最も練習したバイグラムの改善傾向を折れ線グラフで表示します。",
           en: "Visualizes IKI trends across training sessions. Shows improvement in your most-practiced bigrams over the last 20 sessions.")
    }
    var trainingProgressTotalSessions: String { ja("総セッション数", en: "Total Sessions") }
    var trainingProgressStreak: String { ja("連続日数", en: "Day Streak") }
    var trainingProgressBestImprovement: String { ja("最大改善", en: "Best Improvement") }
    var trainingProgressNoBestImprovement: String { ja("—", en: "—") }
    var trainingProgressChartNoData: String {
        ja("トレーニングを完了するとIKI推移グラフが表示されます。",
           en: "Complete training sessions to see your IKI trend here.")
    }
    var trainingProgressIKIAxis: String { ja("IKI (ms)", en: "IKI (ms)") }

    // MARK: - Charts: Section Titles (Issue #266)

    var chartTitleActivityCalendar: String { ja("アクティビティカレンダー", en: "Activity Calendar") }
    var chartTitleWeeklyReport: String { ja("週次レポート", en: "Weekly Report") }
    var chartTitleHourlyDistribution: String { ja("時間別分布", en: "Hourly Distribution") }
    var chartTitleDailyTotals: String { ja("日別合計", en: "Daily Totals") }
    var chartTitleMonthlyTotals: String { ja("月別合計", en: "Monthly Totals") }
    var chartTitleKeyAccumulation: String { ja("累計打鍵数", en: "Key Accumulation") }
    var accumDeviceFilterAll: String      { ja("全デバイス", en: "All Devices") }
    var chartTitleKeyboardHeatmap: String { ja("キーボードヒートマップ", en: "Keyboard Heatmap") }
    var chartTitleTopKeys: String { ja("上位20キー — 全期間", en: "Top 20 Keys — All Time") }
    var chartTitleKeyCategories: String { ja("キー分類", en: "Key Categories") }
    var chartTitleTopKeysPerDay: String { ja("日別上位10キー", en: "Top 10 Keys per Day") }
    var chartTitleTopBigrams: String { ja("上位20バイグラム", en: "Top 20 Bigrams") }
    var chartTitleLearningCurve: String { ja("エルゴノミクス学習曲線", en: "Ergonomic Learning Curve") }
    var chartTitleLayoutComparison: String { ja("レイアウト比較", en: "Layout Comparison") }
    var chartTitleCmdShortcuts: String { ja("⌘ キーボードショートカット", en: "⌘ Keyboard Shortcuts") }
    var chartTitleAllCombos: String { ja("全キーボードコンボ", en: "All Keyboard Combos") }

    // MARK: - Charts: Common UI Labels (Issue #266)

    var noDataYet: String { ja("(データなし)", en: "(no data yet)") }
    var copyChartAsImageHelp: String { ja("チャートを画像としてコピー", en: "Copy chart as image") }
    var sortDescendingHelp: String { ja("降順 (最多から)", en: "Descending (Most frequent first)") }
    var sortAscendingHelp: String { ja("昇順 (最少から)", en: "Ascending (Least frequent first)") }
    var weeklyReportNeedTwoWeeks: String { ja("2週間以上のデータが必要です", en: "Need at least two weeks of data") }
    var tableHeaderMetric: String { ja("指標", en: "Metric") }
    var tableHeaderThisWeek: String { ja("今週", en: "This week") }
    var tableHeaderLastWeek: String { ja("先週", en: "Last week") }
    var tableHeaderErgoScore: String { ja("エルゴスコア", en: "Ergo Score") }
    var tableHeaderTravel: String { ja("移動距離", en: "Travel") }
    var tableHeaderCurrent: String { ja("現在", en: "Current") }
    var tableHeaderProposed: String { ja("提案", en: "Proposed") }
    var tableHeaderChange: String { ja("変化", en: "Change") }
    var fingerFilterAll: String { ja("すべて", en: "All") }

    // MARK: - Charts: Live Tab (Issue #266)

    var liveSubTabMonitor: String      { ja("モニター",  en: "Monitor") }
    var liveSubTabIntelligence: String { ja("分析",      en: "Intelligence") }
    var liveSubTabWPMTest: String      { ja("WPMテスト", en: "WPM Test") }

    var activitySubTabSpeed: String    { ja("スピード",  en: "Speed") }
    var activitySubTabPatterns: String { ja("パターン",  en: "Patterns") }
    var activitySubTabVolume: String   { ja("ボリューム", en: "Volume") }

    var keyboardSubTabHeatmap: String  { ja("ヒートマップ", en: "Heatmap") }
    var keyboardSubTabTopKeys: String  { ja("頻度",        en: "Top Keys") }

    var trainingSubTabDrill: String    { ja("ドリル",    en: "Drill") }
    var trainingSubTabProgress: String { ja("進捗",      en: "Progress") }
    var trainingSubTabTargets: String  { ja("ターゲット", en: "Targets") }

    var drillPresetsLabel: String       { ja("プリセット",          en: "Presets") }
    var drillPresetsEmpty: String       { ja("保存済みプリセットなし", en: "No saved presets") }
    var drillPresetsSaveCurrent: String { ja("現在の設定を保存",      en: "Save current settings") }
    var drillPresetsDelete: String      { ja("削除",                en: "Delete") }

    var mouseSubTabDistance: String    { ja("距離",          en: "Distance") }
    var mouseSubTabDirection: String   { ja("方向",          en: "Direction") }
    var mouseSubTabClicks: String      { ja("クリック",      en: "Clicks") }
    var mouseSubTabHeatmap: String     { ja("ヒートマップ",  en: "Heatmap") }

    var appsSubTabApps: String         { ja("アプリ",    en: "Apps") }
    var appsSubTabDevices: String      { ja("デバイス",  en: "Devices") }

    // MARK: - Typing tab sub-tabs (#311)

    var typingSubTabLive: String       { ja("ライブ",        en: "Live") }
    var typingSubTabActivity: String   { ja("アクティビティ", en: "Activity") }
    var typingSubTabKeyboard: String   { ja("キーボード",     en: "Keyboard") }
    var typingSubTabShortcuts: String  { ja("ショートカット", en: "Shortcuts") }
    var typingSubTabApps: String       { ja("アプリ",         en: "Apps") }
    var typingSubTabDevices: String    { ja("デバイス",       en: "Devices") }

    var ergoSubTabRecommendations: String { ja("提案",             en: "Tips") }
    var ergoSubTabBigrams: String      { ja("バイグラム",         en: "Bigrams") }
    var ergoSubTabLayout: String       { ja("レイアウト",         en: "Layout") }
    var ergoSubTabFatigue: String      { ja("疲労",              en: "Fatigue") }
    var ergoSubTabOptimizer: String    { ja("オプティマイザ",     en: "Optimizer") }
    var ergoSubTabComparison: String   { ja("比較",              en: "Compare") }

    // MARK: - Charts: Key Swap Optimizer (Issue #235)

    var optimizerTitle: String         { ja("キースワップシミュレータ",  en: "Key Swap Simulator") }
    var optimizerInstruction: String   {
        ja("キーをドラッグしてスワップ。ダブルクリックでロック/解除。",
           en: "Drag a key onto another to swap. Double-click to lock/unlock.")
    }
    var optimizerScoreBefore: String   { ja("変更前",            en: "Before") }
    var optimizerScoreAfter: String    { ja("変更後",            en: "After") }
    var optimizerResetButton: String   { ja("リセット",          en: "Reset") }
    var optimizerUndoButton: String    { ja("元に戻す",          en: "Undo") }
    var optimizerExportButton: String  { ja("レイアウトを保存",  en: "Export Layout") }
    var optimizerSwapCount: String     { ja("スワップ",          en: "swap(s)") }
    var optimizerExported: String      { ja("保存済み: ",        en: "Saved: ") }
    var optimizerNoData: String        {
        ja("データ不足。しばらくタイプしてからお試しください。",
           en: "Not enough data yet. Type for a while first.")
    }
    var optimizerHelpText: String      {
        ja("キーをドラッグしてスワップし、エルゴノミクススコアの変化をリアルタイムでプレビューします。ダブルクリックでキーをロック。",
           en: "Drag keys to simulate swaps and preview the ergonomic score change live. Double-click a key to lock it in place.")
    }
    var optimizerSwapHistoryTitle: String { ja("スワップ履歴",   en: "Swap History") }

    // MARK: - Issue #304: VoiceOver accessibility labels for optimizer

    func accessibilityKeyLabel(key: String, isSelected: Bool, isLocked: Bool, originalSlot: String) -> String {
        let isChanged = key != originalSlot
        let stateEN: String
        let stateJA: String
        if isSelected {
            stateEN = ", selected"; stateJA = "、選択中"
        } else if isLocked {
            stateEN = ", locked";   stateJA = "、ロック中"
        } else if isChanged {
            stateEN = ", swapped from \(originalSlot)"; stateJA = "、\(originalSlot)から移動"
        } else {
            stateEN = ""; stateJA = ""
        }
        return resolved == .japanese
            ? "\(key)キー\(stateJA)"
            : "Key \(key)\(stateEN)"
    }

    var accessibilityKeyHint: String {
        ja("タップで選択、ダブルタップでロック切替",
           en: "Tap to select or swap. Double-tap to toggle lock.")
    }

    func accessibilitySwapHistoryItem(index: Int, from: String, to: String) -> String {
        resolved == .japanese
            ? "スワップ\(index):\(from)と\(to)を交換"
            : "Swap \(index): \(from) and \(to)"
    }
    var optimizerScoreFormula: String     {
        ja("スコア = 100 − 0.30×同指 − 0.25×高負荷 − 0.15×親指偏り − 0.20×行到達 + 0.20×交互 + 0.10×親指効率  (0〜100 に丸め)",
           en: "score = 100 − 0.30×SFB − 0.25×HS − 0.15×TI − 0.20×Reach + 0.20×Alt + 0.10×TE  (clamped 0–100)")
    }
    var optimizerTravelNote: String       {
        ja("※ 行到達 = 頻度加重平均のホーム行からの距離 (正規化)。フィンガートラベルは参考値のみ。",
           en: "* Reach = frequency-weighted mean row distance from home row (normalised). Finger travel is shown for reference only.")
    }

    var liveTypingHint: String {
        ja("このウィンドウを開いたままタイプするとライブタイミングが表示されます。",
           en: "Type with this window open to see live timing.")
    }
    var ikiSpeedFast: String { ja("速い (<150ms)", en: "Fast (<150ms)") }
    var ikiSpeedMedium: String { ja("普通", en: "Medium") }
    var ikiSpeedSlow: String { ja("遅い (>400ms)", en: "Slow (>400ms)") }
    var wpmRecording: String { ja("記録中…", en: "Recording…") }

    // MARK: - Charts: Ergonomics / Layout Comparison (Issue #266)

    var ergoMetricSameFingerRate: String { ja("同指率", en: "Same-finger rate") }
    var ergoMetricHandAltRate: String { ja("交互打鍵率", en: "Hand alternation rate") }
    var ergoMetricHandAlt: String { ja("交互打鍵", en: "Hand alternation") }
    var ergoMetricErgoScore: String { ja("エルゴノミクススコア", en: "Ergonomic score") }
    var ergoMetricHighStrainRate: String { ja("高負荷率", en: "High-strain rate") }
    var ergoMetricThumbImbalance: String { ja("親指アンバランス", en: "Thumb imbalance") }
    var ergoMetricFingerTravel: String { ja("指移動距離", en: "Finger travel") }
    var layoutComparisonCalculating: String { ja("レイアウト比較を計算中…", en: "Calculating layout comparison…") }
    var layoutComparisonNeedData: String {
        ja("レイアウト比較を計算するにはより多くのタイピングデータが必要です",
           en: "Need more typing data to compute layout comparison")
    }
    var layerAllTimePressesAxis: String { ja("全期間プレス数", en: "All-time presses") }

    func ergoMetricAllTime(_ percent: Int) -> String { ja("全期間: \(percent)%", en: "All-time: \(percent)%") }
    func ergoMetricToday(_ percent: Int) -> String { ja("本日: \(percent)%", en: "Today: \(percent)%") }
    func recommendedSwapsLabel(_ swaps: String) -> String { ja("推奨スワップ: \(swaps)", en: "Recommended swaps: \(swaps)") }
    func layoutBasedOnBigrams(_ count: String) -> String {
        ja("合計 \(count) バイグラムに基づく。あなたのレイアウトが現在のベースライン。代替案はエルゴノミクススコア順。",
           en: "Based on \(count) bigrams. Your Layout is your current baseline; alternatives sorted by ergonomic score.")
    }
    func layerKeyTodayCount(_ count: Int, pressesLabel: String) -> String {
        ja("本日: \(count) \(pressesLabel)", en: "Today: \(count) \(pressesLabel)")
    }
    func layerKeyAllTimeCount(_ count: Int, pressesLabel: String) -> String {
        ja("全期間: \(count) \(pressesLabel)", en: "All-time: \(count) \(pressesLabel)")
    }

    // MARK: - Menu: Ergonomic Recommendations (Issue #299)

    var recommendationsSectionTitle: String {
        ja("改善提案", en: "Recommendations")
    }
    var recommendationsEmpty: String {
        ja("現在の改善提案はありません", en: "No recommendations right now")
    }
    func ergoRecTitle(_ key: String) -> String {
        switch key {
        case "ergoRec.sameFinger.title":  return ja("同指打鍵を減らす",         en: "Reduce same-finger bigrams")
        case "ergoRec.outerColumn.title": return ja("高負荷バイグラムを避ける", en: "Avoid high-strain bigrams")
        case "ergoRec.alternation.title": return ja("交互打鍵を増やす",         en: "Improve hand alternation")
        case "ergoRec.rowReach.title":    return ja("ホーム行を活用する",       en: "Stay closer to the home row")
        default: return key
        }
    }
    func ergoRecDetail(_ key: String) -> String {
        switch key {
        case "ergoRec.sameFinger.detail":  return ja("隣接キーは別の指で打ちましょう",
                                                     en: "Avoid pressing adjacent keys with the same finger")
        case "ergoRec.outerColumn.detail": return ja("行をまたぐ同指連打はスコアを下げます",
                                                     en: "Same-finger bigrams that span rows lower your score")
        case "ergoRec.alternation.detail": return ja("左右交互に打鍵すると疲労が減ります",
                                                     en: "Alternating hands reduces strain and improves rhythm")
        case "ergoRec.rowReach.detail":    return ja("上下の行への移動が多めです。ホーム行寄りのキーを意識しましょう",
                                                     en: "You reach beyond the home row often — aim for home-row keys where possible")
        default: return key
        }
    }
    func recImpact(_ pts: Int) -> String { ja("+\(pts)pt", en: "+\(pts)pt") }

    // MARK: - Shortcut Strain Analysis (Issue #335)

    var shortcutStrainTitle: String {
        ja("ショートカット負荷分析", en: "Shortcut Strain")
    }

    var shortcutStrainHelp: String {
        ja("モディファイアキーとベースキーが同じ手にある場合、片手でストレッチが必要になり負荷が高まります。頻度の高いコンボほど影響が大きくなります。",
           en: "A shortcut is strained when the modifier and base key are on the same hand, forcing a one-handed stretch. Higher-frequency combos have greater impact.")
    }

    var shortcutStrainNoData: String {
        ja("片手ショートカットは検出されませんでした", en: "No same-hand shortcuts detected")
    }

    func shortcutStrainRate(pct: Int, sameCount: Int, totalCount: Int) -> String {
        ja("同手率 \(pct)%（\(sameCount) / \(totalCount) 押下）",
           en: "Same-hand rate: \(pct)% (\(sameCount) of \(totalCount) presses)")
    }

    // MARK: - Advanced Mode (#307)

    var advancedModeMenuTitle: String { ja("高度なモード", en: "Advanced Mode") }
    var advancedModeOn: String { ja("高度なモード: オン", en: "Advanced Mode: On") }
    var advancedModeOff: String { ja("高度なモード: オフ", en: "Advanced Mode: Off") }

    // MARK: - Helper

    private func ja(_ japanese: String, en english: String) -> String {
        resolved == .japanese ? japanese : english
    }
}
