import SwiftUI

public struct OverviewSectionView: View {
    @ObservedObject var appState: AppState
    public let onOpenSettings: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        VStack(spacing: 12) {
            // Header Device Status Card
            LiquidGlassCard {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.accentSubtle)
                            .frame(width: 40, height: 40)
                        Image(systemName: "headphones")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(appState.deviceName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)

                        HStack(spacing: 5) {
                            Circle()
                                .fill(appState.isConnected ? Theme.success : Theme.error)
                                .frame(width: 6, height: 6)
                            Text(appState.linkStatusText)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Quick Settings Button
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(7)
                            .background(Circle().fill(Color.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .help("Open Settings Window")
                }
            }

            // Granular Battery Indicators (L / R / Case)
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    LiquidGlassSectionHeader(
                        title: "Battery Indicators",
                        icon: "battery.100.bolt"
                    )

                    HStack(spacing: 8) {
                        BatteryCardView(slot: .left, status: appState.leftBattery)
                        BatteryCardView(slot: .right, status: appState.rightBattery)
                        BatteryCardView(slot: .caseEnclosure, status: appState.caseBattery)
                    }
                }
            }

            // Noise Control & Strength
            LiquidGlassCard {
                NoiseControlCardView(appState: appState)
            }

            // Game Mode & LHDC Preference Cards
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    LiquidGlassSectionHeader(
                        title: "Performance & Codec",
                        icon: "bolt.badge.clock.fill"
                    )

                    VStack(spacing: 8) {
                        // Game Mode (Low Latency)
                        featureToggleRow(
                            title: "Game Mode",
                            subtitle: "Ultra-low 45ms audio latency",
                            icon: "gamecontroller.fill",
                            isOn: appState.isGameModeEnabled,
                            activeBadge: "45ms"
                        ) {
                            appState.toggleGameMode()
                        }

                        // LHDC Preference (High-Res Audio)
                        featureToggleRow(
                            title: "LHDC Audio Preference",
                            subtitle: "Request 24-bit / 96 kHz high-res profile",
                            icon: "hifispeaker.fill",
                            isOn: appState.isHiResLhdcEnabled,
                            activeBadge: "Hi-Res"
                        ) {
                            appState.toggleLhdc()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func featureToggleRow(
        title: String,
        subtitle: String,
        icon: String,
        isOn: Bool,
        activeBadge: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isOn ? Theme.accentSubtle : Color.primary.opacity(0.05))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isOn ? Theme.accent : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)

                        if isOn {
                            Text(activeBadge)
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(Theme.accentSubtle))
                                .foregroundStyle(Theme.accent)
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Native iOS/macOS style mini toggle pill
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? Theme.accent : Color.primary.opacity(0.12))
                        .frame(width: 32, height: 18)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .padding(2)
                        .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                .animation(Theme.quickAnimation, value: isOn)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(isOn ? Theme.accent.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
