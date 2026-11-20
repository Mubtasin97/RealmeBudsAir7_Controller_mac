import Foundation

public struct PairedDevice: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let macAddress: String
    public var isConnected: Bool
    public var isThisMac: Bool
    public var iconName: String

    public init(
        id: String = UUID().uuidString,
        name: String,
        macAddress: String,
        isConnected: Bool = false,
        isThisMac: Bool = false,
        iconName: String = "laptopcomputer"
    ) {
        self.id = id
        self.name = name
        self.macAddress = macAddress
        self.isConnected = isConnected
        self.isThisMac = isThisMac
        self.iconName = iconName
    }
}
