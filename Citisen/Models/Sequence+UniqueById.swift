import Foundation

extension Sequence where Element: Identifiable {
    /// Keeps the first element for each `id`, preserving order.
    ///
    /// `Place.id` is a v5 UUID derived from `googlePlaceId`, so two curated
    /// suggestions that resolve to the same Google place produce the same id.
    /// SwiftUI's `ForEach` treats duplicate ids as undefined behaviour, so any
    /// list that reaches a view has to be unique.
    func uniquedById() -> [Element] {
        var seen = Set<Element.ID>()
        return filter { seen.insert($0.id).inserted }
    }
}
