import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable {
    case appearance = "appearance"
    case equalizer = "equalizer"
    case connection = "connection"
    case notifications = "notifications"
    case about = "about"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .appearance: "Appearance"
        case .equalizer: "Equalizer"
        case .connection: "Connection"
        case .notifications: "Notifications"
        case .about: "About"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .appearance: "circle.lefthalf.filled"
        case .equalizer: "waveform"
        case .connection: "bolt.horizontal.circle"
        case .notifications: "bell.badge"
        case .about: "info.circle"
        }
    }
}

public struct SettingsWindowView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var appearanceManager = AppearanceManager.shared
    @State private var selectedTab: SettingsTab = .appearance

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            appearanceTab
                .tabItem {
                    Label(SettingsTab.appearance.title, systemImage: SettingsTab.appearance.sfSymbol)
                }
                .tag(SettingsTab.appearance)

            equalizerTab
                .tabItem {
                    Label(SettingsTab.equalizer.title, systemImage: SettingsTab.equalizer.sfSymbol)
                }
                .tag(SettingsTab.equalizer)

            connectionTab
                .tabItem {
                    Label(SettingsTab.connection.title, systemImage: SettingsTab.connection.sfSymbol)
                }
                .tag(SettingsTab.connection)

            notificationsTab
                .tabItem {
                    Label(SettingsTab.notifications.title, systemImage: SettingsTab.notifications.sfSymbol)
                }
                .tag(SettingsTab.notifications)

            aboutTab
                .tabItem {
                    Label(SettingsTab.about.title, systemImage: SettingsTab.about.sfSymbol)
                }
                .tag(SettingsTab.about)
        }
        .padding(20)
        .frame(width: 520, height: 460)
        .preferredColorScheme(appearanceManager.colorSchemeOverride)
    }

    // MARK: - 1. Appearance Tab
    private var appearanceTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Theme & Visual Style")
                    .font(.system(size: 15, weight: .bold))
                Text("Select an appearance mode for Realme Buds Controller. This does not alter macOS system settings.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                appearanceCard(mode: .system, title: "System", icon: "circle.lefthalf.filled", desc: "Follow macOS appearance automatically")
                appearanceCard(mode: .light, title: "Light", icon: "sun.max.fill", desc: "Always use crisp, translucent light mode")
                appearanceCard(mode: .dark, title: "Dark", icon: "moon.stars.fill", desc: "Always use immersive deep dark mode")
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("LIQUID GLASS ADAPTIVITY")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Adaptive Contrast & Transparency")
                            .font(.system(size: 12, weight: .medium))
                        Text("Translucent floating glass surfaces respect macOS 'Reduce Transparency' and 'Increase Contrast' accessibility settings.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func appearanceCard(mode: AppAppearance, title: String, icon: String, desc: String) -> some View {
        let isSelected = appearanceManager.currentPreference == mode
        Button {
            withAnimation(Theme.quickAnimation) {
                appearanceManager.currentPreference = mode
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Theme.accent : Color.primary.opacity(0.06))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.white : .primary)
                }

                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)

                Text(desc)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(height: 28)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                    .fill(isSelected ? Theme.accentSubtle : Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. Equalizer Tab
    private var equalizerTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sound Profiles & Equalizer")
                    .font(.system(size: 15, weight: .bold))
                Text("Tune the frequency response curve stored directly in the earbuds' DSP.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Presets row
            HStack(spacing: 8) {
                ForEach(EqualizerPreset.allCases) { preset in
                    eqPresetCard(preset: preset)
                }
            }

            Divider()

            // 6-Band Graphic Equalizer Visualizer & Sliders
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("6-BAND GRAPHIC EQUALIZER")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(appState.activeEqPreset.title)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.accent)
                }

                HStack(spacing: 12) {
                    ForEach($appState.currentEqBands) { $band in
                        VStack(spacing: 6) {
                            Text(String(format: "%+.1f dB", band.gainDb))
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(band.gainDb != 0 ? Theme.accent : .secondary)

                            // Vertical Slider
                            Slider(value: $band.gainDb, in: -6.0...6.0, step: 0.5)
                                .rotationEffect(.degrees(-90))
                                .frame(width: 80, height: 32)
                                .tint(Theme.accent)

                            Text(band.frequencyLabel)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.03))
                )
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func eqPresetCard(preset: EqualizerPreset) -> some View {
        let isSelected = appState.activeEqPreset == preset
        Button {
            withAnimation(Theme.quickAnimation) {
                appState.activeEqPreset = preset
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: preset.sfSymbol)
                    .font(.system(size: 14))
                Text(preset.title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
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
                    .strokeBorder(isSelected ? Color.white.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. Connection Tab
    private var connectionTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Connection & Reconnection Behaviors")
                    .font(.system(size: 15, weight: .bold))
                Text("Configure how the Mac initiates and maintains communication links.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                toggleRow(
                    title: "Automatic Connection on Launch",
                    desc: "Scan and open RFCOMM channel 15 automatically whenever app starts",
                    icon: "link",
                    isOn: $appState.autoConnectOnLaunch
                )

                toggleRow(
                    title: "Automatic Reconnection",
                    desc: "Re-establish RFCOMM control session when earbuds are taken out of the case",
                    icon: "arrow.clockwise",
                    isOn: $appState.autoReconnectOnDisconnect
                )

                toggleRow(
                    title: "Launch at Login",
                    desc: "Run Realme Buds Controller in background at system startup via SMAppService",
                    icon: "power",
                    isOn: $appState.launchAtLogin
                )
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("BACKGROUND PERSISTENCE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Image(systemName: "menubar.rectangle")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.accent)
                    Text("The controller runs as a native lightweight menu bar accessory (LSUIElement). Closing this window does not terminate background monitoring.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.03)))
            }

            Spacer()
        }
    }

    // MARK: - 4. Notifications Tab
    private var notificationsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications & Alerts")
                    .font(.system(size: 15, weight: .bold))
                Text("Control system banners and notification center alerts.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                toggleRow(
                    title: "Enable Notifications",
                    desc: "Receive alerts for earbud telemetry and multi-connect events",
                    icon: "bell.fill",
                    isOn: $appState.enableNotifications
                )

                if appState.enableNotifications {
                    VStack(spacing: 10) {
                        toggleRow(
                            title: "Low Battery Warning",
                            desc: "Notify when either earbud drops below 20% remaining charge",
                            icon: "battery.25",
                            isOn: $appState.notifyLowBattery
                        )

                        toggleRow(
                            title: "Device Connection Changes",
                            desc: "Notify when a secondary host connects, disconnects, or switches",
                            icon: "arrow.triangle.swap",
                            isOn: $appState.notifyDeviceSwitched
                        )

                        toggleRow(
                            title: "Charging Completed",
                            desc: "Notify when both earbuds and the charging case reach 100%",
                            icon: "bolt.fill",
                            isOn: $appState.notifyChargingCompleted
                        )
                    }
                    .padding(.leading, 18)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer()
        }
    }

    // MARK: - 5. About Tab
    private var aboutTab: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.accentSubtle)
                    .frame(width: 60, height: 60)
                Image(systemName: "headphones")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(spacing: 2) {
                Text("Realme Buds Controller")
                    .font(.system(size: 16, weight: .bold))
                Text("Version 1.0.0 (Build 1) · macOS 27.2")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Text("Native Apple Silicon utility designed for Realme Buds Air 7.\nDeveloped with Swift 6 and SwiftUI Liquid Glass design language.")
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 24)

            Spacer()

            Text("Design System: Liquid Glass · Soft Violet #7652C8")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func toggleRow(title: String, desc: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .frame(width: 22)
                .foregroundStyle(isOn.wrappedValue ? Theme.accent : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Theme.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }
}
