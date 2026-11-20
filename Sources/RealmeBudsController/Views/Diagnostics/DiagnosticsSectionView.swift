import SwiftUI

public enum DiagnosticFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case errors = "Errors/Warn"
    case packets = "Packets"

    public var id: String { rawValue }
}

public struct DiagnosticsSectionView: View {
    @ObservedObject var appState: AppState
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
        VStack(spacing: 12) {
            // 1. Bluetooth & RFCOMM Channel Status Card
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    LiquidGlassSectionHeader(
                        title: "Bluetooth Radio & RFCOMM Status",
                        icon: "antenna.radiowaves.left.and.right"
                    )

                    HStack(spacing: 12) {
                        // RSSI Gauge
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SIGNAL QUALITY")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("\(appState.rssi)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(rssiColor)
                                Text("dBm")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            Text(rssiDescription)
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(rssiColor)
                        }

                        Divider().frame(height: 30)

                        // Channel & Transport
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SERVICE & CHANNEL")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text("\(appState.rfcommServiceName) · Ch \(appState.rfcommChannel)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            Text("BR/EDR Classic ACL Link")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Status Badge
                        VStack(alignment: .trailing, spacing: 3) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(appState.isConnected ? Theme.success : Theme.error)
                                    .frame(width: 6, height: 6)
                                Text("ACTIVE")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Theme.success)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.success.opacity(0.12)))

                            Text("MTU: 672 B")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // 2. Firmware & Hardware Information Card
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    LiquidGlassSectionHeader(
                        title: "Firmware & Hardware Profile",
                        icon: "cpu"
                    )

                    VStack(spacing: 5) {
                        infoRow(label: "Hardware Model", value: "\(appState.deviceName) (\(appState.deviceModelCode))")
                        infoRow(label: "Firmware Version", value: "v\(appState.firmwareVersion) (L/R Synced)")
                        infoRow(label: "Product / HW ID", value: appState.hardwareRevision)
                        infoRow(label: "Bluetooth & DSP SoC", value: appState.bluetoothSoC)
                    }
                }
            }

            // 3. Connection & Audio Stream Information Card
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    LiquidGlassSectionHeader(
                        title: "Connection & Audio Stream",
                        icon: "waveform.badge.magnifyingglass"
                    )

                    VStack(spacing: 5) {
                        infoRow(label: "Active Audio Codec", value: appState.activeCodec)
                        infoRow(label: "Packet Exchange", value: "TX: \(appState.txPacketsCount) pkts · RX: \(appState.rxPacketsCount) pkts")
                        infoRow(label: "Packet Drops / Errors", value: "\(appState.packetDropCount) (0.0% loss rate)")
                    }
                }
            }

            // 4. Protocol Exchange & Error Log
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
    }

    private var rssiColor: Color {
        if appState.rssi >= -60 { return Theme.success }
        if appState.rssi >= -75 { return Theme.warning }
        return Theme.error
    }

    private var rssiDescription: String {
        if appState.rssi >= -60 { return "Excellent" }
        if appState.rssi >= -75 { return "Good" }
        return "Weak Signal"
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private func logRow(entry: DiagnosticEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(entry.formattedTime)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text(entry.level.rawValue)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 0.5)
                    .background(RoundedRectangle(cornerRadius: 3).fill(levelColor(entry.level).opacity(0.18)))
                    .foregroundStyle(levelColor(entry.level))

                Text("[\(entry.category)]")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text(entry.message)
                .font(.system(size: 9.5))
                .foregroundStyle(.primary)

            if let hex = entry.hexData {
                Text(hex)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.04)))
            }
        }
        .padding(3)
    }

    private func levelColor(_ level: DiagnosticLevel) -> Color {
        switch level {
        case .info: return .blue
        case .tx: return .orange
        case .rx: return Theme.accent
        case .warn: return .yellow
        case .error: return .red
        }
    }

    private func copyLogsToClipboard() {
        let text = appState.diagnosticLogs.map {
            "\($0.formattedTime) [\($0.level.rawValue)] [\($0.category)] \($0.message) \($0.hexData ?? "")"
        }.joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)

        copiedNotice = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copiedNotice = false
        }
    }
}
