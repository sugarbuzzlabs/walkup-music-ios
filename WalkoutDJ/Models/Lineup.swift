import Foundation

struct Lineup: Codable, Identifiable, Hashable {
    var id: UUID
    var teamId: UUID
    var name: String
    var playerIDs: [UUID]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        teamId: UUID,
        name: String,
        playerIDs: [UUID] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.teamId = teamId
        self.name = name
        self.playerIDs = playerIDs
        self.createdAt = createdAt
    }

    // Backward-compatible decoding: old JSON without teamId gets a placeholder
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        teamId = try container.decodeIfPresent(UUID.self, forKey: .teamId) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        playerIDs = try container.decode([UUID].self, forKey: .playerIDs)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
