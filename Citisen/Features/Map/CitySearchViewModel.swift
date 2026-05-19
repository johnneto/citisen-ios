import Foundation
import Observation
import os

@MainActor
@Observable
final class CitySearchViewModel {
    var query: String = "" {
        didSet {
            guard oldValue != query else { return }
            scheduleSearch()
        }
    }
    private(set) var predictions: [CityPrediction] = []
    private(set) var isLoading: Bool = false
    private(set) var errorMessage: String?

    private let client: GooglePlacesClient
    private var sessionToken: String = UUID().uuidString
    private var searchTask: Task<Void, Never>?
    private let debounce: UInt64

    init(
        client: GooglePlacesClient = GooglePlacesClient(),
        debounceMs: Int = AppConfig.CitySearch.debounceMilliseconds
    ) {
        self.client = client
        self.debounce = UInt64(max(0, debounceMs)) * 1_000_000
    }

    /// Resolves a tapped prediction to a full `City`. Reuses the autocomplete
    /// session token so Google bills both calls under the same session, then
    /// rotates the token for the next search.
    func resolve(_ prediction: CityPrediction) async -> City? {
        do {
            guard let details = try await client.cityDetails(
                placeId: prediction.placeId,
                sessionToken: sessionToken
            ) else { return nil }
            sessionToken = UUID().uuidString
            return CityMapper.makeCity(from: details, fallbackName: prediction.primaryText)
        } catch {
            AppLog.places.error("cityDetails failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Couldn't load that city. Try again."
            return nil
        }
    }

    func clear() {
        searchTask?.cancel()
        query = ""
        predictions = []
        isLoading = false
        errorMessage = nil
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let snapshot = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !snapshot.isEmpty else {
            predictions = []
            isLoading = false
            errorMessage = nil
            return
        }

        searchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            if self.debounce > 0 {
                try? await Task.sleep(nanoseconds: self.debounce)
            }
            if Task.isCancelled { return }
            self.isLoading = true
            self.errorMessage = nil
            do {
                let results = try await self.client.autocompleteCities(
                    query: snapshot,
                    sessionToken: self.sessionToken
                )
                if Task.isCancelled { return }
                self.predictions = results
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                AppLog.places.error("autocompleteCities failed: \(error.localizedDescription, privacy: .public)")
                self.predictions = []
                self.errorMessage = "Search failed. Try again."
            }
            if !Task.isCancelled {
                self.isLoading = false
            }
        }
    }
}
