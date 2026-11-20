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
        guard let device = activeDevice ?? detectPairedBuds() else {
            AppState.shared.appendLog(
                level: .error,
                category: "BLE",
                message: "Cannot discover services: Paired Realme Buds Air 7 not found."
            )
            return
        }

        if !device.isConnected() {
            AppState.shared.appendLog(
                level: .warn,
                category: "BLE",
                message: "Earbuds are not currently connected to macOS audio/ACL. Attempting baseband open..."
            )
            let openRet = device.openConnection()
            if openRet != kIOReturnSuccess {
                AppState.shared.appendLog(
                    level: .warn,
                    category: "BLE",
                    message: "device.openConnection returned code \(openRet). Proceeding with discovery..."
                )
            }
        }

        serviceDiscovery = .querying
        isPerformingSDP = true
        AppState.shared.appendLog(
            level: .info,
            category: "SDP",
            message: "Performing SDP service discovery on '\(device.nameOrAddress ?? "")'..."
        )

        let status = device.performSDPQuery(self)
        if status != kIOReturnSuccess {
            AppState.shared.appendLog(
                level: .warn,
                category: "SDP",
                message: "performSDPQuery call returned status \(status). Falling back to model-specific channel \(Self.documentedRFCOMMChannel)..."
            )
            serviceDiscovery = .fallback(
                channel: Self.documentedRFCOMMChannel,
                reason: "SDP query call returned \(status)"
            )
            connectRFCOMM(channelID: Self.documentedRFCOMMChannel)
        }
    }

    // MARK: - Step 4: Open RFCOMM Control Connection

    public func connectRFCOMM(channelID: UInt8) {
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
    @objc public func sdpQueryComplete(_ device: IOBluetoothDevice!, status: IOReturn) {
        self.isPerformingSDP = false

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
extension RealmeBluetoothService: @preconcurrency IOBluetoothRFCOMMChannelDelegate {
    public func rfcommChannelOpenComplete(_ rfcommChannel: IOBluetoothRFCOMMChannel!, status error: IOReturn) {
        self.isConnectingRFCOMM = false

        if error == kIOReturnSuccess {
            let channelID = UInt8(rfcommChannel.getID())
            let mtu = rfcommChannel.getMTU()
            self.activeChannel = rfcommChannel
            self.rfcommState = .connected(channel: channelID, mtu: mtu)
            AppState.shared.isConnected = true
            AppState.shared.rfcommChannel = Int(channelID)
            AppState.shared.linkStatusText = "Connected · RFCOMM Ch \(channelID)"

            AppState.shared.appendLog(
                level: .info,
                category: "RFCOMM",
                message: "RFCOMM connection established successfully on channel \(channelID)! (MTU: \(mtu) bytes)"
            )
        } else {
            let errDesc = self.humanReadableIOReturn(error)
            self.rfcommState = .failed(error: errDesc, code: error)
            AppState.shared.isConnected = false
            AppState.shared.appendLog(
                level: .error,
                category: "RFCOMM",
                message: "RFCOMM channel open failed: [\(error)] \(errDesc)"
            )
        }
    }

    public func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        AppState.shared.appendLog(
            level: .warn,
            category: "RFCOMM",
            message: "RFCOMM channel \(rfcommChannel.getID()) was closed by remote device or system."
        )
        if self.activeChannel == rfcommChannel {
            self.activeChannel = nil
        }
        self.rfcommState = .disconnected
        AppState.shared.isConnected = false
        AppState.shared.linkStatusText = "Disconnected"
    }

    public func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        // As specified in the requirements: "Do not change any earbud settings yet."
        // We only observe and log incoming diagnostic telemetry packet length.
        let hexString = (0..<min(dataLength, 32)).map {
            String(format: "%02X", dataPointer.advanced(by: $0).load(as: UInt8.self))
        }.joined(separator: " ")

        AppState.shared.rxPacketsCount += 1
        AppState.shared.appendLog(
            level: .rx,
            category: "RFCOMM",
            message: "Received \(dataLength) bytes from earbud control channel",
            hexData: hexString + (dataLength > 32 ? "..." : "")
        )
    }
}

// MARK: - Device Connect/Disconnect Handlers

extension RealmeBluetoothService {
    @objc public func handleDeviceConnectedNotification(_ notification: IOBluetoothUserNotification!, device: IOBluetoothDevice!) {
        guard let device = device else { return }
        let name = device.nameOrAddress ?? ""
        if name.lowercased().contains("realme buds air") || name.lowercased().contains("buds air 7") {
            AppState.shared.appendLog(
                level: .info,
                category: "CONNECT",
                message: "Device connect notification: '\(name)' connected to macOS."
            )
            self.activeDevice = device
            self.earbudDetection = .detected(name: name, address: device.addressString ?? "", isAclConnected: true)
            self.registerDeviceDisconnectNotification(device)

            // Auto-connect RFCOMM if configured
            if AppState.shared.autoConnectOnLaunch && !self.rfcommState.isConnected {
                self.discoverServicesAndConnect()
            }
        }
    }

    @objc public func handleDeviceDisconnectedNotification(_ notification: IOBluetoothUserNotification!, device: IOBluetoothDevice!) {
        guard let device = device else { return }
        let name = device.nameOrAddress ?? ""
        AppState.shared.appendLog(
            level: .warn,
            category: "DISCONNECT",
            message: "Device disconnect notification: '\(name)' disconnected from macOS."
        )
        self.earbudDetection = .detected(name: name, address: device.addressString ?? "", isAclConnected: false)
        self.closeRFCOMMConnection()
    }
}
