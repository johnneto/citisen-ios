import CoreLocation
import XCTest
@testable import Citisen

final class OpeningHoursCalculatorTests: XCTestCase {
    // Google day indices: 0 = Sunday … 6 = Saturday.

    /// A weekday/clock point in Google's format: day 0 = Sunday … 6 = Saturday.
    private struct Point {
        let day: Int
        let hour: Int
        let minute: Int
    }

    /// Builds a UTC instant; tests pass explicit UTC offsets for the place so
    /// results are independent of the machine's timezone.
    private func utcDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let components = DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
        guard let date = calendar.date(from: components) else {
            preconditionFailure("Invalid fixture date")
        }
        return date
    }

    private func period(open: Point, close: Point?) -> OpeningPeriod {
        OpeningPeriod(
            openDay: open.day,
            openHour: open.hour,
            openMinute: open.minute,
            closeDay: close?.day,
            closeHour: close?.hour,
            closeMinute: close?.minute
        )
    }

    func test_plainDayHours_openAndClosed() {
        // Monday 9:00–22:00 at UTC+0. 2026-08-03 is a Monday.
        let periods = [period(open: Point(day: 1, hour: 9, minute: 0), close: Point(day: 1, hour: 22, minute: 0))]

        let during = OpeningHoursCalculator.status(
            periods: periods, utcOffsetMinutes: 0, at: utcDate(2026, 8, 3, 12, 0)
        )
        guard case .open(let closesAt) = during else {
            return XCTFail("Expected open, got \(during)")
        }
        XCTAssertEqual(closesAt, utcDate(2026, 8, 3, 22, 0))

        let before = OpeningHoursCalculator.status(
            periods: periods, utcOffsetMinutes: 0, at: utcDate(2026, 8, 3, 7, 30)
        )
        guard case .closed(let opensAt) = before else {
            return XCTFail("Expected closed, got \(before)")
        }
        XCTAssertEqual(opensAt, utcDate(2026, 8, 3, 9, 0))
    }

    func test_splitShift_closedBetweenShifts() {
        // Monday 9:00–12:00 and 13:00–22:00.
        let periods = [
            period(open: Point(day: 1, hour: 9, minute: 0), close: Point(day: 1, hour: 12, minute: 0)),
            period(open: Point(day: 1, hour: 13, minute: 0), close: Point(day: 1, hour: 22, minute: 0))
        ]

        let morning = OpeningHoursCalculator.status(
            periods: periods, utcOffsetMinutes: 0, at: utcDate(2026, 8, 3, 10, 0)
        )
        guard case .open(let morningClose) = morning else {
            return XCTFail("Expected open in the morning shift")
        }
        XCTAssertEqual(morningClose, utcDate(2026, 8, 3, 12, 0))

        let lunchGap = OpeningHoursCalculator.status(
            periods: periods, utcOffsetMinutes: 0, at: utcDate(2026, 8, 3, 12, 30)
        )
        guard case .closed(let reopens) = lunchGap else {
            return XCTFail("Expected closed between shifts")
        }
        XCTAssertEqual(reopens, utcDate(2026, 8, 3, 13, 0))

        let evening = OpeningHoursCalculator.status(
            periods: periods, utcOffsetMinutes: 0, at: utcDate(2026, 8, 3, 20, 0)
        )
        guard case .open(let eveningClose) = evening else {
            return XCTFail("Expected open in the evening shift")
        }
        XCTAssertEqual(eveningClose, utcDate(2026, 8, 3, 22, 0))
    }

    func test_overnightBar_openPastMidnight() {
        // Friday 22:00 → Saturday 02:00.
        let periods = [period(open: Point(day: 5, hour: 22, minute: 0), close: Point(day: 6, hour: 2, minute: 0))]

        // Saturday 01:00 — still inside Friday's period.
        let lateNight = OpeningHoursCalculator.status(
            periods: periods, utcOffsetMinutes: 0, at: utcDate(2026, 8, 8, 1, 0)
        )
        guard case .open(let closesAt) = lateNight else {
            return XCTFail("Expected open past midnight")
        }
        XCTAssertEqual(closesAt, utcDate(2026, 8, 8, 2, 0))
    }

    func test_saturdayToSundayWeekWrap() {
        // Saturday 22:00 → Sunday 02:00 wraps the week boundary (6 → 0).
        let periods = [period(open: Point(day: 6, hour: 22, minute: 0), close: Point(day: 0, hour: 2, minute: 0))]

        // Sunday 01:00 (2026-08-09 is a Sunday).
        let status = OpeningHoursCalculator.status(
            periods: periods, utcOffsetMinutes: 0, at: utcDate(2026, 8, 9, 1, 0)
        )
        guard case .open(let closesAt) = status else {
            return XCTFail("Expected open across the week wrap")
        }
        XCTAssertEqual(closesAt, utcDate(2026, 8, 9, 2, 0))
    }

    func test_alwaysOpen_sentinel() {
        let periods = [period(open: Point(day: 0, hour: 0, minute: 0), close: nil)]
        let status = OpeningHoursCalculator.status(
            periods: periods, utcOffsetMinutes: 0, at: utcDate(2026, 8, 3, 3, 0)
        )
        XCTAssertEqual(status, .open(closesAt: nil))
    }

    func test_missingData_isUnknown() {
        XCTAssertEqual(
            OpeningHoursCalculator.status(periods: nil, utcOffsetMinutes: 0, at: Date()),
            .unknown
        )
        XCTAssertEqual(
            OpeningHoursCalculator.status(periods: [], utcOffsetMinutes: 0, at: Date()),
            .unknown
        )
        XCTAssertEqual(
            OpeningHoursCalculator.status(
                periods: [period(open: Point(day: 1, hour: 9, minute: 0), close: Point(day: 1, hour: 22, minute: 0))],
                utcOffsetMinutes: nil,
                at: Date()
            ),
            .unknown
        )
    }

    func test_placeTimezone_notDeviceTimezone() {
        // Tokyo place (UTC+9), Monday 9:00–22:00 local.
        // At 2026-08-03 01:00 UTC it is Monday 10:00 in Tokyo → open,
        // even though in e.g. Los Angeles (UTC-7) it is still Sunday.
        let periods = [period(open: Point(day: 1, hour: 9, minute: 0), close: Point(day: 1, hour: 22, minute: 0))]
        let status = OpeningHoursCalculator.status(
            periods: periods, utcOffsetMinutes: 9 * 60, at: utcDate(2026, 8, 3, 1, 0)
        )
        guard case .open(let closesAt) = status else {
            return XCTFail("Expected open in the place's timezone")
        }
        // Closes Monday 22:00 Tokyo = 13:00 UTC.
        XCTAssertEqual(closesAt, utcDate(2026, 8, 3, 13, 0))
    }
}

final class PlaceResolutionScorerTests: XCTestCase {
    private func candidate(
        name: String,
        ratingCount: Int?,
        latitude: Double = 38.72,
        longitude: Double = -9.14,
        businessStatus: String? = "OPERATIONAL",
        primaryType: String? = "restaurant",
        types: [String]? = ["restaurant"]
    ) throws -> PlaceV1 {
        var fields: [String] = [
            "\"id\": \"id-\(UUID().uuidString)\"",
            "\"displayName\": { \"text\": \"\(name)\" }",
            "\"location\": { \"latitude\": \(latitude), \"longitude\": \(longitude) }"
        ]
        if let ratingCount { fields.append("\"userRatingCount\": \(ratingCount)") }
        if let businessStatus { fields.append("\"businessStatus\": \"\(businessStatus)\"") }
        if let primaryType { fields.append("\"primaryType\": \"\(primaryType)\"") }
        if let types {
            fields.append("\"types\": [\(types.map { "\"\($0)\"" }.joined(separator: ","))]")
        }
        let json = "{ \(fields.joined(separator: ", ")) }"
        return try JSONDecoder().decode(PlaceV1.self, from: Data(json.utf8))
    }

    private var lisbonContext: PlaceResolutionScorer.Context {
        .init(
            curatedName: "Cervejaria Ramiro",
            cityCenter: CLLocationCoordinate2D(latitude: 38.72, longitude: -9.14),
            cityRadiusMeters: 5_000
        )
    }

    func test_officialListingBeatsDupeListedFirst() throws {
        // Google ranks a low-signal duplicate first; the official listing with
        // thousands of ratings must win.
        let dupe = try candidate(
            name: "Cervejaria Ramiro",
            ratingCount: 3,
            businessStatus: nil,
            primaryType: nil,
            types: nil
        )
        let official = try candidate(name: "Cervejaria Ramiro", ratingCount: 4_800)

        let choice = PlaceResolutionScorer.pickBest([dupe, official], context: lisbonContext)
        XCTAssertEqual(choice?.index, 1)
        XCTAssertEqual(choice?.place.userRatingCount, 4_800)
    }

    func test_nearTie_keepsGoogleFirstResult() throws {
        // Two healthy listings with comparable signals — defer to Google's order.
        let first = try candidate(name: "Cervejaria Ramiro", ratingCount: 2_000)
        let second = try candidate(name: "Cervejaria Ramiro", ratingCount: 2_400)

        let choice = PlaceResolutionScorer.pickBest([first, second], context: lisbonContext)
        XCTAssertEqual(choice?.index, 0)
    }

    func test_diacriticFoldedNameSimilarity() {
        XCTAssertEqual(
            PlaceResolutionScorer.nameSimilarity("Cafe A Brasileira", "Café A Brasileira"),
            1.0,
            accuracy: 0.001
        )
    }

    func test_supersetOfficialNameScoresHigh() {
        let sim = PlaceResolutionScorer.nameSimilarity("O Zé", "Restaurante O Zé")
        XCTAssertGreaterThan(sim, 0.6)
    }

    func test_farOutsideCandidateLosesToInCity() throws {
        // Same name, but ~200 km away (another city) vs in-city.
        let elsewhere = try candidate(
            name: "Cervejaria Ramiro",
            ratingCount: 5_000,
            latitude: 40.5,
            longitude: -8.0
        )
        let inCity = try candidate(name: "Cervejaria Ramiro", ratingCount: 3_000)

        let choice = PlaceResolutionScorer.pickBest([elsewhere, inCity], context: lisbonContext)
        XCTAssertEqual(choice?.index, 1)
    }

    func test_hopelessMatch_rejected() throws {
        // Unrelated name and zero ratings → nil rather than a wrong pin.
        let junk = try candidate(
            name: "Quiosque Genérico",
            ratingCount: 0,
            businessStatus: nil,
            primaryType: nil,
            types: nil
        )
        XCTAssertNil(PlaceResolutionScorer.pickBest([junk], context: lisbonContext))
    }
}

final class DetailsMappingTests: XCTestCase {
    private func decodePlace(_ json: String) throws -> PlaceV1 {
        try JSONDecoder().decode(PlaceV1.self, from: Data(json.utf8))
    }

    func test_wire_decodesPeriodsAndUtcOffset() throws {
        let place = try decodePlace("""
        {
          "id": "ChIJ_hours",
          "displayName": { "text": "Hourful" },
          "location": { "latitude": 1, "longitude": 2 },
          "utcOffsetMinutes": 540,
          "regularOpeningHours": {
            "openNow": true,
            "weekdayDescriptions": ["Monday: 9:00 AM – 10:00 PM"],
            "periods": [
              { "open": { "day": 1, "hour": 9, "minute": 0 },
                "close": { "day": 1, "hour": 22, "minute": 0 } }
            ]
          }
        }
        """)
        XCTAssertEqual(place.utcOffsetMinutes, 540)
        let period = try XCTUnwrap(place.regularOpeningHours?.periods?.first)
        XCTAssertEqual(period.open?.day, 1)
        XCTAssertEqual(period.close?.hour, 22)
    }

    func test_mapper_refetchDescription_neverLeaksCityId() throws {
        let details = try decodePlace("""
        {
          "id": "ChIJ_leak",
          "displayName": { "text": "Tasca do Zé" },
          "location": { "latitude": 1, "longitude": 2 },
          "primaryType": "restaurant"
        }
        """)
        let place = try XCTUnwrap(
            PlaceMapper.makePlace(from: details, cityId: "dyn_lisbon_pt", mode: .food)
        )
        XCTAssertFalse(place.description.contains("dyn_"))
        XCTAssertFalse(place.descriptionIsCurated)
        XCTAssertNotNil(place.detailsFetchedAt)
    }

    func test_mapper_curatedRationale_marksDescriptionCurated() throws {
        let details = try decodePlace("""
        {
          "id": "ChIJ_curated",
          "displayName": { "text": "Tasca do Zé" },
          "location": { "latitude": 38.72, "longitude": -9.14 }
        }
        """)
        let curated = CuratedSpot(
            name: "Tasca do Zé",
            neighborhood: "Alfama",
            rationale: "Beloved neighborhood tasca with grilled fish.",
            primaryType: "restaurant"
        )
        let place = try XCTUnwrap(
            PlaceMapper.makePlace(
                from: details,
                curated: curated,
                city: PipelineFixture.lisbon,
                mode: .food
            )
        )
        XCTAssertTrue(place.descriptionIsCurated)
        XCTAssertEqual(place.description, "Beloved neighborhood tasca with grilled fish.")
        XCTAssertEqual(place.tags.first, "Alfama")
        XCTAssertNil(place.detailsFetchedAt)
    }

    func test_mapper_preservesRelativeTimeVerbatim() throws {
        let details = try decodePlace("""
        {
          "id": "ChIJ_reviews",
          "displayName": { "text": "X" },
          "location": { "latitude": 1, "longitude": 2 },
          "reviews": [
            { "rating": 5, "text": { "text": "Great" },
              "relativePublishTimeDescription": "a year ago" }
          ]
        }
        """)
        let place = try XCTUnwrap(
            PlaceMapper.makePlace(from: details, cityId: "any", mode: .standard)
        )
        XCTAssertEqual(place.reviews.first?.relativeTime, "a year ago")
        // Singular "a year ago" must not collapse to 0 days for sorting.
        XCTAssertEqual(place.reviews.first?.daysAgo, 365)
    }

    func test_parseDaysAgo_handlesSingularForms() {
        XCTAssertEqual(PlaceMapper.parseDaysAgo("a year ago"), 365)
        XCTAssertEqual(PlaceMapper.parseDaysAgo("an hour ago"), 0)
        XCTAssertEqual(PlaceMapper.parseDaysAgo("3 months ago"), 90)
        XCTAssertEqual(PlaceMapper.parseDaysAgo("2 weeks ago"), 14)
    }

    func test_mergePreservesCuratedDescriptionAndTags() throws {
        let cheap = try XCTUnwrap(PlaceMapper.makePlace(
            from: try decodePlace("""
            { "id": "ChIJ_m", "displayName": { "text": "Spot" },
              "location": { "latitude": 1, "longitude": 2 } }
            """),
            curated: CuratedSpot(
                name: "Spot",
                neighborhood: "Alfama",
                rationale: "Why visit text.",
                primaryType: nil
            ),
            city: PipelineFixture.lisbon,
            mode: .food
        ))
        let full = try XCTUnwrap(PlaceMapper.makePlace(
            from: try decodePlace("""
            { "id": "ChIJ_m", "displayName": { "text": "Spot" },
              "location": { "latitude": 1, "longitude": 2 },
              "editorialSummary": { "text": "Google's blurb" },
              "reviews": [ { "rating": 4, "text": { "text": "Nice" } } ] }
            """),
            cityId: "dyn_lisbon_pt",
            mode: .food
        ))

        let merged = PlaceMapper.merge(fullDetails: full, preservingCuratedFrom: cheap)
        XCTAssertEqual(merged.description, "Why visit text.")
        XCTAssertTrue(merged.descriptionIsCurated)
        XCTAssertEqual(merged.tags.first, "Alfama")
        XCTAssertEqual(merged.reviews.count, 1)
        XCTAssertNotNil(merged.detailsFetchedAt)
    }
}

final class GeminiPromptTests: XCTestCase {
    func test_prompt_containsOfficialNameContract_andModePalette() {
        for mode in TravelMode.allCases {
            let prompt = GeminiClient().buildPrompt(
                city: PipelineFixture.lisbon,
                mode: mode,
                minCount: 10,
                maxCount: 20
            )
            XCTAssertTrue(prompt.contains("official name EXACTLY"), "\(mode) missing naming contract")
            XCTAssertTrue(prompt.contains("maximum 15 words"), "\(mode) missing rationale cap")
            for type in mode.typePalette {
                XCTAssertTrue(prompt.contains(type), "\(mode) palette missing \(type)")
            }
            // Regressions from the old prompt must stay gone.
            XCTAssertFalse(prompt.contains("Atlas Obscura"))
            XCTAssertFalse(prompt.contains("priotizing"))
            XCTAssertFalse(prompt.contains("hitorical"))
            XCTAssertFalse(prompt.contains("avoid common global chains"))
        }
    }
}

/// Shared fixtures for the details-pipeline suites.
enum PipelineFixture {
    static let lisbon = City(
        id: "dyn_lisbon_pt",
        name: "Lisbon",
        country: "Portugal",
        emojiFlag: "🇵🇹",
        center: Coordinate(latitude: 38.72, longitude: -9.14),
        defaultSpanKm: 8,
        countryCode: "PT"
    )
}
