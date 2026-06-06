import Foundation

struct AppSettings: Codable, Hashable {
    var autoStopDuration: TimeInterval
    var defaultVolume: Float
    var defaultInningBreakDuration: TimeInterval
    var fadeOutDuration: TimeInterval
    var audioDuckingEnabled: Bool

    init(
        autoStopDuration: TimeInterval = 10.0,
        defaultVolume: Float = 0.8,
        defaultInningBreakDuration: TimeInterval = 120.0,
        fadeOutDuration: TimeInterval = 3.0,
        audioDuckingEnabled: Bool = true
    ) {
        self.autoStopDuration = autoStopDuration
        self.defaultVolume = defaultVolume
        self.defaultInningBreakDuration = defaultInningBreakDuration
        self.fadeOutDuration = fadeOutDuration
        self.audioDuckingEnabled = audioDuckingEnabled
    }

    // Backward-compatible decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        autoStopDuration = try container.decode(TimeInterval.self, forKey: .autoStopDuration)
        defaultVolume = try container.decode(Float.self, forKey: .defaultVolume)
        defaultInningBreakDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .defaultInningBreakDuration) ?? 120.0
        fadeOutDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .fadeOutDuration) ?? 3.0
        audioDuckingEnabled = try container.decodeIfPresent(Bool.self, forKey: .audioDuckingEnabled) ?? true
    }
}
