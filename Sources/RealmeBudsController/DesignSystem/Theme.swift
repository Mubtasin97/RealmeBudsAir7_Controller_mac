import SwiftUI

/// Unified Design System and Brand Palette for Realme Buds Controller.
public enum Theme {
    /// Brand Soft Violet Accent: #7652C8 (rgb: 118, 82, 200)
    public static let accent = Color(red: 118 / 255.0, green: 82 / 255.0, blue: 200 / 255.0)
    public static let accentSubtle = accent.opacity(0.18)
    public static let accentGlow = accent.opacity(0.35)

    // Semantic status colors
    public static let success = Color.green
    public static let warning = Color.orange
    public static let error = Color.red
    public static let batteryCharging = Color.green
    public static let batteryLow = Color.red

    // Corner Radii
    public static let radiusSmall: CGFloat = 8
    public static let radiusMedium: CGFloat = 12
    public static let radiusLarge: CGFloat = 16
    public static let radiusPill: CGFloat = 999
}

public extension Color {
    static let rbcAccent = Theme.accent
}
