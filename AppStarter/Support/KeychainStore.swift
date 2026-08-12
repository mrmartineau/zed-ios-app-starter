import Foundation
import Security

/// Minimal Keychain wrapper for small secrets, used here to hold a development
/// API key out of `UserDefaults` (which is plain-text in the app container).
///
/// The Keychain raises the bar but does not make a secret safe on a device you
/// don't control: anyone with the device can read an app's Keychain items on a
/// jailbroken phone, and `kSecAttrAccessibleAfterFirstUnlock` is required for
/// background access. Treat this as "not casually readable", not "secret".
enum KeychainStore {
    /// Reads a UTF-8 string previously stored under `key`.
    static func string(for key: String) -> String? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }

        return String(data: data, encoding: .utf8)
    }

    /// Stores `value` under `key`, replacing anything already there.
    /// Passing `nil` deletes the item.
    @discardableResult
    static func set(_ value: String?, for key: String) -> Bool {
        let query = baseQuery(for: key)

        // Delete-then-add rather than SecItemUpdate: it's one code path for
        // both "first write" and "overwrite", and the delete is a no-op when
        // nothing is stored.
        SecItemDelete(query as CFDictionary)

        guard let data = value?.data(using: .utf8), !data.isEmpty else {
            return true
        }

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
    }

    private static func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Bundle.main.bundleIdentifier ?? "AppStarter",
            kSecAttrAccount as String: key,
        ]
    }
}
