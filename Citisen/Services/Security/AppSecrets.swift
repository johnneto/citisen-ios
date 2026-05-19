import Foundation

struct AppSecrets {
    let pairs: [(key: String, value: String)]

    static func fromBundle(_ bundle: Bundle = .main) -> AppSecrets {
        let keys = [AppConfig.Secrets.geminiKey, AppConfig.Secrets.googlePlacesKey]
        let pairs: [(String, String)] = keys.compactMap { key in
            guard let raw = bundle.object(forInfoDictionaryKey: key) as? String else {
                return (key, "")
            }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("$(") { return (key, "") }
            return (key, trimmed)
        }
        return AppSecrets(pairs: pairs)
    }

    var hasAnyKey: Bool {
        pairs.contains { !$0.value.isEmpty }
    }
}
