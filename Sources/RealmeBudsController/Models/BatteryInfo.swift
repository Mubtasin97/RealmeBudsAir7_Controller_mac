import Foundation

public enum BudSlot: String, CaseIterable, Identifiable, Sendable {
    case left = "left"
    case right = "right"
    case caseEnclosure = "case"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .left: "Left Bud"
        case .right: "Right Bud"
        case .caseEnclosure: "Charging Case"
        }
    }

    public var shortLabel: String {
        switch self {
        case .left: "L"
        case .right: "R"
        case .caseEnclosure: "Case"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .left: "earbuds"
        case .right: "earbuds"
        case .caseEnclosure: "headphones.circle.fill"
        }
    }
}

public struct BatteryStatus: Equatable, Sendable {
    public var percentage: Int?
    public var isCharging: Bool

    public init(percentage: Int? = nil, isCharging: Bool = false) {
        self.percentage = percentage
        self.isCharging = isCharging
    }

    public var formattedText: String {
        guard let percentage else { return "—" }
        return "\(percentage)%"
    }
}
