//
//  AudioManager.swift
//  GetCooking
//
//  Created by Owen Limantoro on 22/08/26.
//
/// Centralized sound-effect manager for the game.
///
/// This is a Swift singleton (the idiomatic equivalent of a Unity "AudioManager"
/// autoload/singleton). There is no inspector in SpriteKit/SwiftUI, so instead of
/// dragging clips into slots you simply reference the sound by name — the manager
/// finds and preloads the matching `.wav` from the app bundle automatically.
///
/// Usage from anywhere:
///
///     AudioManager.shared.play(.addPoint)          // one-shot
///     AudioManager.shared.startClockWarning()      // begin looping tick
///     AudioManager.shared.stopClockWarning()       // stop the loop
///
/// Convenience wrappers are also provided, e.g. `AudioManager.shared.playAddPoint()`.
///


import AVFoundation
final class AudioManager: NSObject {
    /// The single shared instance. Access everything through `AudioManager.shared`.
    static let shared = AudioManager()

    // MARK: - Settings

    /// Master toggle. Set to false to mute all SFX (e.g. from a settings screen).
    var isEnabled: Bool = true

    /// Master volume for one-shot effects, 0.0...1.0.
    var effectsVolume: Float = 1.0 {
        didSet { effectsVolume = min(max(effectsVolume, 0), 1) }
    }

    /// Background-music volume, 0.0...1.0. Kept under the effects so a chime or
    /// the bell always reads clearly over the loop. Changing it takes effect on
    /// any music already playing.
    var musicVolume: Float = 0.45 {
        didSet {
            musicVolume = min(max(musicVolume, 0), 1)
            musicPlayer?.volume = musicVolume
        }
    }

    // MARK: - Private state

    /// Preloaded raw audio data for each effect. Loading the bytes once up front
    /// means playback never touches the disk, so there is no first-play hitch.
    private var soundData: [SoundEffect: Data] = [:]

    /// Currently-playing one-shot players. We hold strong references here so ARC
    /// does not deallocate a player mid-sound; they are removed when they finish.
    private var activePlayers: [AVAudioPlayer] = []

    /// Dedicated player for the looping low-time warning so it can be stopped later.
    private var clockWarningPlayer: AVAudioPlayer?

    /// Dedicated player for the looping background music.
    private var musicPlayer: AVAudioPlayer?

    /// The music track currently loaded, so a repeat `startMusic` for the same
    /// track is a no-op rather than a restart from the top.
    private var currentMusicName: String?

    // MARK: - Persistence

    /// UserDefaults keys the Settings screen reads and writes. AudioManager
    /// only reads them, once, at launch — the Settings sliders own writing them.
    static let musicVolumeKey = "settings.musicVolume"
    static let sfxVolumeKey = "settings.sfxVolume"

    // MARK: - Init

    private override init() {
        super.init()
        configureAudioSession()
        preloadAll()
        loadSavedVolumes()
    }

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
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AudioManager] Failed to configure audio session: \(error)")
        }
    }

    /// Loads the bytes for every sound once at startup.
    private func preloadAll() {
        for effect in SoundEffect.allCases {
            guard let url = url(for: effect) else {
                print("[AudioManager] ⚠️ Missing sound file: \(effect.rawValue).wav")
                continue
            }
            do {
                soundData[effect] = try Data(contentsOf: url)
            } catch {
                print("[AudioManager] Failed to load \(effect.rawValue): \(error)")
            }
        }
    }

    /// Resolves the file URL for a sound.
    ///
    /// The clips live on disk in `Resources/Sounds/Sound Effect/`, but where
    /// they end up *in the bundle* depends on how the folder was added to the
    /// target: a folder reference (blue) keeps the directory structure, while a
    /// group (yellow) flattens every file into the bundle root. Rather than
    /// depend on which, this tries the known subdirectories, then a flat lookup,
    /// then a last-resort scan of every `.wav` in the bundle by name — so it
    /// finds the file under any of those layouts.
    private func url(for effect: SoundEffect) -> URL? {
        url(forResourceNamed: effect.rawValue)
    }

    /// Resolves a `.wav` in the bundle by base file name, regardless of which
    /// folder it sits in. The background music track lives in `Sounds/` (not the
    /// `Sound Effect/` subfolder), so it goes through the same resolver.
    private func url(forResourceNamed name: String) -> URL? {
        let candidateSubdirectories = [
            "Sounds/Sound Effect",
            "Resources/Sounds/Sound Effect",
            "Sound Effect",
            "Sounds",
            "Resources/Sounds",
        ]
        
        for subdirectory in candidateSubdirectories {
            if let url = Bundle.main.url(forResource: name,
                                         withExtension: "wav",
                                         subdirectory: subdirectory) {
                return url
            }
        }

        // Flat lookup — the group (yellow-folder) case.
        if let url = Bundle.main.url(forResource: name, withExtension: "wav") {
            return url
        }

        // Last resort: match by file name across every .wav the bundle knows
        // about, so an unexpected folder layout still resolves.
        let everyWav = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) ?? []
        return everyWav.first { $0.deletingPathExtension().lastPathComponent == name }
    }

    // MARK: - Public API: one-shot effects

    /// Plays a sound once. Multiple calls overlap cleanly (each gets its own
    /// player), so rapid repeats like `bubbleGrab` never cut each other off.
    func play(_ effect: SoundEffect) {
        guard isEnabled, let data = soundData[effect] else { return }
        do {
            let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
            player.delegate = self
            player.volume = effectsVolume
            player.prepareToPlay()
            player.play()
            activePlayers.append(player)   // retain until it finishes
        } catch {
            print("[AudioManager] Failed to play \(effect.rawValue): \(error)")
        }
    }

    // MARK: - Public API: looping low-time warning

    /// Starts the looping ticking warning for when time is running low.
    /// Call `stopClockWarning()` when time is added back or the round ends.
    func startClockWarning() {
        guard isEnabled, clockWarningPlayer == nil,
              let data = soundData[.clockRunningOut] else { return }
        do {
            let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
            player.numberOfLoops = -1        // loop forever until stopped
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
    func startMusic(_ name: String = "gameplay_getcooking", fadeIn: TimeInterval = 1.5) {
        guard isEnabled else { return }

        // Same track already going — leave it running rather than restart it.
        if name == currentMusicName, musicPlayer?.isPlaying == true { return }

        // Different track: fade the old one out first.
        if currentMusicName != nil { stopMusic() }

        guard let url = url(forResourceNamed: name) else {
            print("[AudioManager] ⚠️ Missing music file: \(name).wav")
            return
        }
        
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1        // loop for the whole session
            player.volume = 0                // faded up below
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

        guard fadeOut > 0 else { player.stop(); return }

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

    // MARK: - Convenience wrappers
    // Optional readable shortcuts so call sites can read like plain English.

    func playAddPoint()   { play(.addPoint) }   // GameManager: on scoring a point
    func playBell()       { play(.bell) }       // GameManager: dish finished / order up
    func playBubbleGrab() { play(.bubbleGrab) } // PlayerController: pick up an item
    func playBubblePut()  { play(.bubblePut) }  // PlayerController: place an item
    func playCountdown()  { play(.countdown) }  // GameManager: round start
    func playLoseHeart()  { play(.loseHeart) }  // GameManager: mistake / dropped order
    func playPutOrder()   { play(.putOrder) }   // GameManager: order submitted
    func playReset()      { play(.reset) }      // ResetButton: level restart
    func playUIClick()    { play(.uiClick) }    // Any menu/UI button tap
}

// MARK: - AVAudioPlayerDelegate

extension AudioManager: AVAudioPlayerDelegate {
    /// Releases each one-shot player once it finishes so the array does not grow.
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        activePlayers.removeAll { $0 === player }
    }
}
