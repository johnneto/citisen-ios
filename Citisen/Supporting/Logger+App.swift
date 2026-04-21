import Foundation
import OSLog

enum AppLog {
    private static let subsystem = "app.citisen"

    static let app      = Logger(subsystem: subsystem, category: "app")
    static let nav      = Logger(subsystem: subsystem, category: "navigation")
    static let map      = Logger(subsystem: subsystem, category: "map")
    static let location = Logger(subsystem: subsystem, category: "location")
    static let data     = Logger(subsystem: subsystem, category: "data")
    static let prefs    = Logger(subsystem: subsystem, category: "prefs")
    static let ai       = Logger(subsystem: subsystem, category: "ai")
    static let places   = Logger(subsystem: subsystem, category: "places")
    static let analytics = Logger(subsystem: subsystem, category: "analytics")
}
