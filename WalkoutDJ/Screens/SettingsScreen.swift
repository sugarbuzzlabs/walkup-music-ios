import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject var storage: StorageManager
    @State private var autoStopDuration: Double = 10
    @State private var defaultVolume: Double = 0.8
    @State private var defaultInningBreakDuration: Double = 120
    @State private var fadeOutDuration: Double = 3
    @State private var audioDuckingEnabled: Bool = true
    @State private var showingResetConfirmation = false
    @State private var initialized = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Playback") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Auto-Stop Duration")
                            Spacer()
                            Text("\(Int(autoStopDuration))s")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $autoStopDuration, in: 5...30, step: 1) {
                            Text("Auto-Stop Duration")
                        }
                        .onChange(of: autoStopDuration) {
                            saveSettings()
                        }

                        Text("Songs will auto-stop after this duration during Game Day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Default Volume")
                            Spacer()
                            Text("\(Int(defaultVolume * 100))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $defaultVolume, in: 0...1, step: 0.05) {
                            Text("Default Volume")
                        }
                        .onChange(of: defaultVolume) {
                            saveSettings()
                        }
                    }
                }

                Section("Stadium Audio") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Inning Break Duration")
                            Spacer()
                            Text("\(Int(defaultInningBreakDuration))s")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $defaultInningBreakDuration, in: 30...300, step: 5) {
                            Text("Inning Break Duration")
                        }
                        .onChange(of: defaultInningBreakDuration) {
                            saveSettings()
                        }

                        Text("Default auto-stop for new inning break songs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Fade-Out Duration")
                            Spacer()
                            Text("\(Int(fadeOutDuration))s")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $fadeOutDuration, in: 1...10, step: 1) {
                            Text("Fade-Out Duration")
                        }
                        .onChange(of: fadeOutDuration) {
                            saveSettings()
                        }
                    }

                    Toggle("Audio Ducking", isOn: $audioDuckingEnabled)
                        .onChange(of: audioDuckingEnabled) {
                            saveSettings()
                        }

                    Text("Lowers background music volume when a sound effect plays")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Data") {
                    HStack {
                        Text("Teams")
                        Spacer()
                        Text("\(storage.teams.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Players")
                        Spacer()
                        Text("\(storage.teamPlayers.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Lineups")
                        Spacer()
                        Text("\(storage.teamLineups.count)")
                            .foregroundStyle(.secondary)
                    }

                    let songsCount = storage.teamPlayers.filter { $0.songFileName != nil }.count
                    HStack {
                        Text("Songs Imported")
                        Spacer()
                        Text("\(songsCount)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Reset All Data", role: .destructive) {
                        showingResetConfirmation = true
                    }
                } footer: {
                    Text("This will delete all players, lineups, and imported songs. This cannot be undone.")
                }

                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("HypeDeck")
                                .font(.headline)
                            Text("v1.0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Free & Offline")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                if !initialized {
                    autoStopDuration = storage.settings.autoStopDuration
                    defaultVolume = Double(storage.settings.defaultVolume)
                    defaultInningBreakDuration = storage.settings.defaultInningBreakDuration
                    fadeOutDuration = storage.settings.fadeOutDuration
                    audioDuckingEnabled = storage.settings.audioDuckingEnabled
                    initialized = true
                }
            }
            .confirmationDialog("Reset All Data?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                Button("Reset Everything", role: .destructive) {
                    resetAllData()
                }
            } message: {
                Text("All players, lineups, and imported songs will be permanently deleted.")
            }
        }
    }

    private func saveSettings() {
        let settings = AppSettings(
            autoStopDuration: autoStopDuration,
            defaultVolume: Float(defaultVolume),
            defaultInningBreakDuration: defaultInningBreakDuration,
            fadeOutDuration: fadeOutDuration,
            audioDuckingEnabled: audioDuckingEnabled
        )
        storage.updateSettings(settings)
    }

    private func resetAllData() {
        // Delete all song files
        for player in storage.players {
            if let songFileName = player.songFileName {
                storage.deleteSongFile(named: songFileName)
            }
        }

        // Clear all data
        for player in storage.players {
            storage.deletePlayer(id: player.id)
        }
        for lineup in storage.lineups {
            storage.deleteLineup(id: lineup.id)
        }

        // Reset settings
        let defaults = AppSettings()
        storage.updateSettings(defaults)
        autoStopDuration = defaults.autoStopDuration
        defaultVolume = Double(defaults.defaultVolume)
    }
}
