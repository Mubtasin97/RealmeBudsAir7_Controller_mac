import AppKit
import SwiftUI

public struct OverviewSectionView: View {
    @ObservedObject var appState: AppState
    public let onOpenSettings: () -> Void

    public var body: some View {
        VStack(spacing: 12) {
            productBatterySection

            LiquidGlassCard {
                NoiseControlCardView(appState: appState)
            }

            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    LiquidGlassSectionHeader(
                        title: "Performance & Codec",
                        icon: "bolt.badge.clock.fill"
                    )

                    VStack(spacing: 8) {
                        featureToggleRow(
                            title: "Game Mode",
                            subtitle: "Ultra-low 45ms audio latency",
                            icon: "gamecontroller.fill",
                            isOn: appState.isGameModeEnabled,
                            activeBadge: "45ms"
                        ) {
                            appState.toggleGameMode()
                        }
                        .disabled(!appState.gameModeKnown)

                        featureToggleRow(
                            title: "LHDC Audio Preference",
                            subtitle: "Earbud preference · macOS uses AAC/SBC",
                            icon: "hifispeaker.fill",
                            isOn: appState.isHiResLhdcEnabled,
                            activeBadge: "Hi-Res"
                        ) {
                            appState.toggleLhdc()
                        }
                        .disabled(!appState.lhdcKnown)

                        featureToggleRow(
                            title: "Spatial Audio",
                            subtitle: "Use the verified spatial-audio switch",
                            icon: "arkit",
                            isOn: appState.isSpatialAudioEnabled,
                            activeBadge: "Spatial"
                        ) {
                            appState.toggleSpatialAudio()
                        }
                        .disabled(!appState.spatialAudioKnown)
                    }
                }
            }
        }
    }

    private var productBatterySection: some View {
        LiquidGlassCard {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    productImage("BudsAir7CaseOpen")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: 112)
                        .padding(.horizontal, 8)

                    caseBatteryBadge
                        .padding(.top, 4)
                        .padding(.trailing, 4)
                }

                HStack(alignment: .top, spacing: 14) {
                    budBatteryView(
                        title: "Left",
                        imageName: "BudsAir7Left",
                        status: appState.leftBattery
                    )

                    budBatteryView(
                        title: "Right",
                        imageName: "BudsAir7Right",
                        status: appState.rightBattery
                    )
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 2)
            }
        }
    }

    private func budBatteryView(title: String, imageName: String, status: BatteryStatus) -> some View {
        VStack(spacing: 5) {
            productImage(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 58, height: 62)

            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)

                batteryBadge(status: status)

                Text(status.isCharging ? "Charging" : (appState.batteryLoading && status.percentage == nil ? "Updating…" : (appState.batteryError != nil && status.percentage == nil ? "Unavailable" : "Wear status unavailable")))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(status.isCharging ? Theme.batteryCharging : .secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var caseBatteryBadge: some View {
        VStack(alignment: .trailing, spacing: 3) {
            batteryBadge(status: appState.caseBattery)
            Text(appState.caseBattery.isCharging
                 ? "Charging"
                 : (appState.batteryLoading && appState.caseBattery.percentage == nil
                    ? "Updating…"
                    : (appState.batteryError != nil && appState.caseBattery.percentage == nil ? "Unavailable" : "Case")))
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(appState.caseBattery.isCharging ? Theme.batteryCharging : .secondary)
        }
        .padding(7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func batteryBadge(status: BatteryStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: status.isCharging ? "bolt.fill" : "battery.100")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(status.isCharging ? Theme.batteryCharging : batteryColor(for: status.percentage))

            Text(status.formattedText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(status.isCharging ? Theme.batteryCharging.opacity(0.12) : Color.primary.opacity(0.06))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(status.isCharging ? Theme.batteryCharging.opacity(0.28) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func batteryColor(for percentage: Int?) -> Color {
        guard let percentage else { return .secondary }
        if percentage <= 20 { return Theme.batteryLow }
        if percentage <= 40 { return Theme.warning }
        return Theme.accent
    }

    private func productImage(_ name: String) -> Image {
        let url = Bundle.main.url(forResource: name, withExtension: "png")
            ?? Bundle.module.url(forResource: name, withExtension: "png")
        if let url, let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "rectangle.dashed")
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
