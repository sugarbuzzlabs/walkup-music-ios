# Feature Requirements Document: Situational & Ambient Music

## 1. Overview
**Feature Name:** Situational & Ambient Music
**Target Audience:** Game-day DJs, coaches, and parents managing audio for baseball/softball games.
**Objective:** Provide a dedicated, easy-to-access interface for playing non-walkout audio during games. This includes pre-game warm-ups, inning breaks, and quick-hit situational sound effects (e.g., strikeout, home run). The goal is to eliminate dead air and enhance the stadium atmosphere without requiring the user to switch to a different app like Apple Music or Spotify.

## 2. User Stories
As a game-day DJ, I want to play a continuous playlist of high-energy music during pre-game warm-ups so the team gets hyped before the first pitch. 

As a game-day DJ, I want to tap a single button to start an inning break song that automatically fades out after exactly 2 minutes (or a custom duration) so I don't have to manually stop the music when the umpire calls "Play Ball."

As a game-day DJ, I want quick access to a soundboard of situational effects (e.g., "Charge!" organ, strikeout whistle, home run siren) so I can react instantly to on-field events.

As a game-day DJ, I want the app to handle audio ducking and fading gracefully when switching between a walkout song, an inning break song, and a situational sound effect.

## 3. Scope & Requirements

### 3.1. UI/UX Additions
The app currently has four main tabs: `Roster`, `Lineup`, `Game Day`, and `Settings`. To accommodate the new features, the app should introduce a new primary tab called `Stadium` (or `DJ`). Alternatively, a sub-navigation toggle can be added within the `Game Day` tab to switch between `Walkouts` and `Stadium Audio`. The new `Stadium` view must be divided into three distinct sections: Warm-up Playlists, Inning Breaks, and Situational Sounds.

### 3.2. Feature Breakdown

The following table outlines the specific requirements for each of the three core sub-features within the Situational & Ambient Music module.

| Feature | Description | Core Requirements | Audio Behavior |
| :--- | :--- | :--- | :--- |
| **Warm-up Playlists** | Continuous playback of selected tracks for pre-game or post-game scenarios. | Users must be able to select multiple tracks from Apple Music or local device storage to create a playlist. Standard media controls (Play, Pause, Next, Previous, Shuffle, Repeat) must be present. | When a walkout song or situational sound is triggered from another tab, the warm-up playlist should automatically pause or fade out. |
| **Inning Break Music** | Single-track playback designed specifically for the ~2 minutes of downtime between half-innings. | Users can assign specific songs to an "Inning Breaks" list. Each song must have a configurable "Auto-Stop Duration" (defaulting to 120 seconds). A prominent "Fade & Stop" button must be available to manually trigger the fade-out early. | Instead of a hard stop, the audio must smoothly fade out over the last 3-5 seconds of the configured duration. |
| **Situational Sounds** | A grid of large, easily tappable buttons for instant sound effect playback. | The UI should feature a grid layout (e.g., 2x3 or 3x3) of customizable buttons. The app should ship with 5-10 royalty-free stadium sounds (e.g., "Charge!", Airhorn). Users must also be able to map their own short audio clips to a button. | Tapping a button plays the sound immediately. If background music is playing, it should "duck" (lower volume by 70%) while the sound effect plays, then return to normal volume. |

## 4. Technical Considerations

### 4.1. Audio Engine & State Management
The app will require robust use of `AVAudioSession` and `AVAudioPlayer` (or `AVQueuePlayer` for playlists) within the iOS AVFoundation framework. The audio engine must handle multiple audio sources gracefully. For example, playing an `AVAudioPlayer` sound effect over an `MPMusicPlayerController` (Apple Music) track requires specific audio session category configurations, specifically utilizing `AVAudioSessionCategoryPlayback` with `AVAudioSessionCategoryOptionDuckOthers`.

Furthermore, Apple Music playback via `MPMusicPlayerController` does not have native fade-out methods. Fading Apple Music tracks requires a custom implementation using a timer to incrementally step down the system volume or application volume over a set duration.

### 4.2. Data Schema Updates
To support these features, the underlying data models must be updated. The Playlists model needs to store an array of song IDs or URIs. The Inning Breaks model needs to store the song ID, start time (cue point), and auto-stop duration. Finally, the Soundboard model needs to store the button label, color or icon, and the associated audio file path or URI.

## 5. Settings & Configuration
The existing `Settings` tab must be updated to include global configurations for the new features. 

| Setting | Description | Default Value |
| :--- | :--- | :--- |
| **Default Inning Break Duration** | Global setting applied to new inning break songs. | 120 seconds |
| **Fade-Out Duration** | Global setting dictating how long the fade takes when an inning break song ends or is manually stopped. | 3 seconds |
| **Audio Ducking Toggle** | Enable or disable the behavior where background music lowers in volume when a situational sound is played. | Enabled |

## 6. Future Enhancements (Out of Scope for V1)
Future iterations could explore Spotify integration, though Spotify's iOS SDK has strict limitations on offline playback and DJ-style mixing, making this technically difficult. Another potential enhancement is automated inning tracking, which would link the inning break music to a digital scoreboard within the app to automatically suggest the next song based on the game state.
