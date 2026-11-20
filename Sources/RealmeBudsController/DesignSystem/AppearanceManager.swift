import AppKit
import SwiftUI

public enum AppAppearance: String, CaseIterable, Identifiable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    public var iconName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }
    }
}

@MainActor
public final class AppearanceManager: ObservableObject {
    public static let shared = AppearanceManager()

    private let defaultsKey = "rbc_app_appearance_mode"

    @Published public var currentPreference: AppAppearance {
        didSet {
            UserDefaults.standard.set(currentPreference.rawValue, forKey: defaultsKey)
            applyAppearance()
        }
    }

    public var colorSchemeOverride: ColorScheme? {
        switch currentPreference {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// Returns the effective icon to show in the header button (Sun for Light, Moon for Dark)
    public var headerButtonIconName: String {
        switch currentPreference {
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.stars.fill"
        case .system:
            // Check current effective system appearance
            let isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? "moon.stars.fill" : "sun.max.fill"
        }
    }

    public var headerButtonTooltip: String {
        switch currentPreference {
        case .light:
            return "Current: Light Mode. Click to switch to Dark Mode."
        case .dark:
            return "Current: Dark Mode. Click to switch to Light Mode."
        case .system:
            return "Current: System Mode. Click to switch appearance."
        }
    }

    private init() {
        let savedRaw = UserDefaults.standard.string(forKey: defaultsKey) ?? AppAppearance.system.rawValue
        self.currentPreference = AppAppearance(rawValue: savedRaw) ?? .system
        applyAppearance()
    }

    /// Toggle between Light and Dark mode from the header button
    public func toggleLightDark() {
        if currentPreference == .light {
            currentPreference = .dark
        } else {
            currentPreference = .light
        }
    }

    public func applyAppearance() {
        switch currentPreference {
        case .system:
            NSApp?.appearance = nil
        case .light:
            NSApp?.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp?.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
