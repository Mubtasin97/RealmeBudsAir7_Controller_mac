import SwiftUI

/// Translucent Liquid Glass Card Container
public struct LiquidGlassCard<Content: View>: View {
    public let cornerRadius: CGFloat
    public let content: Content

    public init(cornerRadius: CGFloat = Theme.radiusMedium, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
            }
    }
}

/// Violet Highlighted Pill Button
public struct LiquidGlassPillButton: View {
    public let title: String
    public let icon: String?
    public let isSelected: Bool
    public let action: () -> Void

    public init(title: String, icon: String? = nil, isSelected: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Theme.accent : Color.primary.opacity(0.06))
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Section Header with optional trailing accessory
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
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.8)

            Spacer()

            if let accessory {
                accessory
            }
        }
        .padding(.horizontal, 4)
    }
}
