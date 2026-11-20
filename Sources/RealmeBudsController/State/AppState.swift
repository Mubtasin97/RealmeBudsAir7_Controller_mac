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
        case .devices: "laptopcomputer.and.iphone"
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

    // Device Identification & Link State
    @Published public var deviceName: String = "Realme Buds Air 7"
    @Published public var firmwareVersion: String = "1.1.0.66"
    @Published public var isConnected: Bool = true
    @Published public var linkStatusText: String = "Connected (RFCOMM Ch 15)"
    @Published public var rssi: Int = -52 // dBm

    // Battery Telemetry
    @Published public var leftBattery: BatteryStatus = BatteryStatus(percentage: 85, isCharging: false)
    @Published public var rightBattery: BatteryStatus = BatteryStatus(percentage: 90, isCharging: false)
    @Published public var caseBattery: BatteryStatus = BatteryStatus(percentage: 65, isCharging: true)

    // Noise Control
    @Published public var noiseControlMode: NoiseControlMode = .anc(.smart)

    // Quick Switches
    @Published public var isGameModeEnabled: Bool = false
    @Published public var isDualConnectionEnabled: Bool = true
    @Published public var isSpatialAudioEnabled: Bool = true
    @Published public var isHiResLhdcEnabled: Bool = true
    @Published public var isInEarDetectionEnabled: Bool = true
    @Published public var isWindNoiseReductionEnabled: Bool = true
    @Published public var isDynamicBassEnabled: Bool = true

    // Equalizer
    @Published public var activeEqPreset: EqualizerPreset = .original

    // Remembered Devices
    @Published public var rememberedDevices: [PairedDevice] = [
        PairedDevice(
            name: "MacBook Pro (This Mac)",
            macAddress: "F4:D4:88:AA:11:01",
            isConnected: true,
            isThisMac: true,
            iconName: "laptopcomputer"
        ),
        PairedDevice(
            name: "Protik's iPhone 16 Pro",
            macAddress: "DC:A9:04:88:33:22",
            isConnected: true,
            isThisMac: false,
            iconName: "iphone"
        ),
        PairedDevice(
            name: "iPad Air 5",
            macAddress: "A0:C9:A0:55:77:88",
            isConnected: false,
            isThisMac: false,
            iconName: "ipad"
        )
    ]

    // Diagnostics Telemetry Log
    @Published public var diagnosticLogs: [DiagnosticEntry] = []

    // Connection Preferences
    @Published public var autoConnectOnLaunch: Bool = true
    @Published public var autoReconnectOnDisconnect: Bool = true
    @Published public var launchAtLogin: Bool = false

    private init() {
        populateInitialDiagnosticLogs()
    }

    private func populateInitialDiagnosticLogs() {
        diagnosticLogs = [
            DiagnosticEntry(
                level: .info,
                category: "INIT",
                message: "Realme Buds Controller initialized (macOS 27.2 / arm64)"
            ),
            DiagnosticEntry(
                level: .tx,
                category: "RFCOMM",
                message: "Handshake opcode 0x0100 dispatched to Channel 15",
                hexData: "AA 07 00 00 00 01 01 00 00"
            ),
            DiagnosticEntry(
                level: .rx,
                category: "RFCOMM",
                message: "Handshake ACK received from Buds Air 7",
                hexData: "AA 07 00 00 00 81 01 00 00"
            ),
            DiagnosticEntry(
                level: .rx,
                category: "BATTERY",
                message: "Battery status update: L=85%, R=90%, Case=65% (charging)",
                hexData: "AA 0D 00 00 06 81 02 06 00 00 03 01 55 02 5A 03 C1"
            ),
            DiagnosticEntry(
                level: .rx,
                category: "ANC",
                message: "Current noise mode: ANC Smart (0x20)",
                hexData: "AA 0A 00 00 0C 81 03 03 00 01 01 20"
            )
        ]
    }

    public func setNoiseMode(_ mode: NoiseControlMode) {
        withAnimation(.easeInOut(duration: 0.2)) {
            noiseControlMode = mode
        }
        appendLog(
            level: .tx,
            category: "ANC",
            message: "Noise mode switched to \(mode.title)"
        )
    }

    public func toggleGameMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isGameModeEnabled.toggle()
        }
        appendLog(
            level: .tx,
            category: "GAME_MODE",
            message: "Game mode toggled to \(isGameModeEnabled ? "ON" : "OFF")"
        )
    }

    public func toggleDeviceConnection(for device: PairedDevice) {
        guard let index = rememberedDevices.firstIndex(where: { $0.id == device.id }) else { return }

        // If trying to connect a third device while 2 are connected
        let activeCount = rememberedDevices.filter(\.isConnected).count
        if !device.isConnected && activeCount >= 2 {
            appendLog(
                level: .warn,
                category: "MULTI_CONNECT",
                message: "Max 2 active devices reached. Disconnect an existing device first to switch."
            )
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            rememberedDevices[index].isConnected.toggle()
        }

        appendLog(
            level: .tx,
            category: "MULTI_CONNECT",
            message: "\(device.name) connection state changed to \(rememberedDevices[index].isConnected ? "Connected" : "Disconnected")"
        )
    }

    public func appendLog(level: DiagnosticLevel, category: String, message: String, hexData: String? = nil) {
        let entry = DiagnosticEntry(level: level, category: category, message: message, hexData: hexData)
        diagnosticLogs.insert(entry, at: 0)
        if diagnosticLogs.count > 100 {
            diagnosticLogs.removeLast()
        }
    }

    public func clearLogs() {
        diagnosticLogs.removeAll()
    }
}
