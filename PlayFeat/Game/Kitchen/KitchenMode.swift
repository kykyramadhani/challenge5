//
//  KitchenMode.swift
//  PlayFeat
//
//  Which kind of shift is running, and so when the active order is finished.
//  The playtest has only the Procurement role, so delivering is the finish
//  line; with all three roles the order isn't done until it is served.
//

import Foundation

nonisolated enum KitchenMode {
    /// One player, Procurement only: the active order completes the moment
    /// every requirement has been delivered to its portal.
    case playtest
    /// Procurement, Chef and Front House: a fully delivered order stays
    /// active until it has been cooked, assembled and served to the customer.
    case multiplayer
}
