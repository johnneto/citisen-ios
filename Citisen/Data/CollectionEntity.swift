import Foundation
import SwiftData

@Model
final class CollectionEntity {
    @Attribute(.unique)
    var id: UUID
    var name: String
    var cityId: String
    var cityName: String
    var countryName: String
    var colorHexes: [String]
    var iconSymbol: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \SavedSpotEntity.collection)
    var spots: [SavedSpotEntity] = []

    init(
        id: UUID = UUID(),
        name: String,
        cityId: String,
        cityName: String,
        countryName: String,
        colorHexes: [String] = ["C8975A", "D4695E", "4A8C6F"],
        iconSymbol: String = "bookmark.fill"
    ) {
        self.id = id
        self.name = name
        self.cityId = cityId
        self.cityName = cityName
        self.countryName = countryName
        self.colorHexes = colorHexes
        self.iconSymbol = iconSymbol
        self.createdAt = Date()
    }
}
