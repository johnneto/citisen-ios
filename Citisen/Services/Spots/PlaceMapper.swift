import Foundation

enum PlaceMapper {
    static func makePlace(
        from details: PlaceDetailsPayload,
        curated: CuratedSpot,
        city: City,
        mode: TravelMode
    ) -> Place? {
        guard let location = details.geometry?.location else { return nil }
        let id = Place.id(forGooglePlaceId: details.placeId)
        let openNow = details.currentOpeningHours?.openNow ?? details.openingHours?.openNow ?? false
        let weekday = details.currentOpeningHours?.weekdayText ?? details.openingHours?.weekdayText ?? []

        var tags: [String] = []
        if let neighborhood = curated.neighborhood, !neighborhood.isEmpty {
            tags.append(neighborhood)
        }
        if let primaryType = details.types?.first {
            tags.append(formatType(primaryType))
        }

        let description = curated.rationale
            ?? details.editorialSummary?.overview
            ?? "\(mode.displayName) spot in \(city.name)."

        let category = details.types?.first.map(formatType) ?? mode.displayName

        return Place(
            id: id,
            googlePlaceId: details.placeId,
            cityId: city.id,
            name: details.name ?? curated.name,
            category: category,
            mode: mode,
            coordinate: Coordinate(latitude: location.lat, longitude: location.lng),
            rating: details.rating ?? 0,
            reviewCount: details.userRatingsTotal ?? 0,
            priceLevel: details.priceLevel ?? 1,
            description: description,
            tags: tags,
            openingHours: openingHours(from: weekday),
            isOpenNow: openNow,
            closesAt: closesAt(from: weekday),
            reviews: details.reviews?.compactMap(makeReview) ?? [],
            address: details.formattedAddress ?? "",
            website: details.website.flatMap { URL(string: $0) },
            phone: details.internationalPhoneNumber ?? details.formattedPhoneNumber
        )
    }

    private static func formatType(_ type: String) -> String {
        type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private static func openingHours(from weekday: [String]) -> OpeningHours {
        // Google's weekday_text starts with Monday and is "Day: hours" format.
        func hours(at index: Int) -> String? {
            guard weekday.indices.contains(index) else { return nil }
            let parts = weekday[index].split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return parts[1].trimmingCharacters(in: .whitespaces)
        }
        return OpeningHours(
            monday: hours(at: 0),
            tuesday: hours(at: 1),
            wednesday: hours(at: 2),
            thursday: hours(at: 3),
            friday: hours(at: 4),
            saturday: hours(at: 5),
            sunday: hours(at: 6)
        )
    }

    private static func closesAt(from weekday: [String]) -> String? {
        let weekdayIndex = (Calendar.current.component(.weekday, from: Date()) + 5) % 7  // Sun=1 → 6 (Sun); Mon=2 → 0
        guard weekday.indices.contains(weekdayIndex) else { return nil }
        let line = weekday[weekdayIndex]
        guard let dashRange = line.range(of: "–") ?? line.range(of: "-") else { return nil }
        return String(line[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
    }

    private static func makeReview(_ payload: PlaceReview) -> Review? {
        guard let rating = payload.rating, let text = payload.text else { return nil }
        let daysAgo = parseDaysAgo(payload.relativeTimeDescription)
        return Review(
            id: UUID(),
            authorName: payload.authorName ?? "Anonymous",
            rating: rating,
            daysAgo: daysAgo,
            text: text
        )
    }

    private static func parseDaysAgo(_ text: String?) -> Int {
        guard let text else { return 0 }
        let lower = text.lowercased()
        let scanner = Scanner(string: lower)
        var value = 0
        _ = scanner.scanInt(&value)
        if lower.contains("year") { return value * 365 }
        if lower.contains("month") { return value * 30 }
        if lower.contains("week") { return value * 7 }
        if lower.contains("day") { return value }
        if lower.contains("hour") { return 0 }
        return 0
    }
}
