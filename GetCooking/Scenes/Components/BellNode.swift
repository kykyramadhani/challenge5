//
//  BellNode.swift
//  GetCooking
//
//  Created by Owen Limantoro on 14/08/26.
//

import SwiftUI
import SpriteKit

final class BellNode: SKNode {
    private let bell: SKSpriteNode
    public let size: CGSize = CGSize(width: 165, height: 200)
    
    init(direction: SwipeDirection) {
        let imageName = direction == .left
            ? "LeftBell"
            : "RightBell"
        
        bell = SKSpriteNode(imageNamed: imageName)
        
        super.init()
        
        bell.size = self.size
        addChild(bell)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
