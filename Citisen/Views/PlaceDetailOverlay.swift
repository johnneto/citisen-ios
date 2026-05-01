import SwiftUI

struct PlaceDetailOverlay: View {
    let place: Place
    @Binding var isShowing: Bool

    var body: some View {
        ZStack {
            // Background to dismiss on tap
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isShowing = false
                }

            // The actual detail content card
            PlaceDetailView(place: place)
                .background(.background)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(radius: 10)
                .padding(40) // Padding around the detail card
                .onTapGesture {
                    // This empty gesture prevents taps on the detail card itself
                    // from dismissing the overlay. SwiftUI's gesture system
                    // prioritizes child gestures.
                }
        }
    }
}

#Preview {
    @Previewable @State var isShowing = true
    PlaceDetailOverlay(
        place: Place(
            id: UUID(),
            cityId: "rome",
            name: "Colosseum",
            category: "Landmark",
            mode: .history,
            coordinate: Coordinate(latitude: 41.8902, longitude: 12.4924),
            rating: 4.7,
            reviewCount: 2000,
            priceLevel: 1,
            description: "An ancient amphitheatre in the center of the city of Rome, Italy.",
            tags: ["landmark", "historic", "ancient"],
            openingHours: OpeningHours(),
            isOpenNow: true,
            closesAt: "19:00",
            reviews: [],
            address: "Piazza del Colosseo, 1, 00184 Rome, Italy",
            website: URL(string: "https://www.colosseum.it"),
            phone: "+39 06 3996 7700"
        ),
        isShowing: $isShowing
    )
}
