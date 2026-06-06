import Foundation
import SwiftUI

enum TeamColor: String, Codable, CaseIterable {
    case green, red, blue, orange, purple, yellow, pink, teal, indigo, mint, cyan, brown

    var color: Color {
        switch self {
        case .green: return .green
        case .red: return .red
        case .blue: return .blue
        case .orange: return .orange
        case .purple: return .purple
        case .yellow: return .yellow
        case .pink: return .pink
        case .teal: return .teal
        case .indigo: return .indigo
        case .mint: return .mint
        case .cyan: return .cyan
        case .brown: return .brown
        }
    }

    var displayName: String { rawValue.capitalized }
}

struct Team: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var photoFileName: String?
    var teamColor: TeamColor?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        photoFileName: String? = nil,
        teamColor: TeamColor? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.photoFileName = photoFileName
        self.teamColor = teamColor
        self.createdAt = createdAt
    }

    // Backward-compatible decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        photoFileName = try container.decodeIfPresent(String.self, forKey: .photoFileName)
        teamColor = try container.decodeIfPresent(TeamColor.self, forKey: .teamColor)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    var accentColor: Color {
        teamColor?.color ?? .green
    }
}
