import SwiftUI

public enum DiagnosticFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case errors = "Errors/Warn"
    case packets = "Packets"

    public var id: String { rawValue }
}

public struct DiagnosticsSectionView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var bluetooth = RealmeBluetoothService.shared
    @State private var activeFilter: DiagnosticFilter = .all
    @State private var copiedNotice = false

    @Environment(\.colorScheme) private var colorScheme

    private var filteredLogs: [DiagnosticEntry] {
        switch activeFilter {
        case .all:
            return appState.diagnosticLogs
        case .errors:
            return appState.diagnosticLogs.filter { $0.level == .error || $0.level == .warn }
        case .packets:
            return appState.diagnosticLogs.filter { $0.level == .tx || $0.level == .rx }
        }
    }

    public var body: some View {
        VStack(spacing: 10) {
            // 1. Bluetooth Availability
            bluetoothAvailabilityCard

            // 2. Earbud Detection
            earbudDetectionCard

            // 3. Service Discovery
            serviceDiscoveryCard

            // 4. RFCOMM Connection Status
            rfcommConnectionStatusCard

            // 5. Diagnostic Event Log
            diagnosticLogCard
        }
    }

    // MARK: - 1. Bluetooth Availability Card

    private var bluetoothAvailabilityCard: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    LiquidGlassSectionHeader(
                        title: "1. Bluetooth Availability",
                        icon: bluetooth.bluetoothAvailability.sfSymbol
                    )
                    Spacer()
                    badgeView(
                        title: bluetooth.bluetoothAvailability.isAvailable ? "AVAILABLE" : "UNAVAILABLE",
                        color: bluetooth.bluetoothAvailability.isAvailable ? Theme.success : Theme.error
                    )
                }

                VStack(spacing: 5) {
                    infoRow(
                        label: "Radio State",
                        value: bluetooth.bluetoothAvailability.title
                    )
                    infoRow(
                        label: "TCC Permission",
                        value: permissionDescription
                    )
                }
            }
        }
    }

    // MARK: - 2. Earbud Detection Card

    private var earbudDetectionCard: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    LiquidGlassSectionHeader(
                        title: "2. Earbud Detection",
                        icon: "headphones"
                    )
                    Spacer()
                    switch bluetooth.earbudDetection {
                    case .detected(_, _, let acl):
                        badgeView(
                            title: acl ? "CONNECTED" : "PAIRED",
                            color: acl ? Theme.success : Theme.warning
                        )
                    case .searching:
                        badgeView(title: "SCANNING", color: Theme.accent)
                    case .notFound, .notSearched:
                        badgeView(title: "NOT FOUND", color: Theme.error)
                    }
                }

                VStack(spacing: 5) {
                    switch bluetooth.earbudDetection {
                    case .detected(let name, let address, let isAclConnected):
                        infoRow(label: "Target Device", value: name)
                        infoRow(label: "Bluetooth Address", value: address)
                        infoRow(
                            label: "macOS ACL Audio Link",
                            value: isAclConnected ? "Active (Connected)" : "Dormant (Disconnected)"
                        )
                    case .searching:
                        infoRow(label: "Status", value: "Scanning paired devices...")
                    case .notFound:
                        infoRow(label: "Status", value: "No Realme Buds Air 7 detected in paired list")
                    case .notSearched:
                        infoRow(label: "Status", value: "Not scanned yet")
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        bluetooth.detectPairedBuds()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Scan Paired Devices")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.accent.opacity(0.12)))
                        .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 3. Service Discovery Card

    private var serviceDiscoveryCard: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    LiquidGlassSectionHeader(
                        title: "3. Service Discovery (SDP)",
                        icon: "magnifyingglass.circle"
                    )
                    Spacer()
                    switch bluetooth.serviceDiscovery {
                    case .discovered:
                        badgeView(title: "DISCOVERED", color: Theme.success)
                    case .fallback:
                        badgeView(title: "FALLBACK CH 15", color: Theme.warning)
                    case .querying:
                        badgeView(title: "QUERYING", color: Theme.accent)
                    case .failed:
                        badgeView(title: "FAILED", color: Theme.error)
                    case .idle:
                        badgeView(title: "IDLE", color: .secondary)
                    }
                }

                VStack(spacing: 5) {
                    infoRow(label: "Control Service Name", value: RealmeBluetoothService.documentedServiceName)
                    infoRow(label: "Service UUID", value: RealmeBluetoothService.documentedServiceUUID)

                    switch bluetooth.serviceDiscovery {
                    case .discovered(let name, let channel, _):
                        infoRow(label: "Resolved Service", value: "\(name) · RFCOMM Ch \(channel)")
                    case .fallback(let channel, let reason):
                        infoRow(label: "Resolved Channel", value: "Channel \(channel) (Fallback: \(reason))")
                    case .querying:
                        infoRow(label: "SDP Status", value: "Querying SDP service records from device...")
                    case .failed(let err):
                        infoRow(label: "SDP Status", value: "Failed: \(err)")
                    case .idle:
                        infoRow(label: "SDP Status", value: "Awaiting discovery trigger")
                    }

                    // BESOTA Safety Protection Row
                    HStack {
                        Text("OTA Protection")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Theme.success)
                            Text("BESOTA (Ch 13) Blocked")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Theme.success)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        bluetooth.discoverServicesAndConnect()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform.badge.magnifyingglass")
                            Text("Discover Services & Connect")
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.accent.opacity(0.12)))
                        .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(bluetooth.isPerformingSDP)
                }
            }
        }
    }

    // MARK: - 4. RFCOMM Connection Status Card

    private var rfcommConnectionStatusCard: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    LiquidGlassSectionHeader(
                        title: "4. RFCOMM Control Connection",
                        icon: "cable.connector"
                    )
                    Spacer()
                    switch bluetooth.rfcommState {
                    case .connected:
                        badgeView(title: "CONNECTED", color: Theme.success)
                    case .connecting:
                        badgeView(title: "CONNECTING", color: Theme.warning)
                    case .disconnecting:
                        badgeView(title: "CLOSING", color: Theme.warning)
                    case .failed:
                        badgeView(title: "FAILED", color: Theme.error)
                    case .disconnected:
                        badgeView(title: "DISCONNECTED", color: .secondary)
                    }
                }

                VStack(spacing: 5) {
                    switch bluetooth.rfcommState {
                    case .connected(let channel, let mtu):
                        infoRow(label: "RFCOMM Channel", value: "Channel \(channel) (Active)")
                        infoRow(label: "Maximum Transmission Unit", value: "\(mtu) Bytes")
                        infoRow(label: "Telemetry Packets", value: "RX: \(appState.rxPacketsCount) pkts")
                    case .connecting(let channel):
                        infoRow(label: "RFCOMM Channel", value: "Channel \(channel) (Connecting...)")
                        infoRow(label: "Status", value: "Asynchronous channel open pending...")
                    case .failed(let error, let code):
                        infoRow(label: "Error Code", value: "\(code) (0x\(String(UInt32(bitPattern: code), radix: 16, uppercase: true)))")
                        infoRow(label: "Error Detail", value: error)
                    case .disconnecting:
                        infoRow(label: "Status", value: "Closing channel cleanly...")
                    case .disconnected:
                        infoRow(label: "Status", value: "RFCOMM channel is closed")
                        infoRow(label: "Default Channel", value: "Channel \(RealmeBluetoothService.documentedRFCOMMChannel)")
                    }
                }

                HStack(spacing: 8) {
                    Spacer()
                    if bluetooth.rfcommState.isConnected {
                        Button {
                            bluetooth.closeRFCOMMConnection()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle")
                                Text("Close Connection")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.error.opacity(0.12)))
                            .foregroundStyle(Theme.error)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            let ch = bluetooth.serviceDiscovery.resolvedChannel ?? RealmeBluetoothService.documentedRFCOMMChannel
                            bluetooth.connectRFCOMM(channelID: ch)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                Text("Open RFCOMM Channel")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.accent.opacity(0.12)))
                            .foregroundStyle(Theme.accent)
                        }
                        .buttonStyle(.plain)
                        .disabled(bluetooth.isConnectingRFCOMM)
                    }
                }
            }
        }
    }

    // MARK: - 5. Diagnostic Event Log Card

    private var diagnosticLogCard: some View {
        LiquidGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    LiquidGlassSectionHeader(
                        title: "Diagnostic Event Log (\(filteredLogs.count))",
                        icon: "doc.text.magnifyingglass"
                    )
                    Spacer()
                    HStack(spacing: 6) {
                        Button(copiedNotice ? "Copied!" : "Copy") {
                            copyLogsToClipboard()
                        }
                        .font(.system(size: 9, weight: .medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.accent)

                        Button("Clear") {
                            appState.clearLogs()
                        }
                        .font(.system(size: 9, weight: .medium))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }

                // Filter tabs
                HStack(spacing: 4) {
                    ForEach(DiagnosticFilter.allCases) { filter in
                        Button {
                            activeFilter = filter
                        } label: {
                            Text(filter.rawValue)
                                .font(.system(size: 9, weight: activeFilter == filter ? .bold : .medium))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(activeFilter == filter ? Theme.accent : Color.primary.opacity(0.05)))
                                .foregroundStyle(activeFilter == filter ? Color.white : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Scrollable logs area
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        if filteredLogs.isEmpty {
                            Text("No events recorded for current filter.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(filteredLogs) { entry in
                                logRow(entry: entry)
                            }
                        }
                    }
                    .padding(4)
                }
                .frame(height: 120)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.04))
                )
            }
        }
    }

    // MARK: - Helpers

    private var permissionDescription: String {
        switch bluetooth.bluetoothAvailability {
        case .unauthorized(let reason):
            return reason
        case .poweredOn, .poweredOff, .resetting:
            return "Authorized (Always Allowed)"
        case .unsupported:
            return "Unsupported"
        case .unknown:
            return "Verifying..."
        }
    }

    private func badgeView(title: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 9, weight: .regular))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func logRow(entry: DiagnosticEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Text(entry.formattedTime)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text(entry.level.rawValue)
                    .font(.system(size: 7, weight: .bold))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(logColor(for: entry.level).opacity(0.18)))
                    .foregroundStyle(logColor(for: entry.level))

                Text("[\(entry.category)]")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.accent)

                Spacer()
            }

            Text(entry.message)
                .font(.system(size: 9))
                .foregroundStyle(.primary)

            if let hex = entry.hexData {
                Text(hex)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Color.secondary.opacity(0.8))
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(0.02))
        )
    }

    private func logColor(for level: DiagnosticLevel) -> Color {
        switch level {
        case .info: return Color.blue
        case .tx: return Color.orange
        case .rx: return Color.green
        case .warn: return Color.yellow
        case .error: return Color.red
        }
    }

    private func copyLogsToClipboard() {
        let text = filteredLogs.map { entry in
            "[\(entry.formattedTime)] [\(entry.level.rawValue)] [\(entry.category)] \(entry.message)\(entry.hexData != nil ? " | Hex: \(entry.hexData!)" : "")"
        }.joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        copiedNotice = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copiedNotice = false
        }
    }
}
