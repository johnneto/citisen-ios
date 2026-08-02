import XCTest
@testable import Citisen

final class PlaceProvenanceTests: XCTestCase {
    private func decodePlace(_ json: String) throws -> PlaceV1 {
        try JSONDecoder().decode(PlaceV1.self, from: Data(json.utf8))
    }

    private var minimalDetails: String {
        """
        { "id": "ChIJ_prov", "displayName": { "text": "Spot" },
          "location": { "latitude": 38.72, "longitude": -9.14 } }
        """
    }

    /// Cache entries written before `source` existed must keep working, and read
    /// back as AI-curated so they never raise the "keep this?" offer.
    func test_cachedPlaceWithoutSourceKey_decodesAsAICurated() throws {
        let legacy = """
        {
          "id": "\(UUID().uuidString)",
          "cityId": "dyn_lisbon_pt",
          "name": "Legacy Spot",
          "category": "Restaurant",
          "mode": "\(TravelMode.food.rawValue)",
          "coordinate": { "latitude": 38.72, "longitude": -9.14 }
        }
        """
        let place = try JSONDecoder().decode(Place.self, from: Data(legacy.utf8))
        XCTAssertEqual(place.source, .aiCurated)
    }

    func test_sourceSurvivesEncodeDecodeRoundTrip() throws {
        let searched = try XCTUnwrap(PlaceMapper.makePlace(
            from: try decodePlace(minimalDetails),
            cityId: "dyn_lisbon_pt",
            mode: .food,
            source: .userSearch
        ))
        let data = try JSONEncoder().encode(searched.withSource(.userSaved))
        let decoded = try JSONDecoder().decode(Place.self, from: data)
        XCTAssertEqual(decoded.source, .userSaved)
        XCTAssertEqual(decoded.id, searched.id)
    }

    func test_curationPathIsAICurated_searchPathIsUserSearch() throws {
        let curatedPlace = try XCTUnwrap(PlaceMapper.makePlace(
            from: try decodePlace(minimalDetails),
            curated: CuratedSpot(name: "Spot", neighborhood: nil, rationale: nil, primaryType: nil),
            city: PipelineFixture.lisbon,
            mode: .food
        ))
        XCTAssertEqual(curatedPlace.source, .aiCurated)

        let searched = try XCTUnwrap(PlaceMapper.makePlace(
            from: try decodePlace(minimalDetails),
            cityId: "dyn_lisbon_pt",
            mode: .food,
            source: .userSearch
        ))
        XCTAssertEqual(searched.source, .userSearch)

        // The default keeps the saved-spot refetch path quiet.
        let refetched = try XCTUnwrap(PlaceMapper.makePlace(
            from: try decodePlace(minimalDetails),
            cityId: "dyn_lisbon_pt",
            mode: .food
        ))
        XCTAssertEqual(refetched.source, .aiCurated)
    }

    /// Enriching a kept spot with the full details mask must not relabel it as
    /// an AI suggestion — that would silently drop its badge.
    func test_mergePreservesUserSavedProvenance() throws {
        let kept = try XCTUnwrap(PlaceMapper.makePlace(
            from: try decodePlace(minimalDetails),
            cityId: "dyn_lisbon_pt",
            mode: .food,
            source: .userSearch
        )).withSource(.userSaved)
        let fresh = try XCTUnwrap(PlaceMapper.makePlace(
            from: try decodePlace("""
            { "id": "ChIJ_prov", "displayName": { "text": "Spot" },
              "location": { "latitude": 38.72, "longitude": -9.14 },
              "editorialSummary": { "text": "Google's blurb" } }
            """),
            cityId: "dyn_lisbon_pt",
            mode: .food
        ))

        let merged = PlaceMapper.merge(fullDetails: fresh, preservingCuratedFrom: kept)
        XCTAssertEqual(merged.source, .userSaved)
    }
}

final class KeptPlacesCacheTests: XCTestCase {
    private let cache = SpotsCache()
    /// Each test suffixes this with a UUID so runs never share a kept-place file.
    private let key = "dyn_lisbon_pt_food"

    private func place(named name: String) -> Place {
        Place(
            id: UUID(),
            googlePlaceId: "gp-\(name)",
            cityId: "dyn_lisbon_pt",
            name: name,
            category: "Restaurant",
            mode: .food,
            coordinate: Coordinate(latitude: 38.72, longitude: -9.14),
            rating: nil,
            reviewCount: 0,
            priceLevel: nil,
            description: "",
            tags: [],
            openingHours: OpeningHours(),
            reviews: [],
            address: nil,
            website: nil,
            phone: nil,
            source: .userSaved
        )
    }

    func test_appendDedupesById() {
        let key = "\(self.key)_dedupe_\(UUID().uuidString)"
        let original = place(named: "Ramiro")
        cache.appendKeptPlace(original, key: key)
        cache.appendKeptPlace(original, key: key)

        let loaded = cache.loadKeptPlaces(key: key)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, original.id)
    }

    func test_appendCapsAtConfiguredMaximum_droppingOldest() {
        let key = "\(self.key)_cap_\(UUID().uuidString)"
        let cap = AppConfig.Spots.maxKeptPlacesPerCityMode
        let first = place(named: "First")
        cache.appendKeptPlace(first, key: key)
        for index in 0..<cap {
            cache.appendKeptPlace(place(named: "Spot \(index)"), key: key)
        }

        let loaded = cache.loadKeptPlaces(key: key)
        XCTAssertEqual(loaded.count, cap)
        XCTAssertFalse(loaded.contains { $0.id == first.id })
    }

    /// Kept places must outlive both the curated list TTL and an explicit
    /// "clear cached spots" — they are the only spots the user picked by hand.
    func test_keptPlacesSurviveListCacheClear() {
        let key = "\(self.key)_survive_\(UUID().uuidString)"
        let kept = place(named: "Ramiro")
        cache.appendKeptPlace(kept, key: key)

        cache.clearLists(forCityId: "dyn_lisbon_pt")

        XCTAssertEqual(cache.loadKeptPlaces(key: key).map(\.id), [kept.id])
    }
}
