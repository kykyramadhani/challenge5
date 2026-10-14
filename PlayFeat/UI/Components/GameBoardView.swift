//
//  GameBoardView.swift
//  PlayFeat
//
//  Hosts the transparent SpriteKit scene over the camera feed: the board
//  during play, and the hand glow at all times. Keeps the scene sized to the
//  screen; the screen that owns the scene connects it to the game.
//

import SpriteKit
import SwiftUI

struct GameBoardView: View {
    let scene: GameScene

    /// Plate and reset button on screen. Until then only the hand glow is drawn.
    let showsBoard: Bool

    /// False out of the foreground: stops SpriteKit's Metal render loop, where
    /// iOS refuses GPU work. `scene.isPaused` alone only freezes the game; the
    /// view would keep drawing.
    let isRendering: Bool

    var body: some View {
        GeometryReader { proxy in
            SpriteView(
                scene: scene,
                isPaused: !isRendering,
                options: [.allowsTransparency, .ignoresSiblingOrder]
            )
            .background(.clear)
            .onAppear {
                scene.size = proxy.size
                scene.showsBoard = showsBoard
            }
            .onChange(of: proxy.size) { _, newSize in
                scene.size = newSize
            }
            .onChange(of: showsBoard) { _, isUp in
                scene.showsBoard = isUp
            }
        }
        .ignoresSafeArea()
    }
}
