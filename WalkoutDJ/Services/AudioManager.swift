import AVFoundation
import SwiftUI

@MainActor
final class AudioManager: NSObject, ObservableObject {
    // Main player state (walkouts, warm-up, inning breaks)
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.8

    // SFX player state (soundboard - plays over main)
    @Published var isSFXPlaying = false

    // Playlist state
    @Published var playlistIndex: Int = 0
    @Published var isShuffled = false
    @Published var isRepeating = false

    private var player: AVAudioPlayer?
    private var sfxPlayer: AVAudioPlayer?
    private var autoStopTimer: Timer?
    private var progressTimer: Timer?
    private var fadeTimer: Timer?
    private var sessionConfigured = false

    // Playlist queue
    private var playlistURLs: [URL] = []
    private var playlistStartTimes: [TimeInterval] = []
    private var shuffledOrder: [Int] = []
    private var onPlaybackFinished: (() -> Void)?

    // Ducking
    private var preDuckVolume: Float = 0.8
    private var isDucked = false

    override init() {
        super.init()
    }

    // MARK: - Main Playback

    func loadAndPlay(url: URL, startTime: TimeInterval = 0, autoStopAfter: TimeInterval? = nil, volume: Float? = nil) {
        stopFade()
        stopMain()
        configureAudioSession()

        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            audioPlayer.currentTime = startTime
            audioPlayer.volume = volume ?? self.volume

            self.player = audioPlayer
            self.duration = audioPlayer.duration
            self.currentTime = startTime

            if let vol = volume {
                self.volume = vol
            }

            audioPlayer.play()
            isPlaying = true
            startProgressTimer()

            if let autoStop = autoStopAfter, autoStop > 0 {
                autoStopTimer = Timer.scheduledTimer(withTimeInterval: autoStop, repeats: false) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.stop()
                    }
                }
            }
        } catch {
            print("Failed to load audio: \(error)")
        }
    }

    /// Play with fade-out at the end instead of hard stop
    func loadAndPlayWithFade(url: URL, startTime: TimeInterval = 0, playDuration: TimeInterval, fadeOutDuration: TimeInterval, volume: Float? = nil) {
        stopFade()
        stopMain()
        configureAudioSession()

        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.delegate = self
            audioPlayer.prepareToPlay()
            audioPlayer.currentTime = startTime
            let playVolume = volume ?? self.volume
            audioPlayer.volume = playVolume

            self.player = audioPlayer
            self.duration = audioPlayer.duration
            self.currentTime = startTime

            if let vol = volume {
                self.volume = vol
            }

            audioPlayer.play()
            isPlaying = true
            startProgressTimer()

            // Schedule fade-out to begin before the end
            let fadeStartDelay = max(0, playDuration - fadeOutDuration)
            autoStopTimer = Timer.scheduledTimer(withTimeInterval: fadeStartDelay, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.fadeOut(duration: fadeOutDuration)
                }
            }
        } catch {
            print("Failed to load audio: \(error)")
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressTimer()
        autoStopTimer?.invalidate()
        autoStopTimer = nil
    }

    func resume() {
        guard let player, !player.isPlaying else { return }
        configureAudioSession()
        player.play()
        isPlaying = true
        startProgressTimer()
    }

    func stop() {
        stopFade()
        stopMain()
    }

    private func stopMain() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopProgressTimer()
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        onPlaybackFinished = nil
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = max(0, min(time, player.duration))
        player.currentTime = clamped
        currentTime = clamped
    }

    func setVolume(_ newVolume: Float) {
        let clamped = max(0, min(1, newVolume))
        volume = clamped
        player?.volume = clamped
    }

    // MARK: - Fade Out

    func fadeOut(duration: TimeInterval) {
        guard let player, isPlaying else { return }
        stopFade()

        let startVolume = player.volume
        let steps = 20
        let interval = duration / Double(steps)
        let volumeStep = startVolume / Float(steps)
        var currentStep = 0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                currentStep += 1
                let newVolume = max(0, startVolume - volumeStep * Float(currentStep))
                self.player?.volume = newVolume

                if currentStep >= steps {
                    self.stopFade()
                    self.stop()
                }
            }
        }
    }

    /// Manually trigger fade & stop (for inning break "Fade & Stop" button)
    func fadeAndStop(duration: TimeInterval = 3.0) {
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        fadeOut(duration: duration)
    }

    private func stopFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }

    // MARK: - SFX Playback (Soundboard)

    func playSFX(url: URL, volume: Float = 1.0, duckMain: Bool = true) {
        configureAudioSession()
        sfxPlayer?.stop()

        do {
            let sfx = try AVAudioPlayer(contentsOf: url)
            sfx.delegate = self
            sfx.prepareToPlay()
            sfx.volume = volume

            self.sfxPlayer = sfx

            // Duck main audio if playing
            if duckMain, isPlaying, let player {
                preDuckVolume = player.volume
                player.volume = preDuckVolume * 0.3
                isDucked = true
            }

            sfx.play()
            isSFXPlaying = true
        } catch {
            print("Failed to play SFX: \(error)")
        }
    }

    private func sfxDidFinish() {
        isSFXPlaying = false
        sfxPlayer = nil

        // Restore ducked volume
        if isDucked, let player {
            player.volume = preDuckVolume
            isDucked = false
        }
    }

    // MARK: - Playlist Playback

    func loadPlaylist(urls: [URL], startTimes: [TimeInterval]? = nil, shuffle: Bool = false, volume: Float? = nil) {
        stopMain()
        playlistURLs = urls
        playlistStartTimes = startTimes ?? Array(repeating: 0, count: urls.count)
        isShuffled = shuffle
        playlistIndex = 0

        if shuffle {
            shuffledOrder = Array(0..<urls.count).shuffled()
        } else {
            shuffledOrder = Array(0..<urls.count)
        }

        guard !urls.isEmpty else { return }
        playTrackAtCurrentIndex(volume: volume)
    }

    func playlistNext(volume: Float? = nil) {
        guard !playlistURLs.isEmpty else { return }
        playlistIndex += 1
        if isRepeating && playlistIndex >= playlistURLs.count {
            playlistIndex = 0
        }
        guard playlistIndex < playlistURLs.count else {
            stop()
            return
        }
        playTrackAtCurrentIndex(volume: volume)
    }

    func playlistPrevious(volume: Float? = nil) {
        guard !playlistURLs.isEmpty else { return }
        // If more than 3 seconds in, restart current track
        if currentTime > 3 {
            let idx = effectiveIndex
            let url = playlistURLs[idx]
            let startTime = playlistStartTimes[idx]
            loadAndPlay(url: url, startTime: startTime, volume: volume)
            onPlaybackFinished = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.playlistNext(volume: volume)
                }
            }
            return
        }
        playlistIndex = max(0, playlistIndex - 1)
        playTrackAtCurrentIndex(volume: volume)
    }

    func toggleShuffle() {
        isShuffled.toggle()
        if isShuffled {
            shuffledOrder = Array(0..<playlistURLs.count).shuffled()
        } else {
            shuffledOrder = Array(0..<playlistURLs.count)
        }
    }

    func toggleRepeat() {
        isRepeating.toggle()
    }

    private var effectiveIndex: Int {
        guard !shuffledOrder.isEmpty, playlistIndex < shuffledOrder.count else { return 0 }
        return shuffledOrder[playlistIndex]
    }

    private func playTrackAtCurrentIndex(volume: Float? = nil) {
        let idx = effectiveIndex
        guard idx < playlistURLs.count else { return }
        let url = playlistURLs[idx]
        let startTime = idx < playlistStartTimes.count ? playlistStartTimes[idx] : 0
        loadAndPlay(url: url, startTime: startTime, volume: volume)
        onPlaybackFinished = { [weak self] in
            Task { @MainActor [weak self] in
                self?.playlistNext(volume: volume)
            }
        }
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        guard !sessionConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            sessionConfigured = true
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    // MARK: - Progress Timer

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let playerPtr = ObjectIdentifier(player)
        Task { @MainActor in
            // Check if it was the SFX player that finished
            if let sfx = self.sfxPlayer, ObjectIdentifier(sfx) == playerPtr {
                self.sfxDidFinish()
                return
            }

            // Main player finished
            if let callback = self.onPlaybackFinished {
                self.isPlaying = false
                self.stopProgressTimer()
                callback()
            } else {
                self.stop()
            }
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        print("Audio decode error: \(error?.localizedDescription ?? "unknown")")
        let playerPtr = ObjectIdentifier(player)
        Task { @MainActor in
            if let sfx = self.sfxPlayer, ObjectIdentifier(sfx) == playerPtr {
                self.sfxDidFinish()
            } else {
                self.stop()
            }
        }
    }
}
