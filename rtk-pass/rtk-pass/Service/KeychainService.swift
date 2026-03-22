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
    static let appLockPinHash = "lock.pinHash"
    static let appLockPinInitialized = "lock.pinInitialized"
    static let appLockFaceIDEnabled = "lock.faceIDEnabled"
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

extension KeychainService {
    func saveAppLockPinHash(_ value: String) throws {
        try save(value, KeychainKey.appLockPinHash)
    }

    func loadAppLockPinHash() throws -> String? {
        try load(KeychainKey.appLockPinHash)
    }

    func saveAppLockPinInitialized(_ isInitialized: Bool) throws {
        try save(isInitialized ? "1" : "0", KeychainKey.appLockPinInitialized)
    }

    func loadAppLockPinInitialized() throws -> Bool {
        (try load(KeychainKey.appLockPinInitialized)) == "1"
    }

    func saveAppLockFaceIDEnabled(_ isEnabled: Bool) throws {
        try save(isEnabled ? "1" : "0", KeychainKey.appLockFaceIDEnabled)
    }

    func loadAppLockFaceIDEnabled() throws -> Bool? {
        guard let value = try load(KeychainKey.appLockFaceIDEnabled) else {
            return nil
        }
        return value == "1"
    }
}
