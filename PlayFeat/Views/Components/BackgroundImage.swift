//
//  BackgroundImage.swift
//  GetCooking
//
//  Created by Owen Limantoro on 15/08/26.
//

import SwiftUI

struct BackgroundImage: View {
    private var imageName : String
    
    init(_ imageName: String) {
        self.imageName = imageName
    }
    
    var body: some View {
        Group {
            // Background image
            Image(imageName)
                .resizable()
                .scaledToFill()
                .blur(radius: 20)
            
            // Dark overlay to make text readable
            Color.black.opacity(0.5)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    BackgroundImage("GetCooking")
}
