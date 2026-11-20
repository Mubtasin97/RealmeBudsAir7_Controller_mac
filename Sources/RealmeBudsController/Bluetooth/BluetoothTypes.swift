import Foundation

public enum BluetoothAvailabilityState: Equatable, Sendable {
    case unknown
    case resetting
    case unsupported
    case unauthorized(String)
    case poweredOff
    case poweredOn

    public var title: String {
        switch self {
        case .unknown:
            return "Checking Bluetooth..."
        case .resetting:
            return "Bluetooth Resetting"
        case .unsupported:
            return "Bluetooth Unsupported"
        case .unauthorized(let reason):
            return "Unauthorized: \(reason)"
        case .poweredOff:
            return "Bluetooth Powered Off"
        case .poweredOn:
            return "Bluetooth Powered On"
        }
    }

    public var isAvailable: Bool {
        if case .poweredOn = self { return true }
        return false
    }

    public var sfSymbol: String {
        switch self {
        case .unknown, .resetting:
            return "antenna.radiowaves.left.and.right"
        case .unsupported, .unauthorized:
            return "exclamationmark.triangle.fill"
        case .poweredOff:
            return "bolt.slash.fill"
        case .poweredOn:
            return "bolt.fill"
        }
    }
}

public enum EarbudDetectionState: Equatable, Sendable {
    case notSearched
    case searching
    case notFound
    case detected(name: String, address: String, isAclConnected: Bool)

    public var title: String {
        switch self {
        case .notSearched:
            return "Not Scanned"
        case .searching:
            return "Searching Paired Devices..."
        case .notFound:
            return "Realme Buds Air 7 Not Found"
        case .detected(let name, _, let isAclConnected):
            return "\(name) (\(isAclConnected ? "ACL Active" : "ACL Dormant"))"
        }
    }

    public var isDetected: Bool {
        if case .detected = self { return true }
        return false
    }
}

public enum ServiceDiscoveryState: Equatable, Sendable {
    case idle
    case querying
    case discovered(serviceName: String, channel: UInt8, uuid: String)
    case fallback(channel: UInt8, reason: String)
    case failed(String)

    public var title: String {
        switch self {
        case .idle:
            return "Idle"
        case .querying:
            return "Querying SDP Records..."
        case .discovered(let name, let channel, _):
            return "\(name) (RFCOMM Ch \(channel))"
        case .fallback(let channel, _):
            return "Fallback (RFCOMM Ch \(channel))"
        case .failed(let err):
            return "Failed: \(err)"
        }
    }

    public var resolvedChannel: UInt8? {
        switch self {
        case .discovered(_, let channel, _):
            return channel
        case .fallback(let channel, _):
            return channel
        default:
            return nil
        }
    }
}

public enum RFCOMMConnectionState: Equatable, Sendable {
    case disconnected
    case connecting(channel: UInt8)
    case connected(channel: UInt8, mtu: UInt16)
    case disconnecting
    case failed(error: String, code: Int32)

    public var title: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting(let ch):
            return "Opening RFCOMM Ch \(ch)..."
        case .connected(let ch, let mtu):
            return "Connected (Ch \(ch) · MTU \(mtu)B)"
        case .disconnecting:
            return "Disconnecting..."
        case .failed(let err, let code):
            return "Error \(code): \(err)"
        }
    }

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}
