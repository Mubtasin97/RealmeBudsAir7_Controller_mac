import SwiftUI
import Combine

public enum NavigationSection: String, CaseIterable, Identifiable, Sendable {
    case overview = "overview"
    case devices = "devices"
    case settings = "settings"
    case diagnostics = "diagnostics"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .overview: "Overview"
        case .devices: "Devices"
        case .settings: "Settings"
        case .diagnostics: "Diagnostics"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .overview: "headphones"
        case .devices: "rectangle.2.swap"
        case .settings: "slider.horizontal.3"
        case .diagnostics: "waveform.path.ecg"
        }
    }
}

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    // Active Navigation in Popover
    @Published public var activeSection: NavigationSection = .overview

    // MARK: - Device Info & Link Status
    @Published public var deviceName: String = "Realme Buds Air 7"
    @Published public var deviceModelCode: String = "RMA2401"
    @Published public var firmwareVersion: String = "1.1.0.66"
    @Published public var hardwareRevision: String = "0x064812"
    @Published public var bluetoothSoC: String = "Bestechnic BES2700YP"
    @Published public var isConnected: Bool = false
    @Published public var rfcommChannel: Int = 15
    @Published public var rfcommServiceName: String = "oppointeraction"
    @Published public var serviceUUID: String = "0000079A-D102-11E1-9B23-00025B00A5A5"
    @Published public var linkStatusText: String = "Disconnected"
    @Published public var rssi: Int = -52 // dBm
    @Published public var activeCodec: String = "AAC-LC (48 kHz / 24-bit)"
    @Published public var txPacketsCount: Int = 0
    @Published public var rxPacketsCount: Int = 0
    @Published public var packetDropCount: Int = 0

    // MARK: - Battery Telemetry
    @Published public var leftBattery: BatteryStatus = BatteryStatus(percentage: 85, isCharging: false)
    @Published public var rightBattery: BatteryStatus = BatteryStatus(percentage: 90, isCharging: false)
    @Published public var caseBattery: BatteryStatus = BatteryStatus(percentage: 65, isCharging: true)

    // MARK: - Noise Control
    @Published public var noiseControlMode: NoiseControlMode = .anc(.smart)

    // MARK: - Quick Hardware Switches
    @Published public var isGameModeEnabled: Bool = false
    @Published public var isHiResLhdcEnabled: Bool = true
    @Published public var isDualConnectionEnabled: Bool = true
    @Published public var isSpatialAudioEnabled: Bool = true
    @Published public var isInEarDetectionEnabled: Bool = true
    @Published public var isWindNoiseReductionEnabled: Bool = true
    @Published public var isDynamicBassEnabled: Bool = true

    // MARK: - Equalizer
    @Published public var activeEqPreset: EqualizerPreset = .original {
        didSet {
            currentEqBands = activeEqPreset.defaultBands
        }
    }
    @Published public var currentEqBands: [EqualizerBand] = EqualizerPreset.original.defaultBands

    // MARK: - Connected & Remembered Devices (Dual Connection)
    @Published public var rememberedDevices: [PairedDevice] = [
        PairedDevice(
            name: "MacBook Pro (This Mac)",
            macAddress: "F4:D4:88:AA:11:01",
            connectionState: .connected,
            slotNumber: 1,
            isThisMac: true,
            iconName: "laptopcomputer",
            lastConnectedTime: "Primary Host (Active)"
        ),
        PairedDevice(
            name: "Protik's iPhone 16 Pro",
            macAddress: "DC:A9:04:88:33:22",
            connectionState: .connected,
            slotNumber: 2,
            isThisMac: false,
            iconName: "iphone",
            lastConnectedTime: "Secondary Host (Active)"
        ),
        PairedDevice(
            name: "iPad Air 5",
            macAddress: "A0:C9:A0:55:77:88",
            connectionState: .disconnected,
            slotNumber: nil,
            isThisMac: false,
            iconName: "ipad",
            lastConnectedTime: "Yesterday at 18:42"
        ),
        PairedDevice(
            name: "ThinkPad X1 Carbon",
            macAddress: "50:EB:71:34:99:A0",
            connectionState: .disconnected,
            slotNumber: nil,
            isThisMac: false,
            iconName: "desktopcomputer",
            lastConnectedTime: "3 days ago"
        )
    ]

    // MARK: - Settings: Preferences
    @Published public var autoConnectOnLaunch: Bool = true
    @Published public var autoReconnectOnDisconnect: Bool = true
    @Published public var launchAtLogin: Bool = false

    // Settings: Notifications
    @Published public var enableNotifications: Bool = true
    @Published public var notifyLowBattery: Bool = true
    @Published public var notifyDeviceSwitched: Bool = true
    @Published public var notifyChargingCompleted: Bool = false

    // MARK: - Diagnostics Telemetry Log
    @Published public var diagnosticLogs: [DiagnosticEntry] = []

    private init() {
        populateInitialDiagnosticLogs()
    }

    private func populateInitialDiagnosticLogs() {
        diagnosticLogs = [
            DiagnosticEntry(
                level: .info,
                category: "SYSTEM",
                message: "Realme Buds Controller initialized. Ready for Bluetooth Classic RFCOMM communication."
            )
        ]
    }

    // MARK: - Actions

    public func setNoiseMode(_ mode: NoiseControlMode) {
        withAnimation(Theme.quickAnimation) {
            noiseControlMode = mode
        }
        appendLog(
            level: .tx,
            category: "ANC",
            message: "Noise control command 0x0404 dispatched: \(mode.title)"
        )
    }

    public func toggleGameMode() {
        withAnimation(Theme.quickAnimation) {
            isGameModeEnabled.toggle()
        }
        appendLog(
            level: .tx,
            category: "GAME_MODE",
            message: "Game mode 0x0403 [0x06] updated to \(isGameModeEnabled ? "ENABLED (45ms)" : "DISABLED")"
        )
    }

    public func toggleLhdc() {
        withAnimation(Theme.quickAnimation) {
            isHiResLhdcEnabled.toggle()
        }
        appendLog(
            level: .tx,
            category: "LHDC",
            message: "High-Res audio switch 0x0403 [0x18] updated to \(isHiResLhdcEnabled ? "ENABLED" : "DISABLED")"
        )
    }

    public func toggleDeviceConnection(for device: PairedDevice) {
        guard let index = rememberedDevices.firstIndex(where: { $0.id == device.id }) else { return }

        let activeCount = rememberedDevices.filter(\.isConnected).count
        if !device.isConnected && activeCount >= 2 {
            appendLog(
                level: .warn,
                category: "MULTI_CONNECT",
                message: "Multi-connect limit: Both hardware slots are occupied. Pick a device to disconnect first."
            )
            return
        }

        withAnimation(Theme.quickAnimation) {
            if rememberedDevices[index].isConnected {
                rememberedDevices[index].connectionState = .disconnected
                rememberedDevices[index].slotNumber = nil
            } else {
                rememberedDevices[index].connectionState = .connected
                let takenSlots = Set(rememberedDevices.compactMap(\.slotNumber))
                rememberedDevices[index].slotNumber = takenSlots.contains(1) ? 2 : 1
            }
        }

        appendLog(
            level: .tx,
            category: "MULTI_CONNECT",
            message: "0x040B operateMultiConnect sent for '\(device.name)': \(rememberedDevices[index].connectionState.rawValue)"
        )
    }

    public func swapDevice(disconnecting oldDevice: PairedDevice, connecting newDevice: PairedDevice) {
        guard let oldIdx = rememberedDevices.firstIndex(where: { $0.id == oldDevice.id }),
              let newIdx = rememberedDevices.firstIndex(where: { $0.id == newDevice.id }) else { return }

        let slot = rememberedDevices[oldIdx].slotNumber ?? 2

        withAnimation(Theme.quickAnimation) {
            rememberedDevices[oldIdx].connectionState = .disconnected
            rememberedDevices[oldIdx].slotNumber = nil

            rememberedDevices[newIdx].connectionState = .connected
            rememberedDevices[newIdx].slotNumber = slot
        }

        appendLog(
            level: .tx,
            category: "MULTI_CONNECT",
            message: "Swapped Slot \(slot): Disconnected '\(oldDevice.name)', connected '\(newDevice.name)'"
        )
    }

    public func appendLog(level: DiagnosticLevel, category: String, message: String, hexData: String? = nil) {
        let entry = DiagnosticEntry(level: level, category: category, message: message, hexData: hexData)
        diagnosticLogs.insert(entry, at: 0)
        if diagnosticLogs.count > 150 {
            diagnosticLogs.removeLast()
        }
        print("[\(entry.formattedTime)] [\(level.rawValue)] [\(category)] \(message)\(hexData != nil ? " | Hex: \(hexData!)" : "")")
    }

    public func clearLogs() {
        diagnosticLogs.removeAll()
    }
}
