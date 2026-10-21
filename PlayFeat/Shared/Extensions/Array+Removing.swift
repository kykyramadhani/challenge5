//
//  Array+Removing.swift
//  PlayFeat
//
//  A multiset difference: what an order still needs once the items already
//  underway are taken out — one copy each, so two lettuces needed and one in
//  the pot still leaves one.
//

extension Array where Element: Equatable {
    /// This array with one copy of each of `items` taken out, first match first.
    func removingOneOfEach(_ items: [Element]) -> [Element] {
        var remaining = self
        for item in items {
            if let index = remaining.firstIndex(of: item) { remaining.remove(at: index) }
        }
        return remaining
    }
}
