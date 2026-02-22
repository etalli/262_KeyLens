import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let monitor = KeyboardMonitor()
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 通知権限を初期化（シングルトン初回アクセス）
        _ = NotificationManager.shared

        // メニューバーアイコンを設定
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "KC"

        let menu = NSMenu()
        menu.delegate = self   // menuWillOpen でメニューを再構築
        statusItem.menu = menu

        startMonitor()
    }

    // MARK: - 監視開始

    private func startMonitor() {
        if monitor.start() {
            print("[KeyCounter] 監視開始")
        } else {
            showPermissionAlert()
            // 権限が付与されるまで 3 秒ごとにリトライ
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    self?.monitor.start()
                    print("[KeyCounter] 権限取得 → 監視開始")
                    timer.invalidate()
                }
            }
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "アクセシビリティ権限が必要です"
        alert.informativeText = """
            キー入力を監視するには、アクセシビリティ権限が必要です。
            「システム設定 → プライバシーとセキュリティ → アクセシビリティ」で
            KeyCounter を許可してください。
            """
        alert.addButton(withTitle: "システム設定を開く")
        alert.addButton(withTitle: "あとで")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - NSMenuDelegate

    /// メニューを開く直前に最新データで再構築
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        let total = KeyCountStore.shared.totalCount
        let topKeys = KeyCountStore.shared.topKeys(limit: 10)

        // ヘッダー：合計カウント
        let header = NSMenuItem(title: "合計: \(total.formatted()) キー入力", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        // 上位10キーを表示
        if topKeys.isEmpty {
            let empty = NSMenuItem(title: "（まだ入力なし）", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for (i, (key, count)) in topKeys.enumerated() {
                let rank = String(format: "%2d", i + 1)
                let item = NSMenuItem(
                    title: "\(rank)  \(key)  --  \(count.formatted())",
                    action: nil,
                    keyEquivalent: ""
                )
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        // 保存先フォルダを Finder で開く
        let openItem = NSMenuItem(title: "保存先を開く", action: #selector(openSaveDir), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func openSaveDir() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KeyCounter")
        NSWorkspace.shared.open(dir)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Array helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
