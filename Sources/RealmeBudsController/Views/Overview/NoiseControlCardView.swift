import SwiftUI

public struct NoiseControlCardView: View {
    @ObservedObject var appState: AppState

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LiquidGlassSectionHeader(
                title: "Noise Control",
                icon: "waveform.slash"
            )

            // Primary 3 Modes
            HStack(spacing: 6) {
                modeButton(
                    title: "Off",
                    icon: "circle.slash",
                    isSelected: isOff
                ) {
                    appState.setNoiseMode(.off)
                }

                modeButton(
                    title: "Transparency",
                    icon: "ear.and.waveform",
                    isSelected: isTransparency
                ) {
                    appState.setNoiseMode(.transparency)
                }

                modeButton(
                    title: "Noise Cancelling",
                    icon: "waveform.slash",
                    isSelected: isAnc
                ) {
                    if !isAnc {
                        appState.setNoiseMode(.anc(.smart))
                    }
                }
            }

            // ANC Strength sub-levels (only shown when ANC is active)
            if isAnc {
                VStack(alignment: .leading, spacing: 6) {
                    Text("CANCELLATION STRENGTH")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 2)

                    HStack(spacing: 4) {
                        ForEach(ANCStrength.allCases) { strength in
                            strengthButton(strength: strength)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .padding(.top, 4)
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
    private func modeButton(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(isSelected ? Theme.accent : Color.primary.opacity(0.05))
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func strengthButton(strength: ANCStrength) -> some View {
        let isSelected = currentStrength == strength
        Button {
            appState.setNoiseMode(.anc(strength))
        } label: {
            HStack(spacing: 4) {
                Image(systemName: strength.sfSymbol)
                    .font(.system(size: 9, weight: .semibold))
                Text(strength.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.85) : Color.primary.opacity(0.04))
            )
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
