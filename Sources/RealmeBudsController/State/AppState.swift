import SwiftUI
import Combine
import ServiceManagement

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
    @Published public var deviceModelCode: String = "Unavailable"
    @Published public var firmwareVersion: String = "Unavailable"
    @Published public var hardwareRevision: String = "Unavailable"
    @Published public var bluetoothSoC: String = "Unavailable"
    @Published public var isConnected: Bool = false
    @Published public var rfcommChannel: Int = 15
    @Published public var rfcommServiceName: String = "oppointeraction"
    @Published public var serviceUUID: String = "0000079A-D102-11E1-9B23-00025B00A5A5"
    @Published public var linkStatusText: String = "Disconnected"
    @Published public var rssi: Int?
    @Published public var activeCodec: String = "Unavailable"
    @Published public var txPacketsCount: Int = 0
    @Published public var rxPacketsCount: Int = 0
    @Published public var packetDropCount: Int = 0

    // MARK: - Battery Telemetry
    @Published public var leftBattery: BatteryStatus = BatteryStatus()
    @Published public var rightBattery: BatteryStatus = BatteryStatus()
    @Published public var caseBattery: BatteryStatus = BatteryStatus()
    @Published public var batteryLoading: Bool = false
    @Published public var batteryError: String?

    // MARK: - Noise Control
    @Published public var noiseControlMode: NoiseControlMode = .unknown

    // MARK: - Quick Hardware Switches
    @Published public var isGameModeEnabled: Bool = false
    @Published public var isHiResLhdcEnabled: Bool = false
    @Published public var isDualConnectionEnabled: Bool = false
    @Published public var isSpatialAudioEnabled: Bool = false
    @Published public var gameModeKnown: Bool = false
    @Published public var lhdcKnown: Bool = false
    @Published public var spatialAudioKnown: Bool = false
    @Published public var eqPresetKnown: Bool = false
    @Published public var isInEarDetectionEnabled: Bool = false
    @Published public var isInEarDetectionKnown: Bool = false
    @Published public var isWindNoiseReductionEnabled: Bool = false
    @Published public var isDynamicBassEnabled: Bool = false
    @Published public var audioLoading: Bool = false
    @Published public var audioError: String?

    // MARK: - Equalizer
    @Published public var activeEqPreset: EqualizerPreset = .original {
        didSet {
            currentEqBands = activeEqPreset.defaultBands
        }
    }
    @Published public var currentEqBands: [EqualizerBand] = EqualizerPreset.original.defaultBands

    // MARK: - Connected & Remembered Devices (Dual Connection)
    @Published public var rememberedDevices: [PairedDevice] = []
    @Published public var rememberedDevicesLoading: Bool = false
    @Published public var rememberedDevicesError: String?
    @Published public var dualDeviceKnown: Bool = false
    @Published public var pendingReplacementOld: PairedDevice?
    @Published public var pendingReplacementNew: PairedDevice?

    // MARK: - Settings: Preferences
    @Published public var autoConnectOnLaunch: Bool = true {
        didSet { ApplicationSupportPreferences.save(key: "autoConnectOnLaunch", value: autoConnectOnLaunch) }
    }
    @Published public var autoReconnectOnDisconnect: Bool = true {
        didSet { ApplicationSupportPreferences.save(key: "autoReconnectOnDisconnect", value: autoReconnectOnDisconnect) }
    }
    @Published public var launchAtLogin: Bool = false {
        didSet {
            ApplicationSupportPreferences.save(key: "launchAtLogin", value: launchAtLogin)
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                appendLog(level: .error, category: "LOGIN_ITEM", message: "Could not update launch at login: \(error.localizedDescription)")
            }
        }
    }

    // Settings: Notifications
    @Published public var enableNotifications: Bool = true {
        didSet { ApplicationSupportPreferences.save(key: "enableNotifications", value: enableNotifications) }
    }
    @Published public var notifyLowBattery: Bool = true {
        didSet { ApplicationSupportPreferences.save(key: "notifyLowBattery", value: notifyLowBattery) }
    }
    @Published public var notifyDeviceSwitched: Bool = true {
        didSet { ApplicationSupportPreferences.save(key: "notifyDeviceSwitched", value: notifyDeviceSwitched) }
    }
    @Published public var notifyChargingCompleted: Bool = false {
        didSet { ApplicationSupportPreferences.save(key: "notifyChargingCompleted", value: notifyChargingCompleted) }
    }

    // MARK: - Diagnostics Telemetry Log
    @Published public var diagnosticLogs: [DiagnosticEntry] = []

    private init() {
        autoConnectOnLaunch = ApplicationSupportPreferences.load(key: "autoConnectOnLaunch", default: true)
        autoReconnectOnDisconnect = ApplicationSupportPreferences.load(key: "autoReconnectOnDisconnect", default: true)
        launchAtLogin = ApplicationSupportPreferences.load(key: "launchAtLogin", default: SMAppService.mainApp.status == .enabled)
        enableNotifications = ApplicationSupportPreferences.load(key: "enableNotifications", default: true)
        notifyLowBattery = ApplicationSupportPreferences.load(key: "notifyLowBattery", default: true)
        notifyDeviceSwitched = ApplicationSupportPreferences.load(key: "notifyDeviceSwitched", default: true)
        notifyChargingCompleted = ApplicationSupportPreferences.load(key: "notifyChargingCompleted", default: false)
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
        RealmeBluetoothService.shared.setNoiseMode(mode)
    }

    public func toggleGameMode() {
        RealmeBluetoothService.shared.setGameMode(!isGameModeEnabled)
    }

    public func toggleLhdc() {
        RealmeBluetoothService.shared.setLHDC(!isHiResLhdcEnabled)
    }

    public func setEQPreset(_ preset: EqualizerPreset) {
        RealmeBluetoothService.shared.setEQPreset(preset)
    }

    public func toggleSpatialAudio() {
        RealmeBluetoothService.shared.setSpatialAudio(!isSpatialAudioEnabled)
    }

    public func toggleDeviceConnection(for device: PairedDevice) {
        guard !device.isThisMac else {
            appendLog(level: .warn, category: "MULTI_CONNECT", message: "This Mac cannot be disconnected by the controller.")
            return
        }
        if device.isConnected {
            RealmeBluetoothService.shared.disconnectRememberedDevice(device)
        } else {
            RealmeBluetoothService.shared.connectRememberedDevice(device)
        }
    }

    public func swapDevice(disconnecting oldDevice: PairedDevice, connecting newDevice: PairedDevice) {
        guard !oldDevice.isThisMac, !newDevice.isThisMac else { return }
        RealmeBluetoothService.shared.requestReplaceRememberedDevice(oldDevice, with: newDevice)
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
