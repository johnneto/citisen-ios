import SwiftUI

struct ContentView: View {
    @State private var selectedPlace: Place?

    var body: some View {
        NavigationStack {
            VStack {
                Text("Welcome to the Ticket Manager!")
                    .font(.title)
                    .padding()

                Button("Show Place Details") {
                    selectedPlace = Place(
                        id: UUID(),
                        cityId: "rome",
                        name: "Colosseum",
                        category: "Historic",
                        mode: .history,
                        coordinate: Coordinate(latitude: 41.8902, longitude: 12.4924),
                        rating: 4.5,
                        reviewCount: 10000,
                        priceLevel: 2,
                        description: "An ancient amphitheatre in the center of the city of Rome, Italy.",
                        tags: ["historic", "ancient", "rome"],
                        openingHours: OpeningHours(),
                        isOpenNow: true,
                        closesAt: nil,
                        reviews: [],
                        address: "Piazza del Colosseo, 1, 00184 Roma RM, Italy",
                        website: URL(string: "https://www.colosseo.it/"),
                        phone: nil
                    )
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Home")
            .overlay {
                if let place = selectedPlace {
                    PlaceDetailOverlay(
                        place: place,
                        isShowing: Binding(
                            get: { selectedPlace != nil },
                            set: { if !$0 { selectedPlace = nil } }
                        )
                    )
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .animation(.default, value: selectedPlace)
        }
    }
}

#Preview {
    ContentView()
}
