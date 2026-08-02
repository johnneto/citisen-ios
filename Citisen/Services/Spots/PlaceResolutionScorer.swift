import CoreLocation
import Foundation

/// Picks the best Google Places candidate for a Gemini-curated spot name.
///
/// Google Maps often carries several listings for the same venue — the official
/// one plus user-created or generic duplicates. Taking Google's first Text Search
/// hit unconditionally sometimes lands on a dupe, so we fetch a handful of
/// candidates and rank them, deferring to Google's own order on near-ties so
/// matches that are already correct never regress.
enum PlaceResolutionScorer {
    struct Context {
        let curatedName: String
        let cityCenter: CLLocationCoordinate2D
        let cityRadiusMeters: Double
    }

    struct Choice {
        let place: PlaceV1
        /// Index in Google's original ranking; non-zero means we overrode it.
        let index: Int
        let score: Double
        let nameSimilarity: Double
    }

    static func pickBest(_ candidates: [PlaceV1], context: Context) -> Choice? {
        guard !candidates.isEmpty else { return nil }
        // Permanently closed listings are never the right answer, even when they
        // are Google's top hit — drop them so a live listing further down can win.
        let scored = candidates.enumerated()
            .filter { !isPermanentlyClosed($0.element) }
            .map { index, place in
                Choice(
                    place: place,
                    index: index,
                    score: score(place, context: context),
                    nameSimilarity: nameSimilarity(context.curatedName, place.displayName?.text ?? "")
                )
            }
        guard let first = scored.first else { return nil }
        var chosen = scored.max(by: { $0.score < $1.score }) ?? first
        // Anti-regression tie-break: only override Google's ranking when clearly
        // better — unless Google's top hit is a reseller, which is never right.
        if chosen.index != first.index,
           chosen.score - first.score < 0.10,
           !isResale(first.place, context: context) {
            chosen = first
        }
        // Every candidate was a reseller: no pin beats a ticket desk wearing the
        // landmark's name.
        if isResale(chosen.place, context: context) { return nil }
        // Reject only hopeless matches: barely-overlapping name AND either no
        // ratings (dupe signature) or far outside the city.
        if chosen.nameSimilarity < 0.20 {
            let farOutside = distance(chosen.place, from: context.cityCenter)
                .map { $0 > context.cityRadiusMeters * 3 } ?? false
            if (chosen.place.userRatingCount ?? 0) == 0 || farOutside {
                return nil
            }
        }
        return chosen
    }

    static func score(_ place: PlaceV1, context: Context) -> Double {
        let sim = nameSimilarity(context.curatedName, place.displayName?.text ?? "")

        // Official listings accumulate ratings; user-created dupes have few or none.
        // log10 so 100 vs 120 barely differs but 3 vs 3000 strongly does.
        let popularity = min(log10(Double(place.userRatingCount ?? 0) + 1) / 4.0, 1.0)

        let operational: Double
        switch place.businessStatus {
        case "OPERATIONAL": operational = 1.0
        case nil:           operational = 0.6   // landmarks often omit it
        default:            operational = 0.0   // closed temporarily/permanently
        }

        let proximity: Double
        if let meters = distance(place, from: context.cityCenter) {
            let radius = max(context.cityRadiusMeters, 1)
            proximity = meters <= radius ? 1.0 : max(0, 1 - (meters - radius) / (2 * radius))
        } else {
            proximity = 0.5
        }

        // User-created map items typically carry no type and no ratings.
        let dupePenalty = (place.primaryType == nil
                           && (place.types?.isEmpty ?? true)
                           && (place.userRatingCount ?? 0) == 0) ? 0.15 : 0.0

        // Big enough to lose against any plausible real listing — resellers often
        // out-rate the monument itself, so popularity alone cannot settle it.
        let resalePenalty = isResale(place, context: context) ? 0.35 : 0.0

        return 0.45 * sim + 0.30 * popularity + 0.15 * proximity + 0.10 * operational
            - dupePenalty - resalePenalty
    }

    static func isPermanentlyClosed(_ place: PlaceV1) -> Bool {
        place.businessStatus == "CLOSED_PERMANENTLY"
    }

    /// Ticket resellers, tour desks and "skip the line" outfits pack the landmark's
    /// name into their own ("Granada Spain Alhambra Tickets"), which reads as a
    /// strong name match and can outrank the monument's own listing. Only words the
    /// curated name did not itself ask for count, so "Tour Eiffel" never flags itself.
    static func isResale(_ place: PlaceV1, context: Context) -> Bool {
        let curated = tokens(context.curatedName)
        let extra = tokens(place.displayName?.text ?? "").subtracting(curated)
        if !extra.isDisjoint(with: resaleWords) { return true }
        // A monument is not a travel agency; a stall selling entry to one is.
        return curated.isDisjoint(with: resaleWords)
            && !Set(place.types ?? []).isDisjoint(with: resaleTypes)
    }

    private static let resaleWords: Set<String> = [
        "ticket", "tickets", "entrada", "entradas",
        "biglietti", "billets", "billetes", "bilhetes",
        "tour", "tours", "excursion", "excursions", "excursiones",
        "guided", "sightseeing", "transfer", "transfers", "booking", "bookings"
    ]

    private static let resaleTypes: Set<String> = ["travel_agency", "tour_agency"]

    /// Diacritic- and case-folded token similarity: half Jaccard, half overlap
    /// coefficient — overlap gives credit when the official name is a superset
    /// of the curated one ("Restaurante O Zé" vs "O Zé").
    static func nameSimilarity(_ lhs: String, _ rhs: String) -> Double {
        let tokensA = tokens(lhs)
        let tokensB = tokens(rhs)
        guard !tokensA.isEmpty, !tokensB.isEmpty else { return 0 }
        let intersection = Double(tokensA.intersection(tokensB).count)
        let jaccard = intersection / Double(tokensA.union(tokensB).count)
        let overlap = intersection / Double(min(tokensA.count, tokensB.count))
        return 0.5 * jaccard + 0.5 * overlap
    }

    private static let stopWords: Set<String> = [
        "the", "a", "of", "de", "da", "do", "dos", "das",
        "la", "le", "el", "los", "las", "and", "e", "y", "et"
    ]

    private static func tokens(_ string: String) -> Set<String> {
        let folded = string.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return Set(
            folded
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count > 1 && !stopWords.contains($0) }
        )
    }

    private static func distance(_ place: PlaceV1, from center: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let location = place.location else { return nil }
        return CLLocation(latitude: location.latitude, longitude: location.longitude)
            .distance(from: CLLocation(latitude: center.latitude, longitude: center.longitude))
    }
}
