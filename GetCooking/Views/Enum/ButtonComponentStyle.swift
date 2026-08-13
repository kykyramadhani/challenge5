//
//  ButtonStyle.swift
//  GetCooking
//
//  Created by Owen Limantoro on 13/08/26.
//

import Foundation
import SwiftUI

enum ButtonComponentStyle {
    case primary
    case text
    
    var textColor: Color {
        switch self {
        case .primary:
            return Color("Primary")
        case .text:
            return .BG
        }
    }
    
    var bg: Color {
        switch self {
        case .primary:
            return .BG
        case .text:
            return .white
        }
    }
}
