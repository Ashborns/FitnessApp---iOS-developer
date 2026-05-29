import Foundation
import Security

/// A lightweight wrapper around the iOS Keychain for secure token storage.
/// Uses `kSecClassGenericPassword` with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` accessibility.
struct KeychainWrapper {

    /// Saves a string value to the Keychain for the given key.
    /// Uses a delete-before-insert pattern to handle updates.
    /// - Parameters:
    ///   - key: The account identifier for the Keychain item.
    ///   - value: The string value to store.
    /// - Returns: `true` if the save succeeded, `false` otherwise.
    @discardableResult
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]

        // Delete any existing item for this key before inserting
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Loads a string value from the Keychain for the given key.
    /// - Parameter key: The account identifier for the Keychain item.
    /// - Returns: The stored string value, or `nil` if no item exists or the read fails.
    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }

        return string
    }

    /// Deletes the Keychain item for the given key.
    /// - Parameter key: The account identifier for the Keychain item.
    /// - Returns: `true` if the item was removed or did not exist, `false` on unexpected error.
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
