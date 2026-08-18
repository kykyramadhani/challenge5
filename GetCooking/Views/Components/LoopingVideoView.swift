//
//  LoopingVideoView.swift
//  GetCooking
//
//  Plays a bundled clip on a loop, silently, with no controls.
//
//  `VideoPlayer` from AVKit would be less code, but it draws scrub controls
//  over the picture — wrong for a tutorial page that is meant to read as
//  artwork rather than as a video the player is expected to operate.
//
//  Mounted for as long as the tutorial is open, not just while its own page
//  is showing: an AVPlayer has to open the file, parse it and decode a frame
//  before its layer has anything to draw, and doing all that at the moment
//  the page turns is a black flash. Staying mounted means the frame is long
//  since ready and the page turn only has to reveal it.
//

import AVFoundation
import SwiftUI

struct LoopingVideoView: UIViewRepresentable {
    /// File name in the bundle, without the `.mp4`.
    let resource: String

    /// Whether this clip's page is the one on screen. Inactive clips hold
    /// their opening frame so they are ready to be shown instantly.
    var isActive: Bool

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()

        guard let url = Bundle.main.url(forResource: resource, withExtension: "mp4") else {
            return view
        }

        let player = AVQueuePlayer()
        player.isMuted = true

        // The looper has to be held somewhere: it stops looping the instant it
        // is deallocated, which as a local would be the end of this function.
        view.looper = AVPlayerLooper(
            player: player,
            templateItem: AVPlayerItem(url: url)
        )

        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect

        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        guard let player = uiView.playerLayer.player else { return }

        if isActive {
            player.play()
        } else {
            // Parked at the start, so whenever this page comes round the layer
            // is already showing frame one rather than nothing.
            player.pause()
            player.seek(to: .zero)
        }
    }

    /// A view whose backing layer *is* the player layer, so it resizes with the
    /// view instead of needing manual frame bookkeeping — the same trick
    /// `CameraPreviewView` uses.
    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }

        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        var looper: AVPlayerLooper?
    }
}
