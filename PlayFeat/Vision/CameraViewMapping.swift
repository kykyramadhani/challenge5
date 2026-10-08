//
//  CameraViewMapping.swift
//  PlayFeat
//
//  Created by Owen Limantoro on 07/10/26.
//
//  Turns a point Vision reports (normalized, origin bottom-left) into a point
//  on screen (origin top-left), undoing the same fitting the camera preview
//  applies. Pure maths, so the hands, the body and the preview all share one
//  mapping and never disagree about where the player is.
//

import AVFoundation
import CoreGraphics

/// `nonisolated` so the camera's background queue can use it too: it holds
/// no shared state, just two numbers and some arithmetic.
nonisolated struct CameraViewMapping {
    /// Size of the frames Vision reads, after rotation. Zero until the first
    /// frame arrives, which makes `viewPoint` fall back to a plain stretch.
    var bufferSize: CGSize = .zero

    /// How the preview fits the feed to the screen.
    var gravity: AVLayerVideoGravity = .resizeAspectFill

    /// A Vision point mapped into a view of `viewSize`.
    func viewPoint(_ normalized: CGPoint, in viewSize: CGSize) -> CGPoint {
        Self.viewPoint(fromNormalized: normalized, viewSize: viewSize,
                       bufferSize: bufferSize, gravity: gravity)
    }
    
    /// Maps a normalized Vision point (origin bottom-left) into view space
    /// (origin top-left), reproducing what the preview layer's `gravity` does
    /// to the image: scale the frame to cover (`.resizeAspectFill`) or to fit
    /// inside (`.resizeAspect`) the view, centre it, and let any overflow hang
    /// off the edges.
    ///
    /// Skipping that crop is what pulled the skeleton off the hand on device —
    /// it costs up to ~123pt of horizontal error on a 19.5:9 iPhone, and
    /// exactly 0 on a 4:3 iPad, which is why it looked fine in some places.
    ///
    /// No horizontal flip here: the capture connection is mirrored at source
    /// (see `configureSessionIfNeeded`), so Vision already sees the same
    /// left-right arrangement the player does.
    static func viewPoint(
        fromNormalized normalized: CGPoint,
        viewSize: CGSize,
        bufferSize: CGSize,
        gravity: AVLayerVideoGravity = .resizeAspectFill
    ) -> CGPoint {
        let flipped = CGPoint(x: normalized.x, y: 1 - normalized.y)

        guard viewSize.width > 0, viewSize.height > 0,
              bufferSize.width > 0, bufferSize.height > 0,
              gravity != .resize else {
            // No frame measured yet (or an outright stretch was asked for) —
            // a plain stretch is the best mapping available.
            return CGPoint(x: flipped.x * viewSize.width, y: flipped.y * viewSize.height)
        }

        let widthScale = viewSize.width / bufferSize.width
        let heightScale = viewSize.height / bufferSize.height
        let scale = gravity == .resizeAspect
            ? min(widthScale, heightScale)   // fit: whole frame, letterboxed
            : max(widthScale, heightScale)   // fill: covers the view, cropped
        
        let displayed = CGSize(width: bufferSize.width * scale, height: bufferSize.height * scale)
        let origin = CGPoint(
            // Negative when filling (that edge is cropped off-screen),
            // positive when fitting (that edge is a letterbox bar).
            x: (viewSize.width - displayed.width) / 2,
            y: (viewSize.height - displayed.height) / 2
        )
        return CGPoint(
            x: origin.x + flipped.x * displayed.width,
            y: origin.y + flipped.y * displayed.height
        )
    }
}
