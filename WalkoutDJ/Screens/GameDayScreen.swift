import SwiftUI

struct GameDayScreen: View {
    @EnvironmentObject var storage: StorageManager
    @EnvironmentObject var audioManager: AudioManager
    @State private var selectedLineupID: UUID?
    @State private var currentIndex: Int = 0
    @State private var wasPlaying = false

    private var selectedLineup: Lineup? {
        storage.teamLineups.first { $0.id == selectedLineupID }
    }

    private var lineupPlayers: [Player] {
        guard let lineup = selectedLineup else { return [] }
        return lineup.playerIDs.compactMap { id in
            storage.players.first { $0.id == id }
        }
    }

    private var currentPlayer: Player? {
        guard currentIndex >= 0, currentIndex < lineupPlayers.count else { return nil }
        return lineupPlayers[currentIndex]
    }

    private var onDeckPlayer: Player? {
        let nextIndex = currentIndex + 1
        if nextIndex < lineupPlayers.count {
            return lineupPlayers[nextIndex]
        } else if lineupPlayers.count > 1 {
            // Wrap — next up is the first batter
            return lineupPlayers[0]
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if storage.teamLineups.isEmpty {
                    ContentUnavailableView(
                        "No Lineups",
                        systemImage: "play.circle",
                        description: Text("Create a lineup first to use Game Day mode")
                    )
                } else if selectedLineup == nil {
                    lineupPicker
                } else if lineupPlayers.isEmpty {
                    ContentUnavailableView(
                        "Empty Lineup",
                        systemImage: "person.fill.questionmark",
                        description: Text("Add players to this lineup first")
                    )
                } else {
                    walkoutView
                }
            }
            .navigationTitle("Game Day")
            .toolbar {
                if selectedLineup != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            audioManager.stop()
                            selectedLineupID = nil
                            currentIndex = 0
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Lineups")
                            }
                        }
                    }
                }
            }
            .onChange(of: storage.activeTeamId) {
                // Reset game day state when switching teams
                audioManager.stop()
                selectedLineupID = nil
                currentIndex = 0
            }
            .onChange(of: audioManager.isPlaying) {
                if audioManager.isPlaying {
                    wasPlaying = true
                } else if wasPlaying {
                    // Song finished — auto-advance to next batter
                    wasPlaying = false
                    advanceToNext()
                }
            }
        }
    }

    // MARK: - Lineup Picker

    private var lineupPicker: some View {
        List {
            Section {
                ForEach(storage.teamLineups) { lineup in
                    Button {
                        selectedLineupID = lineup.id
                        currentIndex = 0
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(lineup.name)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.primary)

                                let count = lineup.playerIDs.count
                                Text("\(count) batter\(count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "play.circle.fill")
                                .font(.title)
                                .foregroundStyle(storage.teamColor)
                        }
                        .padding(.vertical, 8)
                    }
                }
            } header: {
                Text("Select a lineup")
            }
        }
    }

    // MARK: - Walkout View

    private var walkoutView: some View {
        VStack(spacing: 0) {
            // Position indicator
            HStack {
                Text("\(currentIndex + 1) of \(lineupPlayers.count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            // Progress bar
            HStack(spacing: 4) {
                ForEach(0..<lineupPlayers.count, id: \.self) { index in
                    Capsule()
                        .fill(index == currentIndex ? storage.teamColor : Color.gray.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)

            Spacer()

            // Current batter
            if let player = currentPlayer {
                currentBatterView(player: player)
            }

            Spacer()

            // Playback controls
            playbackControls

            Spacer()

            // On deck
            if let onDeck = onDeckPlayer {
                let isWrapping = currentIndex == lineupPlayers.count - 1
                onDeckView(player: onDeck, isWrapping: isWrapping)
            } else {
                Text("Last Batter")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)
            }

            // Navigation controls
            navigationControls
                .padding(.bottom, 8)
        }
    }

    // MARK: - Current Batter

    private func currentBatterView(player: Player) -> some View {
        VStack(spacing: 8) {
            Text("NOW BATTING")
                .font(.caption.weight(.bold))
                .tracking(2)
                .foregroundStyle(storage.teamColor)

            PlayerPhotoView(player: player, size: 100)

            Text("#\(player.jerseyNumber)")
                .font(.system(size: 72, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)

            Text(player.name)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.horizontal)

            if player.songFileName != nil {
                HStack(spacing: 4) {
                    Image(systemName: "music.note")
                    if audioManager.isPlaying {
                        Text(formatTime(audioManager.currentTime))
                            .monospacedDigit()
                    } else {
                        Text("Ready")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else {
                Text("No song assigned")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 40) {
            if audioManager.isPlaying {
                Button {
                    wasPlaying = false
                    audioManager.stop()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.red)
                }
            } else {
                Button {
                    playCurrentSong()
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(currentPlayer?.songFileName != nil ? AnyShapeStyle(storage.teamColor) : AnyShapeStyle(.gray))
                }
                .disabled(currentPlayer?.songFileName == nil)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - On Deck

    private func onDeckView(player: Player, isWrapping: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(isWrapping ? "TOP OF ORDER" : "ON DECK")
                .font(.caption2.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(.orange)

            HStack(spacing: 8) {
                Text("#\(player.jerseyNumber)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(.secondary)

                Text(player.name)
                    .font(.title3.weight(.medium))

                if player.songFileName != nil {
                    Image(systemName: "music.note")
                        .font(.caption)
                        .foregroundStyle(storage.teamColor)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 16)
    }

    // MARK: - Navigation Controls

    private var navigationControls: some View {
        HStack(spacing: 0) {
            Button {
                goToPrevious()
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Prev")
                }
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .disabled(currentIndex <= 0)

            Divider()
                .frame(height: 30)

            Button {
                goToNext()
            } label: {
                HStack {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .disabled(lineupPlayers.isEmpty)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func playCurrentSong() {
        guard let player = currentPlayer,
              let songFileName = player.songFileName else { return }

        let url = storage.songFileURL(for: songFileName)
        audioManager.loadAndPlay(
            url: url,
            startTime: player.songStartTime,
            autoStopAfter: storage.settings.autoStopDuration,
            volume: storage.settings.defaultVolume
        )
    }

    private func advanceToNext() {
        if currentIndex < lineupPlayers.count - 1 {
            currentIndex += 1
        } else {
            // Wrap back to the top of the lineup
            currentIndex = 0
        }
    }

    private func goToNext() {
        wasPlaying = false
        audioManager.stop()
        advanceToNext()
    }

    private func goToPrevious() {
        wasPlaying = false
        audioManager.stop()
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
