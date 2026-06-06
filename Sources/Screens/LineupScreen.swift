import SwiftUI

struct LineupScreen: View {
    @EnvironmentObject var storage: StorageManager
    @State private var showingCreateLineup = false
    @State private var lineupToEdit: Lineup?

    var body: some View {
        NavigationStack {
            Group {
                if storage.teamLineups.isEmpty {
                    ContentUnavailableView(
                        "No Lineups",
                        systemImage: "list.number",
                        description: Text("Tap + to create a batting lineup")
                    )
                } else {
                    List {
                        ForEach(storage.teamLineups) { lineup in
                            NavigationLink {
                                LineupEditorView(lineup: lineup)
                            } label: {
                                LineupRow(lineup: lineup, playerCount: storage.teamPlayers.count)
                            }
                        }
                        .onDelete(perform: deleteLineups)
                    }
                }
            }
            .navigationTitle("Lineups")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreateLineup = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                    }
                }
            }
            .alert("New Lineup", isPresented: $showingCreateLineup) {
                CreateLineupAlert { name in
                    guard let teamId = storage.activeTeamId else { return }
                    let lineup = Lineup(teamId: teamId, name: name)
                    storage.addLineup(lineup)
                }
            }
        }
    }

    private func deleteLineups(at offsets: IndexSet) {
        let teamLineups = storage.teamLineups
        for index in offsets {
            storage.deleteLineup(id: teamLineups[index].id)
        }
    }
}

// MARK: - Lineup Row

struct LineupRow: View {
    let lineup: Lineup
    let playerCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lineup.name)
                .font(.title3.weight(.semibold))

            Text("\(lineup.playerIDs.count) batters")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create Lineup Alert

struct CreateLineupAlert: View {
    let onCreate: (String) -> Void
    @State private var name = ""

    var body: some View {
        TextField("Lineup Name", text: $name)
        Button("Cancel", role: .cancel) {}
        Button("Create") {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                onCreate(trimmed)
            }
        }
    }
}

// MARK: - Lineup Editor

struct LineupEditorView: View {
    @EnvironmentObject var storage: StorageManager
    @State private var lineup: Lineup
    @State private var showingAddPlayers = false
    @State private var showingRename = false
    @Environment(\.editMode) private var editMode

    init(lineup: Lineup) {
        _lineup = State(initialValue: lineup)
    }

    private var lineupPlayers: [Player] {
        lineup.playerIDs.compactMap { id in
            storage.players.first { $0.id == id }
        }
    }

    private var availablePlayers: [Player] {
        storage.teamPlayers
            .filter { !lineup.playerIDs.contains($0.id) }
            .sorted { $0.jerseyNumber < $1.jerseyNumber }
    }

    var body: some View {
        List {
            if lineupPlayers.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Empty Lineup",
                        systemImage: "person.fill.questionmark",
                        description: Text("Add players from your roster")
                    )
                }
            } else {
                Section("Batting Order") {
                    ForEach(Array(lineupPlayers.enumerated()), id: \.element.id) { index, player in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .center)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.name)
                                    .font(.body.weight(.semibold))
                                Text("#\(player.jerseyNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if player.songFileName != nil {
                                Image(systemName: "music.note")
                                    .font(.caption)
                                    .foregroundStyle(storage.teamColor)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .onMove(perform: movePlayers)
                    .onDelete(perform: removeFromLineup)
                }
            }

            Section {
                Button {
                    showingAddPlayers = true
                } label: {
                    Label("Add Players", systemImage: "person.badge.plus")
                        .font(.title3)
                }

                if !lineupPlayers.isEmpty {
                    Button("Reset to Roster Order") {
                        resetToRosterOrder()
                    }
                }
            }
        }
        .navigationTitle(lineup.name)
        .environment(\.editMode, .constant(.active))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingRename = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }

                    Button {
                        addAllPlayers()
                    } label: {
                        Label("Add All Players", systemImage: "person.3.fill")
                    }
                    .disabled(availablePlayers.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Rename Lineup", isPresented: $showingRename) {
            RenameLineupAlert(currentName: lineup.name) { newName in
                lineup.name = newName
                saveLineup()
            }
        }
        .sheet(isPresented: $showingAddPlayers) {
            AddPlayersSheet(availablePlayers: availablePlayers) { selectedIDs in
                lineup.playerIDs.append(contentsOf: selectedIDs)
                saveLineup()
            }
        }
    }

    private func movePlayers(from source: IndexSet, to destination: Int) {
        lineup.playerIDs.move(fromOffsets: source, toOffset: destination)
        saveLineup()
    }

    private func removeFromLineup(at offsets: IndexSet) {
        lineup.playerIDs.remove(atOffsets: offsets)
        saveLineup()
    }

    private func resetToRosterOrder() {
        let rosterOrder = storage.teamPlayers.sorted { $0.jerseyNumber < $1.jerseyNumber }
        let currentIDs = Set(lineup.playerIDs)
        lineup.playerIDs = rosterOrder.filter { currentIDs.contains($0.id) }.map(\.id)
        saveLineup()
    }

    private func addAllPlayers() {
        lineup.playerIDs.append(contentsOf: availablePlayers.map(\.id))
        saveLineup()
    }

    private func saveLineup() {
        storage.updateLineup(lineup)
    }
}

// MARK: - Rename Alert

struct RenameLineupAlert: View {
    let currentName: String
    let onRename: (String) -> Void
    @State private var name: String = ""

    var body: some View {
        TextField("Lineup Name", text: $name)
            .onAppear { name = currentName }
        Button("Cancel", role: .cancel) {}
        Button("Rename") {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                onRename(trimmed)
            }
        }
    }
}

// MARK: - Add Players Sheet

struct AddPlayersSheet: View {
    @EnvironmentObject var storage: StorageManager
    let availablePlayers: [Player]
    let onAdd: ([UUID]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List(availablePlayers, selection: $selectedIDs) { player in
                HStack(spacing: 12) {
                    Text("#\(player.jerseyNumber)")
                        .font(.body.bold().monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .center)

                    Text(player.name)
                        .font(.body.weight(.medium))

                    Spacer()

                    if player.songFileName != nil {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundStyle(storage.teamColor)
                    }
                }
                .padding(.vertical, 2)
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Add Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(selectedIDs.count))") {
                        let ordered = availablePlayers.filter { selectedIDs.contains($0.id) }.map(\.id)
                        onAdd(ordered)
                        dismiss()
                    }
                    .disabled(selectedIDs.isEmpty)
                    .bold()
                }
            }
        }
    }
}
