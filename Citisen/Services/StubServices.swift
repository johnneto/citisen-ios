import Foundation
import Observation
import os

@Observable
final class AnalyticsService {
    func track(_ event: String, properties: [String: String] = [:]) {
        AppLog.analytics.debug("event: \(event, privacy: .public) \(properties)")
    }
}

final class CrashReportingService {
    func report(_ error: Error, message: String? = nil) {
        AppLog.analytics.error("crash-report: \(message ?? "", privacy: .public) \(error.localizedDescription)")
    }
}
