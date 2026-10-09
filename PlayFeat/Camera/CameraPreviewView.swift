//
//  CameraPreviewView.swift
//  VisionChef
//
//  Layer 1 (back): the live front-camera feed the player sees themselves in.
//  It renders the game's *existing* CameraSession rather than making its own —
//  iOS only allows one AVCaptureSession per camera at a time.
//

import UIKit
import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let camera: CameraSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        let layer = view.videoPreviewLayer
        layer.session = camera.captureSession
        layer.videoGravity = camera.previewGravity

        if let connection = layer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true // natural "selfie" view
        }
        
        // Rotation is driven by the camera's RotationCoordinator, which needs
        // this layer to compute the horizon-level preview angle.
        camera.attach(previewLayer: layer)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.videoGravity = camera.previewGravity
    }

    /// A UIView whose backing layer *is* the preview layer, so it resizes with
    /// the view automatically instead of needing manual frame bookkeeping.
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
