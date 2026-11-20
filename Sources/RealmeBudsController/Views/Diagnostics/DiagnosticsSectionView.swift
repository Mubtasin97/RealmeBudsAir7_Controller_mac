import SwiftUI

public struct DiagnosticsSectionView: View {
    @ObservedObject var appState: AppState

    public var body: some View {
        VStack(spacing: 12) {
            // Signal Quality & RFCOMM Link Health Card
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    LiquidGlassSectionHeader(title: "Radio & RFCOMM Channel", icon: "antenna.radiowaves.left.and.right")

                    HStack(spacing: 12) {
                        // Signal Gauge
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SIGNAL QUALITY")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("\(appState.rssi)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(rssiColor)
                                Text("dBm")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider().frame(height: 24)

                        // Channel info
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SERVICE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                            Text("oppointeraction · Ch 15")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        }

                        Spacer()

                        // Status badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(appState.isConnected ? Theme.success : Theme.error)
                                .frame(width: 6, height: 6)
                            Text("OPEN")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.success)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.success.opacity(0.12)))
                    }
                }
            }

            // Packet Trace & Live Event Log
            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    LiquidGlassSectionHeader(
                        title: "Protocol Packet Trace",
                        icon: "doc.text.magnifyingglass",
                        accessory: AnyView(
                            HStack(spacing: 8) {
                                Button("Clear") {
                                    appState.clearLogs()
                                }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                                .buttonStyle(.plain)
                            }
                        )
                    )

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            if appState.diagnosticLogs.isEmpty {
                                Text("No packet events logged yet.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 16)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                ForEach(appState.diagnosticLogs) { entry in
                                    logRow(entry: entry)
                                }
                            }
                        }
                        .padding(4)
                    }
                    .frame(height: 140)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                            .fill(Color.black.opacity(0.15))
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
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(levelBadgeColor(entry.level).opacity(0.2)))
                    .foregroundStyle(levelBadgeColor(entry.level))

                Text("[\(entry.category)]")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text(entry.message)
                .font(.system(size: 10))
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
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.primary.opacity(0.02))
        )
    }

    private func levelBadgeColor(_ level: DiagnosticLevel) -> Color {
        switch level {
        case .info: return .blue
        case .tx: return .orange
        case .rx: return Theme.accent
        case .warn: return .yellow
        case .error: return .red
        }
    }
}
