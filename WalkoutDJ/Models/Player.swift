import Foundation

struct Player: Codable, Identifiable, Hashable {
    var id: UUID
    var teamId: UUID
    var name: String
    var jerseyNumber: Int
    var photoFileName: String?
    var songFileName: String?
    var songDisplayName: String?
    var songStartTime: TimeInterval
    var createdAt: Date

    init(
        id: UUID = UUID(),
        teamId: UUID,
        name: String,
        jerseyNumber: Int,
        photoFileName: String? = nil,
        songFileName: String? = nil,
        songDisplayName: String? = nil,
        songStartTime: TimeInterval = 0.0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.teamId = teamId
        self.name = name
        self.jerseyNumber = jerseyNumber
        self.photoFileName = photoFileName
        self.songFileName = songFileName
        self.songDisplayName = songDisplayName
        self.songStartTime = songStartTime
        self.createdAt = createdAt
    }

    // Backward-compatible decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        teamId = try container.decodeIfPresent(UUID.self, forKey: .teamId) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        jerseyNumber = try container.decode(Int.self, forKey: .jerseyNumber)
        photoFileName = try container.decodeIfPresent(String.self, forKey: .photoFileName)
        songFileName = try container.decodeIfPresent(String.self, forKey: .songFileName)
        songDisplayName = try container.decodeIfPresent(String.self, forKey: .songDisplayName)
        songStartTime = try container.decode(TimeInterval.self, forKey: .songStartTime)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    /// Returns songDisplayName if set, otherwise extracts the original name from the UUID-prefixed filename
    var effectiveSongName: String {
        if let displayName = songDisplayName, !displayName.isEmpty {
            return displayName
        }
        guard let fileName = songFileName else { return "Song" }
        let withoutExt = (fileName as NSString).deletingPathExtension
        if let underscoreIndex = withoutExt.firstIndex(of: "_") {
            return String(withoutExt[withoutExt.index(after: underscoreIndex)...])
        }
        return withoutExt
    }
}
