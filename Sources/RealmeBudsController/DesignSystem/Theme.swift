import SwiftUI

/// Unified Design System, Liquid Glass tokens, and Brand Palette for Realme Buds Controller.
public enum Theme {
    /// Brand Soft Violet Accent: #7652C8 (rgb: 118, 82, 200)
    public static let accent = Color(red: 118 / 255.0, green: 82 / 255.0, blue: 200 / 255.0)
    public static let accentLight = Color(red: 142 / 255.0, green: 110 / 255.0, blue: 224 / 255.0)
    public static let accentSubtle = accent.opacity(0.18)
    public static let accentGlow = accent.opacity(0.35)

    // Semantic Status Colors
    public static let success = Color(red: 52 / 255.0, green: 199 / 255.0, blue: 89 / 255.0)
    public static let warning = Color(red: 255 / 255.0, green: 149 / 255.0, blue: 0 / 255.0)
    public static let error = Color(red: 255 / 255.0, green: 59 / 255.0, blue: 48 / 255.0)
    public static let batteryCharging = Color(red: 50 / 255.0, green: 215 / 255.0, blue: 75 / 255.0)
    public static let batteryLow = Color(red: 255 / 255.0, green: 69 / 255.0, blue: 58 / 255.0)

    // Corner Radii
    public static let radiusSmall: CGFloat = 8
    public static let radiusMedium: CGFloat = 12
    public static let radiusLarge: CGFloat = 16
    public static let radiusCard: CGFloat = 14
    public static let radiusPill: CGFloat = 999

    // Animation Timings
    public static let quickAnimation = Animation.spring(response: 0.28, dampingFraction: 0.82)
    public static let smoothTransition = Animation.smooth(duration: 0.25)
}

public extension Color {
    static let rbcAccent = Theme.accent
}
