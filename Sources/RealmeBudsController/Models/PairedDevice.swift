import Foundation

public enum DeviceConnectionState: String, Sendable {
    case connected = "Connected"
    case connecting = "Connecting…"
    case disconnected = "Not Connected"
}

public struct PairedDevice: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let macAddress: String
    public var connectionState: DeviceConnectionState
    public var slotNumber: Int? // 1 or 2 for active multi-connect slots
    public var isThisMac: Bool
    public var iconName: String
    public var lastConnectedTime: String

    public var isConnected: Bool {
        connectionState == .connected
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        macAddress: String,
        connectionState: DeviceConnectionState = .disconnected,
        slotNumber: Int? = nil,
        isThisMac: Bool = false,
        iconName: String = "laptopcomputer",
        lastConnectedTime: String = "Active now"
    ) {
        self.id = id
        self.name = name
        self.macAddress = macAddress
        self.connectionState = connectionState
        self.slotNumber = slotNumber
        self.isThisMac = isThisMac
        self.iconName = iconName
        self.lastConnectedTime = lastConnectedTime
    }
}
