import SwiftUI

enum StadiumSection: String, CaseIterable {
    case warmup = "Warm-Up"
    case inningBreak = "Inning Break"
    case soundboard = "Soundboard"
}

struct StadiumScreen: View {
    @EnvironmentObject var storage: StorageManager
    @State private var selectedSection: StadiumSection = .soundboard

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(StadiumSection.allCases, id: \.self) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                // Content
                switch selectedSection {
                case .warmup:
                    WarmupView()
                case .inningBreak:
                    InningBreakView()
                case .soundboard:
                    SoundboardView()
                }
            }
            .navigationTitle("Stadium")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let url = URL(string: "spotify://"), UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        } else if let url = URL(string: "https://apps.apple.com/app/spotify-music-and-podcasts/id324684580") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "headphones")
                            .font(.title3)
                    }
                }
            }
        }
    }
}

// MARK: - Soundboard View

struct SoundboardView: View {
    @EnvironmentObject var storage: StorageManager
    @EnvironmentObject var audioManager: AudioManager
    @State private var showingAddButton = false
    @State private var buttonToEdit: SoundboardButton?
    @State private var isEditing = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            if storage.stadiumData.soundboard.isEmpty {
                ContentUnavailableView(
                    "No Sounds",
                    systemImage: "speaker.wave.3.fill",
                    description: Text("Tap + to add sound effects")
                )
                .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(storage.stadiumData.soundboard) { button in
                        SoundboardButtonView(button: button, isEditing: isEditing) {
                            buttonToEdit = button
                        }
                    }
                }
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    if !storage.stadiumData.soundboard.isEmpty {
                        Button(isEditing ? "Done" : "Edit") {
                            isEditing.toggle()
                        }
                    }
                    Button {
                        showingAddButton = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddButton) {
            SoundboardEditSheet(mode: .add)
        }
        .sheet(item: $buttonToEdit) { button in
            SoundboardEditSheet(mode: .edit(button))
        }
    }
}

struct SoundboardButtonView: View {
    @EnvironmentObject var storage: StorageManager
    @EnvironmentObject var audioManager: AudioManager
    let button: SoundboardButton
    var isEditing: Bool = false
    var onEdit: (() -> Void)?

    private var buttonColor: Color {
        TeamColor(rawValue: button.colorName)?.color ?? storage.teamColor
    }

    var body: some View {
        Button {
            if isEditing {
                onEdit?()
            } else {
                playSound()
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    if let emoji = button.iconEmoji, !emoji.isEmpty {
                        Text(emoji)
                            .font(.system(size: 28))
                    } else {
                        Image(systemName: button.iconName)
                            .font(.title2)
                    }
                    Text(button.label)
                        .font(.caption.bold())
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 90)
                .background(buttonColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isEditing ? buttonColor : buttonColor.opacity(0.5), lineWidth: isEditing ? 2 : 1, antialiased: true)
                )
                .foregroundStyle(buttonColor)

                if isEditing {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, buttonColor)
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEditing && button.songFileName == nil)
    }

    private func playSound() {
        guard let fileName = button.songFileName else { return }
        let url = storage.songFileURL(for: fileName)
        audioManager.playSFX(
            url: url,
            volume: storage.settings.defaultVolume,
            duckMain: storage.settings.audioDuckingEnabled
        )
    }
}

// MARK: - Soundboard Edit Sheet

enum SoundboardEditMode: Identifiable {
    case add
    case edit(SoundboardButton)

    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let b): return b.id.uuidString
        }
    }
}

struct SoundboardEditSheet: View {
    @EnvironmentObject var storage: StorageManager
    @Environment(\.dismiss) private var dismiss
    let mode: SoundboardEditMode

    @State private var label = ""
    @State private var colorName = "green"
    @State private var iconName = "speaker.wave.2.fill"
    @State private var iconEmoji = ""
    @State private var songFileName: String?
    @State private var songDisplayName: String?
    @State private var showingDocumentPicker = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var existing: SoundboardButton? {
        if case .edit(let b) = mode { return b }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Button Label") {
                    TextField("e.g. Charge!, Airhorn", text: $label)
                        .font(.title3)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(TeamColor.allCases, id: \.self) { tc in
                            Button {
                                colorName = tc.rawValue
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(tc.color)
                                        .frame(width: 36, height: 36)
                                    if colorName == tc.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Icon") {
                    HStack {
                        Text("Emoji")
                        Spacer()
                        TextField("e.g. 🎺 ⚾️ 🔥", text: $iconEmoji)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onChange(of: iconEmoji) {
                                // Keep only the last emoji character
                                let emojis = iconEmoji.filter { $0.isEmoji }
                                if let last = emojis.last {
                                    iconEmoji = String(last)
                                } else if !iconEmoji.isEmpty {
                                    iconEmoji = ""
                                }
                            }
                    }

                    if !iconEmoji.isEmpty {
                        Button("Clear Emoji (use symbol instead)") {
                            iconEmoji = ""
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(SoundboardButton.availableIcons, id: \.symbol) { icon in
                            Button {
                                iconName = icon.symbol
                                iconEmoji = ""
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(iconEmoji.isEmpty && iconName == icon.symbol ? (TeamColor(rawValue: colorName)?.color ?? .green) : Color.gray.opacity(0.2))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: icon.symbol)
                                        .font(.body)
                                        .foregroundStyle(iconEmoji.isEmpty && iconName == icon.symbol ? .white : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Sound File") {
                    if let name = songDisplayName ?? songFileName {
                        Text(name)
                            .lineLimit(2)
                        Button("Change Sound") {
                            showingDocumentPicker = true
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
                        Button("Delete Sound", role: .destructive) {
                            deleteButton()
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Sound" : "Add Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                        .bold()
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker { url in
                    importSound(from: url)
                }
            }
            .onAppear {
                if let b = existing {
                    label = b.label
                    colorName = b.colorName
                    iconName = b.iconName
                    iconEmoji = b.iconEmoji ?? ""
                    songFileName = b.songFileName
                    songDisplayName = b.songDisplayName
                }
            }
        }
    }

    private func save() {
        let trimmed = label.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        var data = storage.stadiumData
        if var b = existing {
            if let idx = data.soundboard.firstIndex(where: { $0.id == b.id }) {
                b.label = trimmed
                b.colorName = colorName
                b.iconName = iconName
                b.iconEmoji = iconEmoji.isEmpty ? nil : iconEmoji
                b.songFileName = songFileName
                b.songDisplayName = songDisplayName
                data.soundboard[idx] = b
            }
        } else {
            let b = SoundboardButton(
                label: trimmed,
                colorName: colorName,
                iconName: iconName,
                iconEmoji: iconEmoji.isEmpty ? nil : iconEmoji,
                songFileName: songFileName,
                songDisplayName: songDisplayName
            )
            data.soundboard.append(b)
        }
        storage.updateStadiumData(data)
        dismiss()
    }

    private func deleteButton() {
        guard let b = existing else { return }
        var data = storage.stadiumData
        if let fileName = b.songFileName {
            storage.deleteSongFile(named: fileName)
        }
        data.soundboard.removeAll { $0.id == b.id }
        storage.updateStadiumData(data)
        dismiss()
    }

    private func importSound(from url: URL) {
        if let oldFile = songFileName {
            storage.deleteSongFile(named: oldFile)
        }
        if let fileName = storage.importSongFile(from: url) {
            songFileName = fileName
            songDisplayName = url.deletingPathExtension().lastPathComponent
        }
    }
}

// MARK: - Inning Break View

struct InningBreakView: View {
    @EnvironmentObject var storage: StorageManager
    @EnvironmentObject var audioManager: AudioManager
    @State private var showingAddSong = false
    @State private var playingId: UUID?

    var body: some View {
        Group {
            if storage.stadiumData.inningBreakSongs.isEmpty {
                ContentUnavailableView(
                    "No Inning Break Songs",
                    systemImage: "clock.fill",
                    description: Text("Tap + to add songs for between innings")
                )
            } else {
                List {
                    ForEach(storage.stadiumData.inningBreakSongs) { song in
                        InningBreakRow(song: song, isPlaying: playingId == song.id) {
                            playInningBreak(song)
                        } onStop: {
                            audioManager.fadeAndStop(duration: storage.settings.fadeOutDuration)
                            playingId = nil
                        }
                    }
                    .onDelete(perform: deleteInningBreakSongs)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddSong = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAddSong) {
            InningBreakAddSheet()
        }
        .onChange(of: audioManager.isPlaying) {
            if !audioManager.isPlaying {
                playingId = nil
            }
        }
    }

    private func playInningBreak(_ song: InningBreakSong) {
        let url = storage.songFileURL(for: song.songFileName)
        audioManager.loadAndPlayWithFade(
            url: url,
            startTime: song.startTime,
            playDuration: song.autoStopDuration,
            fadeOutDuration: storage.settings.fadeOutDuration,
            volume: storage.settings.defaultVolume
        )
        playingId = song.id
    }

    private func deleteInningBreakSongs(at offsets: IndexSet) {
        var data = storage.stadiumData
        for index in offsets {
            let song = data.inningBreakSongs[index]
            storage.deleteSongFile(named: song.songFileName)
        }
        data.inningBreakSongs.remove(atOffsets: offsets)
        storage.updateStadiumData(data)
    }
}

struct InningBreakRow: View {
    @EnvironmentObject var storage: StorageManager
    let song: InningBreakSong
    let isPlaying: Bool
    let onPlay: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.songDisplayName)
                    .font(.body.weight(.semibold))
                Text("\(Int(song.autoStopDuration))s with fade")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                if isPlaying { onStop() } else { onPlay() }
            } label: {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(isPlaying ? .red : storage.teamColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct InningBreakAddSheet: View {
    @EnvironmentObject var storage: StorageManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingDocumentPicker = false
    @State private var songFileName: String?
    @State private var songDisplayName = ""
    @State private var autoStopDuration: Double = 120

    var body: some View {
        NavigationStack {
            Form {
                Section("Song") {
                    if songFileName != nil {
                        Text(songDisplayName)
                        Button("Change Song") {
                            showingDocumentPicker = true
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

                Section("Auto-Stop Duration") {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text("\(Int(autoStopDuration))s")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $autoStopDuration, in: 30...300, step: 5)
                }
            }
            .navigationTitle("Add Inning Break Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(songFileName == nil)
                        .bold()
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker { url in
                    importSong(from: url)
                }
            }
            .onAppear {
                autoStopDuration = storage.settings.defaultInningBreakDuration
            }
        }
    }

    private func save() {
        guard let fileName = songFileName else { return }
        let song = InningBreakSong(
            songFileName: fileName,
            songDisplayName: songDisplayName,
            autoStopDuration: autoStopDuration
        )
        var data = storage.stadiumData
        data.inningBreakSongs.append(song)
        storage.updateStadiumData(data)
        dismiss()
    }

    private func importSong(from url: URL) {
        if let old = songFileName {
            storage.deleteSongFile(named: old)
        }
        if let fileName = storage.importSongFile(from: url) {
            songFileName = fileName
            songDisplayName = url.deletingPathExtension().lastPathComponent
        }
    }
}

// MARK: - Warm-Up View

struct WarmupView: View {
    @EnvironmentObject var storage: StorageManager
    @EnvironmentObject var audioManager: AudioManager
    @State private var showingAddTrack = false
    @State private var isPlaylistActive = false

    var body: some View {
        VStack(spacing: 0) {
            if storage.stadiumData.playlist.isEmpty {
                ContentUnavailableView(
                    "No Warm-Up Tracks",
                    systemImage: "music.note.list",
                    description: Text("Tap + to add tracks for pre-game music")
                )
            } else {
                // Playback controls
                warmupControls
                    .padding()

                // Track list
                List {
                    ForEach(Array(storage.stadiumData.playlist.enumerated()), id: \.element.id) { index, track in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 24)

                            Text(track.songDisplayName)
                                .font(.body)
                                .lineLimit(1)

                            Spacer()

                            if isPlaylistActive && audioManager.playlistIndex == index {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.caption)
                                    .foregroundStyle(storage.teamColor)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete(perform: deleteTracks)
                    .onMove(perform: moveTracks)
                }
                .environment(\.editMode, .constant(.active))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddTrack = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showingAddTrack) {
            WarmupAddSheet()
        }
        .onChange(of: audioManager.isPlaying) {
            if !audioManager.isPlaying && !audioManager.isPlaying {
                isPlaylistActive = false
            }
        }
    }

    private var warmupControls: some View {
        VStack(spacing: 12) {
            // Now playing
            if isPlaylistActive, audioManager.playlistIndex < storage.stadiumData.playlist.count {
                let track = storage.stadiumData.playlist[audioManager.playlistIndex]
                Text(track.songDisplayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }

            // Main controls
            HStack(spacing: 24) {
                Button {
                    audioManager.toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.title3)
                        .foregroundStyle(audioManager.isShuffled ? storage.teamColor : .secondary)
                }

                Button {
                    audioManager.playlistPrevious(volume: storage.settings.defaultVolume)
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.title2)
                }
                .disabled(!isPlaylistActive)

                Button {
                    if isPlaylistActive && audioManager.isPlaying {
                        audioManager.pause()
                    } else if isPlaylistActive {
                        audioManager.resume()
                    } else {
                        startPlaylist()
                    }
                } label: {
                    Image(systemName: isPlaylistActive && audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(storage.teamColor)
                }

                Button {
                    audioManager.playlistNext(volume: storage.settings.defaultVolume)
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.title2)
                }
                .disabled(!isPlaylistActive)

                Button {
                    audioManager.toggleRepeat()
                } label: {
                    Image(systemName: "repeat")
                        .font(.title3)
                        .foregroundStyle(audioManager.isRepeating ? storage.teamColor : .secondary)
                }
            }
            .buttonStyle(.plain)

            // Stop button
            if isPlaylistActive {
                Button {
                    audioManager.stop()
                    isPlaylistActive = false
                } label: {
                    Text("Stop Warm-Up")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func startPlaylist() {
        let urls = storage.stadiumData.playlist.map {
            storage.songFileURL(for: $0.songFileName)
        }
        guard !urls.isEmpty else { return }
        audioManager.loadPlaylist(
            urls: urls,
            shuffle: audioManager.isShuffled,
            volume: storage.settings.defaultVolume
        )
        isPlaylistActive = true
    }

    private func deleteTracks(at offsets: IndexSet) {
        var data = storage.stadiumData
        for index in offsets {
            let track = data.playlist[index]
            storage.deleteSongFile(named: track.songFileName)
        }
        data.playlist.remove(atOffsets: offsets)
        storage.updateStadiumData(data)
    }

    private func moveTracks(from source: IndexSet, to destination: Int) {
        var data = storage.stadiumData
        data.playlist.move(fromOffsets: source, toOffset: destination)
        storage.updateStadiumData(data)
    }
}

struct WarmupAddSheet: View {
    @EnvironmentObject var storage: StorageManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingDocumentPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Add a track to your warm-up playlist")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    showingDocumentPicker = true
                } label: {
                    Label("Import from Files", systemImage: "folder")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(storage.teamColor)
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("Add Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker { url in
                    importTrack(from: url)
                }
            }
        }
    }

    private func importTrack(from url: URL) {
        if let fileName = storage.importSongFile(from: url) {
            let displayName = url.deletingPathExtension().lastPathComponent
            let track = PlaylistTrack(songFileName: fileName, songDisplayName: displayName)
            var data = storage.stadiumData
            data.playlist.append(track)
            storage.updateStadiumData(data)
            dismiss()
        }
    }
}

// MARK: - Emoji Detection

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && (scalar.value > 0x238C || unicodeScalars.count > 1)
    }
}
