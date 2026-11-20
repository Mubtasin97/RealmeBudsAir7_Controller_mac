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

    private let defaultsKey = "app_appearance_preference"

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

    private init() {
        let savedRaw = UserDefaults.standard.string(forKey: defaultsKey) ?? AppAppearance.system.rawValue
        self.currentPreference = AppAppearance(rawValue: savedRaw) ?? .system
        applyAppearance()
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
