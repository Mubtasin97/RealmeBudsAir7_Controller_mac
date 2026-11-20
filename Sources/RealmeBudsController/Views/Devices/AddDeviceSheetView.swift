import SwiftUI

public struct AddDeviceSheetView: View {
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Add New Device")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 12) {
                stepRow(
                    number: "1",
                    title: "Place Earbuds in Case",
                    description: "Place both Realme Buds Air 7 into the charging case and leave the lid open."
                )

                stepRow(
                    number: "2",
                    title: "Hold Pairing Button",
                    description: "Press and hold the function button on the charging case for 3 seconds until the indicator light pulses white."
                )

                stepRow(
                    number: "3",
                    title: "Connect via Bluetooth",
                    description: "Open Bluetooth Settings on your other device (iPhone, iPad, PC) and select 'Realme Buds Air 7'."
                )
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusMedium, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )

            HStack {
                Button("Open System Bluetooth Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                .font(.system(size: 11))

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .controlSize(.small)
            }
        }
        .padding(18)
        .frame(width: 340)
    }

    private func stepRow(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 20, height: 20)
                Text(number)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                Text(description)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
