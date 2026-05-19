import Foundation
import OSLog
import Security

final class KeychainService {
    static let shared = KeychainService()

    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "app.citisen") {
        self.service = service
    }

    func read(_ key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func write(_ value: String, for key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query = baseQuery(for: key)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus != errSecItemNotFound {
            AppLog.app.error("Keychain update failed for \(key, privacy: .public): \(updateStatus)")
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess {
            AppLog.app.error("Keychain add failed for \(key, privacy: .public): \(addStatus)")
            return false
        }
        return true
    }

    @discardableResult
    func delete(_ key: String) -> Bool {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    func bootstrap(from secrets: AppSecrets) {
        for (key, value) in secrets.pairs {
            guard !value.isEmpty else { continue }
            if read(key) == value { continue }
            write(value, for: key)
        }
    }

    func requireString(_ key: String) throws -> String {
        guard let value = read(key), !value.isEmpty else {
            throw SpotsError.missingAPIKey(key)
        }
        return value
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
