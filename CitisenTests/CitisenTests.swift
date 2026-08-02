//
//  CitisenTests.swift
//  CitisenTests
//
//  Created by Joao Caetano on 13/04/2026.
//

import XCTest
@testable import Citisen

final class CitisenTests: XCTestCase {
    // MARK: - PlaceV1 decoding

    func test_PlaceV1_decodes_canonical_searchText_response() throws {
        let json = """
        {
          "places": [
            {
              "id": "ChIJ_abc123",
              "displayName": { "text": "Telliskivi", "languageCode": "en" },
              "formattedAddress": "Telliskivi 60a, Tallinn",
              "location": { "latitude": 59.4407, "longitude": 24.7297 },
              "rating": 4.6,
              "userRatingCount": 1234,
              "priceLevel": "PRICE_LEVEL_MODERATE",
              "types": ["restaurant", "bar"],
              "regularOpeningHours": {
                "openNow": true,
                "weekdayDescriptions": ["Monday: 9:00 AM – 10:00 PM"]
              },
              "currentOpeningHours": {
                "openNow": false,
                "weekdayDescriptions": ["Monday: Closed"]
              },
              "websiteUri": "https://telliskivi.example",
              "nationalPhoneNumber": "+372 600 0000",
              "internationalPhoneNumber": "+372 600 0000",
              "reviews": [
                {
                  "rating": 5,
                  "text": { "text": "Loved it", "languageCode": "en" },
                  "relativePublishTimeDescription": "2 weeks ago",
                  "publishTime": "2026-05-01T12:00:00Z",
                  "authorAttribution": { "displayName": "Jane Doe" }
                }
              ],
              "editorialSummary": { "text": "Trendy creative city quarter.", "languageCode": "en" }
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(SearchTextResponse.self, from: data)

        let place = try XCTUnwrap(response.places?.first)
        XCTAssertEqual(place.id, "ChIJ_abc123")
        XCTAssertEqual(place.displayName?.text, "Telliskivi")
        XCTAssertEqual(place.formattedAddress, "Telliskivi 60a, Tallinn")
        XCTAssertEqual(place.location?.latitude, 59.4407)
        XCTAssertEqual(place.location?.longitude, 24.7297)
        XCTAssertEqual(place.rating, 4.6)
        XCTAssertEqual(place.userRatingCount, 1234)
        XCTAssertEqual(place.priceLevel, "PRICE_LEVEL_MODERATE")
        XCTAssertEqual(place.types, ["restaurant", "bar"])
        XCTAssertEqual(place.regularOpeningHours?.openNow, true)
        XCTAssertEqual(place.currentOpeningHours?.weekdayDescriptions?.first, "Monday: Closed")
        XCTAssertEqual(place.websiteUri, "https://telliskivi.example")
        XCTAssertEqual(place.internationalPhoneNumber, "+372 600 0000")
        XCTAssertEqual(place.editorialSummary?.text, "Trendy creative city quarter.")

        let review = try XCTUnwrap(place.reviews?.first)
        XCTAssertEqual(review.rating, 5)
        XCTAssertEqual(review.text?.text, "Loved it")
        XCTAssertEqual(review.relativePublishTimeDescription, "2 weeks ago")
        XCTAssertEqual(review.authorAttribution?.displayName, "Jane Doe")
    }

    func test_PlaceV1_decodes_with_missing_optionals() throws {
        let json = """
        { "places": [ { "id": "ChIJ_min", "displayName": { "text": "X" } } ] }
        """
        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(SearchTextResponse.self, from: data)
        let place = try XCTUnwrap(response.places?.first)
        XCTAssertEqual(place.id, "ChIJ_min")
        XCTAssertNil(place.location)
        XCTAssertNil(place.rating)
        XCTAssertNil(place.reviews)
    }

    // MARK: - PlaceMapper

    func test_PlaceMapper_mapsPriceLevelEnum() {
        XCTAssertEqual(PlaceMapper.priceLevelInt("PRICE_LEVEL_FREE"), 0)
        XCTAssertEqual(PlaceMapper.priceLevelInt("PRICE_LEVEL_INEXPENSIVE"), 1)
        XCTAssertEqual(PlaceMapper.priceLevelInt("PRICE_LEVEL_MODERATE"), 2)
        XCTAssertEqual(PlaceMapper.priceLevelInt("PRICE_LEVEL_EXPENSIVE"), 3)
        XCTAssertEqual(PlaceMapper.priceLevelInt("PRICE_LEVEL_VERY_EXPENSIVE"), 4)
        XCTAssertEqual(PlaceMapper.priceLevelInt("PRICE_LEVEL_UNSPECIFIED"), 1)
        XCTAssertEqual(PlaceMapper.priceLevelInt(nil), 1)
    }

    // MARK: - AppConfig field mask

    // MARK: - TabBarLayout

    func test_TabBarLayout_slotIndex_skipsCenterpiece() {
        XCTAssertEqual(TabBarLayout.slotIndex(forOrderIndex: 0), 0)
        XCTAssertEqual(TabBarLayout.slotIndex(forOrderIndex: 1), 1)
        XCTAssertNil(TabBarLayout.slotIndex(forOrderIndex: 2)) // centerpiece
        XCTAssertEqual(TabBarLayout.slotIndex(forOrderIndex: 3), 2)
        XCTAssertEqual(TabBarLayout.slotIndex(forOrderIndex: 4), 3)
        XCTAssertNil(TabBarLayout.slotIndex(forOrderIndex: -1))
        XCTAssertNil(TabBarLayout.slotIndex(forOrderIndex: 5))
    }

    // MARK: - AutocompleteRequest encoding

    private func encodedKeys(_ request: AutocompleteRequest) throws -> [String: Any] {
        let data = try JSONEncoder().encode(request)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func test_AutocompleteRequest_omitsNilFields() throws {
        let request = AutocompleteRequest(
            input: "caf",
            sessionToken: "token-1",
            locationBias: nil,
            includedPrimaryTypes: nil,
            languageCode: nil
        )
        let object = try encodedKeys(request)
        XCTAssertEqual(object["input"] as? String, "caf")
        XCTAssertEqual(object["sessionToken"] as? String, "token-1")
        // Places rejects explicit nulls — the hand-written encoder must drop them.
        XCTAssertNil(object["locationBias"])
        XCTAssertNil(object["includedPrimaryTypes"])
        XCTAssertNil(object["languageCode"])
    }

    func test_AutocompleteRequest_encodesLocationBiasCircle() throws {
        let request = AutocompleteRequest(
            input: "caf",
            sessionToken: "token-1",
            locationBias: SearchTextRequest.LocationBias(
                circle: .init(
                    center: LatLngV1(latitude: 59.437, longitude: 24.7536),
                    radius: 30_000
                )
            ),
            includedPrimaryTypes: ["locality"],
            languageCode: "en"
        )
        let object = try encodedKeys(request)
        let bias = try XCTUnwrap(object["locationBias"] as? [String: Any])
        let circle = try XCTUnwrap(bias["circle"] as? [String: Any])
        let center = try XCTUnwrap(circle["center"] as? [String: Any])
        XCTAssertEqual(center["latitude"] as? Double, 59.437)
        XCTAssertEqual(center["longitude"] as? Double, 24.7536)
        XCTAssertEqual(circle["radius"] as? Double, 30_000)
        XCTAssertEqual(object["includedPrimaryTypes"] as? [String], ["locality"])
        XCTAssertEqual(object["languageCode"] as? String, "en")
    }

    // MARK: - SearchSuggestion

    private func suggestion(placeId: String?, types: [String]) throws -> AutocompleteSuggestion {
        let idField = placeId.map { "\"placeId\": \"\($0)\"," } ?? ""
        let typeList = types.map { "\"\($0)\"" }.joined(separator: ", ")
        let json = """
        {
          "placePrediction": {
            \(idField)
            "text": { "text": "Full text" },
            "structuredFormat": {
              "mainText": { "text": "Main" },
              "secondaryText": { "text": "Secondary" }
            },
            "types": [\(typeList)]
          }
        }
        """
        return try JSONDecoder().decode(AutocompleteSuggestion.self, from: Data(json.utf8))
    }

    func test_SearchSuggestion_classifiesLocalityAsCity() throws {
        let parsed = try XCTUnwrap(
            SearchSuggestion(from: suggestion(placeId: "ChIJ_city", types: ["locality", "political"]))
        )
        XCTAssertEqual(parsed.kind, .city)
        XCTAssertEqual(parsed.iconSymbol, "globe.europe.africa")
        XCTAssertEqual(parsed.primaryText, "Main")
        XCTAssertEqual(parsed.secondaryText, "Secondary")
    }

    func test_SearchSuggestion_classifiesEstablishmentAsPlace() throws {
        let parsed = try XCTUnwrap(
            SearchSuggestion(from: suggestion(placeId: "ChIJ_spot", types: ["restaurant", "establishment"]))
        )
        XCTAssertEqual(parsed.kind, .place)
        XCTAssertEqual(parsed.iconSymbol, "fork.knife")
    }

    func test_SearchSuggestion_fallsBackToGenericPinForUnknownType() throws {
        let parsed = try XCTUnwrap(
            SearchSuggestion(from: suggestion(placeId: "ChIJ_x", types: ["point_of_interest"]))
        )
        XCTAssertEqual(parsed.kind, .place)
        XCTAssertEqual(parsed.iconSymbol, "mappin.circle")
    }

    func test_SearchSuggestion_returnsNilWithoutPlaceId() throws {
        XCTAssertNil(SearchSuggestion(from: try suggestion(placeId: nil, types: ["locality"])))
    }

    // MARK: - CityService pinning

    @MainActor
    private func makeCityService() throws -> (CityService, UserPreferencesService) {
        let suiteName = "citisen.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let prefs = UserPreferencesService(defaults: defaults)
        return (CityService(prefs: prefs), prefs)
    }

    private func makeCity(name: String, countryCode: String) -> City {
        City(
            id: City.stableId(name: name, countryCode: countryCode),
            name: name,
            country: countryCode,
            emojiFlag: "",
            center: Coordinate(latitude: 0, longitude: 0),
            defaultSpanKm: 8,
            countryCode: countryCode
        )
    }

    @MainActor
    func test_CityService_pinnedCityOutranksGeocodedCity() throws {
        let (service, prefs) = try makeCityService()
        let geocoded = makeCity(name: "Tallinn", countryCode: "EE")
        prefs.lastDynamicCity = geocoded
        let pinned = makeCity(name: "Porto", countryCode: "PT")

        service.setActiveCity(pinned)

        XCTAssertTrue(service.isCityPinned)
        XCTAssertEqual(service.activeCity.id, pinned.id)
    }

    @MainActor
    func test_CityService_unpinRestoresGeocodedCity() throws {
        let (service, _) = try makeCityService()
        let pinned = makeCity(name: "Porto", countryCode: "PT")
        service.setActiveCity(pinned)
        let epochBefore = service.citySelectionEpoch

        service.unpinCity()

        XCTAssertFalse(service.isCityPinned)
        // No geocoded city yet, so the pick survives as the most recent city —
        // but the pin is gone, so the next GPS fix is free to take over.
        XCTAssertEqual(service.citySelectionEpoch, epochBefore)
    }

    @MainActor
    func test_CityService_pinSurvivesRelaunch() throws {
        let suiteName = "citisen.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let firstPrefs = UserPreferencesService(defaults: defaults)
        firstPrefs.lastDynamicCity = makeCity(name: "Tallinn", countryCode: "EE")
        let pinned = makeCity(name: "Porto", countryCode: "PT")
        CityService(prefs: firstPrefs).setActiveCity(pinned)

        // Cold start: a fresh prefs + service reading the same defaults.
        let relaunched = CityService(prefs: UserPreferencesService(defaults: defaults))
        XCTAssertTrue(relaunched.isCityPinned)
        XCTAssertEqual(relaunched.activeCity.id, pinned.id)
    }

    func test_AppConfig_searchTextFieldMask_containsAllFieldsRead() {
        let mask = AppConfig.Endpoints.searchTextFieldMask
        let required = [
            "places.id",
            "places.displayName",
            "places.formattedAddress",
            "places.location",
            "places.rating",
            "places.userRatingCount",
            "places.priceLevel",
            "places.types",
            "places.regularOpeningHours",
            "places.currentOpeningHours",
            "places.websiteUri",
            "places.nationalPhoneNumber",
            "places.internationalPhoneNumber",
            "places.reviews",
            "places.editorialSummary",
            "places.photos"
        ]
        for path in required {
            XCTAssertTrue(
                mask.contains(path),
                "searchTextFieldMask is missing required field path: \(path)"
            )
        }
    }
}
