//
//  CameraPermissionOverlay.swift
//  GetCooking
//
//  Created by Owen Limantoro on 12/08/26.
//

import SwiftUI

struct CameraPermissionDeniedOverlay: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
            Text("Camera access is required to play VisionChef.")
                .multilineTextAlignment(.center)
                .font(.headline)
            Text("Enable it in Settings \u{2192} Privacy & Security \u{2192} Camera.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding()
    }
}

#Preview {
    CameraPermissionDeniedOverlay()
}
