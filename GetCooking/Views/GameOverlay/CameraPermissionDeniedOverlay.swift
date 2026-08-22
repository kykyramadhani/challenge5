//
//  CameraPermissionOverlay.swift
//  GetCooking
//
//  Created by Owen Limantoro on 12/08/26.
//

import SwiftUI

struct CameraPermissionDeniedOverlay: View {
    var body: some View {
        VStack(spacing: 24) {
            Image("PlayFeatMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 260, height: 260)
            
            Text("Camera Permission is Required")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.appTertiaryText)
            
            Text("Go to your settings and allow access to your camera")
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundStyle(.appTertiaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
        .frame(maxWidth: 800)
        .padding(40)
    }
}

#Preview {
    CameraPermissionDeniedOverlay()
}
