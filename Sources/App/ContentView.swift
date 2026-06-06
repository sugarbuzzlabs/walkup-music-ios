import SwiftUI

struct ContentView: View {
    @EnvironmentObject var storage: StorageManager

    var body: some View {
        if storage.teams.isEmpty {
            // First launch — prompt to create a team
            FirstTeamView()
        } else {
            mainTabView
        }
    }

    private var mainTabView: some View {
        TabView {
            Tab("Roster", systemImage: "person.3.fill") {
                RosterScreen()
            }

            Tab("Lineup", systemImage: "list.number") {
                LineupScreen()
            }

            Tab("Game Day", systemImage: "play.circle.fill") {
                GameDayScreen()
            }

            Tab("Stadium", systemImage: "speaker.wave.3.fill") {
                StadiumScreen()
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsScreen()
            }
        }
        .tint(storage.teamColor)
        .preferredColorScheme(.dark)
    }
}

// MARK: - First Team View

struct FirstTeamView: View {
    @EnvironmentObject var storage: StorageManager
    @State private var teamName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "figure.baseball")
                    .font(.system(size: 64))
                    .foregroundStyle(.green) // Welcome screen always green

                VStack(spacing: 8) {
                    Text("Welcome to HypeDeck")
                        .font(.title.bold())

                    Text("Create your first team to get started")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                TextField("Team Name", text: $teamName)
                    .font(.title3)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)
                    .autocorrectionDisabled()

                Button {
                    createTeam()
                } label: {
                    Text("Create Team")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.horizontal, 40)
                .disabled(teamName.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
    }

    private func createTeam() {
        let name = teamName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let team = Team(name: name)
        storage.addTeam(team)
    }
}
