//
//  LoopingVideoView.swift
//  GetCooking
//
//  Plays a bundled clip silently, with no controls — on a loop by default, or
//  once through with a callback when it ends.
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
    /// File name in the bundle, without its extension.
    let resource: String

    /// The clip's extension. Kept explicit rather than guessed: the tutorial
    /// ships `.mov` exports straight from the designer, and re-encoding them
    /// to `.mp4` would only cost quality.
    var fileExtension: String = "mov"

    /// Whether this clip's page is the one on screen. Inactive clips hold
    /// their opening frame so they are ready to be shown instantly.
    var isActive: Bool

    /// Plays once instead of looping. The tutorial's short pinch clip is a
    /// beat that hands over to the next page on its own, so looping it would
    /// leave the player watching it repeat with nothing to do.
    var playsOnce: Bool = false

    /// Called when a `playsOnce` clip reaches its end. Never fires while
    /// looping.
    var onFinished: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()

        guard let url = Bundle.main.url(forResource: resource, withExtension: fileExtension) else {
            return view
        }

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true

        if playsOnce {
            player.insert(item, after: nil)
            // `AVPlayerLooper` is what would otherwise restart it; without one
            // the item simply stops on its last frame, which is what this page
            // wants while the next one is prepared.
            context.coordinator.observe(item: item) {
                onFinished?()
            }
        } else {
            // The looper has to be held somewhere: it stops looping the instant
            // it is deallocated, which as a local would be the end of this
            // function.
            view.looper = AVPlayerLooper(player: player, templateItem: item)
        }

        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect

        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        guard let player = uiView.playerLayer.player else { return }

        // Kept fresh, so the callback always closes over the current page's
        // state rather than the one this view was first built for.
        context.coordinator.onFinished = onFinished

        if isActive {
            player.play()
        } else {
            // Parked at the start, so whenever this page comes round the layer
            // is already showing frame one rather than nothing.
            player.pause()
            player.seek(to: .zero)
        }
    }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    /// Holds the end-of-playback observation, which has to outlive
    /// `makeUIView` and be torn down with the view.
    final class Coordinator {
        var onFinished: (() -> Void)?
        private var token: NSObjectProtocol?

        func observe(item: AVPlayerItem, _ handler: @escaping () -> Void) {
            onFinished = handler
            token = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { [weak self] _ in
                self?.onFinished?()
            }
        }

        func stopObserving() {
            if let token { NotificationCenter.default.removeObserver(token) }
            token = nil
        }

        deinit { stopObserving() }
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
