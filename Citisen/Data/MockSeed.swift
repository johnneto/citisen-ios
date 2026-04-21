import Foundation

enum MockSeed {
    // Deterministic UUID from a string hash so previews and saves are stable.
    static func deterministicUUID(from string: String) -> UUID {
        var hasher = Hasher()
        hasher.combine(string)
        let seed = UInt64(bitPattern: Int64(hasher.finalize()))
        let upper = seed
        let lower = seed &* 0x9E37_79B9_7F4A_7C15
        return UUID(uuid: (
            UInt8((upper >> 56) & 0xFF),
            UInt8((upper >> 48) & 0xFF),
            UInt8((upper >> 40) & 0xFF),
            UInt8((upper >> 32) & 0xFF),
            UInt8((upper >> 24) & 0xFF),
            UInt8((upper >> 16) & 0xFF),
            UInt8((upper >> 8) & 0xFF),
            UInt8(upper & 0xFF),
            UInt8((lower >> 56) & 0xFF),
            UInt8((lower >> 48) & 0xFF),
            UInt8((lower >> 40) & 0xFF),
            UInt8((lower >> 32) & 0xFF),
            UInt8((lower >> 24) & 0xFF),
            UInt8((lower >> 16) & 0xFF),
            UInt8((lower >> 8) & 0xFF),
            UInt8(lower & 0xFF)
        ))
    }

    static let sampleReviews: [Review] = [
        Review(
            id: deterministicUUID(from: "review-1"),
            authorName: "Maarja",
            rating: 5,
            daysAgo: 2,
            text: "Extraordinary — book ahead, the small room fills up fast."
        ),
        Review(
            id: deterministicUUID(from: "review-2"),
            authorName: "Tim",
            rating: 4,
            daysAgo: 5,
            text: "Warm, atmospheric. Service a little slow but worth it."
        ),
        Review(
            id: deterministicUUID(from: "review-3"),
            authorName: "Henrik",
            rating: 5,
            daysAgo: 11,
            text: "Hidden gem — locals know, tourists usually miss it."
        )
    ]

    static let allPlaces: [Place] = {
        tallinnPlaces + tartuPlaces + helsinkiPlaces + rigaPlaces
    }()

    static func places(for city: City) -> [Place] {
        allPlaces.filter { $0.cityId == city.id }
    }

    static func places(for city: City, mode: TravelMode) -> [Place] {
        let filtered = places(for: city)
        if mode == .standard { return filtered }
        return filtered.filter { $0.mode == mode }
    }
}
