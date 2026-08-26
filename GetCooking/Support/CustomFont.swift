//
//  CustomFont.swift
//  GetCooking
//
//  Created by Owen Limantoro on 26/08/26.
//

import SwiftUI

enum CustomFont: String {
    case regular = "AtkinsonHyperlegible-Regular.ttf"
    case bold = "AtkinsonHyperlegible-Bold.ttf"
    
    init(weight: Font.Weight) {
        switch weight {
        case .regular:
            self = .regular
        case .bold:
            self = .bold
        default:
            self = .regular
        }
    }
}

extension Font {
    static func custom(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.custom(CustomFont(weight: weight).rawValue, size: size)
    }
}
