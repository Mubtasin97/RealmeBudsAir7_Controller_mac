import Foundation
import CoreBluetooth
@preconcurrency import IOBluetooth

@MainActor
public final class RealmeBluetoothService: NSObject, ObservableObject {
    public static let shared = RealmeBluetoothService()

    // Documented protocol constants
    public static let documentedServiceName = "oppointeraction"
    public static let documentedServiceUUID = "0000079A-D102-11E1-9B23-00025B00A5A5"
    public static let documentedRFCOMMChannel: UInt8 = 15
    public static let dangerousOtaServiceNames = ["ota", "besota"]
    public static let dangerousOtaChannel: UInt8 = 13

    // Published Diagnostic & Connection States
    @Published public private(set) var bluetoothAvailability: BluetoothAvailabilityState = .unknown
    @Published public private(set) var earbudDetection: EarbudDetectionState = .notSearched
    @Published public private(set) var serviceDiscovery: ServiceDiscoveryState = .idle
    @Published public private(set) var rfcommState: RFCOMMConnectionState = .disconnected

    // Active Device and Channel References
    public private(set) var activeDevice: IOBluetoothDevice?
    public private(set) var activeChannel: IOBluetoothRFCOMMChannel?

    // Notifications & Central Manager
    private var centralManager: CBCentralManager?
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotification: IOBluetoothUserNotification?

    // Outstanding operations tracker
    public private(set) var isPerformingSDP = false
    public private(set) var isConnectingRFCOMM = false
    private var receiveBuffer: [UInt8] = []
    private var protocolSequence: UInt8 = 1
    private var batteryRefreshTimer: Timer?
    private var batteryResponseTimer: Timer?
    private var audioResponseTimer: Timer?
    private var pendingAudioOpcode: UInt16?
    private var pendingAudioFeature: UInt8?
    private var deviceManagementTimer: Timer?
    private var rememberedDeviceResponseTimer: Timer?
    private var pendingReplacement: (old: PairedDevice, new: PairedDevice)?
    private var reconnectTimer: Timer?
    private var reconnectAttempts: Int = 0
    private var lastConnectionFingerprint: String?

    private override init() {
        super.init()
        setupCentralManager()
        setupSystemConnectNotification()
    }

    // MARK: - Central Manager & Permissions

    private func setupCentralManager() {
        centralManager = CBCentralManager(delegate: self, queue: .main, options: [
            CBCentralManagerOptionShowPowerAlertKey: true
        ])
    }

    private func setupSystemConnectNotification() {
        // Register for system-wide Bluetooth connect notifications to detect when buds connect to macOS audio
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(handleDeviceConnectedNotification(_:device:))
        )
    }

    // MARK: - Step 1: Detect Paired Realme Buds Air 7

    @discardableResult
    public func detectPairedBuds() -> IOBluetoothDevice? {
        earbudDetection = .searching
        AppState.shared.appendLog(
            level: .info,
            category: "DEVICE",
            message: "Scanning macOS paired Bluetooth devices for Realme Buds Air 7..."
        )

        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            earbudDetection = .notFound
            AppState.shared.appendLog(
                level: .warn,
                category: "DEVICE",
                message: "No paired Bluetooth devices reported by macOS."
            )
            return nil
        }

        // Search for Realme Buds Air 7 or matching variant
        let target = paired.first { device in
            let name = (device.nameOrAddress ?? "").lowercased()
            return name.contains("realme buds air") ||
                   name.contains("buds air 7") ||
                   name.contains("buds air7") ||
                   (name.contains("realme") && name.contains("air"))
        }

        if let device = target {
            let name = device.nameOrAddress ?? "Realme Buds Air 7"
            let address = device.addressString ?? "Unknown Address"
            let isConnected = device.isConnected()

            self.activeDevice = device
            earbudDetection = .detected(name: name, address: address, isAclConnected: isConnected)

            AppState.shared.deviceName = name
            AppState.shared.appendLog(
                level: .info,
                category: "DEVICE",
                message: "Found paired earbuds: '\(name)' [\(address)] (ACL connected: \(isConnected))"
            )

            // Register specific disconnect notification for this device
            registerDeviceDisconnectNotification(device)
            return device
        } else {
            earbudDetection = .notFound
            AppState.shared.appendLog(
                level: .warn,
                category: "DEVICE",
                message: "Realme Buds Air 7 is not in paired devices list. Please pair them in macOS Bluetooth Settings."
            )
            return nil
        }
    }

    private func registerDeviceDisconnectNotification(_ device: IOBluetoothDevice) {
        disconnectNotification?.unregister()
        disconnectNotification = device.register(
            forDisconnectNotification: self,
            selector: #selector(handleDeviceDisconnectedNotification(_:device:))
        )
    }

    // MARK: - Step 2 & 3: Discover Bluetooth Services & Find OPO Control Service

    public func discoverServicesAndConnect() {
        guard rfcommState != .connecting(channel: 15),
              !isPerformingSDP,
              !isConnectingRFCOMM,
              activeChannel?.isOpen() != true else {
            AppState.shared.appendLog(
                level: .info,
                category: "RFCOMM",
                message: "Ignoring duplicate service-discovery request: an RFCOMM session is already active or connecting."
            )
            return
        }

        guard let device = activeDevice ?? detectPairedBuds() else {
            AppState.shared.appendLog(
                level: .error,
                category: "BLE",
                message: "Cannot discover services: Paired Realme Buds Air 7 not found."
            )
            return
        }

        let openRet = device.openConnection()
        if openRet == kIOReturnSuccess {
            AppState.shared.appendLog(
                level: .info,
                category: "BLE",
                message: "Normal Bluetooth ACL/baseband open accepted. Waiting briefly before SDP discovery..."
            )
        } else {
            AppState.shared.appendLog(
                level: .warn,
                category: "BLE",
                message: "device.openConnection returned code \(openRet). Proceeding with SDP discovery..."
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            guard !self.rfcommState.isConnected && !self.isConnectingRFCOMM else { return }

            self.serviceDiscovery = .querying
            self.isPerformingSDP = true
            AppState.shared.appendLog(
                level: .info,
                category: "SDP",
                message: "Performing SDP service discovery on '\(device.nameOrAddress ?? "")'..."
            )

            let status = device.performSDPQuery(self)
            if status != kIOReturnSuccess {
                self.isPerformingSDP = false
                AppState.shared.appendLog(
                    level: .warn,
                    category: "SDP",
                    message: "performSDPQuery call returned status \(status). Falling back to model-specific channel \(Self.documentedRFCOMMChannel)..."
                )
                self.serviceDiscovery = .fallback(
                    channel: Self.documentedRFCOMMChannel,
                    reason: "SDP query call returned \(status)"
                )
                self.connectRFCOMM(channelID: Self.documentedRFCOMMChannel)
            }
        }
    }

    // MARK: - Step 4: Open RFCOMM Control Connection

    public func connectRFCOMM(channelID: UInt8) {
        if rfcommState.isConnected {
            AppState.shared.appendLog(
                level: .info,
                category: "RFCOMM",
                message: "Ignoring duplicate RFCOMM open request: channel is already connected."
            )
            return
        }

        if isConnectingRFCOMM {
            AppState.shared.appendLog(
                level: .info,
                category: "RFCOMM",
                message: "Ignoring duplicate RFCOMM open request: channel open is already in progress."
            )
            return
        }

        guard let device = activeDevice else {
            AppState.shared.appendLog(
                level: .error,
                category: "RFCOMM",
                message: "Cannot open RFCOMM: No active device."
            )
            return
        }

        // Safety verification: BESOTA protection
        if channelID == Self.dangerousOtaChannel {
            AppState.shared.appendLog(
                level: .error,
                category: "SAFETY",
                message: "CRITICAL: Attempted connection to Channel \(channelID) (BESOTA / OTA firmware flashing service) was blocked by safety filter."
            )
            rfcommState = .failed(error: "BESOTA safety block", code: -1)
            return
        }

        // If already connected or connecting
        if let existing = activeChannel, existing.isOpen() {
            AppState.shared.appendLog(
                level: .info,
                category: "RFCOMM",
                message: "RFCOMM channel \(existing.getID()) is already open."
            )
            rfcommState = .connected(channel: UInt8(existing.getID()), mtu: existing.getMTU())
            return
        }

        rfcommState = .connecting(channel: channelID)
        isConnectingRFCOMM = true
        AppState.shared.appendLog(
            level: .info,
            category: "RFCOMM",
            message: "Opening RFCOMM channel \(channelID) asynchronously..."
        )

        var tempChannel: IOBluetoothRFCOMMChannel?
        let status = device.openRFCOMMChannelAsync(&tempChannel, withChannelID: channelID, delegate: self)

        if status == kIOReturnSuccess {
            if let ch = tempChannel {
                self.activeChannel = ch
            }
            AppState.shared.appendLog(
                level: .info,
                category: "RFCOMM",
                message: "openRFCOMMChannelAsync accepted (status 0). Waiting for channel open completion..."
            )
        } else {
            let errorDesc = humanReadableIOReturn(status)
            isConnectingRFCOMM = false
            rfcommState = .failed(error: errorDesc, code: status)
            AppState.shared.appendLog(
                level: .error,
                category: "RFCOMM",
                message: "openRFCOMMChannelAsync failed immediately: [\(status)] \(errorDesc)"
            )
        }
    }

    // MARK: - Step 8: Close Connection Properly

    public func closeRFCOMMConnection() {
        guard let channel = activeChannel else {
            rfcommState = .disconnected
            return
        }

        rfcommState = .disconnecting
        AppState.shared.appendLog(
            level: .info,
            category: "RFCOMM",
            message: "Closing RFCOMM channel \(channel.getID())..."
        )

        let status = channel.close()
        if status != kIOReturnSuccess {
            AppState.shared.appendLog(
                level: .warn,
                category: "RFCOMM",
                message: "channel.close() returned code \(status)"
            )
        }
        self.activeChannel = nil
        rfcommState = .disconnected
        stopBatterySession()
        AppState.shared.isConnected = false
    }

    // MARK: - Error Code Formatter

    private func humanReadableIOReturn(_ status: IOReturn) -> String {
        switch status {
        case kIOReturnSuccess:
            return "Success (kIOReturnSuccess)"
        case -536870212: // 0xE00002BC
            return "kIOReturnError (General error / Resource locked or daemon restriction)"
        case -536870187: // 0xE00002D5
            return "kIOReturnNotPermitted (Bluetooth permission denied by macOS TCC)"
        case -536870195: // 0xE00002CD
            return "kIOReturnNotResponding (Device not responding or out of range)"
        case -536870199: // 0xE00002C9
            return "kIOReturnOffline (Device offline / dormant)"
        case -536870160: // 0xE00002F0
            return "kIOReturnNotFound (Service or RFCOMM channel not found)"
        case -536870201: // 0xE00002C7
            return "kIOReturnNotOpen (Channel not open)"
        case -536870186: // 0xE00002D6
            return "kIOReturnBusy (Bluetooth subsystem busy)"
        case -536870163: // 0xE00002ED
            return "kIOReturnTimeout (Connection timed out)"
        default:
            return "IOReturn code: \(status) (0x\(String(UInt32(bitPattern: status), radix: 16, uppercase: true)))"
        }
    }
}

// MARK: - CBCentralManagerDelegate (Bluetooth Availability & Permission Handling)

extension RealmeBluetoothService: CBCentralManagerDelegate {
    public nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = central.state
        let auth = CBCentralManager.authorization

        DispatchQueue.main.async {
            switch state {
            case .poweredOn:
                MainActor.assumeIsolated {
                    RealmeBluetoothService.shared.bluetoothAvailability = .poweredOn
                    AppState.shared.appendLog(
                        level: .info,
                        category: "BLE",
                        message: "Bluetooth radio powered on and authorized (State: .poweredOn)."
                    )
                    if RealmeBluetoothService.shared.earbudDetection == .notSearched {
                        RealmeBluetoothService.shared.detectPairedBuds()
                    }
                }

            case .poweredOff:
                MainActor.assumeIsolated {
                    RealmeBluetoothService.shared.bluetoothAvailability = .poweredOff
                    AppState.shared.appendLog(
                        level: .warn,
                        category: "BLE",
                        message: "macOS Bluetooth radio is powered off."
                    )
                }

            case .unauthorized:
                let desc: String
                switch auth {
                case .denied: desc = "Access Denied by User in System Settings"
                case .restricted: desc = "Access Restricted by System Policy"
                case .notDetermined: desc = "Permission Not Determined"
                default: desc = "Unauthorized"
                }
                MainActor.assumeIsolated {
                    RealmeBluetoothService.shared.bluetoothAvailability = .unauthorized(desc)
                    AppState.shared.appendLog(
                        level: .error,
                        category: "PERM",
                        message: "Bluetooth permission error: \(desc). Check System Settings > Privacy & Security > Bluetooth."
                    )
                }

            case .unsupported:
                MainActor.assumeIsolated {
                    RealmeBluetoothService.shared.bluetoothAvailability = .unsupported
                    AppState.shared.appendLog(
                        level: .error,
                        category: "BLE",
                        message: "Bluetooth is unsupported on this hardware."
                    )
                }

            case .resetting:
                MainActor.assumeIsolated {
                    RealmeBluetoothService.shared.bluetoothAvailability = .resetting
                    AppState.shared.appendLog(
                        level: .warn,
                        category: "BLE",
                        message: "Bluetooth radio is resetting..."
                    )
                }

            case .unknown:
                MainActor.assumeIsolated {
                    RealmeBluetoothService.shared.bluetoothAvailability = .unknown
                }
            @unknown default:
                break
            }
        }
    }
}

// MARK: - SDP Service Discovery Notification Handler

extension RealmeBluetoothService {
    public func requestFirmwareInfo() {
        guard rfcommState.isConnected, activeChannel?.isOpen() == true else { return }
        writeProtocolFrame(opcode: 0x0103, payload: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.writeProtocolFrame(opcode: 0x0105, payload: [])
        }
    }

    public func refreshDeviceManagement() {
        guard rfcommState.isConnected, activeChannel?.isOpen() == true else { return }
        AppState.shared.rememberedDevicesLoading = true
        AppState.shared.rememberedDevicesError = nil
        writeProtocolFrame(opcode: 0x010D, payload: [0x01, 0x11])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.requestRememberedDevices()
        }

        deviceManagementTimer?.invalidate()
        deviceManagementTimer = Timer.scheduledTimer(withTimeInterval: 90.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.requestRememberedDevices()
                }
            }
        }
    }

    public func requestRememberedDevices() {
        guard rfcommState.isConnected, activeChannel?.isOpen() == true else {
            AppState.shared.rememberedDevicesLoading = false
            AppState.shared.rememberedDevicesError = "Bluetooth control connection unavailable"
            return
        }
        AppState.shared.rememberedDevicesLoading = true
        AppState.shared.rememberedDevicesError = nil
        writeProtocolFrame(opcode: 0x0112, payload: [])

        rememberedDeviceResponseTimer?.invalidate()
        rememberedDeviceResponseTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    AppState.shared.rememberedDevicesLoading = false
                    AppState.shared.rememberedDevicesError = "Remembered-device response timed out"
                    AppState.shared.appendLog(level: .warn, category: "MULTI_CONNECT", message: "Remembered-device query 0x0112 timed out")
                }
            }
        }
    }

    public func setDualDeviceEnabled(_ enabled: Bool) {
        guard rfcommState.isConnected, activeChannel?.isOpen() == true else { return }
        AppState.shared.rememberedDevicesLoading = true
        AppState.shared.rememberedDevicesError = nil
        writeProtocolFrame(opcode: 0x0403, payload: [0x11, enabled ? 0x01 : 0x00])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.writeProtocolFrame(opcode: 0x010D, payload: [0x01, 0x11])
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) { [weak self] in
            self?.requestRememberedDevices()
        }
    }

    public func connectRememberedDevice(_ device: PairedDevice) {
        guard !device.isThisMac else { return }
        let activeCount = AppState.shared.rememberedDevices.filter(\.isConnected).count
        if activeCount >= 2 {
            AppState.shared.rememberedDevicesError = "Both dual-connection slots are occupied"
            return
        }
        guard let mac = macBytes(from: device.macAddress) else {
            AppState.shared.rememberedDevicesError = "Invalid remembered-device address"
            return
        }
        var payload: [UInt8] = [0x01]
        payload.append(contentsOf: mac)
        payload.append(0x01)
        AppState.shared.rememberedDevicesLoading = true
        AppState.shared.rememberedDevicesError = nil
        writeProtocolFrame(opcode: 0x040B, payload: payload)
    }

    public func disconnectRememberedDevice(_ device: PairedDevice) {
        guard !device.isThisMac else {
            AppState.shared.rememberedDevicesError = "This Mac cannot be disconnected by the controller"
            return
        }
        guard let mac = macBytes(from: device.macAddress) else {
            AppState.shared.rememberedDevicesError = "Invalid remembered-device address"
            return
        }
        var payload: [UInt8] = [0x01]
        payload.append(contentsOf: mac)
        payload.append(0x00)
        AppState.shared.rememberedDevicesLoading = true
        AppState.shared.rememberedDevicesError = nil
        writeProtocolFrame(opcode: 0x040B, payload: payload)
    }

    public func requestReplaceRememberedDevice(_ oldDevice: PairedDevice, with newDevice: PairedDevice) {
        guard !oldDevice.isThisMac, !newDevice.isThisMac else { return }
        AppState.shared.pendingReplacementOld = oldDevice
        AppState.shared.pendingReplacementNew = newDevice
    }

    public func confirmReplaceRememberedDevice() {
        guard let oldDevice = AppState.shared.pendingReplacementOld,
              let newDevice = AppState.shared.pendingReplacementNew else { return }
        AppState.shared.pendingReplacementOld = nil
        AppState.shared.pendingReplacementNew = nil
        disconnectThenConnect(oldDevice: oldDevice, newDevice: newDevice)
    }

    public func cancelReplaceRememberedDevice() {
        AppState.shared.pendingReplacementOld = nil
        AppState.shared.pendingReplacementNew = nil
    }

    private func disconnectThenConnect(oldDevice: PairedDevice, newDevice: PairedDevice) {
        guard let oldMac = macBytes(from: oldDevice.macAddress),
              let newMac = macBytes(from: newDevice.macAddress) else {
            AppState.shared.rememberedDevicesError = "Invalid replacement-device address"
            return
        }
        AppState.shared.rememberedDevicesLoading = true
        var disconnectPayload: [UInt8] = [0x01]
        disconnectPayload.append(contentsOf: oldMac)
        disconnectPayload.append(0x00)
        writeProtocolFrame(opcode: 0x040B, payload: disconnectPayload)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            var connectPayload: [UInt8] = [0x01]
            connectPayload.append(contentsOf: newMac)
            connectPayload.append(0x01)
            self?.writeProtocolFrame(opcode: 0x040B, payload: connectPayload)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.requestRememberedDevices()
        }
    }

    private func macBytes(from string: String) -> [UInt8]? {
        let components = string.split(separator: ":")
        guard components.count == 6 else { return nil }
        var bytes: [UInt8] = []
        for component in components {
            guard component.count == 2, let byte = UInt8(component, radix: 16) else { return nil }
            bytes.append(byte)
        }
        return Array(bytes.reversed())
    }

    private func parseRememberedDevices(_ payload: [UInt8]) {
        rememberedDeviceResponseTimer?.invalidate()
        rememberedDeviceResponseTimer = nil
        AppState.shared.rememberedDevicesLoading = false

        guard payload.count >= 2 else {
            AppState.shared.rememberedDevicesError = "Invalid remembered-device response"
            return
        }
        let status = payload[0]
        guard status == 0x00 else {
            AppState.shared.rememberedDevicesError = "Remembered-device query rejected with status 0x\(String(status, radix: 16, uppercase: true))"
            return
        }

        let count = Int(payload[1])
        var index = 2
        var devices: [PairedDevice] = []
        let localAddress = activeDevice?.addressString?.lowercased().replacingOccurrences(of: "-", with: ":")

        for _ in 0..<count {
            guard index + 10 <= payload.count else { break }
            let addressBytes = Array(payload[index..<index + 6])
            let entryLength = Int(payload[index + 6])
            let connectionStateRaw = payload[index + 7]
            let flags = payload[index + 8]
            let nameLength = Int(payload[index + 9])
            let nameStart = index + 10
            guard nameStart + nameLength <= payload.count else { break }

            let nameBytes = Array(payload[nameStart..<nameStart + nameLength])
            let name = String(bytes: nameBytes, encoding: .utf8) ?? "Unknown Device"
            let displayBytes = addressBytes.reversed().map { String(format: "%02X", $0) }
            let macAddress = displayBytes.joined(separator: ":")
            let normalizedAddress = macAddress.lowercased()

            let isThisMac = (flags & 0x01 != 0) ||
                (localAddress != nil && (normalizedAddress == localAddress || normalizedAddress == localAddress?.replacingOccurrences(of: "-", with: ":")))
            let connected = connectionStateRaw == 0x01 || connectionStateRaw == 0x02
            let slotNumber: Int?
            if isThisMac {
                slotNumber = 1
            } else if connected {
                slotNumber = connectionStateRaw == 0x02 ? 2 : 1
            } else {
                slotNumber = nil
            }

            devices.append(PairedDevice(
                name: name,
                macAddress: macAddress,
                connectionState: connected ? .connected : .disconnected,
                slotNumber: slotNumber,
                isThisMac: isThisMac,
                iconName: isThisMac ? "laptopcomputer" : (name.lowercased().contains("phone") ? "iphone" : "display"),
                lastConnectedTime: connected ? "Connected link" : "Previously paired"
            ))

            let nextIndex = nameStart + nameLength
            if entryLength > 0 && nextIndex < index + 7 + entryLength {
                index = index + 7 + entryLength
            } else {
                index = nextIndex
            }
        }

        if AppState.shared.rememberedDevices != devices {
            AppState.shared.rememberedDevices = devices
        }
        AppState.shared.rememberedDevicesError = nil
        AppState.shared.appendLog(
            level: .info,
            category: "MULTI_CONNECT",
            message: "Remembered-device list refreshed: \(devices.count) device(s), \(devices.filter(\.isConnected).count) connected"
        )
    }

    private func parseDeviceOperationAck(_ payload: [UInt8]) {
        guard let status = payload.first else {
            AppState.shared.rememberedDevicesError = "Device operation acknowledgement was empty"
            AppState.shared.rememberedDevicesLoading = false
            return
        }
        if status == 0x00 {
            AppState.shared.rememberedDevicesError = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                self?.requestRememberedDevices()
            }
            AppState.shared.appendLog(level: .info, category: "MULTI_CONNECT", message: "Device operation confirmed")
        } else {
            AppState.shared.rememberedDevicesLoading = false
            AppState.shared.rememberedDevicesError = "Device operation rejected with status 0x\(String(status, radix: 16, uppercase: true))"
            AppState.shared.appendLog(level: .warn, category: "MULTI_CONNECT", message: "Device operation rejected")
        }
    }

    @objc public nonisolated func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        guard let device else { return }
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                let service = RealmeBluetoothService.shared
                service.isPerformingSDP = false
                service.completeSDPQuery(device, status: status)
            }
        }
    }

    private func completeSDPQuery(_ device: IOBluetoothDevice, status: IOReturn) {

        guard status == kIOReturnSuccess else {
            let err = self.humanReadableIOReturn(status)
            AppState.shared.appendLog(
                level: .warn,
                category: "SDP",
                message: "SDP query failed: \(err). Using model fallback RFCOMM channel \(Self.documentedRFCOMMChannel)..."
            )
            self.serviceDiscovery = .fallback(
                channel: Self.documentedRFCOMMChannel,
                reason: "SDP status \(status)"
            )
            self.connectRFCOMM(channelID: Self.documentedRFCOMMChannel)
            return
        }

        guard let services = device.services as? [IOBluetoothSDPServiceRecord] else {
            AppState.shared.appendLog(
                level: .warn,
                category: "SDP",
                message: "SDP succeeded but returned 0 service records. Using fallback channel \(Self.documentedRFCOMMChannel)..."
            )
            self.serviceDiscovery = .fallback(
                channel: Self.documentedRFCOMMChannel,
                reason: "Empty services"
            )
            self.connectRFCOMM(channelID: Self.documentedRFCOMMChannel)
            return
        }

        AppState.shared.appendLog(
            level: .info,
            category: "SDP",
            message: "SDP query returned \(services.count) service records. Inspecting for '\(Self.documentedServiceName)'..."
        )

        // Target UUID: 0000079A-D102-11E1-9B23-00025B00A5A5
        let cleanHex = Self.documentedServiceUUID.replacingOccurrences(of: "-", with: "")
        var bytes = [UInt8]()
        var index = cleanHex.startIndex
        while index < cleanHex.endIndex {
            let next = cleanHex.index(index, offsetBy: 2)
            if let b = UInt8(cleanHex[index..<next], radix: 16) {
                bytes.append(b)
            }
            index = next
        }
        let targetUUID = IOBluetoothSDPUUID(bytes: bytes, length: bytes.count)

        var matchedChannel: UInt8?
        var matchedName: String?

        for record in services {
            let sName = record.getServiceName() ?? "<unnamed>"
            let sNameLower = sName.lowercased()

            // Safety filter: Explicitly skip BESOTA / OTA
            if sNameLower.contains("ota") || sNameLower.contains("besota") {
                AppState.shared.appendLog(
                    level: .warn,
                    category: "SAFETY",
                    message: "Skipping firmware flashing service '\(sName)' for safety."
                )
                continue
            }

            var chID: BluetoothRFCOMMChannelID = 0
            let rfStatus = record.getRFCOMMChannelID(&chID)

            if chID == Self.dangerousOtaChannel {
                AppState.shared.appendLog(
                    level: .warn,
                    category: "SAFETY",
                    message: "Skipping unsafe channel 13 (BESOTA OTA)."
                )
                continue
            }

            let matchesUUID = record.matchesUUIDArray([targetUUID])
            let matchesName = sNameLower.contains(Self.documentedServiceName.lowercased()) ||
                              sNameLower.contains("oppo")

            if matchesUUID || matchesName {
                if rfStatus == kIOReturnSuccess && chID > 0 {
                    matchedChannel = UInt8(chID)
                    matchedName = sName
                    AppState.shared.appendLog(
                        level: .info,
                        category: "SDP",
                        message: "Discovered OPO control service '\(sName)' on RFCOMM channel \(chID) (UUID matched: \(matchesUUID))."
                    )
                    break
                }
            }
        }

        if let ch = matchedChannel, let name = matchedName {
            self.serviceDiscovery = .discovered(
                serviceName: name,
                channel: ch,
                uuid: Self.documentedServiceUUID
            )
            self.connectRFCOMM(channelID: ch)
        } else {
            AppState.shared.appendLog(
                level: .warn,
                category: "SDP",
                message: "OPO service not explicitly found in SDP records. Applying model-specific fallback RFCOMM channel \(Self.documentedRFCOMMChannel)..."
            )
            self.serviceDiscovery = .fallback(
                channel: Self.documentedRFCOMMChannel,
                reason: "Not found in SDP"
            )
            self.connectRFCOMM(channelID: Self.documentedRFCOMMChannel)
        }
    }
}

// MARK: - IOBluetoothRFCOMMChannelDelegate (Step 5, 6: Connect, Disconnect, Data)

@MainActor
extension RealmeBluetoothService: IOBluetoothRFCOMMChannelDelegate {
    public nonisolated func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        guard let rfcommChannel else { return }
        let channelID = UInt8(rfcommChannel.getID())
        let mtu = rfcommChannel.getMTU()
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                let service = RealmeBluetoothService.shared
                service.isConnectingRFCOMM = false
                if error == kIOReturnSuccess {
                    service.activeChannel = rfcommChannel
                    service.rfcommState = .connected(channel: channelID, mtu: mtu)
                    service.stopReconnectTimer()
                    AppState.shared.isConnected = true
                    AppState.shared.rfcommChannel = Int(channelID)
                    AppState.shared.linkStatusText = "Connected · RFCOMM Ch \(channelID)"

                    AppState.shared.appendLog(
                        level: .info,
                        category: "RFCOMM",
                        message: "RFCOMM connection established successfully on channel \(channelID)! (MTU: \(mtu) bytes)"
                    )
                    service.startBatterySession()
                    service.refreshDeviceManagement()
                } else {
                    let errDesc = service.humanReadableIOReturn(error)
                    service.rfcommState = .failed(error: errDesc, code: error)
                    AppState.shared.isConnected = false
                    AppState.shared.appendLog(
                        level: .error,
                        category: "RFCOMM",
                        message: "RFCOMM channel open failed: [\(error)] \(errDesc)"
                    )
                    if AppState.shared.autoReconnectOnDisconnect {
                        service.scheduleReconnect(attempt: 1)
                    }
                }
            }
        }
    }

    public nonisolated func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        guard let rfcommChannel else { return }
        let channelID = UInt8(rfcommChannel.getID())
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                AppState.shared.appendLog(
                    level: .warn,
                    category: "RFCOMM",
                    message: "RFCOMM channel \(channelID) was closed by remote device or system."
                )
                let service = RealmeBluetoothService.shared
                if service.activeChannel == rfcommChannel {
                    service.activeChannel = nil
                }
                service.rfcommState = .disconnected
                service.stopBatterySession()
                AppState.shared.isConnected = false
                AppState.shared.linkStatusText = "Disconnected"
                service.scheduleReconnect(attempt: 1)
            }
        }
    }

    public nonisolated func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        guard let dataPointer else { return }
        let receivedLength = dataLength
        let bytes = (0..<dataLength).map {
            dataPointer.advanced(by: $0).load(as: UInt8.self)
        }

        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                let service = RealmeBluetoothService.shared
                let hexString = bytes.prefix(32).map { String(format: "%02X", $0) }.joined(separator: " ")
                AppState.shared.rxPacketsCount += 1
                AppState.shared.appendLog(
                    level: .rx,
                    category: "RFCOMM",
                    message: "Received \(receivedLength) bytes from earbud control channel",
                    hexData: hexString + (receivedLength > 32 ? "..." : "")
                )
                service.receiveProtocolBytes(bytes)
            }
        }
    }
}

// MARK: - OPO battery protocol

extension RealmeBluetoothService {
    public func refreshAudioSettings() {
        guard rfcommState.isConnected, activeChannel?.isOpen() == true else { return }
        AppState.shared.audioLoading = true
        AppState.shared.audioError = nil

        writeProtocolFrame(opcode: 0x010C, payload: [0x01, 0x01])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.writeProtocolFrame(opcode: 0x010D, payload: [0x03, 0x06, 0x18, 0x1B])
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.70) { [weak self] in
            self?.writeProtocolFrame(opcode: 0x010F, payload: [])
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            AppState.shared.audioLoading = false
        }
    }

    public func setNoiseMode(_ mode: NoiseControlMode) {
        guard mode != .unknown else {
            AppState.shared.audioError = "Noise mode is not known until readback"
            return
        }
        let value: UInt8
        switch mode {
        case .unknown: value = 0x01
        case .off: value = 0x01
        case .transparency: value = 0x02
        case .anc(let strength): value = strength.rawValue
        }
        pendingAudioOpcode = 0x8404
        AppState.shared.audioLoading = true
        AppState.shared.audioError = nil
        writeProtocolFrame(opcode: 0x0404, payload: [0x01, 0x01, value])
        scheduleAudioResponseTimeout()
    }

    public func setGameMode(_ enabled: Bool) {
        pendingAudioOpcode = 0x8403
        pendingAudioFeature = 0x06
        AppState.shared.audioLoading = true
        AppState.shared.audioError = nil
        writeProtocolFrame(opcode: 0x0403, payload: [0x06, enabled ? 0x01 : 0x00])
        scheduleAudioResponseTimeout()
    }

    public func setLHDC(_ enabled: Bool) {
        pendingAudioOpcode = 0x8403
        pendingAudioFeature = 0x18
        AppState.shared.audioLoading = true
        AppState.shared.audioError = nil
        writeProtocolFrame(opcode: 0x0403, payload: [0x18, enabled ? 0x01 : 0x00])
        scheduleAudioResponseTimeout()
    }

    public func setSpatialAudio(_ enabled: Bool) {
        pendingAudioOpcode = 0x8403
        pendingAudioFeature = 0x1B
        AppState.shared.audioLoading = true
        AppState.shared.audioError = nil
        writeProtocolFrame(opcode: 0x0403, payload: [0x1B, enabled ? 0x01 : 0x00])
        scheduleAudioResponseTimeout()
    }

    public func setEQPreset(_ preset: EqualizerPreset) {
        guard preset != .custom else {
            AppState.shared.audioError = "Custom EQ curves are not exposed by the verified protocol"
            return
        }
        pendingAudioOpcode = 0x8406
        AppState.shared.audioLoading = true
        AppState.shared.audioError = nil
        writeProtocolFrame(opcode: 0x0406, payload: [preset.rawValue])
        scheduleAudioResponseTimeout()
    }

    private func scheduleAudioResponseTimeout() {
        audioResponseTimer?.invalidate()
        audioResponseTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if AppState.shared.audioLoading {
                        AppState.shared.audioLoading = false
                        AppState.shared.audioError = "Earbud acknowledgement timed out"
                        self.pendingAudioOpcode = nil
                        self.pendingAudioFeature = nil
                        AppState.shared.appendLog(level: .warn, category: "AUDIO", message: "Audio command acknowledgement timed out")
                    }
                }
            }
        }
    }

    public func handleSleep() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        receiveBuffer.removeAll(keepingCapacity: true)
        AppState.shared.appendLog(level: .info, category: "SYSTEM", message: "Mac entering sleep; preserving menu-bar state")
    }

    public func handleWake() {
        reconnectAttempts = 0
        AppState.shared.appendLog(level: .info, category: "SYSTEM", message: "Mac woke; checking Bluetooth and RFCOMM state")
        if let device = activeDevice ?? detectPairedBuds(), device.isConnected() {
            if rfcommState.isConnected, activeChannel?.isOpen() == true {
                requestBatteryStatus()
                refreshAudioSettings()
                refreshDeviceManagement()
            } else {
                scheduleReconnect(attempt: 1)
            }
        } else {
            scheduleReconnect(attempt: 1)
        }
    }

    private func scheduleReconnect(attempt: Int) {
        guard AppState.shared.autoReconnectOnDisconnect else { return }
        reconnectTimer?.invalidate()
        reconnectAttempts = attempt
        let delay = min(30.0, 2.0 * pow(2.0, Double(attempt - 1)))
        AppState.shared.appendLog(level: .info, category: "RECONNECT", message: "Scheduling RFCOMM recovery attempt \(attempt) in \(Int(delay)) seconds")
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if self.rfcommState.isConnected, self.activeChannel?.isOpen() == true {
                        self.stopReconnectTimer()
                        return
                    }
                    self.detectPairedBuds()
                    self.discoverServicesAndConnect()
                    if self.reconnectAttempts < 5 {
                        self.scheduleReconnect(attempt: self.reconnectAttempts + 1)
                    } else {
                        AppState.shared.appendLog(level: .warn, category: "RECONNECT", message: "Automatic recovery paused after 5 attempts")
                        self.reconnectTimer = nil
                    }
                }
            }
        }
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectAttempts = 0
    }

    private func startBatterySession() {
        receiveBuffer.removeAll(keepingCapacity: true)
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectAttempts = 0
        AppState.shared.batteryLoading = true
        AppState.shared.batteryError = nil
        sendHandshakeAndSubscribe()
        batteryRefreshTimer?.invalidate()
        batteryRefreshTimer = Timer.scheduledTimer(withTimeInterval: 75.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.requestBatteryStatus()
                }
            }
        }
    }

    private func stopBatterySession() {
        stopReconnectTimer()
        batteryRefreshTimer?.invalidate()
        batteryRefreshTimer = nil
        deviceManagementTimer?.invalidate()
        deviceManagementTimer = nil
        rememberedDeviceResponseTimer?.invalidate()
        rememberedDeviceResponseTimer = nil
        audioResponseTimer?.invalidate()
        audioResponseTimer = nil
        pendingAudioOpcode = nil
        pendingAudioFeature = nil
        batteryResponseTimer?.invalidate()
        batteryResponseTimer = nil
        receiveBuffer.removeAll(keepingCapacity: true)
        AppState.shared.batteryLoading = false
        AppState.shared.batteryError = nil
        AppState.shared.leftBattery = BatteryStatus()
        AppState.shared.rightBattery = BatteryStatus()
        AppState.shared.caseBattery = BatteryStatus()
        AppState.shared.rememberedDevices = []
        AppState.shared.rememberedDevicesLoading = false
        AppState.shared.rememberedDevicesError = nil
        AppState.shared.dualDeviceKnown = false
        AppState.shared.isDualConnectionEnabled = false
        AppState.shared.isInEarDetectionKnown = false
        AppState.shared.isInEarDetectionEnabled = false
        AppState.shared.activeCodec = "Unavailable"
        AppState.shared.rssi = nil
        AppState.shared.deviceModelCode = "Unavailable"
        AppState.shared.firmwareVersion = "Unavailable"
        AppState.shared.hardwareRevision = "Unavailable"
        AppState.shared.bluetoothSoC = "Unavailable"
        AppState.shared.eqPresetKnown = false
        AppState.shared.activeEqPreset = .original
        pendingReplacement = nil
        AppState.shared.pendingReplacementOld = nil
        AppState.shared.pendingReplacementNew = nil
        AppState.shared.noiseControlMode = .unknown
        AppState.shared.gameModeKnown = false
        AppState.shared.lhdcKnown = false
        AppState.shared.spatialAudioKnown = false
        AppState.shared.eqPresetKnown = false
    }

    private func sendHandshakeAndSubscribe() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
            guard let self else { return }
            self.writeProtocolFrame(opcode: 0x0100, payload: [])
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) { [weak self] in
            guard let self else { return }
            let subscription: [UInt8] = [
                0x0C, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
                0x0D, 0x0E, 0x0F, 0x10, 0xF1, 0xF2
            ]
            self.writeProtocolFrame(opcode: 0x0205, payload: subscription)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.90) { [weak self] in
            guard let self else { return }
            self.requestBatteryStatus()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.20) { [weak self] in
            self?.refreshAudioSettings()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) { [weak self] in
            self?.requestFirmwareInfo()
        }
    }

    private func requestBatteryStatus() {
        guard rfcommState.isConnected, activeChannel?.isOpen() == true else {
            AppState.shared.batteryLoading = false
            AppState.shared.batteryError = "Bluetooth control connection unavailable"
            AppState.shared.leftBattery = BatteryStatus()
            AppState.shared.rightBattery = BatteryStatus()
            AppState.shared.caseBattery = BatteryStatus()
            return
        }

        AppState.shared.batteryLoading = true
        AppState.shared.batteryError = nil
        writeProtocolFrame(opcode: 0x0106, payload: [])

        batteryResponseTimer?.invalidate()
        batteryResponseTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if AppState.shared.batteryLoading {
                        AppState.shared.batteryLoading = false
                        AppState.shared.batteryError = "Battery response timed out"
                        self.appendBatteryDiagnostics("Battery query 0x0106 timed out")
                    }
                }
            }
        }
    }

    private func writeProtocolFrame(opcode: UInt16, payload: [UInt8]) {
        guard let channel = activeChannel, channel.isOpen() else {
            AppState.shared.batteryError = "RFCOMM channel is not open"
            AppState.shared.batteryLoading = false
            return
        }

        let length = 7 + payload.count
        var frame: [UInt8] = [0xAA]
        frame.append(contentsOf: encodeLEB128(UInt32(length)))
        frame.append(contentsOf: [0x00, 0x00])
        frame.append(contentsOf: [
            UInt8(truncatingIfNeeded: opcode),
            UInt8(truncatingIfNeeded: opcode >> 8)
        ])
        frame.append(protocolSequence)
        protocolSequence = protocolSequence == 255 ? 1 : protocolSequence + 1
        frame.append(contentsOf: [
            UInt8(truncatingIfNeeded: payload.count),
            UInt8(truncatingIfNeeded: payload.count >> 8)
        ])
        frame.append(contentsOf: payload)

        let frameLength = frame.count
        let status: IOReturn = frame.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return kIOReturnError }
            return channel.writeSync(baseAddress, length: UInt16(frameLength))
        }

        if status != kIOReturnSuccess {
            AppState.shared.batteryLoading = false
            AppState.shared.batteryError = "Battery command write failed"
            if opcode >= 0x0400 {
                AppState.shared.audioLoading = false
                AppState.shared.audioError = "Earbud audio command write failed"
            }
            appendBatteryDiagnostics("Failed to write OPO frame 0x\(String(opcode, radix: 16, uppercase: true)): \(status)")
        } else {
            AppState.shared.txPacketsCount += 1
            appendBatteryDiagnostics("Sent OPO frame 0x\(String(opcode, radix: 16, uppercase: true))")
        }
    }

    private func encodeLEB128(_ value: UInt32) -> [UInt8] {
        var remaining = value
        var bytes: [UInt8] = []
        repeat {
            var byte = UInt8(remaining & 0x7F)
            remaining >>= 7
            if remaining != 0 {
                byte |= 0x80
            }
            bytes.append(byte)
        } while remaining != 0
        return bytes
    }

    private func receiveProtocolBytes(_ bytes: [UInt8]) {
        receiveBuffer.append(contentsOf: bytes)

        while !receiveBuffer.isEmpty {
            guard let preambleIndex = receiveBuffer.firstIndex(of: 0xAA) else {
                receiveBuffer.removeAll(keepingCapacity: true)
                return
            }
            if preambleIndex > 0 {
                receiveBuffer.removeFirst(preambleIndex)
            }
            guard receiveBuffer.count >= 2 else { return }

            var lengthOffset = 1
            var outerLength: UInt32 = 0
            var shift: UInt32 = 0
            var decodedLengthByte = false
            var consumedLengthBytes = 0

            while lengthOffset < receiveBuffer.count && consumedLengthBytes < 5 {
                let byte = receiveBuffer[lengthOffset]
                outerLength |= UInt32(byte & 0x7F) << shift
                consumedLengthBytes += 1
                lengthOffset += 1
                if byte & 0x80 == 0 {
                    decodedLengthByte = true
                    break
                }
                shift += 7
            }
            guard decodedLengthByte else { return }

            let frameLength = lengthOffset + Int(outerLength)
            guard receiveBuffer.count >= frameLength else { return }

            let frame = Array(receiveBuffer.prefix(frameLength))
            receiveBuffer.removeFirst(frameLength)
            decodeProtocolFrame(frame)
        }
    }

    private func decodeProtocolFrame(_ frame: [UInt8]) {
        guard frame.count >= 9 else {
            AppState.shared.packetDropCount += 1
            return
        }

        var offset = 1
        while offset < frame.count {
            let byte = frame[offset]
            offset += 1
            if byte & 0x80 == 0 { break }
        }
        guard offset + 2 + 7 <= frame.count else {
            AppState.shared.packetDropCount += 1
            return
        }

        let bodyOffset = offset + 2
        let opcode = UInt16(frame[bodyOffset]) | (UInt16(frame[bodyOffset + 1]) << 8)
        let payloadOffset = bodyOffset + 5
        guard payloadOffset <= frame.count else { return }
        let payload = Array(frame[payloadOffset...])

        if opcode == 0x8106 {
            parseBatteryResponse(payload)
        } else if opcode == 0x8103 {
            parseProductInfo(payload)
        } else if opcode == 0x8105 {
            parseFirmwareInfo(payload)
        } else if opcode == 0x0204 {
            parseBatteryPush(payload)
        } else if opcode == 0x810C {
            parseNoiseQuery(payload)
        } else if opcode == 0x8404 {
            parseNoiseAck(payload)
        } else if opcode == 0x810D {
            parseFeatureQuery(payload)
        } else if opcode == 0x8403 {
            parseFeatureAck(payload)
        } else if opcode == 0x810F {
            parseEQQuery(payload)
        } else if opcode == 0x8406 {
            parseEQAck(payload)
        } else if opcode == 0x8112 {
            parseRememberedDevices(payload)
        } else if opcode == 0x840B {
            parseDeviceOperationAck(payload)
        }
    }

    private func parseProductInfo(_ payload: [UInt8]) {
        guard payload.count >= 4 else {
            AppState.shared.hardwareRevision = "Unavailable"
            return
        }
        let status = payload[0]
        guard status == 0x00 else {
            AppState.shared.hardwareRevision = "Unavailable"
            return
        }
        AppState.shared.hardwareRevision = String(format: "0x%02X%02X%02X", payload[1], payload[2], payload[3])
    }

    private func parseFirmwareInfo(_ payload: [UInt8]) {
        guard payload.count >= 2 else {
            AppState.shared.firmwareVersion = "Unavailable"
            return
        }
        let status = payload[0]
        guard status == 0x00 else {
            AppState.shared.firmwareVersion = "Unavailable"
            return
        }
        let textBytes = Array(payload.dropFirst(1))
        if let text = String(bytes: textBytes, encoding: .utf8)?
            .components(separatedBy: "\0").first?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty {
            AppState.shared.firmwareVersion = text
        } else {
            AppState.shared.firmwareVersion = "Unavailable"
        }
    }

    private func parseBatteryPush(_ payload: [UInt8]) {
        guard payload.count >= 2 else { return }
        if payload[0] == 0x01 {
            parseBatteryEntries(Array(payload.dropFirst(2)), count: Int(payload[1]))
        } else if payload[0] == 0x03 {
            parseNoisePush(payload)
        } else if payload[0] == 0x05 {
            guard payload.count >= 2 else { return }
            let enabled = payload[1] == 0x01
            if AppState.shared.isGameModeEnabled != enabled {
                AppState.shared.isGameModeEnabled = enabled
                AppState.shared.appendLog(level: .rx, category: "AUDIO", message: "Game Mode push confirmed: \(enabled ? "ON" : "OFF")")
            }
            AppState.shared.gameModeKnown = true
        } else if payload[0] == 0xF2 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.requestRememberedDevices()
            }
        } else if [0x06, 0x0D, 0x12, 0x13, 0x16].contains(payload[0]) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.requestRememberedDevices()
            }
        }
    }

    private func parseNoisePush(_ payload: [UInt8]) {
        guard payload.count >= 4, payload[1] >= 1 else { return }
        guard payload[2] == 0x01 else { return }
        applyNoiseValue(payload[3])
    }

    private func parseNoiseQuery(_ payload: [UInt8]) {
        guard payload.count >= 4, payload[0] == 0x00 else { return }
        applyNoiseValue(payload[3])
    }

    private func applyNoiseValue(_ value: UInt8) {
        let mode: NoiseControlMode
        switch value {
        case 0x01: mode = .off
        case 0x02: mode = .transparency
        case 0x04: mode = .anc(.mild)
        case 0x10: mode = .anc(.moderate)
        case 0x08: mode = .anc(.max)
        case 0x20: mode = .anc(.smart)
        default:
            AppState.shared.audioError = "Earbuds returned an unknown noise mode"
            return
        }
        if AppState.shared.noiseControlMode != mode {
            AppState.shared.noiseControlMode = mode
            AppState.shared.appendLog(level: .rx, category: "AUDIO", message: "Noise mode push/query confirmed: \(mode.title)")
        }
        AppState.shared.audioError = nil
    }

    private func parseNoiseAck(_ payload: [UInt8]) {
        guard payload.first != nil else {
            audioAckFailure("Noise-control acknowledgement was empty")
            return
        }
        let status = payload[0]
        if status == 0x0E {
            audioAckFailure("Noise-control change refused; place both earbuds in your ears")
        } else if status != 0x00 {
            audioAckFailure("Noise-control command rejected with status 0x\(String(status, radix: 16, uppercase: true))")
        } else {
            audioAckSuccess {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    self?.writeProtocolFrame(opcode: 0x010C, payload: [0x01, 0x01])
                }
            }
        }
    }

    private func parseFeatureQuery(_ payload: [UInt8]) {
        guard payload.count >= 2, payload[0] == 0x00 else { return }
        let count = Int(payload[1])
        var index = 2
        while index + 1 < payload.count && index - 2 < count * 2 {
            let feature = payload[index]
            let value = payload[index + 1]
            index += 2
            switch feature {
            case 0x06:
                let enabled = value == 0x01
                if AppState.shared.isGameModeEnabled != enabled {
                    AppState.shared.isGameModeEnabled = enabled
                    AppState.shared.appendLog(level: .rx, category: "AUDIO", message: "Game Mode confirmed: \(enabled ? "ON" : "OFF")")
                }
                AppState.shared.gameModeKnown = true
            case 0x18:
                AppState.shared.isHiResLhdcEnabled = value == 0x01
                AppState.shared.lhdcKnown = true
            case 0x1B:
                AppState.shared.isSpatialAudioEnabled = value == 0x01
                AppState.shared.spatialAudioKnown = true
            case 0x11:
                AppState.shared.isDualConnectionEnabled = value == 0x01
                AppState.shared.dualDeviceKnown = true
            default:
                continue
            }
        }
        AppState.shared.audioError = nil
    }

    private func parseFeatureAck(_ payload: [UInt8]) {
        guard let status = payload.first else {
            audioAckFailure("Feature acknowledgement was empty")
            return
        }
        if status != 0x00 {
            audioAckFailure("Feature command rejected with status 0x\(String(status, radix: 16, uppercase: true))")
            return
        }
        let feature = pendingAudioFeature
        audioAckSuccess {
            guard let feature else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.writeProtocolFrame(opcode: 0x010D, payload: [0x01, feature])
            }
        }
        pendingAudioFeature = nil
    }

    private func parseEQQuery(_ payload: [UInt8]) {
        guard payload.count >= 2, payload[0] == 0x00 else { return }
        applyEQPreset(payload[1])
    }

    private func parseEQAck(_ payload: [UInt8]) {
        guard let status = payload.first else {
            audioAckFailure("EQ acknowledgement was empty")
            return
        }
        if status != 0x00 {
            audioAckFailure("EQ command rejected with status 0x\(String(status, radix: 16, uppercase: true))")
            return
        }
        audioAckSuccess {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.writeProtocolFrame(opcode: 0x010F, payload: [])
            }
        }
    }

    private func applyEQPreset(_ rawValue: UInt8) {
        guard let preset = EqualizerPreset(rawValue: rawValue) else {
            AppState.shared.audioError = "Earbuds returned an unknown EQ preset"
            return
        }
        AppState.shared.activeEqPreset = preset
        AppState.shared.eqPresetKnown = true
    }

    private func audioAckSuccess(_ readback: () -> Void) {
        audioResponseTimer?.invalidate()
        audioResponseTimer = nil
        pendingAudioOpcode = nil
        AppState.shared.audioLoading = true
        AppState.shared.audioError = nil
        readback()
    }

    private func audioAckFailure(_ message: String) {
        audioResponseTimer?.invalidate()
        audioResponseTimer = nil
        pendingAudioOpcode = nil
        pendingAudioFeature = nil
        AppState.shared.audioLoading = false
        AppState.shared.audioError = message
        AppState.shared.appendLog(level: .warn, category: "AUDIO", message: message)
    }

    private func parseBatteryResponse(_ payload: [UInt8]) {
        guard payload.count >= 2 else {
            batteryParseError("Battery response has no status/count")
            return
        }
        let status = payload[0]
        guard status == 0x00 else {
            batteryParseError("Battery response status 0x\(String(status, radix: 16, uppercase: true))")
            return
        }
        parseBatteryEntries(Array(payload.dropFirst(2)), count: Int(payload[1]))
    }

    private func parseBatteryEntries(_ entries: [UInt8], count: Int) {
        var values: [UInt8: BatteryStatus] = [:]
        var index = 0
        while index + 1 < entries.count && values.count < count {
            let slot = entries[index]
            let rawLevel = entries[index + 1]
            index += 2

            let unavailable = rawLevel & 0x7F == 0
            let status: BatteryStatus
            if unavailable {
                status = BatteryStatus()
            } else {
                status = BatteryStatus(
                    percentage: Int(rawLevel & 0x7F),
                    isCharging: rawLevel & 0x80 != 0
                )
            }
            values[slot] = status
        }

        batteryResponseTimer?.invalidate()
        batteryResponseTimer = nil
        batteryResponseTimer = nil
        AppState.shared.batteryLoading = false
        AppState.shared.batteryError = nil
        let left = values[0x01] ?? BatteryStatus()
        let right = values[0x02] ?? BatteryStatus()
        let caseBattery = values[0x03] ?? BatteryStatus()
        if AppState.shared.leftBattery != left ||
            AppState.shared.rightBattery != right ||
            AppState.shared.caseBattery != caseBattery {
            AppState.shared.leftBattery = left
            AppState.shared.rightBattery = right
            AppState.shared.caseBattery = caseBattery
            appendBatteryDiagnostics(
                "Battery response: L=\(AppState.shared.leftBattery.formattedText) R=\(AppState.shared.rightBattery.formattedText) Case=\(AppState.shared.caseBattery.formattedText)"
            )
        }
    }

    private func batteryParseError(_ message: String) {
        batteryResponseTimer?.invalidate()
        batteryResponseTimer = nil
        AppState.shared.batteryLoading = false
        AppState.shared.batteryError = message
        appendBatteryDiagnostics(message)
    }

    private func appendBatteryDiagnostics(_ message: String) {
        AppState.shared.appendLog(level: .info, category: "BATTERY", message: message)
    }
}

// MARK: - Device Connect/Disconnect Handlers

extension RealmeBluetoothService {
    @objc public nonisolated func handleDeviceConnectedNotification(_ notification: IOBluetoothUserNotification!, device: IOBluetoothDevice!) {
        guard let device else { return }
        let name = device.nameOrAddress ?? ""
        let lowerName = name.lowercased()
        guard lowerName.contains("realme buds air") ||
              lowerName.contains("buds air 7") ||
              lowerName.contains("buds air7") ||
              (lowerName.contains("realme") && lowerName.contains("air")) else {
            return
        }

        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                let service = RealmeBluetoothService.shared
                AppState.shared.appendLog(
                    level: .info,
                    category: "CONNECT",
                    message: "Device connect notification: '\(name)' connected to macOS."
                )
                service.activeDevice = device
                service.earbudDetection = .detected(name: name, address: device.addressString ?? "", isAclConnected: true)
                service.registerDeviceDisconnectNotification(device)

                if AppState.shared.autoConnectOnLaunch &&
                    !service.rfcommState.isConnected &&
                    !service.isConnectingRFCOMM &&
                    !service.isPerformingSDP {
                    service.discoverServicesAndConnect()
                }
            }
        }
    }

    @objc public nonisolated func handleDeviceDisconnectedNotification(_ notification: IOBluetoothUserNotification!, device: IOBluetoothDevice!) {
        guard let device else { return }
        let name = device.nameOrAddress ?? ""
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                let service = RealmeBluetoothService.shared
                AppState.shared.appendLog(
                    level: .warn,
                    category: "DISCONNECT",
                    message: "Device disconnect notification: '\(name)' disconnected from macOS."
                )
                service.earbudDetection = .detected(name: name, address: device.addressString ?? "", isAclConnected: false)
                service.closeRFCOMMConnection()
                if AppState.shared.autoReconnectOnDisconnect {
                    service.scheduleReconnect(attempt: 1)
                }
            }
        }
    }
}
