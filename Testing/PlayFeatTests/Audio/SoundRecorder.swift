//
//  SoundRecorder.swift
//  PlayFeatTests
//
//  A stand-in for AudioManager: remembers what gameplay asked to hear instead
//  of playing it, so tests stay silent and can check the right sound fired.
//

@testable import PlayFeat

@MainActor
final class SoundRecorder: SoundPlaying {
    private(set) var played: [SoundEffect] = []
    private(set) var isClockWarningOn = false
    private(set) var musicRate: Float = 1

    func play(_ effect: SoundEffect) { played.append(effect) }
    func startClockWarning() { isClockWarningOn = true }
    func stopClockWarning() { isClockWarningOn = false }
    func setMusicRate(_ rate: Float) { musicRate = rate }
}
