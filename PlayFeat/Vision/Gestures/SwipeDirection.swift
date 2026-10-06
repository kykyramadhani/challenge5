//
//  SwipeDirection.swift
//  GetCooking
//
//  Created by Owen Limantoro on 12/08/26.
//

import Foundation

/// Direction of a detected swipe. Horizontal only — it serves the finished
/// dish. Binning the plate is a hand held over the trash, handled in
/// `GameScene` via `HoverDetector`.
enum SwipeDirection: Equatable {
    case left
    case right
}
