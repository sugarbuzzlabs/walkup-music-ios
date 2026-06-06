import Foundation

/// A sound effect button for the soundboard
struct SoundboardButton: Codable, Identifiable, Hashable {
    var id: UUID
    var label: String
    var colorName: String // matches TeamColor raw values or custom
    var iconName: String
    var iconEmoji: String? // if set, used instead of SF Symbol
    var songFileName: String?
    var songDisplayName: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        label: String,
        colorName: String = "green",
        iconName: String = "speaker.wave.2.fill",
        iconEmoji: String? = nil,
        songFileName: String? = nil,
        songDisplayName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.colorName = colorName
        self.iconName = iconName
        self.iconEmoji = iconEmoji
        self.songFileName = songFileName
        self.songDisplayName = songDisplayName
        self.createdAt = createdAt
    }

    // Backward-compatible decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        colorName = try container.decode(String.self, forKey: .colorName)
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName) ?? "speaker.wave.2.fill"
        iconEmoji = try container.decodeIfPresent(String.self, forKey: .iconEmoji)
        songFileName = try container.decodeIfPresent(String.self, forKey: .songFileName)
        songDisplayName = try container.decodeIfPresent(String.self, forKey: .songDisplayName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    static let availableIcons: [(name: String, symbol: String)] = [
        ("Speaker", "speaker.wave.2.fill"),
        ("Music", "music.note"),
        ("Bell", "bell.fill"),
        ("Megaphone", "megaphone.fill"),
        ("Horn", "horn.fill"),
        ("Star", "star.fill"),
        ("Bolt", "bolt.fill"),
        ("Flame", "flame.fill"),
        ("Hand Clap", "hands.clap.fill"),
        ("Trophy", "trophy.fill"),
        ("Baseball", "baseball.fill"),
        ("Figure", "figure.baseball"),
        ("Siren", "light.beacon.max.fill"),
        ("Waveform", "waveform"),
        ("Mic", "mic.fill"),
        ("Whistle", "whistle.fill"),
        ("Guitar", "guitars.fill"),
        ("Heart", "heart.fill"),
        ("Exclaim", "exclamationmark.triangle.fill"),
        ("Sparkle", "sparkles"),
        ("Crown", "crown.fill"),
        ("Flag", "flag.fill"),
        ("Party", "party.popper.fill"),
        ("Fist", "hand.raised.fill"),
    ]
}

/// A song for inning break playback with auto-fade
struct InningBreakSong: Codable, Identifiable, Hashable {
    var id: UUID
    var songFileName: String
    var songDisplayName: String
    var startTime: TimeInterval
    var autoStopDuration: TimeInterval // defaults to 120s
    var createdAt: Date

    init(
        id: UUID = UUID(),
        songFileName: String,
        songDisplayName: String,
        startTime: TimeInterval = 0,
        autoStopDuration: TimeInterval = 120,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.songFileName = songFileName
        self.songDisplayName = songDisplayName
        self.startTime = startTime
        self.autoStopDuration = autoStopDuration
        self.createdAt = createdAt
    }
}

/// A playlist track for warm-up music
struct PlaylistTrack: Codable, Identifiable, Hashable {
    var id: UUID
    var songFileName: String
    var songDisplayName: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        songFileName: String,
        songDisplayName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.songFileName = songFileName
        self.songDisplayName = songDisplayName
        self.createdAt = createdAt
    }
}

/// All stadium audio data for a team
struct StadiumData: Codable, Hashable {
    var teamId: UUID
    var soundboard: [SoundboardButton]
    var inningBreakSongs: [InningBreakSong]
    var playlist: [PlaylistTrack]

    init(
        teamId: UUID,
        soundboard: [SoundboardButton] = [],
        inningBreakSongs: [InningBreakSong] = [],
        playlist: [PlaylistTrack] = []
    ) {
        self.teamId = teamId
        self.soundboard = soundboard
        self.inningBreakSongs = inningBreakSongs
        self.playlist = playlist
    }
}
