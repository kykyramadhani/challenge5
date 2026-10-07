//
//  SoundPlaying.swift
//  PlayFeat
//
//  What gameplay needs from audio. `AudioManager` is the real one; tests pass
//  a recorder, so game rules can be checked without speakers. Views that need
//  music or the volumes keep using `AudioManager` from the environment.
//

import Foundation

/// Class-bound so `GameScene` can hold it `weak`, like its other dependencies.
protocol SoundPlaying: AnyObject {
    func play(_ effect: SoundEffect)
    func startClockWarning()
    func stopClockWarning()
    func setMusicRate(_ rate: Float)
}

extension AudioManager: SoundPlaying {}
