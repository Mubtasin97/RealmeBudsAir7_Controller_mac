import Foundation

public enum EqualizerPreset: UInt8, CaseIterable, Identifiable, Sendable {
    case original = 0
    case deepBass = 1
    case serenade = 2
    case clearBass = 3

    public var id: UInt8 { rawValue }

    public var title: String {
        switch self {
        case .original: "Original Sound"
        case .deepBass: "Deep Bass"
        case .serenade: "Serenade"
        case .clearBass: "Clear Bass"
        }
    }

    public var descriptionText: String {
        switch self {
        case .original: "Studio flat & authentic profile"
        case .deepBass: "Emphasized sub-bass and kick"
        case .serenade: "Warm vocal-forward acoustics"
        case .clearBass: "Tight and punchy low frequencies"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .original: "music.note"
        case .deepBass: "speaker.wave.3.fill"
        case .serenade: "music.mic"
        case .clearBass: "waveform.path"
        }
    }
}
