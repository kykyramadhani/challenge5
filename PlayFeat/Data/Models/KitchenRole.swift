//
//  KitchenRole.swift
//  PlayFeat
//
//  The three jobs in the space kitchen. The player takes one; the other two
//  are stand-ins.
//

import SwiftUI

enum KitchenRole: CaseIterable, Identifiable {
    case procurement, chef, frontHouse

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .procurement: "PROCUREMENT"
        case .chef: "CHEF"
        case .frontHouse: "FRONT-HOUSE"
        }
    }

    var summary: LocalizedStringKey {
        switch self {
        case .procurement: "pass the ingredients to chef and front-house"
        case .chef: "process the ingredients based on the menu"
        case .frontHouse: "arrange the food in tray and serve the beverages"
        }
    }
}
