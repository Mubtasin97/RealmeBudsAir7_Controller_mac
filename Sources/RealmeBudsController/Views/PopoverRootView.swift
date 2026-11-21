import SwiftUI

public struct PopoverRootView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var appearanceManager = AppearanceManager.shared
    public let onOpenSettingsWindow: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    public init(onOpenSettingsWindow: @escaping () -> Void) {
        self.onOpenSettingsWindow = onOpenSettingsWindow
    }

    public var body: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                // Header Bar
                headerBar
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                Divider()

                // Scrollable Content Area
                ZStack {
                    contentBackground
                        .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            switch appState.activeSection {
                            case .overview:
                                OverviewSectionView(appState: appState, onOpenSettings: onOpenSettingsWindow)
                            case .devices:
                                ConnectedDevicesSectionView(appState: appState)
                            case .settings:
                                inlineSettingsView
                            case .diagnostics:
                                DiagnosticsSectionView(appState: appState)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                    }
                    .scrollClipDisabled(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Divider()

                // Footer Bar
                footerBar
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
        }
        .frame(width: 340, height: 500)
        .preferredColorScheme(appearanceManager.colorSchemeOverride)
    }

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    @ViewBuilder
    private var contentBackground: some View {
        if reduceTransparency {
            Rectangle()
                .fill(colorScheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color(nsColor: .controlBackgroundColor))
        } else {
            Rectangle()
                .fill(.regularMaterial)
                .overlay(
                    Rectangle()
                        .fill(colorScheme == .dark
                              ? Color.black.opacity(0.10)
                              : Color.white.opacity(0.10))
                )
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        VStack(spacing: 9) {
            HStack(alignment: .center) {
                HStack(spacing: 7) {
                    Image(systemName: "headphones")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Realme Buds Air 7")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(headerStatusText)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Dedicated Visible Appearance Button (Sun in Light, Moon in Dark)
                Button {
                    withAnimation(Theme.quickAnimation) {
                        appearanceManager.toggleLightDark()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: appearanceManager.headerButtonIconName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(!appState.eqPresetKnown)
                .help(appearanceManager.headerButtonTooltip)

                // Quit Button
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Quit Realme Buds Controller")
            }

            // Section Switcher Segmented Pills
            HStack(spacing: 4) {
                ForEach(NavigationSection.allCases) { section in
                    sectionPill(section: section)
                }
            }
        }
    }

    private var headerStatusText: String {
        let bluetooth = RealmeBluetoothService.shared
        let audioText: String
        if case .detected(_, _, let aclConnected) = bluetooth.earbudDetection {
            audioText = aclConnected ? "Audio connected" : "Audio disconnected"
        } else {
            audioText = "Audio unknown"
        }

        let controlText: String
        switch bluetooth.rfcommState {
        case .connected(let channel, _):
            controlText = "Control connected · Ch \(channel)"
        case .connecting(let channel):
            controlText = "Control connecting · Ch \(channel)"
        case .failed:
            controlText = "Control disconnected"
        case .disconnecting, .disconnected:
            controlText = "Control disconnected"
        }
        return "\(audioText) · \(controlText)"
    }

    @ViewBuilder
    private func sectionPill(section: NavigationSection) -> some View {
        let isSelected = appState.activeSection == section
        Button {
            withAnimation(Theme.quickAnimation) {
                appState.activeSection = section
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: section.sfSymbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(section.title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Theme.accent : Color.primary.opacity(0.04))
            )
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inline Settings View (Quick Popover Access)
    private var inlineSettingsView: some View {
        VStack(spacing: 12) {
            // Appearance Mode Selector Card
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    LiquidGlassSectionHeader(title: "Appearance Mode", icon: "circle.lefthalf.filled")

                    Picker("Mode", selection: $appearanceManager.currentPreference) {
                        ForEach(AppAppearance.allCases) { mode in
                            Label(mode.title, systemImage: mode.iconName)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            // Quick EQ Preset Selector Card
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    LiquidGlassSectionHeader(title: "Equalizer Preset", icon: "waveform")

                    VStack(spacing: 4) {
                        ForEach(EqualizerPreset.allCases) { preset in
                            Button {
                                appState.setEQPreset(preset)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: preset.sfSymbol)
                                        .font(.system(size: 12))
                                        .frame(width: 18)
                                        .foregroundStyle(appState.eqPresetKnown && appState.activeEqPreset == preset ? Theme.accent : .secondary)

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(preset.title)
                                            .font(.system(size: 11, weight: .medium))
                                        Text(preset.descriptionText)
                                            .font(.system(size: 9))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if appState.eqPresetKnown && appState.activeEqPreset == preset {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(Theme.accent)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(appState.eqPresetKnown && appState.activeEqPreset == preset ? Theme.accentSubtle : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(!appState.eqPresetKnown)
                        }
                    }
                }
            }

            // Connection & Notifications Card
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    LiquidGlassSectionHeader(title: "Quick Behaviors", icon: "gearshape")

                    Toggle("Auto-Reconnect on Wake", isOn: $appState.autoReconnectOnDisconnect)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(Theme.accent)

                    HStack {
                        Text(appState.isInEarDetectionKnown ? "In-Ear Detection" : "In-Ear Detection")
                        Spacer()
                        Text(appState.isInEarDetectionKnown
                             ? (appState.isInEarDetectionEnabled ? "Enabled" : "Disabled")
                             : "Unavailable")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 11))

                    Toggle("System Notifications", isOn: $appState.enableNotifications)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(Theme.accent)
                }
                .font(.system(size: 11))
            }

            // Open Separate Settings Window Button
            Button(action: onOpenSettingsWindow) {
                HStack(spacing: 6) {
                    Image(systemName: "macwindow")
                    Text("Open Detailed Settings Window…")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall)
                        .fill(Theme.accentSubtle)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack {
            HStack(spacing: 5) {
                Circle()
                    .fill(appState.isConnected ? Theme.success : Theme.error)
                    .frame(width: 6, height: 6)
                Text(appState.isConnected ? "Control connected" : "Control disconnected")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Settings Window…") {
                onOpenSettingsWindow()
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.accent)
            .buttonStyle(.plain)
        }
    }
}
