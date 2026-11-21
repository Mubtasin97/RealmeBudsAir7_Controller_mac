import SwiftUI

public struct NoiseControlCardView: View {
    @ObservedObject var appState: AppState

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LiquidGlassSectionHeader(
                title: "Noise Control",
                icon: "waveform.slash"
            )

            // Primary 3 Modes
            HStack(spacing: 8) {
                primaryModeButton(
                    title: "Off",
                    icon: "circle.slash",
                    isSelected: isOff
                ) {
                    appState.setNoiseMode(.off)
                }
                .disabled(appState.noiseControlMode == .unknown)

                primaryModeButton(
                    title: "Transparency",
                    icon: "ear.and.waveform",
                    isSelected: isTransparency
                ) {
                    appState.setNoiseMode(.transparency)
                }
                .disabled(appState.noiseControlMode == .unknown)

                primaryModeButton(
                    title: "Noise Cancelling",
                    icon: "waveform.slash",
                    isSelected: isAnc
                ) {
                    if !isAnc {
                        appState.setNoiseMode(.anc(.smart))
                    }
                }
                .disabled(appState.noiseControlMode == .unknown)
            }

            // ANC Strength sub-levels (only shown when ANC is active)
            if isAnc {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("CANCELLATION INTENSITY")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let strength = currentStrength {
                            Text(strength.title)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .padding(.horizontal, 2)

                    HStack(spacing: 6) {
                        ForEach(ANCStrength.allCases) { strength in
                            strengthPill(strength: strength)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .padding(.top, 2)
            }
        }
    }

    private var isOff: Bool {
        if case .off = appState.noiseControlMode { return true }
        return false
    }

    private var isTransparency: Bool {
        if case .transparency = appState.noiseControlMode { return true }
        return false
    }

    private var isAnc: Bool {
        if case .anc = appState.noiseControlMode { return true }
        return false
    }

    private var currentStrength: ANCStrength? {
        if case .anc(let strength) = appState.noiseControlMode {
            return strength
        }
        return nil
    }

    @ViewBuilder
    private func primaryModeButton(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(isSelected ? Theme.accent : (colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04)))
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Color.white.opacity(0.28)
                            : (colorSchemeContrast == .increased ? Color.primary.opacity(0.2) : Color.white.opacity(0.08)),
                        lineWidth: 1
                    )
            )
            .shadow(color: isSelected ? Theme.accentGlow : Color.clear, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func strengthPill(strength: ANCStrength) -> some View {
        let isSelected = currentStrength == strength
        Button {
            appState.setNoiseMode(.anc(strength))
        } label: {
            HStack(spacing: 4) {
                Image(systemName: strength.sfSymbol)
                    .font(.system(size: 9, weight: .semibold))
                Text(strength.title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.9) : (colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04)))
            )
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Color.white.opacity(0.35)
                            : (colorSchemeContrast == .increased ? Color.primary.opacity(0.2) : Color.clear),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
