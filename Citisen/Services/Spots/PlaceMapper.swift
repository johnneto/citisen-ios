import Foundation

enum PlaceMapper {
    /// Maps a Google place resolved from a Gemini-curated suggestion via the
    /// cheaper search field mask (no reviews / editorial summary yet).
    static func makePlace(
        from details: PlaceV1,
        curated: CuratedSpot,
        city: City,
        mode: TravelMode
    ) -> Place? {
        build(from: details, curated: curated, cityId: city.id, mode: mode, fullDetails: false)
    }

    /// Maps a Google place fetched with the full Place Details mask when no
    /// curated metadata is available (e.g. opening a saved spot after its
    /// Gemini cache expired, or a place opened from search). Uses the
    /// persisted `cityId` and `mode`.
    static func makePlace(
        from details: PlaceV1,
        cityId: String,
        mode: TravelMode
    ) -> Place? {
        build(from: details, curated: nil, cityId: cityId, mode: mode, fullDetails: true)
    }

    private static func build(
        from details: PlaceV1,
        curated: CuratedSpot?,
        cityId: String,
        mode: TravelMode,
        fullDetails: Bool
    ) -> Place? {
        guard let location = details.location else { return nil }
        let id = Place.id(forGooglePlaceId: details.id)

        var tags: [String] = []
        if let neighborhood = curated?.neighborhood, !neighborhood.isEmpty {
            tags.append(neighborhood)
        }
        let canonicalType = details.primaryType ?? details.types?.first
        if let canonicalType {
            tags.append(formatType(canonicalType))
        }
        let category = canonicalType.map(formatType) ?? mode.displayName

        let curatedRationale = curated?.rationale
        let description = curatedRationale
            ?? details.editorialSummary?.text
            ?? category

        let hours = details.regularOpeningHours ?? details.currentOpeningHours
        let weekdayText = hours?.weekdayDescriptions
        let periods = details.regularOpeningHours?.periods ?? details.currentOpeningHours?.periods

        return Place(
            id: id,
            googlePlaceId: details.id,
            cityId: cityId,
            name: details.displayName?.text ?? curated?.name ?? "",
            category: category,
            mode: mode,
            coordinate: Coordinate(latitude: location.latitude, longitude: location.longitude),
            rating: details.rating,
            reviewCount: details.userRatingCount ?? 0,
            priceLevel: priceLevelInt(details.priceLevel),
            description: description,
            descriptionIsCurated: curatedRationale != nil,
            tags: tags,
            openingHours: OpeningHours(),
            openingPeriods: periods?.compactMap(makePeriod),
            weekdayText: weekdayText,
            utcOffsetMinutes: details.utcOffsetMinutes,
            reviews: details.reviews?.compactMap(makeReview) ?? [],
            address: normalizedAddress(details.formattedAddress),
            website: details.websiteUri.flatMap { URL(string: $0) },
            phone: details.internationalPhoneNumber ?? details.nationalPhoneNumber,
            photoNames: photoNames(from: details.photos),
            businessStatus: businessStatus(details.businessStatus),
            detailsFetchedAt: fullDetails ? Date() : nil
        )
    }

    /// Merges a freshly fetched full-details place over an existing one,
    /// preserving the curated rationale and tags (neighborhood) that only the
    /// original Gemini resolution carries.
    static func merge(fullDetails fresh: Place, preservingCuratedFrom original: Place) -> Place {
        Place(
            id: fresh.id,
            googlePlaceId: fresh.googlePlaceId,
            cityId: original.cityId,
            name: fresh.name,
            category: fresh.category,
            mode: original.mode,
            coordinate: fresh.coordinate,
            rating: fresh.rating,
            reviewCount: fresh.reviewCount,
            priceLevel: fresh.priceLevel,
            description: original.descriptionIsCurated ? original.description : fresh.description,
            descriptionIsCurated: original.descriptionIsCurated,
            tags: original.tags.isEmpty ? fresh.tags : original.tags,
            openingHours: fresh.openingHours,
            openingPeriods: fresh.openingPeriods,
            weekdayText: fresh.weekdayText,
            utcOffsetMinutes: fresh.utcOffsetMinutes,
            reviews: fresh.reviews,
            address: fresh.address,
            website: fresh.website,
            phone: fresh.phone,
            photoNames: fresh.photoNames,
            businessStatus: fresh.businessStatus,
            detailsFetchedAt: fresh.detailsFetchedAt
        )
    }

    private static func normalizedAddress(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func makePeriod(_ payload: OpeningHoursV1.PeriodV1) -> OpeningPeriod? {
        guard let open = payload.open, let openDay = open.day else { return nil }
        return OpeningPeriod(
            openDay: openDay,
            openHour: open.hour ?? 0,
            openMinute: open.minute ?? 0,
            closeDay: payload.close?.day,
            closeHour: payload.close?.hour,
            closeMinute: payload.close?.minute
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

    /// nil means unknown — a place with no price data must not masquerade as "$".
    static func priceLevelInt(_ value: String?) -> Int? {
        switch value {
        case "PRICE_LEVEL_FREE": return 0
        case "PRICE_LEVEL_INEXPENSIVE": return 1
        case "PRICE_LEVEL_MODERATE": return 2
        case "PRICE_LEVEL_EXPENSIVE": return 3
        case "PRICE_LEVEL_VERY_EXPENSIVE": return 4
        default: return nil
        }
    }

    private static func formatType(_ type: String) -> String {
        type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private static func photoNames(from photos: [PhotoV1]?) -> [String]? {
        guard let photos, !photos.isEmpty else { return nil }
        return Array(photos.prefix(AppConfig.Spots.maxPhotosPerPlace)).map(\.name)
    }

    private static func makeReview(_ payload: ReviewV1) -> Review? {
        guard let rating = payload.rating, let text = payload.text?.text else { return nil }
        return Review(
            id: UUID(),
            authorName: payload.authorAttribution?.displayName ?? "Anonymous",
            rating: rating,
            daysAgo: parseDaysAgo(payload.relativePublishTimeDescription),
            text: text,
            relativeTime: payload.relativePublishTimeDescription
        )
    }

    /// Rough recency for sorting only — display uses `Review.relativeTime`
    /// verbatim. Handles Google's singular forms ("a year ago", "an hour ago").
    static func parseDaysAgo(_ text: String?) -> Int {
        guard let text else { return 0 }
        let lower = text.lowercased()
        var value = 0
        let scanner = Scanner(string: lower)
        if !scanner.scanInt(&value) {
            value = (lower.hasPrefix("a ") || lower.hasPrefix("an ")) ? 1 : 0
        }
        if lower.contains("year") { return value * 365 }
        if lower.contains("month") { return value * 30 }
        if lower.contains("week") { return value * 7 }
        if lower.contains("day") { return value }
        return 0
    }
}
