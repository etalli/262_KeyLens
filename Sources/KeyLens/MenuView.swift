import AppKit
import Charts
import ServiceManagement
import SwiftUI

// MARK: - MenuView

struct MenuView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @ObservedObject private var widgetStore = MenuWidgetStore.shared
    @ObservedObject private var theme = ThemeStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusRow
            divider
            statsSection
            divider
            actionRow
            divider
            settingsSection
            divider
            footerRow
        }
        .frame(width: 280)
        .padding(.vertical, 6)
    }

    // MARK: - Status

    private var statusRow: some View {
        let l = L10n.shared
        let isRunning = appDelegate.isMonitoring
        return HStack(spacing: 6) {
            if isRunning {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text(l.monitoringActive.dropFirst(2))
                    .font(.system(size: 13, weight: .medium))
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                Button(l.monitoringStopped.dropFirst(2)) {
                    appDelegate.openAccessibilitySettings()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.orange)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Stats

    private var statsSection: some View {
        let l = L10n.shared
        let store = KeyCountStore.shared
        let widgets = MenuWidgetStore.shared.orderedEnabled
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(widgets) { widget in
                switch widget {
                case .recordingSince:
                    infoRow(l.recordingSince(store.startedAt), icon: "calendar")
                case .todayTotal:
                    infoRow(String(format: l.todayFormat, store.todayCount.formatted()))
                case .avgInterval:
                    if let avgMs = store.averageIntervalMs {
                        infoRow(String(format: l.avgIntervalFormat, avgMs), icon: "timer")
                    }
                case .estimatedWPM:
                    if let wpm = store.estimatedWPM {
                        menuRow(String(format: l.estimatedWPMFormat, wpm), icon: "speedometer") {
                            appDelegate.showCharts(tab: .typing)
                        }
                    }
                case .miniChart:
                    MiniDailyBarChart()
                case .streak:
                    let goal   = KeyCountStore.shared.dailyGoal
                    let streak = KeyCountStore.shared.currentStreak()
                    let today  = KeyCountStore.shared.todayCount
                    if goal > 0 {
                        infoRow(l.streakCompact(streak: streak, today: today, goal: goal))
                    } else {
                        infoRow(l.streakNoGoalHint)
                    }
                case .shortcutEfficiency:
                    if let pct = KeyCountStore.shared.shortcutEfficiencyToday() {
                        infoRow(l.shortcutEfficiencyDisplay(pct))
                    } else {
                        infoRow(l.shortcutEfficiencyNoData)
                    }
                case .mouseDistance:
                    if let pts = MouseStore.shared.distanceToday() {
                        menuRow(l.mouseDistanceDisplay(pts)) {
                            appDelegate.showMouseDistanceChart()
                        }
                    } else {
                        menuRow(l.mouseDistanceNoData) {
                            appDelegate.showMouseDistanceChart()
                        }
                    }
                case .slowEvents:
                    let count = KeyCountStore.shared.slowEventCount
                    if count > 0 {
                        menuRow(l.slowEventsDisplay(count), icon: "exclamationmark.triangle") {
                            let logDir = FileManager.default.homeDirectoryForCurrentUser
                                .appendingPathComponent("Library/Logs/KeyLens")
                            NSWorkspace.shared.open(logDir)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Action buttons

    private var actionRow: some View {
        let l = L10n.shared
        return VStack(alignment: .leading, spacing: 0) {
            menuRow(l.chartsMenuItem, icon: "chart.bar.xaxis") { appDelegate.showCharts() }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        return VStack(alignment: .leading, spacing: 0) {
            // データ操作サブメニュー
            DataMenuRow()
            Divider().padding(.horizontal, 14).padding(.vertical, 2)
            // 設定サブメニュー（Launch at Login・言語・通知間隔・AI Prompt・リセット）
            SettingsMenuRow()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Footer

    private var footerRow: some View {
        let l = L10n.shared
        return VStack(spacing: 0) {
            menuRow(l.aboutMenuItem,           icon: "info.circle")       { appDelegate.showAboutPanel() }
            menuRow(l.checkForUpdatesMenuItem, icon: "arrow.down.circle") { appDelegate.checkForUpdates() }
            menuRow(l.helpMenuItem,            icon: "questionmark.circle") {
                NSWorkspace.shared.open(URL(string: "https://etalli.github.io/262_KeyLens/landing-page/")!)
            }
            menuRow(l.quit, icon: "power")     { appDelegate.quit() }
        }
    }

    // MARK: - Helpers

    private var divider: some View {
        Divider().padding(.horizontal, 0)
    }

    private func infoRow(_ text: String, icon: String? = nil) -> some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func menuRow(_ title: String, icon: String? = nil, destructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                }
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(destructive ? .red : .primary)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .buttonStyle(HoverRowStyle())
    }

}

// MARK: - OverlayRow (toggle + gear in one row)

private struct OverlayRow: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var isHovered = false
    @ObservedObject private var theme = ThemeStore.shared

    var body: some View {
        let l = L10n.shared
        let isEnabled = KeystrokeOverlayController.shared.isEnabled
        HStack(spacing: 0) {
            // トグル部分（テキストのみ）
            Button(action: { appDelegate.toggleOverlay() }) {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                        .accessibilityHidden(true)
                    Text(l.overlayMenuItem)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .contentShape(Rectangle())
                .padding(.leading, 14)
                .padding(.trailing, 4)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l.overlayMenuItem)
            .accessibilityValue(isEnabled ? "on" : "off")
            .accessibilityAddTraits(.isToggle)

            // Hotkey badge
            Text(OverlayHotkeyManager.shared.displayString)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.trailing, 4)
                .accessibilityHidden(true)

            // ギアボタン：チェックマークの左、ホバー時のみ表示
            Button(action: { appDelegate.showOverlaySettings() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundColor(isHovered ? .secondary : Color.secondary.opacity(0.3))
                    .frame(width: 16)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l.overlaySettingsMenuItem)

            // チェックマーク（最右端・固定位置・他の toggleRow と揃える）
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isEnabled ? theme.accentColor : .clear)
                .padding(.trailing, 14)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
                .onTapGesture { appDelegate.toggleOverlay() }
        }
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                .padding(.horizontal, 6)
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - WPMGaugeRow

private struct WPMGaugeRow: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var isHovered = false
    @ObservedObject private var theme = ThemeStore.shared

    var body: some View {
        let isEnabled = WPMGaugeOverlayController.shared.isEnabled
        HStack(spacing: 0) {
            Button(action: { appDelegate.toggleWPMGauge() }) {
                HStack(spacing: 8) {
                    Image(systemName: "speedometer")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                        .accessibilityHidden(true)
                    Text(L10n.shared.wpmGaugeMenuItem)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .contentShape(Rectangle())
                .padding(.leading, 14)
                .padding(.trailing, 4)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.shared.wpmGaugeMenuItem)
            .accessibilityValue(isEnabled ? "on" : "off")
            .accessibilityAddTraits(.isToggle)

            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(isEnabled ? theme.accentColor : .clear)
                .padding(.trailing, 14)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .accessibilityHidden(true)
                .onTapGesture { appDelegate.toggleWPMGauge() }
        }
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                .padding(.horizontal, 6)
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - DataMenuRow (submenu)

private struct DataMenuRow: View {
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        Button(action: showMenu) {
            HStack(spacing: 8) {
                Image(systemName: "externaldrive")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Text(L10n.shared.dataMenuTitle)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .buttonStyle(HoverRowStyle())
    }

    private func showMenu() {
        let l = L10n.shared
        let menu = NSMenu()
        var held: [NSMenuItemAction] = []

        func add(_ title: String, icon: String? = nil, _ block: @escaping () -> Void) {
            let a = NSMenuItemAction(block)
            held.append(a)
            let item = NSMenuItem(title: title, action: #selector(NSMenuItemAction.invoke), keyEquivalent: "")
            item.target = a
            if let icon {
                item.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)
            }
            menu.addItem(item)
        }

        add(l.showAllMenuItem, icon: "list.bullet.rectangle") { appDelegate.showAllStats() }
        menu.addItem(.separator())
        add(l.exportCSVMenuItem, icon: "tablecells")           { appDelegate.exportCSV() }
        add(l.exportSQLiteMenuItem, icon: "cylinder")          { appDelegate.exportSQLite() }
        add(l.exportSummaryCardMenuItem, icon: "doc.richtext") { appDelegate.exportWeeklySummaryCard() }
        add(l.exportYearInReviewMenuItem, icon: "calendar.badge.clock") { appDelegate.exportYearInReviewCard() }
        add(l.exportDailyNoteMenuItem, icon: "note.text")      { appDelegate.exportDailyNote() }
        add(l.changeDailyNoteFolderMenuItem, icon: "folder.badge.gear") { appDelegate.changeDailyNoteFolder() }
        add(appDelegate.copyConfirmed ? "\(l.copyDataMenuItem) - \(l.copiedConfirmation)" : l.copyDataMenuItem,
            icon: "doc.on.clipboard") {
            appDelegate.copyDataToClipboard()
        }
        add(l.editPromptMenuItem, icon: "text.bubble")         { appDelegate.editAIPrompt() }
        menu.addItem(.separator())
        add(l.openSaveFolder, icon: "folder")                  { appDelegate.openSaveDir() }
        add(l.backupMenuItem, icon: "arrow.up.doc")            { appDelegate.backupData() }
        add(l.restoreMenuItem, icon: "arrow.down.doc")         { appDelegate.restoreData() }
        menu.addItem(.separator())
        add(l.resetMenuItem, icon: "trash")                    { appDelegate.resetCounts() }

        guard let event = NSApp.currentEvent else { return }
        withExtendedLifetime(held) {
            NSMenu.popUpContextMenu(menu, with: event, for: event.window?.contentView ?? NSView())
        }
    }
}

// MARK: - SettingsMenuRow (submenu: Language / Notify Every / Reset)

private struct SettingsMenuRow: View {
    @EnvironmentObject var appDelegate: AppDelegate

    var body: some View {
        Button(action: showMenu) {
            HStack(spacing: 8) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Text(L10n.shared.settingsMenuTitle)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .buttonStyle(HoverRowStyle())
    }

    private func showMenu() {
        let l = L10n.shared
        let menu = NSMenu()
        var held: [NSMenuItemAction] = []

        func add(_ title: String, to target: NSMenu, icon: String? = nil, checked: Bool = false, _ block: @escaping () -> Void) {
            let a = NSMenuItemAction(block)
            held.append(a)
            let item = NSMenuItem(title: title, action: #selector(NSMenuItemAction.invoke), keyEquivalent: "")
            item.target = a
            item.state = checked ? .on : .off
            if let icon { item.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) }
            target.addItem(item)
        }

        func submenu(_ title: String, icon: String? = nil, _ build: (NSMenu) -> Void) {
            let sub = NSMenu()
            build(sub)
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            if let icon { item.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil) }
            item.submenu = sub
            menu.addItem(item)
        }

        // Overlay toggle
        let isOverlay = KeystrokeOverlayController.shared.isEnabled
        add(l.overlayMenuItem, to: menu, icon: "rectangle.inset.filled", checked: isOverlay) {
            appDelegate.toggleOverlay()
        }

        // WPM Meter toggle
        let isWPM = WPMGaugeOverlayController.shared.isEnabled
        add(l.wpmGaugeMenuItem, to: menu, icon: "speedometer", checked: isWPM) {
            appDelegate.toggleWPMGauge()
        }

        menu.addItem(.separator())

        // Customize Menu
        add(l.customizeMenuMenuItem, to: menu, icon: "slider.horizontal.3") {
            appDelegate.showMenuCustomize()
        }

        // Layer Key Mapping (Issue #209)
        add(l.layerMappingMenuTitle, to: menu, icon: "keyboard") {
            appDelegate.showLayerMappingSettings()
        }

        menu.addItem(.separator())

        // Launch at Login
        add(l.launchAtLogin, to: menu, icon: "power", checked: SMAppService.mainApp.status == .enabled) {
            appDelegate.toggleLaunchAtLogin()
        }

        menu.addItem(.separator())

        // Advanced Mode toggle (#307)
        let isAdvanced = UserDefaults.standard.bool(forKey: UDKeys.advancedMode)
        add(l.advancedModeMenuTitle, to: menu, icon: "wrench.and.screwdriver", checked: isAdvanced) {
            UserDefaults.standard.set(!isAdvanced, forKey: UDKeys.advancedMode)
        }

        menu.addItem(.separator())

        // Appearance submenu
        let currentAppearance = ThemeStore.shared.appearance
        submenu(l.appearanceMenuTitle, icon: "paintbrush") { sub in
            for option in AppAppearance.allCases {
                add(option.displayName, to: sub, checked: currentAppearance == option) {
                    ThemeStore.shared.appearance = option
                }
            }
        }

        // Chart Theme submenu
        let currentTheme = ThemeStore.shared.current
        submenu(l.chartThemeMenuTitle, icon: "swatchpalette") { sub in
            for option in ChartTheme.allCases {
                add(option.displayName, to: sub, checked: currentTheme == option) {
                    ThemeStore.shared.current = option
                }
            }
        }

        // Language submenu
        let currentLang = l.language
        submenu(l.languageMenuTitle, icon: "globe") { sub in
            for lang in Language.allCases {
                add(lang.displayName, to: sub, checked: currentLang == lang) {
                    appDelegate.changeLanguage(to: lang)
                }
            }
        }

        // Notify Every submenu
        let currentInterval = KeyCountStore.milestoneInterval
        submenu(l.notificationIntervalMenuTitle, icon: "bell") { sub in
            for interval in [100, 500, 1000, 5000, 10000] {
                add(l.notificationIntervalLabel(interval), to: sub, checked: currentInterval == interval) {
                    appDelegate.setMilestoneInterval(interval)
                }
            }
        }

        // Break Reminder submenu
        let brm = BreakReminderManager.shared
        submenu(l.breakReminderMenuTitle, icon: "cup.and.saucer") { sub in
            add(l.breakReminderOff, to: sub, checked: !brm.isEnabled) {
                brm.isEnabled = false
            }
            for mins in [15, 30, 45, 60] {
                add(l.breakReminderIntervalLabel(mins), to: sub,
                    checked: brm.isEnabled && brm.intervalMinutes == mins) {
                    brm.intervalMinutes = mins
                    brm.isEnabled = true
                }
            }
        }

        // Daily Keystroke Goal submenu
        let ks = KeyCountStore.shared
        submenu(l.dailyGoalMenuTitle, icon: "target") { sub in
            add(l.dailyGoalOff, to: sub, checked: ks.dailyGoal == 0) { ks.dailyGoal = 0 }
            for count in [1000, 3000, 5000, 10000] {
                add(l.dailyGoalLabel(count), to: sub, checked: ks.dailyGoal == count) {
                    ks.dailyGoal = count
                }
            }
        }

        guard let event = NSApp.currentEvent else { return }
        withExtendedLifetime(held) {
            NSMenu.popUpContextMenu(menu, with: event, for: event.window?.contentView ?? NSView())
        }
    }
}

// MARK: - NSMenuItemAction helper

private final class NSMenuItemAction: NSObject {
    let block: () -> Void
    init(_ block: @escaping () -> Void) { self.block = block }
    @objc func invoke() { block() }
}

// MARK: - MiniDailyBarChart

private struct DayBar: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let isToday: Bool
}

private struct MiniDailyBarChart: View {
    @ObservedObject private var theme = ThemeStore.shared
    @State private var days: [DayBar] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.shared.last7Days)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)

            Chart(days) { day in
                BarMark(
                    x: .value("Day", day.label),
                    y: .value("Count", day.count)
                )
                .foregroundStyle(day.isToday ? theme.accentColor : theme.accentColor.opacity(0.35))
                .cornerRadius(2)
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().font(.system(size: 9))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 52)
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 4)
        .onAppear { days = loadDays() }
    }

    private func loadDays() -> [DayBar] {
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let symbols = cal.shortWeekdaySymbols  // ["Sun", "Mon", ..., "Sat"]
        let totals = KeyCountStore.shared.dailyTotals(last: 7)
        return totals.enumerated().compactMap { idx, pair -> DayBar? in
            guard let date = cal.date(from: cal.dateComponents([.year, .month, .day],
                                      from: fmt.date(from: pair.date) ?? Date())) else { return nil }
            let weekdayIndex = cal.component(.weekday, from: date) - 1
            let label = String(symbols[weekdayIndex].prefix(2))
            return DayBar(label: label, count: pair.count, isToday: idx == totals.count - 1)
        }
    }
}

// MARK: - HoverRowStyle

private struct HoverRowStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
                    .padding(.horizontal, 6)
            )
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}
