import Foundation

public enum DiagnosticLevel: String, Sendable {
    case info = "INFO"
    case tx = "TX"
    case rx = "RX"
    case warn = "WARN"
    case error = "ERROR"

    public var sfSymbol: String {
        switch self {
        case .info: "info.circle"
        case .tx: "arrow.up.circle.fill"
        case .rx: "arrow.down.circle.fill"
        case .warn: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }
}

public struct DiagnosticEntry: Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let level: DiagnosticLevel
    public let category: String
    public let message: String
    public let hexData: String?

    public init(
        timestamp: Date = Date(),
        level: DiagnosticLevel,
        category: String,
        message: String,
        hexData: String? = nil
    ) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.hexData = hexData
    }

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}
