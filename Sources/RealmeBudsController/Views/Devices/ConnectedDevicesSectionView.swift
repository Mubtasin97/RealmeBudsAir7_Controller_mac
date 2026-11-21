import SwiftUI

public struct ConnectedDevicesSectionView: View {
    @ObservedObject var appState: AppState
    @State private var showingAddDeviceSheet = false
    @State private var deviceToSwap: PairedDevice? = nil

    @Environment(\.colorScheme) private var colorScheme

    private var activeSlot1Device: PairedDevice? {
        appState.rememberedDevices.first { $0.isConnected && $0.slotNumber == 1 }
    }

    private var activeSlot2Device: PairedDevice? {
        appState.rememberedDevices.first { $0.isConnected && $0.slotNumber == 2 }
    }

    private var inactiveDevices: [PairedDevice] {
        appState.rememberedDevices.filter { !$0.isConnected }
    }

    private var activeCount: Int {
        appState.rememberedDevices.filter(\.isConnected).count
    }

    public var body: some View {
        VStack(spacing: 12) {
            // Dual Connection Status Card
            LiquidGlassCard {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.accentSubtle)
                            .frame(width: 36, height: 36)
                        Image(systemName: "rectangle.2.swap")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Dual-Device Connection")
                                .font(.system(size: 13, weight: .bold))
                            Text(appState.dualDeviceKnown
                                 ? (appState.isDualConnectionEnabled ? "ENABLED" : "DISABLED")
                                 : "READING")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(appState.isDualConnectionEnabled ? Theme.accentSubtle : Color.primary.opacity(0.06)))
                                .foregroundStyle(appState.isDualConnectionEnabled ? Theme.accent : .secondary)
                        }
                        Text("Connect 2 Bluetooth devices simultaneously")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text("Audio source switching is controlled by the earbuds")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { appState.isDualConnectionEnabled },
                        set: { RealmeBluetoothService.shared.setDualDeviceEnabled($0) }
                    ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .tint(Theme.accent)
                        .disabled(!appState.dualDeviceKnown)
                }
            }

            // Two Connection Slots Section
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    LiquidGlassSectionHeader(
                        title: "Hardware Connection Slots (\(activeCount)/2)",
                        icon: "link.badge.plus"
                    )

                    VStack(spacing: 8) {
                        hardwareSlotCard(slotNumber: 1, device: activeSlot1Device, isPrimary: true)
                        hardwareSlotCard(slotNumber: 2, device: activeSlot2Device, isPrimary: false)
                    }
                }
            }

            // Remembered Devices List
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    LiquidGlassSectionHeader(
                        title: "Remembered Devices (\(inactiveDevices.count))",
                        icon: "clock.arrow.circlepath",
                        accessory: AnyView(
                            HStack(spacing: 8) {
                                Button {
                                    RealmeBluetoothService.shared.requestRememberedDevices()
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                }
                                .buttonStyle(.plain)
                                .disabled(appState.rememberedDevicesLoading)

                                Button {
                                    showingAddDeviceSheet = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Device")
                                    }
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Theme.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        )
                    )

                    if appState.rememberedDevicesLoading && appState.rememberedDevices.isEmpty {
                        Text("Reading remembered devices…")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else if let error = appState.rememberedDevicesError {
                        Text(error)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else if inactiveDevices.isEmpty && appState.rememberedDevices.isEmpty {
                        Text("No remembered devices received yet.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if inactiveDevices.isEmpty {
                        Text("All paired devices are currently active in slots.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(inactiveDevices) { device in
                                rememberedDeviceRow(device: device)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddDeviceSheet) {
            AddDeviceSheetView()
        }
        .confirmationDialog(
            "Replace connected device?",
            isPresented: Binding(
                get: { appState.pendingReplacementOld != nil && appState.pendingReplacementNew != nil },
                set: { presented in
                    if !presented {
                        RealmeBluetoothService.shared.cancelReplaceRememberedDevice()
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Replace Device", role: .destructive) {
                RealmeBluetoothService.shared.confirmReplaceRememberedDevice()
            }
            Button("Cancel", role: .cancel) {
                RealmeBluetoothService.shared.cancelReplaceRememberedDevice()
            }
        } message: {
            if let oldDevice = appState.pendingReplacementOld,
               let newDevice = appState.pendingReplacementNew {
                Text("Disconnect \(oldDevice.name) and connect \(newDevice.name)? This Mac will remain connected.")
            }
        }
    }

    // MARK: - Hardware Slot Card View
    @ViewBuilder
    private func hardwareSlotCard(slotNumber: Int, device: PairedDevice?, isPrimary: Bool) -> some View {
        HStack(spacing: 10) {
            // Slot Badge
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(device != nil ? Theme.accent : Color.primary.opacity(0.08))
                    .frame(width: 28, height: 28)
                Text("S\(slotNumber)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(device != nil ? Color.white : .secondary)
            }

            if let device {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(device.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                        if device.isThisMac {
                            Text("THIS MAC")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Theme.accentSubtle))
                                .foregroundStyle(Theme.accent)
                        }
                    }

                    Text(device.lastConnectedTime)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !device.isThisMac {
                    Button("Disconnect") {
                        appState.toggleDeviceConnection(for: device)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.success)
                            .frame(width: 6, height: 6)
                        Text("Connected link")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.success)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Slot \(slotNumber) Available")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Ready for a secondary device connection")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text("Available")
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.05)))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .fill(device != nil ? (colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.02)) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                        .strokeBorder(
                            device != nil ? Theme.accent.opacity(0.2) : Color.primary.opacity(0.06),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Remembered Device Row
    @ViewBuilder
    private func rememberedDeviceRow(device: PairedDevice) -> some View {
        HStack(spacing: 10) {
            Image(systemName: device.iconName)
                .font(.system(size: 14))
                .frame(width: 24, height: 24)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(.system(size: 11, weight: .semibold))
                HStack(spacing: 4) {
                    Text(device.macAddress)
                        .font(.system(size: 9, design: .monospaced))
                    Text("·")
                    Text(device.lastConnectedTime)
                        .font(.system(size: 9))
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            if activeCount < 2 {
                Button("Connect") {
                    appState.toggleDeviceConnection(for: device)
                }
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.accentSubtle))
                .foregroundStyle(Theme.accent)
                .buttonStyle(.plain)
            } else if let secondary = activeSlot2Device, !secondary.isThisMac {
                Button("Swap In") {
                    appState.swapDevice(disconnecting: secondary, connecting: device)
                }
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(Theme.accentSubtle))
                .foregroundStyle(Theme.accent)
                .buttonStyle(.plain)
                .help("Disconnect \(secondary.name) and connect \(device.name)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .fill(Color.primary.opacity(0.02))
        )
    }
}
