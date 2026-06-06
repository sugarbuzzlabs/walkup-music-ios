import Foundation
import SwiftUI

@MainActor
final class StorageManager: ObservableObject {
    @Published var teams: [Team] = []
    @Published var players: [Player] = []
    @Published var lineups: [Lineup] = []
    @Published var settings: AppSettings = AppSettings()
    @Published var activeTeamId: UUID?
    @Published var stadiumData: StadiumData = StadiumData(teamId: UUID())

    private let documentsDirectory: URL
    private let songsDirectory: URL
    private let photosDirectory: URL

    private var teamsFileURL: URL { documentsDirectory.appendingPathComponent("teams.json") }
    private var playersFileURL: URL { documentsDirectory.appendingPathComponent("players.json") }
    private var lineupsFileURL: URL { documentsDirectory.appendingPathComponent("lineups.json") }
    private var settingsFileURL: URL { documentsDirectory.appendingPathComponent("settings.json") }
    private var activeTeamFileURL: URL { documentsDirectory.appendingPathComponent("activeTeam.json") }

    private func stadiumFileURL(for teamId: UUID) -> URL {
        documentsDirectory.appendingPathComponent("stadium_\(teamId.uuidString).json")
    }

    /// Players filtered to the active team
    var teamPlayers: [Player] {
        guard let teamId = activeTeamId else { return [] }
        return players.filter { $0.teamId == teamId }
    }

    /// Lineups filtered to the active team
    var teamLineups: [Lineup] {
        guard let teamId = activeTeamId else { return [] }
        return lineups.filter { $0.teamId == teamId }
    }

    var activeTeam: Team? {
        teams.first { $0.id == activeTeamId }
    }

    var teamColor: Color {
        activeTeam?.accentColor ?? .green
    }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.documentsDirectory = docs
        self.songsDirectory = docs.appendingPathComponent("Songs", isDirectory: true)
        self.photosDirectory = docs.appendingPathComponent("Photos", isDirectory: true)

        createSongsDirectoryIfNeeded()
        createPhotosDirectoryIfNeeded()
        loadTeams()
        loadPlayers()
        loadLineups()
        loadSettings()
        loadActiveTeamId()
        migrateIfNeeded()
        loadStadiumData()
    }

    // MARK: - Migration

    private func migrateIfNeeded() {
        // If there are players/lineups but no teams, migrate to a default team
        if teams.isEmpty && (!players.isEmpty || !lineups.isEmpty) {
            let defaultTeam = Team(name: "My Team")

            // Assign all orphaned players/lineups to the default team
            for i in players.indices {
                players[i].teamId = defaultTeam.id
            }
            for i in lineups.indices {
                lineups[i].teamId = defaultTeam.id
            }

            teams.append(defaultTeam)
            activeTeamId = defaultTeam.id

            saveTeams()
            savePlayers()
            saveLineups()
            saveActiveTeamId()
        }

        // If no active team set but teams exist, pick the first one
        if activeTeamId == nil, let first = teams.first {
            activeTeamId = first.id
            saveActiveTeamId()
        }
    }

    // MARK: - Songs Directory

    private func createSongsDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: songsDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: songsDirectory, withIntermediateDirectories: true)
            } catch {
                print("Failed to create Songs directory: \(error)")
            }
        }
    }

    func songFileURL(for fileName: String) -> URL {
        songsDirectory.appendingPathComponent(fileName)
    }

    func importSongFile(from sourceURL: URL) -> String? {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileName = "\(UUID().uuidString)_\(sourceURL.lastPathComponent)"
        let destinationURL = songFileURL(for: fileName)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return fileName
        } catch {
            print("Failed to import song file: \(error)")
            return nil
        }
    }

    func deleteSongFile(named fileName: String) {
        let fileURL = songFileURL(for: fileName)
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("Failed to delete song file: \(error)")
        }
    }

    // MARK: - Photos Directory

    private func createPhotosDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: photosDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
            } catch {
                print("Failed to create Photos directory: \(error)")
            }
        }
    }

    func photoFileURL(for fileName: String) -> URL {
        photosDirectory.appendingPathComponent(fileName)
    }

    func savePhoto(data: Data) -> String? {
        let fileName = "\(UUID().uuidString).jpg"
        let destinationURL = photoFileURL(for: fileName)
        do {
            try data.write(to: destinationURL, options: .atomic)
            return fileName
        } catch {
            print("Failed to save photo: \(error)")
            return nil
        }
    }

    func deletePhotoFile(named fileName: String) {
        let fileURL = photoFileURL(for: fileName)
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("Failed to delete photo: \(error)")
        }
    }

    // MARK: - Teams

    func addTeam(_ team: Team) {
        teams.append(team)
        saveTeams()

        // Auto-select if it's the first team
        if activeTeamId == nil {
            activeTeamId = team.id
            saveActiveTeamId()
        }
    }

    func updateTeam(_ team: Team) {
        if let index = teams.firstIndex(where: { $0.id == team.id }) {
            teams[index] = team
            saveTeams()
        }
    }

    func deleteTeam(id: UUID) {
        // Delete team photo
        if let team = teams.first(where: { $0.id == id }),
           let photoFileName = team.photoFileName {
            deletePhotoFile(named: photoFileName)
        }

        // Delete all players (and their songs/photos) for this team
        let teamPlayerIds = players.filter { $0.teamId == id }.map(\.id)
        for playerId in teamPlayerIds {
            deletePlayer(id: playerId)
        }

        // Delete all lineups for this team
        lineups.removeAll { $0.teamId == id }
        saveLineups()

        // Remove the team
        teams.removeAll { $0.id == id }
        saveTeams()

        // If we deleted the active team, switch to another
        if activeTeamId == id {
            activeTeamId = teams.first?.id
            saveActiveTeamId()
        }
    }

    func setActiveTeam(id: UUID) {
        activeTeamId = id
        saveActiveTeamId()
        loadStadiumData()
    }

    private func saveTeams() {
        save(teams, to: teamsFileURL)
    }

    private func loadTeams() {
        teams = load(from: teamsFileURL) ?? []
    }

    private func saveActiveTeamId() {
        save(activeTeamId, to: activeTeamFileURL)
    }

    private func loadActiveTeamId() {
        activeTeamId = load(from: activeTeamFileURL)
    }

    // MARK: - Players

    func addPlayer(_ player: Player) {
        players.append(player)
        savePlayers()
    }

    func updatePlayer(_ player: Player) {
        if let index = players.firstIndex(where: { $0.id == player.id }) {
            players[index] = player
            savePlayers()
        }
    }

    func deletePlayer(id: UUID) {
        if let player = players.first(where: { $0.id == id }) {
            if let songFileName = player.songFileName {
                deleteSongFile(named: songFileName)
            }
            if let photoFileName = player.photoFileName {
                deletePhotoFile(named: photoFileName)
            }
        }

        players.removeAll { $0.id == id }
        savePlayers()

        // Remove from all lineups
        for i in lineups.indices {
            lineups[i].playerIDs.removeAll { $0 == id }
        }
        saveLineups()
    }

    private func savePlayers() {
        save(players, to: playersFileURL)
    }

    private func loadPlayers() {
        players = load(from: playersFileURL) ?? []
    }

    // MARK: - Lineups

    func addLineup(_ lineup: Lineup) {
        lineups.append(lineup)
        saveLineups()
    }

    func updateLineup(_ lineup: Lineup) {
        if let index = lineups.firstIndex(where: { $0.id == lineup.id }) {
            lineups[index] = lineup
            saveLineups()
        }
    }

    func deleteLineup(id: UUID) {
        lineups.removeAll { $0.id == id }
        saveLineups()
    }

    private func saveLineups() {
        save(lineups, to: lineupsFileURL)
    }

    private func loadLineups() {
        lineups = load(from: lineupsFileURL) ?? []
    }

    // MARK: - Settings

    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        saveSettings()
    }

    private func saveSettings() {
        save(settings, to: settingsFileURL)
    }

    private func loadSettings() {
        settings = load(from: settingsFileURL) ?? AppSettings()
    }

    // MARK: - Stadium Data

    func updateStadiumData(_ data: StadiumData) {
        stadiumData = data
        saveStadiumData()
    }

    private func saveStadiumData() {
        guard let teamId = activeTeamId else { return }
        var data = stadiumData
        data.teamId = teamId
        save(data, to: stadiumFileURL(for: teamId))
    }

    private func loadStadiumData() {
        guard let teamId = activeTeamId else {
            stadiumData = StadiumData(teamId: UUID())
            return
        }
        stadiumData = load(from: stadiumFileURL(for: teamId)) ?? StadiumData(teamId: teamId)
    }

    // MARK: - Generic JSON Persistence

    private func save<T: Encodable>(_ value: T, to url: URL) {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save \(url.lastPathComponent): \(error)")
        }
    }

    private func load<T: Decodable>(from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Failed to load \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}
