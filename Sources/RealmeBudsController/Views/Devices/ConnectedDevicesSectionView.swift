import SwiftUI

public struct ConnectedDevicesSectionView: View {
    @ObservedObject var appState: AppState
    @State private var showingAddDeviceSheet = false

    private var connectedCount: Int {
        appState.rememberedDevices.filter(\.isConnected).count
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Dual Connection Master Switch Card
            LiquidGlassCard {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Theme.accentSubtle)
                            .frame(width: 32, height: 32)
                        Image(systemName: "rectangle.2.swap")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dual-Device Connection")
                            .font(.system(size: 12, weight: .bold))
                        Text("Simultaneous Mac & Phone link")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $appState.isDualConnectionEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(Theme.accent)
                }
            }

            // Remembered Devices List
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    LiquidGlassSectionHeader(
                        title: "Paired Devices (\(connectedCount)/2 Connected)",
                        icon: "laptopcomputer.and.iphone",
                        accessory: AnyView(
                            Button {
                                showingAddDeviceSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                            }
                            .buttonStyle(.plain)
                        )
                    )

                    VStack(spacing: 6) {
                        ForEach(appState.rememberedDevices) { device in
                            deviceRow(device: device)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddDeviceSheet) {
            AddDeviceSheetView()
        }
    }

    @ViewBuilder
    private func deviceRow(device: PairedDevice) -> some View {
        HStack(spacing: 10) {
            Image(systemName: device.iconName)
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .foregroundStyle(device.isConnected ? Theme.accent : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(device.name)
                        .font(.system(size: 12, weight: .semibold))
                    if device.isThisMac {
                        Text("THIS MAC")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Theme.accentSubtle))
                            .foregroundStyle(Theme.accent)
                    }
                }
                Text(device.macAddress)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if device.isThisMac {
                Text("Active Link")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.success)
            } else {
                Button {
                    appState.toggleDeviceConnection(for: device)
                } label: {
                    Text(device.isConnected ? "Disconnect" : (connectedCount >= 2 ? "Switch" : "Connect"))
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(device.isConnected ? Color.primary.opacity(0.06) : Theme.accentSubtle)
                        )
                        .foregroundStyle(device.isConnected ? Color.secondary : Theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }
}
