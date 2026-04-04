import SwiftUI
import Charts

// MARK: - Typing sub-tab enum (#311)

enum TypingSubTab: String, CaseIterable {
    case live
    case activity
    case keyboard
    case shortcuts
    case apps
    case devices
}

extension ChartsView {

    var typingTab: some View {
        let l = L10n.shared
        return VStack(spacing: 0) {
            Picker("", selection: $typingSubTab) {
                Text(l.typingSubTabLive).tag(TypingSubTab.live)
                Text(l.typingSubTabActivity).tag(TypingSubTab.activity)
                Text(l.typingSubTabKeyboard).tag(TypingSubTab.keyboard)
                Text(l.typingSubTabShortcuts).tag(TypingSubTab.shortcuts)
                Text(l.typingSubTabApps).tag(TypingSubTab.apps)
                Text(l.typingSubTabDevices).tag(TypingSubTab.devices)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            switch typingSubTab {
            case .live:
                liveTab
            case .activity:
                activityTab
            case .keyboard:
                keyboardTab
            case .shortcuts:
                shortcutsTab
            case .apps:
                appsTabAppsContent
            case .devices:
                appsTabDevicesContent
            }
        }
    }
}
