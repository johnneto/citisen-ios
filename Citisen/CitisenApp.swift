import SwiftData
import SwiftUI

@main
struct CitisenApp: App {
    @State private var prefs = UserPreferencesService()
    @State private var location = LocationService()
    @State private var router = AppRouter()
    @State private var places = MockPlacesService()
    @State private var analytics = AnalyticsService()

    private let modelContainer: ModelContainer = {
        MainActor.assumeIsolated {
            AppModelSchema.makeContainer()
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(prefs)
                .environment(location)
                .environment(router)
                .environment(places)
                .environment(CityService(prefs: prefs))
                .environment(analytics)
        }
        .modelContainer(modelContainer)
    }
}
