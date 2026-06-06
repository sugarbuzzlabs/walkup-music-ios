import SwiftUI
import PhotosUI

struct TeamManagementSheet: View {
    @EnvironmentObject var storage: StorageManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddTeam = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(storage.teams) { team in
                    NavigationLink {
                        TeamDetailView(teamId: team.id)
                    } label: {
                        HStack(spacing: 12) {
                            TeamPhotoView(team: team, size: 44)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(team.name)
                                    .font(.title3.weight(.semibold))

                                let playerCount = storage.players.filter { $0.teamId == team.id }.count
                                Text("\(playerCount) player\(playerCount == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if team.id == storage.activeTeamId {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(team.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Teams")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddTeam = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Team", isPresented: $showingAddTeam) {
                CreateTeamAlert { name in
                    let team = Team(name: name)
                    storage.addTeam(team)
                }
            }
        }
    }
}

// MARK: - Team Detail View

struct TeamDetailView: View {
    @EnvironmentObject var storage: StorageManager
    @Environment(\.dismiss) private var dismiss
    @State private var teamName: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageToCrop: UIImage?
    @State private var showingDeleteConfirmation = false
    let teamId: UUID

    private var team: Team? {
        storage.teams.first { $0.id == teamId }
    }

    var body: some View {
        Form {
            // Photo
            Section {
                HStack {
                    Spacer()
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        if let team {
                            if let photoFileName = team.photoFileName,
                               let uiImage = UIImage(contentsOfFile: storage.photoFileURL(for: photoFileName).path) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(team.accentColor.opacity(0.2))
                                        .frame(width: 100, height: 100)
                                    VStack(spacing: 4) {
                                        Image(systemName: "camera.fill")
                                            .font(.title2)
                                        Text("Add Photo")
                                            .font(.caption2)
                                    }
                                    .foregroundStyle(team.accentColor)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            .onChange(of: selectedPhotoItem) {
                loadPhoto()
            }

            // Name
            Section("Team Name") {
                TextField("Team Name", text: $teamName)
                    .font(.title3)
                    .autocorrectionDisabled()
                    .onSubmit { saveName() }
                    .onChange(of: teamName) { saveName() }
            }

            // Color
            Section("Team Color") {
                if let team {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(TeamColor.allCases, id: \.self) { teamColor in
                            Button {
                                var updated = team
                                updated.teamColor = teamColor
                                storage.updateTeam(updated)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(teamColor.color)
                                        .frame(width: 40, height: 40)
                                    if team.teamColor == teamColor {
                                        Image(systemName: "checkmark")
                                            .font(.body.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // Set Active
            Section {
                Button {
                    storage.setActiveTeam(id: teamId)
                } label: {
                    HStack {
                        Text("Set as Active Team")
                        Spacer()
                        if storage.activeTeamId == teamId {
                            Image(systemName: "checkmark")
                                .foregroundStyle(team?.accentColor ?? .green)
                        }
                    }
                }
            }

            // Stats
            Section("Stats") {
                let playerCount = storage.players.filter { $0.teamId == teamId }.count
                let lineupCount = storage.lineups.filter { $0.teamId == teamId }.count
                let songCount = storage.players.filter { $0.teamId == teamId && $0.songFileName != nil }.count

                HStack {
                    Text("Players")
                    Spacer()
                    Text("\(playerCount)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Lineups")
                    Spacer()
                    Text("\(lineupCount)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Songs")
                    Spacer()
                    Text("\(songCount)")
                        .foregroundStyle(.secondary)
                }
            }

            // Delete
            if storage.teams.count > 1 {
                Section {
                    Button("Delete Team", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                } footer: {
                    Text("This will delete all players, lineups, and songs for this team.")
                }
            }
        }
        .navigationTitle(team?.name ?? "Team")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let team {
                teamName = team.name
            }
        }
        .confirmationDialog("Delete \(team?.name ?? "Team")?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                storage.deleteTeam(id: teamId)
                dismiss()
            }
        } message: {
            Text("This will permanently delete all players, lineups, and songs for this team.")
        }
        .fullScreenCover(item: Binding(
            get: { imageToCrop.map { IdentifiableImage(image: $0) } },
            set: { imageToCrop = $0?.image }
        )) { item in
            PhotoCropView(image: item.image) { croppedImage in
                saveTeamPhoto(croppedImage: croppedImage)
            }
        }
    }

    private func saveName() {
        let trimmed = teamName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, var team = team, team.name != trimmed else { return }
        team.name = trimmed
        storage.updateTeam(team)
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

    private func saveTeamPhoto(croppedImage: UIImage) {
        guard let jpegData = croppedImage.jpegData(compressionQuality: 0.8) else { return }

        if let oldPhoto = team?.photoFileName {
            storage.deletePhotoFile(named: oldPhoto)
        }

        if let fileName = storage.savePhoto(data: jpegData) {
            if var updated = team {
                updated.photoFileName = fileName
                storage.updateTeam(updated)
            }
        }
    }
}

// MARK: - Team Photo View

struct TeamPhotoView: View {
    @EnvironmentObject var storage: StorageManager
    let team: Team
    let size: CGFloat

    var body: some View {
        if let photoFileName = team.photoFileName,
           let uiImage = UIImage(contentsOfFile: storage.photoFileURL(for: photoFileName).path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(team.accentColor.opacity(0.2))
                    .frame(width: size, height: size)
                Image(systemName: "person.3.fill")
                    .font(size > 60 ? .title2 : .caption)
                    .foregroundStyle(team.accentColor)
            }
        }
    }
}

// MARK: - Create Team Alert

struct CreateTeamAlert: View {
    let onCreate: (String) -> Void
    @State private var name = ""

    var body: some View {
        TextField("Team Name", text: $name)
        Button("Cancel", role: .cancel) {}
        Button("Create") {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                onCreate(trimmed)
            }
        }
    }
}
