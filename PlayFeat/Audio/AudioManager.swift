//
//  AudioManager.swift
//  PlayFeat
//
//  Created by Owen Limantoro on 22/08/26.
//

import AVFoundation

/// Plays the game's sound effects, looping clock warning and background music.
///
/// There is exactly one instance, created in `PlayFeatApp` and handed out by
/// dependency injection — never reached for globally:
///
/// - SwiftUI views read it from the environment:
///   `@Environment(AudioManager.self) private var audio`
/// - `GameStateManager` receives it through `init`.
/// - `GameScene` receives it through its `audio` property.
///
/// Buttons don't call it directly: `ClickButton` plays the UI click.
///
///     audio.play(.addPoint)          // one-shot
///     audio.startClockWarning()      // begin looping tick
///     audio.stopClockWarning()       // stop the loop

@Observable
final class AudioManager: NSObject {
    // MARK: - Persistence

    /// UserDefaults keys the Settings screen reads and writes. AudioManager
    /// only reads them, once, at launch — the Settings sliders own writing them.
    static let musicVolumeKey = "settings.musicVolume"
    static let sfxVolumeKey = "settings.sfxVolume"

    // MARK: - Settings

    /// Master toggle. Set to false to mute all SFX (e.g. from a settings screen).
    var isEnabled: Bool = true

    /// Master volume for one-shot effects, 0.0...1.0.
    ///
    /// The volumes are `@ObservationIgnored` on purpose: their `didSet` clamps
    /// by assigning the property again. Under `@Observable` that assignment
    /// re-enters the setter forever and crashes with EXC_BAD_ACCESS. No view
    /// reads them (SettingsView keeps its own @AppStorage copy), so nothing
    /// needs to observe them anyway.
    @ObservationIgnored var effectsVolume: Float = 1.0 {
        didSet { effectsVolume = min(max(effectsVolume, 0), 1) }
    }

    /// Background-music volume, 0.0...1.0. Kept under the effects so a chime or
    /// the bell always reads clearly over the loop. Changing it takes effect on
    /// any music already playing.
    @ObservationIgnored var musicVolume: Float = 0.45 {
        didSet {
            musicVolume = min(max(musicVolume, 0), 1)
            musicPlayer?.volume = musicVolume
        }
    }

    /// Preloaded raw audio data for each effect. Loading the bytes once up front
    /// means playback never touches the disk, so there is no first-play hitch.
    @ObservationIgnored private var soundData: [SoundEffect: Data] = [:]

    /// Currently-playing one-shot players. We hold strong references here so ARC
    /// does not deallocate a player mid-sound; they are removed when they finish.
    @ObservationIgnored private var activePlayers: [AVAudioPlayer] = []

    /// Dedicated player for the looping low-time warning so it can be stopped later.
    @ObservationIgnored private var clockWarningPlayer: AVAudioPlayer?

    /// Dedicated player for the looping background music.
    @ObservationIgnored private var musicPlayer: AVAudioPlayer?

    /// The music track currently loaded, so a repeat `startMusic` for the same
    /// track is a no-op rather than a restart from the top.
    @ObservationIgnored private var currentMusicName: String?

    // MARK: - Init

    override init() {
        super.init()
        configureAudioSession()
        preloadAll()
        loadSavedVolumes()
    }

    // MARK: - Public API: one-shot effects

    /// Plays a sound once. Multiple calls overlap cleanly (each gets its own
    /// player), so rapid repeats like `bubbleGrab` never cut each other off.
    func play(_ effect: SoundEffect) {
        guard isEnabled, let data = soundData[effect] else { return }
        
        do {
            let player = try AVAudioPlayer(
                data: data,
                fileTypeHint: AVFileType.wav.rawValue
            )
            player.delegate = self
            player.volume = effectsVolume
            player.prepareToPlay()
            player.play()
            activePlayers.append(player)  // retain until it finishes
        } catch {
            print("[AudioManager] Failed to play \(effect.rawValue): \(error)")
        }
    }

    // MARK: - Public API: looping low-time warning

    /// Starts the looping ticking warning for when time is running low.
    /// Call `stopClockWarning()` when time is added back or the round ends.
    func startClockWarning() {
        guard isEnabled, clockWarningPlayer == nil,
            let data = soundData[.clockRunningOut]
        else { return }

        do {
            let player = try AVAudioPlayer(
                data: data,
                fileTypeHint: AVFileType.wav.rawValue
            )
            player.numberOfLoops = -1  // loop forever until stopped
            player.volume = effectsVolume
            player.prepareToPlay()
            player.play()
            clockWarningPlayer = player
        } catch {
            print("[AudioManager] Failed to start clock warning: \(error)")
        }
    }

    /// Stops the looping low-time warning if it is playing.
    func stopClockWarning() {
        clockWarningPlayer?.stop()
        clockWarningPlayer = nil
    }

    // MARK: - Public API: background music

    /// Starts (or fades in) the looping background-music track. The default is
    /// the gameplay theme; pass another base file name to play a different one.
    ///
    /// Calling this again for the track already playing does nothing, so it is
    /// safe to call on every round start without restarting the loop.
    func startMusic(
        _ name: String = "gameplay_getcooking",
        fadeIn: TimeInterval = 1.5
    ) {
        guard isEnabled else { return }

        // Same track already going — leave it running rather than restart it.
        if name == currentMusicName, musicPlayer?.isPlaying == true { return }

        // Different track: fade the old one out first.
        if currentMusicName != nil { stopMusic() }
        
        guard let wavURL = wavURL(forResourceNamed: name) else { return }

        do {
            let player = try AVAudioPlayer(contentsOf: wavURL)
            player.numberOfLoops = -1  // loop for the whole session
            player.volume = 0  // faded up below
            player.enableRate = true
            player.prepareToPlay()
            player.play()
            player.setVolume(musicVolume, fadeDuration: fadeIn)
            musicPlayer = player
            currentMusicName = name
        } catch {
            print("[AudioManager] Failed to start music \(name): \(error)")
        }
    }

    /// Fades the background music out and stops it.
    func stopMusic(fadeOut: TimeInterval = 0.6) {
        guard let player = musicPlayer else { return }
        musicPlayer = nil
        currentMusicName = nil
        stopClockWarning()

        guard fadeOut > 0 else {
            player.stop()
            return
        }

        player.setVolume(0, fadeDuration: fadeOut)
        // Held by the closure so it survives the fade, then actually stops.
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOut) {
            player.stop()
        }
    }

    /// Sets the background music's playback speed directly. `1.0` is normal
    /// speed, `2.0` is double-time; `AVAudioPlayer` only honours the range
    /// `0.5...2.0`, so anything outside is clamped here rather than silently
    /// ignored by the OS.
    ///
    /// This is an *absolute* setter, not a relative nudge — pass the tempo you
    /// want, not the amount to change by. (The old `changeRate(by:)` added to
    /// the current rate on every call, which pinned it to the 2.0 ceiling after
    /// a round or two.)
    func setMusicRate(_ rate: Float) {
        guard let player = musicPlayer else { return }
        player.rate = min(max(rate, 0.5), 2.0)
    }

    /// Pauses the music in place (e.g. the Pause button) — resume with `resumeMusic()`.
    func pauseMusic() { musicPlayer?.pause() }

    /// Resumes music paused with `pauseMusic()`.
    func resumeMusic() {
        guard isEnabled else { return }
        musicPlayer?.play()
    }

    /// Stops every sound immediately (e.g. on returning to the main menu).
    func stopAll() {
        activePlayers.forEach { $0.stop() }
        activePlayers.removeAll()
        stopClockWarning()
        stopMusic(fadeOut: 0)
    }
}

extension AudioManager {
    /// Applies the volumes the player last chose in Settings. Absent keys leave
    /// the defaults above in place — a fresh install starts at those.
    private func loadSavedVolumes() {
        let defaults = UserDefaults.standard
        
        if defaults.object(forKey: Self.sfxVolumeKey) != nil {
            effectsVolume = Float(defaults.double(forKey: Self.sfxVolumeKey))
        }
        
        if defaults.object(forKey: Self.musicVolumeKey) != nil {
            musicVolume = Float(defaults.double(forKey: Self.musicVolumeKey))
        }
    }

    /// `.ambient` lets game sound mix with the user's music and respect the mute
    /// switch — the usual choice for a casual game. Switch to `.playback` if you
    /// want sound to play even when the silent switch is on.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        
        do {
            try session.setCategory(
                .ambient,
                mode: .default
            )
            
            try session.setActive(true)
            
        } catch {
            print("[AudioManager] Failed to configure audio session: \(error)")
        }
    }

    /// Loads the bytes for every sound once at startup.
    private func preloadAll() {
        for effect in SoundEffect.allCases {
            guard let wavURL = wavURL(forResourceNamed: effect.rawValue) else {
                continue
            }
            
            soundData[effect] = try? Data(contentsOf: wavURL)
        }
    }

    /// Resolves a `.wav` in the bundle by base file name, regardless of which
    /// folder it sits in. The background music track lives in `Sounds/` (not the
    /// `Sound Effect/` subfolder), so it goes through the same resolver.
    private func wavURL(forResourceNamed name: String) -> URL? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            print("[AudioManager] ⚠️ Missing music file: \(name).wav")
            return nil
        }
        
        return url
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioManager: AVAudioPlayerDelegate {
    /// Releases each one-shot player once it finishes so the array does not grow.
    func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        activePlayers.removeAll { $0 === player }
    }
}
