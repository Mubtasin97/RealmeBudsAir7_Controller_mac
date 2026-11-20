import Foundation

public struct EqualizerBand: Identifiable, Equatable, Sendable {
    public let id: String
    public let frequencyLabel: String
    public var gainDb: Double // -6.0 to +6.0 dB

    public init(frequencyLabel: String, gainDb: Double = 0.0) {
        self.id = frequencyLabel
        self.frequencyLabel = frequencyLabel
        self.gainDb = gainDb
    }
}

public enum EqualizerPreset: UInt8, CaseIterable, Identifiable, Sendable {
    case original = 0
    case deepBass = 1
    case serenade = 2
    case clearBass = 3
    case custom = 99

    public var id: UInt8 { rawValue }

    public var title: String {
        switch self {
        case .original: "Original Sound"
        case .deepBass: "Deep Bass"
        case .serenade: "Serenade"
        case .clearBass: "Clear Bass"
        case .custom: "Custom Curves"
        }
    }

    public var descriptionText: String {
        switch self {
        case .original: "Studio flat & authentic profile"
        case .deepBass: "Warm, boosted sub-bass and kick"
        case .serenade: "Vocal-forward clarity"
        case .clearBass: "Punchy, tight dynamic low-end"
        case .custom: "User-defined graphic 6-band curve"
        }
    }

    public var sfSymbol: String {
        switch self {
        case .original: "music.note"
        case .deepBass: "speaker.wave.3.fill"
        case .serenade: "music.mic"
        case .clearBass: "waveform.path"
        case .custom: "slider.vertical.3"
        }
    }

    public var defaultBands: [EqualizerBand] {
        switch self {
        case .original:
            return [
                EqualizerBand(frequencyLabel: "31 Hz", gainDb: 0.0),
                EqualizerBand(frequencyLabel: "125 Hz", gainDb: 0.0),
                EqualizerBand(frequencyLabel: "500 Hz", gainDb: 0.0),
                EqualizerBand(frequencyLabel: "2 kHz", gainDb: 0.0),
                EqualizerBand(frequencyLabel: "8 kHz", gainDb: 0.0),
                EqualizerBand(frequencyLabel: "16 kHz", gainDb: 0.0)
            ]
        case .deepBass:
            return [
                EqualizerBand(frequencyLabel: "31 Hz", gainDb: 4.5),
                EqualizerBand(frequencyLabel: "125 Hz", gainDb: 3.0),
                EqualizerBand(frequencyLabel: "500 Hz", gainDb: 1.0),
                EqualizerBand(frequencyLabel: "2 kHz", gainDb: -0.5),
                EqualizerBand(frequencyLabel: "8 kHz", gainDb: 0.5),
                EqualizerBand(frequencyLabel: "16 kHz", gainDb: 1.0)
            ]
        case .serenade:
            return [
                EqualizerBand(frequencyLabel: "31 Hz", gainDb: -1.0),
                EqualizerBand(frequencyLabel: "125 Hz", gainDb: 0.5),
                EqualizerBand(frequencyLabel: "500 Hz", gainDb: 3.5),
                EqualizerBand(frequencyLabel: "2 kHz", gainDb: 4.0),
                EqualizerBand(frequencyLabel: "8 kHz", gainDb: 2.0),
                EqualizerBand(frequencyLabel: "16 kHz", gainDb: 1.5)
            ]
        case .clearBass:
            return [
                EqualizerBand(frequencyLabel: "31 Hz", gainDb: 3.0),
                EqualizerBand(frequencyLabel: "125 Hz", gainDb: 4.0),
                EqualizerBand(frequencyLabel: "500 Hz", gainDb: -1.0),
                EqualizerBand(frequencyLabel: "2 kHz", gainDb: 1.5),
                EqualizerBand(frequencyLabel: "8 kHz", gainDb: 2.5),
                EqualizerBand(frequencyLabel: "16 kHz", gainDb: 3.0)
            ]
        case .custom:
            return [
                EqualizerBand(frequencyLabel: "31 Hz", gainDb: 2.0),
                EqualizerBand(frequencyLabel: "125 Hz", gainDb: 1.5),
                EqualizerBand(frequencyLabel: "500 Hz", gainDb: 0.0),
                EqualizerBand(frequencyLabel: "2 kHz", gainDb: 1.0),
                EqualizerBand(frequencyLabel: "8 kHz", gainDb: 2.5),
                EqualizerBand(frequencyLabel: "16 kHz", gainDb: 2.0)
            ]
        }
    }
}
