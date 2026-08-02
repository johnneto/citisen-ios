import CoreLocation
import Foundation

struct Coordinate: Codable, Hashable {
    let latitude: Double
    let longitude: Double

    var clLocation: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct OpeningHours: Codable, Hashable {
    var monday: String?
    var tuesday: String?
    var wednesday: String?
    var thursday: String?
    var friday: String?
    var saturday: String?
    var sunday: String?

    var hasAny: Bool {
        monday != nil || tuesday != nil || wednesday != nil || thursday != nil
            || friday != nil || saturday != nil || sunday != nil
    }

    /// Only days that actually have hours — no fabricated "Closed" rows.
    var knownDayLines: [String] {
        let days: [(String, String?)] = [
            ("Monday", monday), ("Tuesday", tuesday), ("Wednesday", wednesday),
            ("Thursday", thursday), ("Friday", friday), ("Saturday", saturday),
            ("Sunday", sunday)
        ]
        return days.compactMap { name, hours in hours.map { "\(name): \($0)" } }
    }
}

/// One opening interval as Google reports it: day 0 = Sunday … 6 = Saturday,
/// in the place's local time. A period with no close point means open 24/7.
struct OpeningPeriod: Codable, Hashable {
    let openDay: Int
    let openHour: Int
    let openMinute: Int
    let closeDay: Int?
    let closeHour: Int?
    let closeMinute: Int?
}

/// Live open/closed state, computed at display time in the place's timezone.
enum OpenStatus: Equatable {
    case open(closesAt: Date?)   // nil closesAt = open 24/7
    case closed(opensAt: Date?)
    case unknown
}

struct Review: Codable, Hashable, Identifiable {
    let id: UUID
    let authorName: String
    let rating: Int
    let daysAgo: Int
    let text: String
    /// Google's relative publish time verbatim ("a year ago", "3 months ago").
    var relativeTime: String?
}

enum BusinessStatus: String, Codable, Hashable {
    case operational
    case closedTemporarily
    case closedPermanently
    case unknown
}

struct Place: Identifiable, Hashable, Codable {
    let id: UUID
    let googlePlaceId: String?
    let cityId: String
    let name: String
    let category: String
    let mode: TravelMode
    let coordinate: Coordinate
    let rating: Double?
    let reviewCount: Int
    let priceLevel: Int?
    let description: String
    let descriptionIsCurated: Bool
    let tags: [String]
    let openingHours: OpeningHours
    let openingPeriods: [OpeningPeriod]?
    let weekdayText: [String]?
    let utcOffsetMinutes: Int?
    let reviews: [Review]
    let address: String?
    let website: URL?
    let phone: String?
    let photoNames: [String]?
    let businessStatus: BusinessStatus
    /// When the full Place Details payload (reviews, editorial summary) was
    /// fetched. nil for places resolved with the cheaper search field mask —
    /// the POI sheet enriches those lazily on first open.
    let detailsFetchedAt: Date?

    init(
        id: UUID,
        googlePlaceId: String? = nil,
        cityId: String,
        name: String,
        category: String,
        mode: TravelMode,
        coordinate: Coordinate,
        rating: Double?,
        reviewCount: Int,
        priceLevel: Int?,
        description: String,
        descriptionIsCurated: Bool = false,
        tags: [String],
        openingHours: OpeningHours,
        openingPeriods: [OpeningPeriod]? = nil,
        weekdayText: [String]? = nil,
        utcOffsetMinutes: Int? = nil,
        reviews: [Review],
        address: String?,
        website: URL?,
        phone: String?,
        photoNames: [String]? = nil,
        businessStatus: BusinessStatus = .unknown,
        detailsFetchedAt: Date? = nil
    ) {
        self.id = id
        self.googlePlaceId = googlePlaceId
        self.cityId = cityId
        self.name = name
        self.category = category
        self.mode = mode
        self.coordinate = coordinate
        self.rating = rating
        self.reviewCount = reviewCount
        self.priceLevel = priceLevel
        self.description = description
        self.descriptionIsCurated = descriptionIsCurated
        self.tags = tags
        self.openingHours = openingHours
        self.openingPeriods = openingPeriods
        self.weekdayText = weekdayText
        self.utcOffsetMinutes = utcOffsetMinutes
        self.reviews = reviews
        self.address = address
        self.website = website
        self.phone = phone
        self.photoNames = photoNames
        self.businessStatus = businessStatus
        self.detailsFetchedAt = detailsFetchedAt
    }

    static func id(forGooglePlaceId googlePlaceId: String) -> UUID {
        UUID.v5(namespace: .citisenPlacesNamespace, name: googlePlaceId)
    }

    /// nil when the price level is unknown — callers should hide the label
    /// rather than show a misleading "$".
    var budgetLabel: String? {
        switch priceLevel {
        case nil: return nil
        case 0: return "Free"
        case 1: return "$"
        case 2: return "$$"
        case 3: return "$$$"
        default: return "$$$$"
        }
    }

    /// Live open/closed state computed from Google's structured periods in the
    /// place's own timezone. `.unknown` when structured hours are unavailable.
    func openStatus(at date: Date = Date()) -> OpenStatus {
        OpeningHoursCalculator.status(
            periods: openingPeriods,
            utcOffsetMinutes: utcOffsetMinutes,
            at: date
        )
    }

    /// Kept for filters (`SubFilter.openNow`); evaluated live, never cached.
    var isOpenNow: Bool {
        if case .open = openStatus() { return true }
        return false
    }

    /// Weekly hours for display: Google's verbatim weekday lines when present,
    /// otherwise whatever day strings exist (mock data), otherwise nil.
    var weekdayLines: [String]? {
        if let weekdayText, !weekdayText.isEmpty { return weekdayText }
        let known = openingHours.knownDayLines
        return known.isEmpty ? nil : known
    }

    /// The place's timezone when Google reported a UTC offset — used to render
    /// closing/opening times in local-to-the-place clock time.
    var timeZone: TimeZone? {
        utcOffsetMinutes.flatMap { TimeZone(secondsFromGMT: $0 * 60) }
    }

    /// Backward-compatible decoding: fields added after the first cache format
    /// fall back to nil/false so previously cached JSON still decodes.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.googlePlaceId = try container.decodeIfPresent(String.self, forKey: .googlePlaceId)
        self.cityId = try container.decode(String.self, forKey: .cityId)
        self.name = try container.decode(String.self, forKey: .name)
        self.category = try container.decode(String.self, forKey: .category)
        self.mode = try container.decode(TravelMode.self, forKey: .mode)
        self.coordinate = try container.decode(Coordinate.self, forKey: .coordinate)
        self.rating = try container.decodeIfPresent(Double.self, forKey: .rating)
        self.reviewCount = try container.decodeIfPresent(Int.self, forKey: .reviewCount) ?? 0
        self.priceLevel = try container.decodeIfPresent(Int.self, forKey: .priceLevel)
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.descriptionIsCurated = try container.decodeIfPresent(Bool.self, forKey: .descriptionIsCurated) ?? false
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.openingHours = try container.decodeIfPresent(OpeningHours.self, forKey: .openingHours) ?? OpeningHours()
        self.openingPeriods = try container.decodeIfPresent([OpeningPeriod].self, forKey: .openingPeriods)
        self.weekdayText = try container.decodeIfPresent([String].self, forKey: .weekdayText)
        self.utcOffsetMinutes = try container.decodeIfPresent(Int.self, forKey: .utcOffsetMinutes)
        self.reviews = try container.decodeIfPresent([Review].self, forKey: .reviews) ?? []
        self.address = try container.decodeIfPresent(String.self, forKey: .address)
        self.website = try container.decodeIfPresent(URL.self, forKey: .website)
        self.phone = try container.decodeIfPresent(String.self, forKey: .phone)
        self.photoNames = try container.decodeIfPresent([String].self, forKey: .photoNames)
        self.businessStatus = try container.decodeIfPresent(BusinessStatus.self, forKey: .businessStatus) ?? .unknown
        self.detailsFetchedAt = try container.decodeIfPresent(Date.self, forKey: .detailsFetchedAt)
    }

    func distance(from origin: CLLocationCoordinate2D) -> CLLocationDistance {
        let pointA = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let pointB = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        return pointA.distance(from: pointB)
    }

    /// `metric` defaults to the device's region configuration (Settings →
    /// General → Language & Region, including a manual measurement override).
    func formattedDistance(
        from origin: CLLocationCoordinate2D,
        metric: Bool = Locale.current.measurementSystem == .metric
    ) -> String {
        let meters = distance(from: origin)
        if metric {
            if meters < 1000 {
                return "\(Int(meters)) m"
            }
            return String(format: "%.1f km", meters / 1000)
        }
        let miles = meters / 1609.34
        if miles < 0.1 {
            return String(format: "%.0f ft", meters * 3.281)
        }
        return String(format: "%.1f mi", miles)
    }
}
