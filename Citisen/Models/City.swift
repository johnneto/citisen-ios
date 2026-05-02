import CoreLocation
import Foundation

struct City: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let country: String
    let emojiFlag: String
    let center: Coordinate
    let defaultSpanKm: Double

    var displayName: String {
        "\(name), \(country)"
    }
}

extension City {
    static let tallinn = City(
        id: "tallinn",
        name: "Tallinn",
        country: "Eesti",
        emojiFlag: "🇪🇪",
        center: Coordinate(latitude: 59.4370, longitude: 24.7536),
        defaultSpanKm: 6
    )

    static let tartu = City(
        id: "tartu",
        name: "Tartu",
        country: "Eesti",
        emojiFlag: "🇪🇪",
        center: Coordinate(latitude: 58.3780, longitude: 26.7290),
        defaultSpanKm: 5
    )

    static let helsinki = City(
        id: "helsinki",
        name: "Helsinki",
        country: "Finland",
        emojiFlag: "🇫🇮",
        center: Coordinate(latitude: 60.1699, longitude: 24.9384),
        defaultSpanKm: 8
    )

    static let riga = City(
        id: "riga",
        name: "Riga",
        country: "Latvia",
        emojiFlag: "🇱🇻",
        center: Coordinate(latitude: 56.9496, longitude: 24.1052),
        defaultSpanKm: 7
    )

    static let all: [City] = [.tallinn, .tartu, .helsinki, .riga]
}
