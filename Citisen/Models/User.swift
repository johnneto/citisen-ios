import Foundation

struct UserProfile: Codable, Hashable {
    var displayName: String
    var handle: String
    var email: String
    var homeCityId: String?

    var initials: String {
        displayName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
    }

    static let placeholder = UserProfile(
        displayName: "Alex Keeler",
        handle: "alex",
        email: "alex@citisen.app",
        homeCityId: City.tallinn.id
    )
}
