import AppKit
import SwiftUI

// MARK: - MenuCustomizeWindowController

/// NSWindowController that hosts the Customize Menu SwiftUI panel.
/// カスタマイズメニューの SwiftUI パネルをホストする NSWindowController。
final class MenuCustomizeWindowController: BaseWindowController {
    static let shared = MenuCustomizeWindowController()

    private init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = L10n.shared.customizeMenuTitle
        panel.isMovableByWindowBackground = true
        panel.titlebarAppearsTransparent = false
        panel.level = .floating
        super.init(window: panel)

        let view = MenuCustomizeView()
        panel.contentView = NSHostingView(rootView: view)
    }

    required init?(coder: NSCoder) { fatalError() }

    func showWindow() {
        // Refresh title in case language changed.
        window?.title = L10n.shared.customizeMenuTitle
        window?.center()
        showAndActivate()
    }
}

// MARK: - MenuCustomizeView

private struct MenuCustomizeView: View {
    @State private var items: [MenuWidget] = MenuWidgetStore.shared.allOrdered
    @State private var enabled: [MenuWidget: Bool] = {
        var d: [MenuWidget: Bool] = [:]
        for w in MenuWidget.allCases { d[w] = MenuWidgetStore.shared.isEnabled(w) }
        return d
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            list
            Divider()
            footer
        }
        .frame(width: 300)
    }

    private var header: some View {
        Text(L10n.shared.customizeMenuHint)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }

    private var list: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, widget in
                HStack(spacing: 8) {
                    Toggle(isOn: Binding(
                        get: { enabled[widget] ?? true },
                        set: { val in
                            enabled[widget] = val
                            MenuWidgetStore.shared.setEnabled(widget, val)
                        }
                    )) {
                        Text(widget.displayName)
                            .font(.system(size: 13))
                    }
                    Spacer()
                    // Up / Down move buttons
                    HStack(spacing: 2) {
                        Button { move(from: idx, by: -1) } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .disabled(idx == 0)
                        Button { move(from: idx, by: 1) } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .disabled(idx == items.count - 1)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.plain)
        .frame(height: 260)
    }

    private func move(from idx: Int, by delta: Int) {
        let dest = idx + delta
        guard dest >= 0, dest < items.count else { return }
        items.move(fromOffsets: IndexSet(integer: idx), toOffset: delta > 0 ? dest + 1 : dest)
        MenuWidgetStore.shared.allOrdered = items
    }

    private var footer: some View {
        HStack {
            Button(L10n.shared.customizeMenuReset) {
                items = MenuWidgetStore.defaultOrder
                MenuWidgetStore.shared.allOrdered = items
                for w in MenuWidget.allCases {
                    let on = MenuWidgetStore.defaultEnabled(w)
                    enabled[w] = on
                    MenuWidgetStore.shared.setEnabled(w, on)
                }
            }
            .font(.system(size: 12))
            Spacer()
            Button(L10n.shared.close) {
                NSApp.keyWindow?.close()
            }
            .buttonStyle(.borderedProminent)
            .font(.system(size: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
