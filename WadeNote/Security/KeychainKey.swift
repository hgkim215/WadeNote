import CryptoKit
import Security
import Foundation

enum KeychainKey {
    static func loadOrCreateSymmetricKey(tag: String) throws -> SymmetricKey {
        if let existing = try load(tag: tag) { return existing }
        let key = SymmetricKey(size: .bits256)
        try store(key, tag: tag)
        return key
    }

    private static func load(tag: String) throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tag,
            kSecReturnData as String: true
        ]
        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = out as? Data else {
            throw NSError(domain: "Keychain", code: Int(status))
        }
        return SymmetricKey(data: data)
    }

    private static func store(_ key: SymmetricKey, tag: String) throws {
        let data = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tag,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "Keychain", code: Int(status))
        }
    }
}
