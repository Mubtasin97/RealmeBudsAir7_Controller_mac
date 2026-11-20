import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable {
    case sound = "sound"
    case features = "features"
    case connection = "connection"
    case about = "about"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sound: "Sound & EQ"
        case .features: "Features"
        case .connection: "Connection"
        case .about: "About"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .sound: "waveform"
        case .features: "slider.horizontal.2.square"
        case .connection: "gearshape.2"
        case .about: "info.circle"
        }
    }
}

public struct SettingsWindowView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var appearanceManager = AppearanceManager.shared
    @State private var selectedTab: SettingsTab = .sound

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            soundTab
                .tabItem {
                    Label(SettingsTab.sound.title, systemImage: SettingsTab.sound.sfSymbol)
                }
                .tag(SettingsTab.sound)

            featuresTab
                .tabItem {
                    Label(SettingsTab.features.title, systemImage: SettingsTab.features.sfSymbol)
                }
                .tag(SettingsTab.features)

            connectionTab
                .tabItem {
                    Label(SettingsTab.connection.title, systemImage: SettingsTab.connection.sfSymbol)
                }
                .tag(SettingsTab.connection)

            aboutTab
                .tabItem {
                    Label(SettingsTab.about.title, systemImage: SettingsTab.about.sfSymbol)
                }
                .tag(SettingsTab.about)
        }
        .padding(20)
        .frame(width: 480, height: 420)
        .preferredColorScheme(appearanceManager.colorSchemeOverride)
    }

    // MARK: - Tabs

    private var soundTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Equalizer Profiles")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(EqualizerPreset.allCases) { preset in
                    eqPresetButton(preset: preset)
                }
            }

            Divider()

            Text("Audio Enhancements")
                .font(.headline)

            VStack(spacing: 10) {
                Toggle(isOn: $appState.isSpatialAudioEnabled) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Spatial Audio")
                            .font(.system(size: 12, weight: .medium))
                        Text("Simulate 3D immersive surround soundfield")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)

                Toggle(isOn: $appState.isHiResLhdcEnabled) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("High-Res Audio (LHDC Preference)")
                            .font(.system(size: 12, weight: .medium))
                        Text("Prefer high-bitrate streaming codec when supported")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)

                Toggle(isOn: $appState.isDynamicBassEnabled) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Dynamic Bass")
                            .font(.system(size: 12, weight: .medium))
                        Text("Intelligently boost low-frequency punch in real time")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)
            }

            Spacer()
        }
    }

    private var featuresTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hardware Features")
                .font(.headline)

            VStack(spacing: 12) {
                Toggle(isOn: $appState.isInEarDetectionEnabled) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("In-Ear Detection")
                            .font(.system(size: 12, weight: .medium))
                        Text("Automatically pause playback when either earbud is removed")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)

                Toggle(isOn: $appState.isWindNoiseReductionEnabled) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Wind Noise Reduction")
                            .font(.system(size: 12, weight: .medium))
                        Text("Suppress external airflow interference over microphones")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)

                Toggle(isOn: $appState.isGameModeEnabled) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Game Mode (Low Latency)")
                            .font(.system(size: 12, weight: .medium))
                        Text("Reduce audio transmission delay for gaming and video")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)
            }

            Spacer()
        }
    }

    private var connectionTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connection Behavior")
                .font(.headline)

            VStack(spacing: 12) {
                Toggle(isOn: $appState.autoConnectOnLaunch) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Auto-Connect on Launch")
                            .font(.system(size: 12, weight: .medium))
                        Text("Automatically open RFCOMM channel when app starts")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)

                Toggle(isOn: $appState.autoReconnectOnDisconnect) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Auto-Reconnect")
                            .font(.system(size: 12, weight: .medium))
                        Text("Re-establish control channel when earbuds wake up")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)

                Toggle(isOn: $appState.launchAtLogin) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Launch at Login")
                            .font(.system(size: 12, weight: .medium))
                        Text("Start Realme Buds Controller in background at system startup")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)
            }

            Divider()

            Text("Appearance")
                .font(.headline)

            Picker("Color Mode", selection: $appearanceManager.currentPreference) {
                ForEach(AppAppearance.allCases) { appAppearance in
                    Label(appAppearance.title, systemImage: appAppearance.iconName)
                        .tag(appAppearance)
                }
            }
            .pickerStyle(.segmented)

            Spacer()
        }
    }

    private var aboutTab: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.accentSubtle)
                    .frame(width: 64, height: 64)
                Image(systemName: "headphones")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(spacing: 4) {
                Text("Realme Buds Controller")
                    .font(.system(size: 16, weight: .bold))
                Text("Version 1.0.0 (Build 1)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Text("Independent native macOS utility for Realme Buds Air 7.\nDeveloped with Swift 6 and SwiftUI for Apple Silicon.")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            Spacer()

            Text("Designed with macOS Liquid Glass theme · Soft Violet #7652C8")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func eqPresetButton(preset: EqualizerPreset) -> some View {
        let isSelected = appState.activeEqPreset == preset
        Button {
            withAnimation {
                appState.activeEqPreset = preset
            }
            appState.appendLog(
                level: .tx,
                category: "EQ",
                message: "EQ preset set to \(preset.title)"
            )
        } label: {
            VStack(spacing: 6) {
                Image(systemName: preset.sfSymbol)
                    .font(.system(size: 14))
                Text(preset.title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(isSelected ? Theme.accent : Color.primary.opacity(0.04))
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
