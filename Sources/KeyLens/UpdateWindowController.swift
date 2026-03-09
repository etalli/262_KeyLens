import AppKit
import SwiftUI

// MARK: - UpdateWindowController

/// Displays update check results in a custom panel with a centered app icon.
/// アップデート確認結果をアイコン中央配置のカスタムパネルで表示する。
final class UpdateWindowController {
    static let shared = UpdateWindowController()
    private init() {}

    /// Show an "update available" panel with a Download button.
    /// アップデートあり：ダウンロードボタン付きパネルを表示する。
    func showUpdateAvailable(current: String, latest: String, releaseURL: URL) {
        let l = L10n.shared
        show(UpdateView(
            title: l.updateAvailableTitle,
            message: l.updateAvailableMessage(current: current, latest: latest),
            primaryLabel: l.downloadButton,
            primaryAction: { NSWorkspace.shared.open(releaseURL) }
        ))
    }

    /// Show an informational panel (up-to-date or error).
    /// 情報表示パネル（最新版 or エラー）を表示する。
    func showInfo(title: String, message: String) {
        show(UpdateView(title: title, message: message, primaryLabel: nil, primaryAction: nil))
    }

    private func show(_ view: UpdateView) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = ""
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = true
        panel.contentView = NSHostingView(rootView: view)
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}

// MARK: - UpdateView

private struct UpdateView: View {
    let title: String
    let message: String
    let primaryLabel: String?
    let primaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
            }

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                if let label = primaryLabel, let action = primaryAction {
                    Button(action: {
                        action()
                        NSApp.keyWindow?.close()
                    }) {
                        Text(label).frame(minWidth: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }

                Button(action: { NSApp.keyWindow?.close() }) {
                    Text(L10n.shared.close).frame(minWidth: 60)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape)
            }
        }
        .padding(28)
        .frame(width: 320)
    }
}
