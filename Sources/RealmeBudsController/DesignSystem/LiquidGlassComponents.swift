import SwiftUI

/// Translucent Liquid Glass Card with accessibility support for Reduce Transparency & Increased Contrast.
public struct LiquidGlassCard<Content: View>: View {
    public let cornerRadius: CGFloat
    public let content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.colorScheme) private var colorScheme

    public init(cornerRadius: CGFloat = Theme.radiusCard, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(14)
            .background {
                cardBackground
            }
    }

    @ViewBuilder
    private var cardBackground: some View {
        let isHighContrast = colorSchemeContrast == .increased

        if reduceTransparency {
            // Opaque solid background for accessibility
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(colorScheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(isHighContrast ? Color.primary : Color.primary.opacity(0.15), lineWidth: isHighContrast ? 1.5 : 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        } else {
            // Translucent Liquid Glass Surface
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .glassEffect(.regular)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            isHighContrast
                                ? Color.primary.opacity(0.4)
                                : (colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.4)),
                            lineWidth: isHighContrast ? 1.5 : 1
                        )
                )
                .shadow(
                    color: colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.06),
                    radius: 8,
                    x: 0,
                    y: 3
                )
        }
    }
}

/// Violet Highlighted Pill Button for Quick Toggles and Filters
public struct LiquidGlassPillButton: View {
    public let title: String
    public let icon: String?
    public let isSelected: Bool
    public let action: () -> Void

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public init(title: String, icon: String? = nil, isSelected: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .default))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Theme.accent : Color.primary.opacity(0.05))
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Color.white.opacity(0.3)
                            : (colorSchemeContrast == .increased ? Color.primary.opacity(0.3) : Color.white.opacity(0.1)),
                        lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

/// Clean Section Header with Typography and Theme Accent Icon
public struct LiquidGlassSectionHeader: View {
    public let title: String
    public let icon: String?
    public let accessory: AnyView?

    public init(title: String, icon: String? = nil, accessory: AnyView? = nil) {
        self.title = title
        self.icon = icon
        self.accessory = accessory
    }

    public var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.6)

            Spacer()

            if let accessory {
                accessory
            }
        }
        .padding(.horizontal, 2)
    }
}
