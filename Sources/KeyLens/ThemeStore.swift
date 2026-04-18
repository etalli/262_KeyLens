import SwiftUI
import Combine

// MARK: - ChartTheme

enum ChartTheme: String, CaseIterable, Identifiable {
    case blue   = "blue"
    case teal   = "teal"
    case purple = "purple"
    case orange = "orange"
    case green  = "green"
    case pink   = "pink"

    var id: String { rawValue }

    var displayName: String {
        L10n.shared.chartThemeDisplayName(self)
    }

    var color: Color {
        switch self {
        case .blue:   return .blue
        case .teal:   return .teal
        case .purple: return .purple
        case .orange: return .orange
        case .green:  return .green
        case .pink:   return .pink
        }
    }

    /// Hue value (0–1) used for the keyboard heatmap gradient.
    var heatmapBaseHue: Double {
        switch self {
        case .blue:   return 0.60
        case .teal:   return 0.50
        case .purple: return 0.75
        case .orange: return 0.08
        case .green:  return 0.35
        case .pink:   return 0.85
        }
    }
}

// MARK: - AppAppearance

enum AppAppearance: String, CaseIterable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var displayName: String { L10n.shared.appearanceDisplayName(self) }

    func apply() {
        switch self {
        case .system: NSApplication.shared.appearance = nil
        case .light:  NSApplication.shared.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

// MARK: - ThemeStore

final class ThemeStore: ObservableObject {
    static let shared = ThemeStore()

    @Published var current: ChartTheme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: UDKeys.chartTheme) }
    }

    @Published var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: UDKeys.appAppearance)
            appearance.apply()
        }
    }

    private init() {
        let savedTheme = UserDefaults.standard.string(forKey: UDKeys.chartTheme) ?? ""
        current = ChartTheme(rawValue: savedTheme) ?? .blue

        let savedAppearance = UserDefaults.standard.string(forKey: UDKeys.appAppearance) ?? ""
        appearance = AppAppearance(rawValue: savedAppearance) ?? .system
    }

    var accentColor: Color { current.color }
}
