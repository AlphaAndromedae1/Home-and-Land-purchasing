import Foundation
import Security

protocol SecretStorage {
    func read() -> String?
    func write(_ value: String) -> Bool
    func delete()
}

/// Stores one secret in the iOS Keychain.
struct KeychainSecretStorage: SecretStorage {
    static let service = "com.alphaandromedae1.homeland"
    let account: String

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
    }

    func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func write(_ value: String) -> Bool {
        delete()
        var attributes = baseQuery
        attributes[kSecValueData as String] = Data(value.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

/// The user's Brave Search API key, which turns on in-app listing results.
final class SearchKeyStore: ObservableObject {
    @Published private(set) var apiKey: String?

    private let storage: any SecretStorage

    init(storage: any SecretStorage = KeychainSecretStorage(account: "brave-search-api-key")) {
        self.storage = storage
        let saved = storage.read()?.trimmed ?? ""
        apiKey = saved.isEmpty ? nil : saved
    }

    var hasKey: Bool {
        apiKey != nil
    }

    @discardableResult
    func save(_ key: String) -> Bool {
        let cleaned = key.trimmed
        guard !cleaned.isEmpty, storage.write(cleaned) else { return false }
        apiKey = cleaned
        return true
    }

    func remove() {
        storage.delete()
        apiKey = nil
    }
}
