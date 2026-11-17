import Foundation
import Security

/// Where the purchased exports are kept. A protocol so tests can use memory.
protocol ExportEntitlementStorage: AnyObject {
    func load() -> Data?
    func save(_ data: Data)
}

/// Keeps data in memory only. For tests.
final class InMemoryExportStorage: ExportEntitlementStorage {
    private var data: Data?
    init(data: Data? = nil) { self.data = data }
    func load() -> Data? { data }
    func save(_ data: Data) { self.data = data }
}

/// Plain UserDefaults storage.
final class DefaultsExportStorage: ExportEntitlementStorage {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String) {
        self.defaults = defaults
        self.key = key
    }

    func load() -> Data? { defaults.data(forKey: key) }
    func save(_ data: Data) { defaults.set(data, forKey: key) }
}

/// Keychain storage. Unlike app data, a keychain item normally survives deleting and reinstalling the app,
/// so a person who bought exports does not lose them.
final class KeychainExportStorage: ExportEntitlementStorage {
    private let service: String
    private let account: String

    init(service: String, account: String) {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    func load() -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func save(_ data: Data) {
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

/// Writes to both stores and reads the first one that has data, so one failing store never loses purchases.
final class MirroredExportStorage: ExportEntitlementStorage {
    private let primary: ExportEntitlementStorage
    private let secondary: ExportEntitlementStorage

    init(primary: ExportEntitlementStorage, secondary: ExportEntitlementStorage) {
        self.primary = primary
        self.secondary = secondary
    }

    func load() -> Data? { primary.load() ?? secondary.load() }

    func save(_ data: Data) {
        primary.save(data)
        secondary.save(data)
    }
}

extension MirroredExportStorage {
    /// What the app uses: Keychain first, UserDefaults as a copy.
    static func standard() -> MirroredExportStorage {
        MirroredExportStorage(
            primary: KeychainExportStorage(service: "com.ecomswift.careerkit.exports", account: "entitlements.v1"),
            secondary: DefaultsExportStorage(key: "ck.exportEntitlements.v1")
        )
    }
}
