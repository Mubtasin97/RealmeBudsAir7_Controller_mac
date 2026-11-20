import SwiftUI

public struct PopoverRootView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var appearanceManager = AppearanceManager.shared
    public let onOpenSettingsWindow: () -> Void

    public init(onOpenSettingsWindow: @escaping () -> Void) {
        self.onOpenSettingsWindow = onOpenSettingsWindow
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            Divider()

            // Main Content Area
            ScrollView {
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
                .padding(14)
            }

            Divider()

            // Footer
            footerBar
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .frame(width: 330, height: 490)
        .preferredColorScheme(appearanceManager.colorSchemeOverride)
    }

    // MARK: - Header
    private var headerBar: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "headphones")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.accent)
                    Text("Realme Buds")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }

                Spacer()

                // Header Appearance Toggle (System -> Light -> Dark -> System)
                Button {
                    cycleAppearance()
                } label: {
                    Image(systemName: appearanceManager.currentPreference.iconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Color Theme: \(appearanceManager.currentPreference.title) (Click to cycle)")

                // Quit Menu Button
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.primary.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Quit Realme Buds Controller")
            }

            // Section Switcher Segment
            HStack(spacing: 4) {
                ForEach(NavigationSection.allCases) { section in
                    sectionPill(section: section)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionPill(section: NavigationSection) -> some View {
        let isSelected = appState.activeSection == section
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                appState.activeSection = section
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: section.sfSymbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(section.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Theme.accent : Color.primary.opacity(0.04))
            )
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inline Settings View (Quick access in Popover)
    private var inlineSettingsView: some View {
        VStack(spacing: 12) {
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    LiquidGlassSectionHeader(title: "Equalizer Preset", icon: "waveform")

                    VStack(spacing: 4) {
                        ForEach(EqualizerPreset.allCases) { preset in
                            Button {
                                appState.activeEqPreset = preset
                            } label: {
                                HStack {
                                    Image(systemName: preset.sfSymbol)
                                        .font(.system(size: 12))
                                        .frame(width: 20)
                                    Text(preset.title)
                                        .font(.system(size: 11, weight: .medium))
                                    Spacer()
                                    if appState.activeEqPreset == preset {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(Theme.accent)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(appState.activeEqPreset == preset ? Theme.accentSubtle : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    LiquidGlassSectionHeader(title: "Preferences", icon: "slider.horizontal.3")

                    Toggle("In-Ear Detection", isOn: $appState.isInEarDetectionEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(Theme.accent)

                    Toggle("High-Res Audio (LHDC)", isOn: $appState.isHiResLhdcEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(Theme.accent)

                    Toggle("Wind Noise Reduction", isOn: $appState.isWindNoiseReductionEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(Theme.accent)
                }
                .font(.system(size: 11))
            }

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

    // MARK: - Footer
    private var footerBar: some View {
        HStack {
            Text(appState.isConnected ? "● Online" : "○ Disconnected")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(appState.isConnected ? Theme.success : .secondary)

            Spacer()

            Button("Settings…") {
                onOpenSettingsWindow()
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
    }

    private func cycleAppearance() {
        switch appearanceManager.currentPreference {
        case .system:
            appearanceManager.currentPreference = .light
        case .light:
            appearanceManager.currentPreference = .dark
        case .dark:
            appearanceManager.currentPreference = .system
        }
    }
}
