import AppKit
import ServiceManagement

// MARK: - Actions

extension AppDelegate {

    func showAllStats() {
        StatsWindowController.shared.showWindow()
    }

    func showCharts() {
        ChartsWindowController.shared.showWindow()
    }

    func showCharts(tab: ChartTab) {
        UserDefaults.standard.set(tab.rawValue, forKey: "selectedChartTab")
        ChartsWindowController.shared.showWindow()
    }

    func showMouseDistanceChart() {
        UserDefaults.standard.set(ChartTab.mouse.rawValue, forKey: "selectedChartTab")
        UserDefaults.standard.set(MouseSubTab.distance.rawValue, forKey: "selectedMouseSubTab")
        ChartsWindowController.shared.showWindow()
    }

    func toggleOverlay() {
        KeystrokeOverlayController.shared.isEnabled.toggle()
        objectWillChange.send()
    }

    func toggleWPMGauge() {
        WPMGaugeOverlayController.shared.isEnabled.toggle()
        objectWillChange.send()
    }

    func showOverlaySettings() {
        OverlaySettingsController.shared.showWindow()
    }

    func showMenuCustomize() {
        MenuCustomizeWindowController.shared.showWindow()
    }

    // Layer Mapping Settings (Issue #209)
    func showLayerMappingSettings() {
        LayerMappingWindowController.shared.show()
    }

    func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            KeyLens.log("LaunchAtLogin toggle failed: \(error)")
        }
        objectWillChange.send()
    }

    @MainActor
    func exportWeeklySummaryCard() {
        let l = L10n.shared
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let tag = dateFmt.string(from: Date())

        let panel = NSSavePanel()
        panel.title = l.exportSummaryCardMenuItem
        panel.nameFieldStringValue = "KeyLens_weekly_\(tag).png"
        panel.allowedContentTypes = [.png]

        let complete: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            if WeeklySummaryGenerator.generate(to: url) != nil {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                let alert = NSAlert()
                alert.messageText = l.weeklySummaryCardSaveFailed
                alert.runModal()
            }
        }

        let window = NSApp.keyWindow ?? ChartsWindowController.shared.window
        if let window {
            panel.beginSheetModal(for: window, completionHandler: complete)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            panel.begin(completionHandler: complete)
        }
    }

    @MainActor
    func exportYearInReviewCard() {
        let l = L10n.shared
        let year = Calendar.current.component(.year, from: Date())

        let panel = NSSavePanel()
        panel.title = l.exportYearInReviewMenuItem
        panel.nameFieldStringValue = "KeyLens_year_\(year).png"
        panel.allowedContentTypes = [.png]

        let complete: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            if YearInReviewGenerator.generate(year: year, to: url) != nil {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else {
                let alert = NSAlert()
                alert.messageText = l.yearInReviewSaveFailed
                alert.runModal()
            }
        }

        let window = NSApp.keyWindow ?? ChartsWindowController.shared.window
        if let window {
            panel.beginSheetModal(for: window, completionHandler: complete)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            panel.begin(completionHandler: complete)
        }
    }

    func exportCSV() {
        let store = KeyCountStore.shared
        let summary = store.exportSummaryCSV()
        let daily   = store.exportDailyCSV()

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let tag = dateFmt.string(from: Date())

        let panel = NSOpenPanel()
        panel.title = L10n.shared.exportCSVMenuItem
        panel.prompt = L10n.shared.exportCSVSaveButton
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let dir = panel.url else { return }
            let summaryURL = dir.appendingPathComponent("KeyLens_summary_\(tag).csv")
            let dailyURL   = dir.appendingPathComponent("KeyLens_daily_\(tag).csv")
            try? summary.write(to: summaryURL, atomically: true, encoding: .utf8)
            try? daily.write(to: dailyURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(dir)
        }
    }

    func exportSQLite() {
        let l = L10n.shared
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let tag = dateFmt.string(from: Date())

        let panel = NSSavePanel()
        panel.title = l.exportSQLiteMenuItem
        panel.prompt = l.exportSQLiteSaveButton
        panel.nameFieldStringValue = "KeyLens_\(tag).db"
        panel.allowedContentTypes = [.init(filenameExtension: "db")!]
        panel.canCreateDirectories = true

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let dest = panel.url else { return }
            do {
                try KeyCountStore.shared.exportSQLite(to: dest)
                NSWorkspace.shared.selectFile(dest.path, inFileViewerRootedAtPath: "")
            } catch {
                KeyLens.log("SQLite export failed: \(error)")
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = l.exportSQLiteFailedAlert
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        }
    }

    // MARK: - Markdown Daily Note Export

    private static let dailyNoteBookmarkKey = "dailyNoteFolderBookmark"

    /// Returns the previously saved daily note folder URL by resolving the stored security-scoped bookmark.
    private func resolvedDailyNoteFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: Self.dailyNoteBookmarkKey) else { return nil }
        var isStale = false
        return try? URL(resolvingBookmarkData: data,
                        options: .withSecurityScope,
                        relativeTo: nil,
                        bookmarkDataIsStale: &isStale)
    }

    /// Saves a security-scoped bookmark for the given folder URL.
    private func saveDailyNoteBookmark(for url: URL) {
        let data = try? url.bookmarkData(options: .withSecurityScope,
                                         includingResourceValuesForKeys: nil,
                                         relativeTo: nil)
        UserDefaults.standard.set(data, forKey: Self.dailyNoteBookmarkKey)
    }

    func exportDailyNote() {
        if let folder = resolvedDailyNoteFolder() {
            writeDailyNote(to: folder)
        } else {
            pickDailyNoteFolder { [weak self] folder in
                self?.writeDailyNote(to: folder)
            }
        }
    }

    func changeDailyNoteFolder() {
        pickDailyNoteFolder { [weak self] folder in
            self?.writeDailyNote(to: folder)
        }
    }

    private func pickDailyNoteFolder(then completion: @escaping (URL) -> Void) {
        let l = L10n.shared
        let panel = NSOpenPanel()
        panel.title = l.dailyNoteFolderPickerTitle
        panel.prompt = l.dailyNoteFolderPickerButton
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.saveDailyNoteBookmark(for: url)
            completion(url)
        }
    }

    private func writeDailyNote(to folder: URL) {
        let l = L10n.shared
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let today = dateFmt.string(from: Date())

        let markdown = KeyCountStore.shared.exportDailyNoteMarkdown(date: today)
        let fileURL = folder.appendingPathComponent("\(today).md")

        _ = folder.startAccessingSecurityScopedResource()
        defer { folder.stopAccessingSecurityScopedResource() }

        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                // Append to existing note
                let handle = try FileHandle(forWritingTo: fileURL)
                handle.seekToEndOfFile()
                if let data = markdown.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            } else {
                try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = l.dailyNoteExportSuccess
                alert.informativeText = fileURL.path
                alert.runModal()
            }
        } catch {
            KeyLens.log("Daily note export failed: \(error)")
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = l.dailyNoteExportFailed
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    func changeLanguage(to lang: Language) {
        L10n.shared.language = lang
        objectWillChange.send()
    }

    func setMilestoneInterval(_ interval: Int) {
        KeyCountStore.milestoneInterval = interval
        objectWillChange.send()
    }

    func resetCounts() {
        let l = L10n.shared
        let alert = NSAlert()
        alert.messageText = l.resetAlertTitle
        alert.informativeText = l.resetAlertMessage
        alert.addButton(withTitle: l.resetConfirmButton)
        alert.addButton(withTitle: l.cancel)
        alert.buttons[0].hasDestructiveAction = true

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let backup = KeyCountStore.shared.backupDBForUndo()
        KeyCountStore.shared.reset()

        let undoAlert = NSAlert()
        undoAlert.messageText = l.resetUndoAlertTitle
        undoAlert.informativeText = l.resetUndoAlertMessage
        undoAlert.addButton(withTitle: l.resetUndoButton)
        undoAlert.addButton(withTitle: l.cancel)
        if undoAlert.runModal() == .alertFirstButtonReturn, let backup {
            KeyCountStore.shared.restoreFromUndo(url: backup)
        } else if let backup {
            try? FileManager.default.removeItem(at: backup)
        }
    }

    func showAboutPanel() {
        AboutWindowController.shared.show()
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func copyDataToClipboard() {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyLens/counts.json")
        guard let data = try? Data(contentsOf: url),
              var json = String(data: data, encoding: .utf8) else { return }
        
        // Inject current intelligence insights into the JSON (simplified)
        let style = KeyCountStore.shared.currentTypingStyle.rawValue
        let fatigue = KeyCountStore.shared.currentFatigueLevel.rawValue
        let insights = """
          "intelligence": {
            "typingStyle": "\(style)",
            "fatigueLevel": "\(fatigue)"
          },
        """
        if let range = json.range(of: "{") {
            json.insert(contentsOf: insights, at: range.upperBound)
        }

        let content = "\(AIPromptStore.shared.currentPrompt)\n\n\(json)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        copyConfirmed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.copyConfirmed = false
        }
    }

    func editAIPrompt() {
        let l = L10n.shared
        let alert = NSAlert()
        alert.messageText = l.editPromptTitle
        alert.addButton(withTitle: l.editPromptSave)
        alert.addButton(withTitle: l.cancel)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 240))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder

        let textView = NSTextView(frame: scrollView.contentView.bounds)
        textView.autoresizingMask = [.width]
        textView.isEditable = true
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.string = AIPromptStore.shared.currentPrompt
        scrollView.documentView = textView

        alert.accessoryView = scrollView

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            AIPromptStore.shared.save(textView.string)
        }
    }

    func backupData() {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let tag = dateFmt.string(from: Date())

        let panel = NSSavePanel()
        panel.title = L10n.shared.backupMenuItem
        panel.nameFieldStringValue = "KeyLens-backup-\(tag).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let dest = panel.url else { return }
            let src = KeyCountStore.shared.saveURL
            try? FileManager.default.copyItem(at: src, to: dest)
        }
    }

    func restoreData() {
        let l = L10n.shared
        let alert = NSAlert()
        alert.messageText = l.restoreAlertTitle
        alert.informativeText = l.restoreAlertMessage
        alert.addButton(withTitle: l.restoreConfirmButton)
        alert.addButton(withTitle: l.cancel)
        alert.buttons[0].hasDestructiveAction = true

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let panel = NSOpenPanel()
        panel.title = l.restoreMenuItem
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK, let src = panel.url else { return }
            let dest = KeyCountStore.shared.saveURL
            do {
                _ = try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: src, to: dest)
                KeyCountStore.shared.reload()
            } catch {
                KeyLens.log("Restore failed: \(error)")
            }
        }
    }

    func openSaveDir() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyLens")
        NSWorkspace.shared.open(dir)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Check for Updates

    func checkForUpdates() {
        let url = URL(string: "https://api.github.com/repos/etalli/262_KeyLens/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.handleUpdateResponse(data: data, error: error)
            }
        }.resume()
    }

    private func handleUpdateResponse(data: Data?, error: Error?) {
        let l = L10n.shared
        guard error == nil, let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tagName"] as? String ?? json["tag_name"] as? String,
              let htmlURL = json["html_url"] as? String
        else {
            UpdateWindowController.shared.showInfo(title: l.updateCheckFailedTitle,
                                                   message: l.updateCheckFailedMessage)
            return
        }

        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        // Strip leading 'v' for comparison (e.g. "v0.44" → "0.44")
        // 先頭の 'v' を除去して比較（例: "v0.44" → "0.44"）
        let latest = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

        if latest.compare(current, options: .numeric) == .orderedDescending,
           let releaseURL = URL(string: htmlURL) {
            UpdateWindowController.shared.showUpdateAvailable(current: current,
                                                              latest: latest,
                                                              releaseURL: releaseURL)
        } else {
            UpdateWindowController.shared.showInfo(title: l.updateUpToDateTitle,
                                                   message: l.updateUpToDateMessage(version: current))
        }
    }
}
