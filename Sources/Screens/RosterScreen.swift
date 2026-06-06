import SwiftUI
import PhotosUI

struct RosterScreen: View {
    @EnvironmentObject var storage: StorageManager
    @State private var showingAddPlayer = false
    @State private var playerToEdit: Player?
    @State private var showingTeamPicker = false

    var body: some View {
        NavigationStack {
            Group {
                if storage.teamPlayers.isEmpty {
                    ContentUnavailableView(
                        "No Players",
                        systemImage: "person.3.fill",
                        description: Text("Tap + to add your first player")
                    )
                } else {
                    List {
                        ForEach(sortedPlayers) { player in
                            PlayerRow(player: player)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    playerToEdit = player
                                }
                        }
                        .onDelete(perform: deletePlayers)
                    }
                }
            }
            .navigationTitle(storage.activeTeam?.name ?? "Roster")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    teamMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddPlayer = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddPlayer) {
                PlayerFormSheet(mode: .add)
            }
            .sheet(item: $playerToEdit) { player in
                PlayerFormSheet(mode: .edit(player))
            }
            .sheet(isPresented: $showingTeamPicker) {
                TeamManagementSheet()
            }
        }
    }

    private var teamMenu: some View {
        Menu {
            ForEach(storage.teams) { team in
                Button {
                    storage.setActiveTeam(id: team.id)
                } label: {
                    HStack {
                        Text(team.name)
                        if team.id == storage.activeTeamId {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            Divider()

            Button {
                showingTeamPicker = true
            } label: {
                Label("Manage Teams", systemImage: "pencil")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "person.3.sequence.fill")
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
        }
    }

    private var sortedPlayers: [Player] {
        storage.teamPlayers.sorted { $0.jerseyNumber < $1.jerseyNumber }
    }

    private func deletePlayers(at offsets: IndexSet) {
        let playersToDelete = offsets.map { sortedPlayers[$0] }
        for player in playersToDelete {
            storage.deletePlayer(id: player.id)
        }
    }
}

// MARK: - Player Row

struct PlayerRow: View {
    @EnvironmentObject var storage: StorageManager
    let player: Player

    var body: some View {
        HStack(spacing: 12) {
            PlayerPhotoView(player: player, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(player.name)
                    .font(.title3.weight(.semibold))

                if player.songFileName != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                        Text(player.effectiveSongName)
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                        Text("No song assigned")
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Player Form

enum PlayerFormMode: Identifiable {
    case add
    case edit(Player)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let player): return player.id.uuidString
        }
    }
}

struct PlayerFormSheet: View {
    @EnvironmentObject var storage: StorageManager
    @EnvironmentObject var audioManager: AudioManager
    @Environment(\.dismiss) private var dismiss

    let mode: PlayerFormMode

    @State private var name: String = ""
    @State private var jerseyNumber: String = ""
    @State private var photoFileName: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageToCrop: UIImage?
    @State private var songFileName: String?
    @State private var songDisplayName: String = ""
    @State private var songStartTime: TimeInterval = 0
    @State private var showingDocumentPicker = false
    @State private var showingDeleteConfirmation = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existingPlayer: Player? {
        if case .edit(let player) = mode { return player }
        return nil
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && Int(jerseyNumber) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                if let photoFileName,
                                   let uiImage = UIImage(contentsOfFile: storage.photoFileURL(for: photoFileName).path) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 80, height: 80)
                                        Image(systemName: "camera.fill")
                                            .font(.title2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .onChange(of: selectedPhotoItem) {
                                loadPhoto()
                            }

                            if photoFileName != nil {
                                Button("Remove Photo", role: .destructive) {
                                    removePhoto()
                                }
                                .font(.caption)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Player Info") {
                    TextField("Name", text: $name)
                        .font(.title3)
                        .autocorrectionDisabled()

                    TextField("Jersey Number", text: $jerseyNumber)
                        .keyboardType(.numberPad)
                        .font(.title3)
                }

                Section("Walk-Up Song") {
                    if let songFile = songFileName {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(songDisplayName.isEmpty ? Self.originalName(from: songFile) : songDisplayName)
                                    .lineLimit(2)

                                Text("Start at \(formatTime(songStartTime))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                previewSong()
                            } label: {
                                Image(systemName: audioManager.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                                    .font(.title)
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }

                        TextField(Self.originalName(from: songFile), text: $songDisplayName)
                            .font(.body)

                        HStack {
                            Text("Start Time")
                            Spacer()
                            Text(formatTime(songStartTime))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $songStartTime, in: 0...max(audioManager.duration, 1)) {
                            Text("Start Time")
                        }

                        Button("Change Song") {
                            showingDocumentPicker = true
                        }

                        Button("Remove Song", role: .destructive) {
                            removeSong()
                        }
                    } else {
                        Button {
                            showingDocumentPicker = true
                        } label: {
                            Label("Import from Files", systemImage: "folder")
                                .font(.title3)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }
                }

                if isEditing {
                    Section {
                        Button("Delete Player", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Player" : "Add Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        audioManager.stop()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                    .bold()
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker { url in
                    importSong(from: url)
                }
            }
            .fullScreenCover(item: Binding(
                get: { imageToCrop.map { IdentifiableImage(image: $0) } },
                set: { imageToCrop = $0?.image }
            )) { item in
                PhotoCropView(image: item.image) { croppedImage in
                    savePhoto(croppedImage: croppedImage)
                }
            }
            .confirmationDialog("Delete Player?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let player = existingPlayer {
                        audioManager.stop()
                        storage.deletePlayer(id: player.id)
                        dismiss()
                    }
                }
            } message: {
                Text("This will also remove the player from all lineups.")
            }
            .onAppear {
                if let player = existingPlayer {
                    name = player.name
                    jerseyNumber = String(player.jerseyNumber)
                    photoFileName = player.photoFileName
                    songFileName = player.songFileName
                    songDisplayName = player.effectiveSongName
                    songStartTime = player.songStartTime
                }
            }
            .onDisappear {
                audioManager.stop()
            }
        }
    }

    private func save() {
        guard let number = Int(jerseyNumber),
              let teamId = storage.activeTeamId else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if var player = existingPlayer {
            // If song changed, delete old file
            if player.songFileName != songFileName, let oldSong = player.songFileName {
                storage.deleteSongFile(named: oldSong)
            }
            // If photo changed, delete old file
            if player.photoFileName != photoFileName, let oldPhoto = player.photoFileName {
                storage.deletePhotoFile(named: oldPhoto)
            }
            player.name = trimmedName
            player.jerseyNumber = number
            player.photoFileName = photoFileName
            player.songFileName = songFileName
            player.songDisplayName = songDisplayName.isEmpty ? nil : songDisplayName
            player.songStartTime = songStartTime
            storage.updatePlayer(player)
        } else {
            let player = Player(
                teamId: teamId,
                name: trimmedName,
                jerseyNumber: number,
                photoFileName: photoFileName,
                songFileName: songFileName,
                songDisplayName: songDisplayName.isEmpty ? nil : songDisplayName,
                songStartTime: songStartTime
            )
            storage.addPlayer(player)
        }

        audioManager.stop()
        dismiss()
    }

    private func importSong(from url: URL) {
        // Delete previous song if replacing
        if let oldSong = songFileName {
            storage.deleteSongFile(named: oldSong)
        }

        if let fileName = storage.importSongFile(from: url) {
            songFileName = fileName
            songStartTime = 0

            // Auto-populate display name from original filename (without extension)
            var originalName = url.deletingPathExtension().lastPathComponent
            // Strip leading number prefix like "11- " if present
            if let range = originalName.range(of: #"^\d+[\s\-\.]*"#, options: .regularExpression) {
                originalName = String(originalName[range.upperBound...])
            }
            songDisplayName = originalName

            // Load to get duration for the slider
            let fileURL = storage.songFileURL(for: fileName)
            audioManager.loadAndPlay(url: fileURL, startTime: 0, volume: storage.settings.defaultVolume)
            audioManager.pause()
        }
    }

    private func removeSong() {
        audioManager.stop()
        if let oldSong = songFileName {
            storage.deleteSongFile(named: oldSong)
        }
        songFileName = nil
        songDisplayName = ""
        songStartTime = 0
    }

    private func previewSong() {
        if audioManager.isPlaying {
            audioManager.stop()
        } else if let songFileName {
            let url = storage.songFileURL(for: songFileName)
            audioManager.loadAndPlay(url: url, startTime: songStartTime, volume: storage.settings.defaultVolume)
        }
    }

    /// Extract the original filename from a UUID-prefixed storage name, minus extension
    static func originalName(from storageFileName: String) -> String {
        // Storage format: "UUID_originalname.mp3"
        let withoutExt = (storageFileName as NSString).deletingPathExtension
        if let underscoreIndex = withoutExt.firstIndex(of: "_") {
            return String(withoutExt[withoutExt.index(after: underscoreIndex)...])
        }
        return withoutExt
    }

    private func loadPhoto() {
        guard let item = selectedPhotoItem else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            guard let uiImage = UIImage(data: data) else { return }
            imageToCrop = uiImage
            selectedPhotoItem = nil
        }
    }

    private func removePhoto() {
        if let oldPhoto = photoFileName {
            storage.deletePhotoFile(named: oldPhoto)
        }
        photoFileName = nil
    }

    private func savePhoto(croppedImage: UIImage) {
        guard let jpegData = croppedImage.jpegData(compressionQuality: 0.8) else { return }
        if let oldPhoto = photoFileName {
            storage.deletePhotoFile(named: oldPhoto)
        }
        if let fileName = storage.savePhoto(data: jpegData) {
            photoFileName = fileName
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Player Photo View

struct PlayerPhotoView: View {
    @EnvironmentObject var storage: StorageManager
    let player: Player
    let size: CGFloat

    var body: some View {
        if let photoFileName = player.photoFileName,
           let uiImage = UIImage(contentsOfFile: storage.photoFileURL(for: photoFileName).path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(storage.teamColor.opacity(0.2))
                    .frame(width: size, height: size)
                Text("#\(player.jerseyNumber)")
                    .font(size > 60 ? .title2.bold().monospacedDigit() : .caption.bold().monospacedDigit())
                    .foregroundStyle(storage.teamColor)
            }
        }
    }
}
