import SwiftUI

public struct BatteryCardView: View {
    public let slot: BudSlot
    public let status: BatteryStatus

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    public var body: some View {
        VStack(spacing: 8) {
            // Header icon and label
            HStack(spacing: 4) {
                Image(systemName: slot.sfSymbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(slot.shortLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // High-legibility gauge
            ZStack {
                Circle()
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06),
                        lineWidth: 4.5
                    )
                    .frame(width: 48, height: 48)

                if let pct = status.percentage {
                    Circle()
                        .trim(from: 0, to: CGFloat(pct) / 100.0)
                        .stroke(
                            gaugeColor(for: pct),
                            style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                        )
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))
                }

                VStack(spacing: 1) {
                    if status.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.batteryCharging)
                    }
                    Text(status.formattedText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }

            // Status label
            HStack(spacing: 3) {
                if status.isCharging {
                    Circle()
                        .fill(Theme.batteryCharging)
                        .frame(width: 4, height: 4)
                    Text("Charging")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.batteryCharging)
                } else if status.percentage != nil {
                    Text("Active")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Offline")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                        .strokeBorder(
                            colorSchemeContrast == .increased
                                ? Color.primary.opacity(0.3)
                                : (colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)),
                            lineWidth: 1
                        )
                )
        )
    }

    private func gaugeColor(for percentage: Int) -> Color {
        if status.isCharging { return Theme.batteryCharging }
        if percentage <= 20 { return Theme.batteryLow }
        if percentage <= 40 { return Theme.warning }
        return Theme.accent
    }
}
