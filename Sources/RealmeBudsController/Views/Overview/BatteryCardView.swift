import SwiftUI

public struct BatteryCardView: View {
    public let slot: BudSlot
    public let status: BatteryStatus

    public var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: slot.sfSymbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(slot.shortLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 4)
                    .frame(width: 44, height: 44)

                if let pct = status.percentage {
                    Circle()
                        .trim(from: 0, to: CGFloat(pct) / 100.0)
                        .stroke(
                            status.isCharging ? Theme.batteryCharging : (pct <= 20 ? Theme.batteryLow : Theme.accent),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                }

                VStack(spacing: 0) {
                    if status.isCharging {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.batteryCharging)
                    }
                    Text(status.formattedText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
            }

            Text(status.isCharging ? "Charging" : (status.percentage != nil ? "Ready" : "Offline"))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(status.isCharging ? Theme.batteryCharging : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
