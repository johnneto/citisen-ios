import Foundation

extension MockSeed {
    static let tartuPlaces: [Place] = {
        let hours = OpeningHours(
            monday: "11:00–21:00", tuesday: "11:00–21:00", wednesday: "11:00–21:00",
            thursday: "11:00–21:00", friday: "11:00–23:00", saturday: "12:00–23:00",
            sunday: "12:00–20:00"
        )
        return [
            Place(
                id: MockSeed.deterministicUUID(from: "tartu-ahhaa"),
                cityId: City.tartu.id,
                name: "AHHAA Science Centre",
                category: "Science museum",
                mode: .turbo,
                coordinate: Coordinate(latitude: 58.3758, longitude: 26.7227),
                rating: 4.7, reviewCount: 890, priceLevel: 2,
                description: "Hands-on science playground — the fastest way to entertain curious minds.",
                tags: ["Family friendly"],
                openingHours: hours, isOpenNow: true, closesAt: "19:00",
                reviews: MockSeed.sampleReviews,
                address: "Sadama 1, Tartu", website: URL(string: "https://ahhaa.ee"), phone: nil
            ),
            Place(
                id: MockSeed.deterministicUUID(from: "tartu-university"),
                cityId: City.tartu.id,
                name: "University of Tartu",
                category: "Historic university",
                mode: .history,
                coordinate: Coordinate(latitude: 58.3805, longitude: 26.7207),
                rating: 4.6, reviewCount: 512, priceLevel: 0,
                description: "The oldest university in the Nordics — visit the attic-turned-museum.",
                tags: ["Landmark"],
                openingHours: hours, isOpenNow: true, closesAt: "18:00",
                reviews: MockSeed.sampleReviews,
                address: "Ülikooli 18, Tartu", website: nil, phone: nil
            ),
            Place(
                id: MockSeed.deterministicUUID(from: "tartu-werner"),
                cityId: City.tartu.id,
                name: "Café Werner",
                category: "Historic café",
                mode: .cafes,
                coordinate: Coordinate(latitude: 58.3814, longitude: 26.7221),
                rating: 4.5, reviewCount: 302, priceLevel: 1,
                description: "Tartu's oldest café — creamy cakes and slow afternoons.",
                tags: ["Historic"],
                openingHours: hours, isOpenNow: true, closesAt: "22:00",
                reviews: MockSeed.sampleReviews,
                address: "Ülikooli 11, Tartu", website: nil, phone: nil
            )
        ]
    }()

    static let helsinkiPlaces: [Place] = {
        let hours = OpeningHours(
            monday: "10:00–22:00", tuesday: "10:00–22:00", wednesday: "10:00–22:00",
            thursday: "10:00–22:00", friday: "10:00–23:00", saturday: "11:00–23:00",
            sunday: "11:00–21:00"
        )
        return [
            Place(
                id: MockSeed.deterministicUUID(from: "helsinki-oodi"),
                cityId: City.helsinki.id,
                name: "Oodi Library",
                category: "Public library",
                mode: .standard,
                coordinate: Coordinate(latitude: 60.1741, longitude: 24.9381),
                rating: 4.8, reviewCount: 1801, priceLevel: 0,
                description: "A civic landmark — reading nooks, recording studios, and a rooftop terrace.",
                tags: ["Architecture"],
                openingHours: hours, isOpenNow: true, closesAt: "20:00",
                reviews: MockSeed.sampleReviews,
                address: "Töölönlahdenkatu 4, Helsinki",
                website: URL(string: "https://oodihelsinki.fi"), phone: nil
            ),
            Place(
                id: MockSeed.deterministicUUID(from: "helsinki-savotta"),
                cityId: City.helsinki.id,
                name: "Savotta",
                category: "Finnish restaurant",
                mode: .food,
                coordinate: Coordinate(latitude: 60.1701, longitude: 24.9515),
                rating: 4.5, reviewCount: 420, priceLevel: 3,
                description: "Lapland classics in a lodge opposite the cathedral.",
                tags: ["Reservations"],
                openingHours: hours, isOpenNow: true, closesAt: "23:00",
                reviews: MockSeed.sampleReviews,
                address: "Aleksanterinkatu 22, Helsinki", website: nil, phone: nil
            ),
            Place(
                id: MockSeed.deterministicUUID(from: "helsinki-suomenlinna"),
                cityId: City.helsinki.id,
                name: "Suomenlinna",
                category: "Sea fortress",
                mode: .history,
                coordinate: Coordinate(latitude: 60.1455, longitude: 24.9881),
                rating: 4.8, reviewCount: 3290, priceLevel: 0,
                description: "UNESCO-listed island fortress, accessible by a short ferry ride.",
                tags: ["UNESCO", "Walk"],
                openingHours: hours, isOpenNow: true, closesAt: nil,
                reviews: MockSeed.sampleReviews,
                address: "Suomenlinna, Helsinki", website: nil, phone: nil
            )
        ]
    }()

    static let rigaPlaces: [Place] = {
        let hours = OpeningHours(
            monday: "10:00–21:00", tuesday: "10:00–21:00", wednesday: "10:00–21:00",
            thursday: "10:00–21:00", friday: "10:00–23:00", saturday: "11:00–23:00",
            sunday: "11:00–20:00"
        )
        return [
            Place(
                id: MockSeed.deterministicUUID(from: "riga-central"),
                cityId: City.riga.id,
                name: "Central Market",
                category: "Food market",
                mode: .food,
                coordinate: Coordinate(latitude: 56.9449, longitude: 24.1157),
                rating: 4.5, reviewCount: 2210, priceLevel: 1,
                description: "Zeppelin-hangar market stacked with smoked fish, honey, and pickles.",
                tags: ["Local favorite"],
                openingHours: hours, isOpenNow: true, closesAt: "18:00",
                reviews: MockSeed.sampleReviews,
                address: "Nēģu iela 7, Riga", website: nil, phone: nil
            ),
            Place(
                id: MockSeed.deterministicUUID(from: "riga-artnouveau"),
                cityId: City.riga.id,
                name: "Art Nouveau District",
                category: "Architecture walk",
                mode: .art,
                coordinate: Coordinate(latitude: 56.9595, longitude: 24.1069),
                rating: 4.7, reviewCount: 1450, priceLevel: 0,
                description: "One of the world's densest collections of Jugendstil facades.",
                tags: ["Walk", "Photo spot"],
                openingHours: hours, isOpenNow: true, closesAt: nil,
                reviews: MockSeed.sampleReviews,
                address: "Alberta iela, Riga", website: nil, phone: nil
            )
        ]
    }()
}
