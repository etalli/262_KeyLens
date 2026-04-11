import SwiftUI

// MARK: - SubTabPicker

/// Segmented picker + divider used at the top of each Charts sub-tab.
/// Encapsulates the repeated Picker + padding + Divider boilerplate.
struct SubTabPicker<SelectionValue: Hashable, Content: View>: View {
    @Binding var selection: SelectionValue
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selection) {
                content()
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
        }
    }
}

// MARK: - SectionHeader

/// Section title with an optional hover-triggered help popover.
/// セクションタイトル + ホバーで表示されるヘルプポップオーバー（任意）。
struct SectionHeader: View {
    let title: String
    let helpText: String
    @State private var showHelp = false

    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.headline)
            Image(systemName: "info.circle")
                .font(.body)
                .foregroundStyle(showHelp ? .primary : .secondary)
                .onHover { showHelp = $0 }
                .popover(isPresented: $showHelp, arrowEdge: .bottom) {
                    Text(helpText)
                        .font(.callout)
                        .padding(10)
                        .frame(width: 280)
                        .fixedSize(horizontal: false, vertical: true)
                }
        }
    }
}

// MARK: - ChartTab

enum ChartTab: String, CaseIterable, Identifiable {
    case summary     = "Summary"
    case typing      = "Typing"
    case mouse       = "Mouse"
    case ergonomics  = "Ergonomics"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .summary:    return "info.circle"
        case .typing:     return "keyboard"
        case .mouse:      return "cursorarrow.motionlines"
        case .ergonomics: return "figure.walk"
        }
    }
}

