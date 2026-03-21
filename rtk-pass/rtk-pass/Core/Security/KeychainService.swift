import Dependencies
import Foundation
import Security

struct KeychainService: Sendable {
    var save: @Sendable (_ value: String, _ key: String) throws -> Void
    var load: @Sendable (_ key: String) throws -> String?
    var remove: @Sendable (_ key: String) throws -> Void
}

enum KeychainKey {
    static let accessToken = "auth.accessToken"
    static let refreshToken = "auth.refreshToken"
}

extension KeychainService {
    static let liveValue = KeychainService(
        save: { value, key in
            let data = Data(value.utf8)
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: data
            ]

            SecItemDelete(query as CFDictionary)
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw AuthError.secureStorageFailure
            }
        },
        load: { key in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]

            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecItemNotFound {
                return nil
            }
            guard status == errSecSuccess,
                  let data = result as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                throw AuthError.secureStorageFailure
            }
            return value
        },
        remove: { key in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]

            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw AuthError.secureStorageFailure
            }
        }
    )

    static let testValue = KeychainService(
        save: { _, _ in },
        load: { _ in nil },
        remove: { _ in }
    )
}

extension KeychainService: DependencyKey {}

extension DependencyValues {
    var keychainService: KeychainService {
        get { self[KeychainService.self] }
        set { self[KeychainService.self] = newValue }
    }
}
