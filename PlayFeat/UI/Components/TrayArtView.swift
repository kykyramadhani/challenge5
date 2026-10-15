//
//  TrayArtView.swift
//  PlayFeat
//
//  The food tray (ompreng) art, with its dirt laid over it when it needs
//  washing. Used in the tray bubble and, big, in the sink panel.
//

import SwiftUI

/// The food tray, with its dirt laid over it when it needs washing.
struct TrayArtView: View {
    var isDirty: Bool
    var dirtOpacity: Double = 1
    var size = CGSize(width: 167, height: 136)

    var body: some View {
        Image(TrayArt.trayImage)
            .resizable()
            .frame(width: size.width, height: size.height)
            .overlay {
                if isDirty {
                    let dirt = TrayArt.dirtSize(onTray: size)
                    Image(TrayArt.dirtImage)
                        .resizable()
                        .frame(width: dirt.width, height: dirt.height)
                        .opacity(dirtOpacity)
                }
            }
    }
}
