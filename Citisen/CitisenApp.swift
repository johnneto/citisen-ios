import OSLog
import SwiftData
import SwiftUI

@main
struct CitisenApp: App {
    @State private var prefs: UserPreferencesService
    @State private var location = LocationService()
    @State private var router = AppRouter()
    @State private var places = CitisenApp.makePlacesService()
    @State private var analytics = AnalyticsService()
    @State private var cityService: CityService

    private let modelContainer: ModelContainer = {
        MainActor.assumeIsolated {
            AppModelSchema.makeContainer()
        }
    }()

    init() {
        KeychainService.shared.bootstrap(from: AppSecrets.fromBundle())
        let prefs = UserPreferencesService()
        _prefs = State(initialValue: prefs)
        _cityService = State(initialValue: CityService(prefs: prefs))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(prefs)
                .environment(location)
                .environment(router)
                .environment(places)
                .environment(cityService)
                .environment(analytics)
        }
        .modelContainer(modelContainer)
    }

    private static func makePlacesService() -> PlacesService {
        let backend: any PlacesBackend
        if FeatureFlags.aiCurationEnabled, FeatureFlags.googlePlacesEnabled {
            backend = RemotePlacesBackend()
            AppLog.app.debug("Using RemotePlacesBackend")
        } else {
            backend = MockPlacesBackend()
            AppLog.app.debug("Using MockPlacesBackend (feature flags off)")
        }
        return MainActor.assumeIsolated {
            PlacesService(backend: backend)
        }
    }
}
