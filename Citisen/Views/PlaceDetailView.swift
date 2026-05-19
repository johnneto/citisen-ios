import SwiftUI

struct PlaceDetailView: View {
    let place: Place

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(place.name)
                .font(.largeTitle)
                .bold()
                .foregroundStyle(.primary)

            Text(place.description)
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    PlaceDetailView(
        place: Place(
            id: UUID(),
            cityId: "paris",
            name: "Eiffel Tower",
            category: "Landmark",
            mode: .history,
            coordinate: Coordinate(latitude: 48.8584, longitude: 2.2945),
            rating: 4.8,
            reviewCount: 1500,
            priceLevel: 2,
            description: "The Eiffel Tower is a wrought-iron lattice tower on the Champ de Mars in Paris, France.",
            tags: ["landmark", "historic"],
            openingHours: OpeningHours(),
            isOpenNow: true,
            closesAt: "23:00",
            reviews: [],
            address: "5 Avenue Anatole France, 75007 Paris, France",
            website: URL(string: "https://www.toureiffel.paris"),
            phone: "+33 1 45 55 75 61"
        )
    )
}
