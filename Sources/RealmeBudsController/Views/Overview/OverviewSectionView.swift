import SwiftUI

public struct OverviewSectionView: View {
    @ObservedObject var appState: AppState
    public let onOpenSettings: () -> Void

    public var body: some View {
        VStack(spacing: 12) {
            // Device Status Header
            LiquidGlassCard {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.accentSubtle)
                            .frame(width: 36, height: 36)
                        Image(systemName: "headphones")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.deviceName)
                            .font(.system(size: 13, weight: .bold))
                        HStack(spacing: 4) {
                            Circle()
                                .fill(appState.isConnected ? Theme.success : Theme.error)
                                .frame(width: 6, height: 6)
                            Text(appState.linkStatusText)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Quick Settings Shortcut
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(Circle().fill(Color.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    .help("Open Settings")
                }
            }

            // Granular Battery Indicators (L / R / Case)
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    LiquidGlassSectionHeader(title: "Battery Levels", icon: "battery.100.bolt")

                    HStack(spacing: 8) {
                        BatteryCardView(slot: .left, status: appState.leftBattery)
                        BatteryCardView(slot: .right, status: appState.rightBattery)
                        BatteryCardView(slot: .caseEnclosure, status: appState.caseBattery)
                    }
                }
            }

            // Noise Control
            LiquidGlassCard {
                NoiseControlCardView(appState: appState)
            }

            // Quick Hardware Toggles
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    LiquidGlassSectionHeader(title: "Quick Modes", icon: "bolt.horizontal.fill")

                    HStack(spacing: 8) {
                        // Game Mode Toggle
                        Button {
                            appState.toggleGameMode()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Game Mode")
                                    .font(.system(size: 11, weight: .medium))
                                Spacer()
                                Text(appState.isGameModeEnabled ? "ON" : "OFF")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(appState.isGameModeEnabled ? Theme.accent : .secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                    .fill(appState.isGameModeEnabled ? Theme.accentSubtle : Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                    .strokeBorder(appState.isGameModeEnabled ? Theme.accent.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        // Spatial Audio Quick Toggle
                        Button {
                            withAnimation {
                                appState.isSpatialAudioEnabled.toggle()
                            }
                            appState.appendLog(
                                level: .tx,
                                category: "SPATIAL",
                                message: "Spatial Audio toggled to \(appState.isSpatialAudioEnabled ? "ON" : "OFF")"
                            )
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Spatial")
                                    .font(.system(size: 11, weight: .medium))
                                Spacer()
                                Text(appState.isSpatialAudioEnabled ? "ON" : "OFF")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(appState.isSpatialAudioEnabled ? Theme.accent : .secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                    .fill(appState.isSpatialAudioEnabled ? Theme.accentSubtle : Color.primary.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                                    .strokeBorder(appState.isSpatialAudioEnabled ? Theme.accent.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
