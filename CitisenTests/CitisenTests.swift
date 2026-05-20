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
