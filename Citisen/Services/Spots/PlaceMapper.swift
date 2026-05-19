import Foundation

enum PlaceMapper {
    static func makePlace(
        from details: PlaceV1,
        curated: CuratedSpot,
        city: City,
        mode: TravelMode
    ) -> Place? {
        guard let location = details.location else { return nil }
        let id = Place.id(forGooglePlaceId: details.id)
        let openNow = details.currentOpeningHours?.openNow ?? details.regularOpeningHours?.openNow ?? false
        let weekday = details.currentOpeningHours?.weekdayDescriptions
            ?? details.regularOpeningHours?.weekdayDescriptions
            ?? []

        var tags: [String] = []
        if let neighborhood = curated.neighborhood, !neighborhood.isEmpty {
            tags.append(neighborhood)
        }
        let canonicalType = details.primaryType ?? details.types?.first
        if let canonicalType {
            tags.append(formatType(canonicalType))
        }

        let description = curated.rationale
            ?? details.editorialSummary?.text
            ?? "\(mode.displayName) spot in \(city.name)."

        let category = canonicalType.map(formatType) ?? mode.displayName

        return Place(
            id: id,
            googlePlaceId: details.id,
            cityId: city.id,
            name: details.displayName?.text ?? curated.name,
            category: category,
            mode: mode,
            coordinate: Coordinate(latitude: location.latitude, longitude: location.longitude),
            rating: details.rating ?? 0,
            reviewCount: details.userRatingCount ?? 0,
            priceLevel: priceLevelInt(details.priceLevel),
            description: description,
            tags: tags,
            openingHours: openingHours(from: weekday),
            isOpenNow: openNow,
            closesAt: closesAt(from: weekday),
            reviews: details.reviews?.compactMap(makeReview) ?? [],
            address: details.formattedAddress ?? "",
            website: details.websiteUri.flatMap { URL(string: $0) },
            phone: details.internationalPhoneNumber ?? details.nationalPhoneNumber,
            photoNames: photoNames(from: details.photos),
            businessStatus: businessStatus(details.businessStatus)
        )
    }

    /// Builds a `Place` from a refetched `PlaceV1` when no curated metadata is
    /// available (e.g. opening a saved spot after its Gemini cache expired).
    /// Uses the persisted `cityId` and `mode` from the saved entity.
    static func makePlace(
        from details: PlaceV1,
        cityId: String,
        mode: TravelMode
    ) -> Place? {
        guard let location = details.location else { return nil }
        let id = Place.id(forGooglePlaceId: details.id)
        let openNow = details.currentOpeningHours?.openNow ?? details.regularOpeningHours?.openNow ?? false
        let weekday = details.currentOpeningHours?.weekdayDescriptions
            ?? details.regularOpeningHours?.weekdayDescriptions
            ?? []

        var tags: [String] = []
        let canonicalType = details.primaryType ?? details.types?.first
        if let canonicalType {
            tags.append(formatType(canonicalType))
        }

        let cityName = City.all.first(where: { $0.id == cityId })?.name ?? cityId
        let description = details.editorialSummary?.text
            ?? "\(mode.displayName) spot in \(cityName)."
        let category = canonicalType.map(formatType) ?? mode.displayName

        return Place(
            id: id,
            googlePlaceId: details.id,
            cityId: cityId,
            name: details.displayName?.text ?? "",
            category: category,
            mode: mode,
            coordinate: Coordinate(latitude: location.latitude, longitude: location.longitude),
            rating: details.rating ?? 0,
            reviewCount: details.userRatingCount ?? 0,
            priceLevel: priceLevelInt(details.priceLevel),
            description: description,
            tags: tags,
            openingHours: openingHours(from: weekday),
            isOpenNow: openNow,
            closesAt: closesAt(from: weekday),
            reviews: details.reviews?.compactMap(makeReview) ?? [],
            address: details.formattedAddress ?? "",
            website: details.websiteUri.flatMap { URL(string: $0) },
            phone: details.internationalPhoneNumber ?? details.nationalPhoneNumber,
            photoNames: photoNames(from: details.photos),
            businessStatus: businessStatus(details.businessStatus)
        )
    }

    private static func businessStatus(_ raw: String?) -> BusinessStatus {
        switch raw {
        case "OPERATIONAL":         return .operational
        case "CLOSED_TEMPORARILY":  return .closedTemporarily
        case "CLOSED_PERMANENTLY":  return .closedPermanently
        default:                    return .unknown
        }
    }

    static func priceLevelInt(_ value: String?) -> Int {
        switch value {
        case "PRICE_LEVEL_FREE": return 0
        case "PRICE_LEVEL_INEXPENSIVE": return 1
        case "PRICE_LEVEL_MODERATE": return 2
        case "PRICE_LEVEL_EXPENSIVE": return 3
        case "PRICE_LEVEL_VERY_EXPENSIVE": return 4
        default: return 1
        }
    }

    private static func formatType(_ type: String) -> String {
        type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private static func openingHours(from weekday: [String]) -> OpeningHours {
        // Google's weekday descriptions start with Monday and use "Day: hours" format.
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

    private static func photoNames(from photos: [PhotoV1]?) -> [String]? {
        guard let photos, !photos.isEmpty else { return nil }
        return Array(photos.prefix(AppConfig.Spots.maxPhotosPerPlace)).map(\.name)
    }

    private static func makeReview(_ payload: ReviewV1) -> Review? {
        guard let rating = payload.rating, let text = payload.text?.text else { return nil }
        let daysAgo = parseDaysAgo(payload.relativePublishTimeDescription)
        return Review(
            id: UUID(),
            authorName: payload.authorAttribution?.displayName ?? "Anonymous",
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
