import Foundation

public enum ANCStrength: UInt8, CaseIterable, Identifiable, Sendable {
    case smart = 0x20
    case mild = 0x04
    case moderate = 0x10
    case max = 0x08

    public var id: UInt8 { rawValue }

    public var title: String {
        switch self {
        case .smart: "Smart"
        case .mild: "Mild"
        case .moderate: "Moderate"
        case .max: "Max"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .smart: "sparkles"
        case .mild: "waveform.badge.minus"
        case .moderate: "waveform"
        case .max: "waveform.slash"
        }
    }
}

public enum NoiseControlMode: Equatable, Identifiable, Sendable {
    case off
    case transparency
    case anc(ANCStrength)

    public var id: String {
        switch self {
        case .off: "off"
        case .transparency: "transparency"
        case .anc(let strength): "anc_\(strength.rawValue)"
        }
    }

    public var title: String {
        switch self {
        case .off: "Off"
        case .transparency: "Transparency"
        case .anc(let strength): "ANC (\(strength.title))"
        }
    }

    public var baseModeName: String {
        switch self {
        case .off: "Off"
        case .transparency: "Transparency"
        case .anc: "Noise Cancelling"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .off: "circle.slash"
        case .transparency: "ear.and.waveform"
        case .anc: "waveform.slash"
        }
    }
}
