import CryptoKit
import Dependencies
import Foundation

enum AppLockError: Error, LocalizedError, Equatable, Sendable {
    case invalidPinFormat
    case pinNotConfigured
    case incorrectCurrentPin

    var errorDescription: String? {
        switch self {
        case .invalidPinFormat:
            return "PIN must contain exactly 4 digits."
        case .pinNotConfigured:
            return "PIN is not configured yet."
        case .incorrectCurrentPin:
            return "Current PIN is incorrect."
        }
    }
}

struct AppLockService: Sendable {
    var isPinConfigured: @Sendable () -> Bool
    var setInitialPin: @Sendable (_ pin: String) throws -> Void
    var verifyPin: @Sendable (_ pin: String) -> Bool
    var changePin: @Sendable (_ currentPin: String, _ newPin: String) throws -> Void
    var isFaceIDAvailable: @Sendable () -> Bool
    var isFaceIDEnabled: @Sendable () -> Bool
    var setFaceIDEnabled: @Sendable (_ isEnabled: Bool) throws -> Void
    var authenticateWithFaceID: @Sendable () async -> Bool
}

extension AppLockService {
    static func live(
        keychainService: KeychainService,
        biometricAuthService: BiometricAuthService
    ) -> AppLockService {
        AppLockService(
            isPinConfigured: {
                guard let hash = try? keychainService.loadAppLockPinHash() else {
                    return false
                }
                return !hash.isEmpty
            },
            setInitialPin: { pin in
                guard Self.isValid(pin: pin) else {
                    throw AppLockError.invalidPinFormat
                }
                try keychainService.saveAppLockPinHash(Self.hash(pin: pin))
                try keychainService.saveAppLockPinInitialized(true)
            },
            verifyPin: { pin in
                guard Self.isValid(pin: pin),
                      let savedHash = try? keychainService.loadAppLockPinHash() else {
                    return false
                }
                return savedHash == Self.hash(pin: pin)
            },
            changePin: { currentPin, newPin in
                guard Self.isValid(pin: currentPin), Self.isValid(pin: newPin) else {
                    throw AppLockError.invalidPinFormat
                }
                guard let savedHash = try keychainService.loadAppLockPinHash() else {
                    throw AppLockError.pinNotConfigured
                }
                guard savedHash == Self.hash(pin: currentPin) else {
                    throw AppLockError.incorrectCurrentPin
                }
                try keychainService.saveAppLockPinHash(Self.hash(pin: newPin))
                try keychainService.saveAppLockPinInitialized(true)
            },
            isFaceIDAvailable: {
                biometricAuthService.isFaceIDAvailable()
            },
            isFaceIDEnabled: {
                guard biometricAuthService.isFaceIDAvailable() else {
                    return false
                }
                return (try? keychainService.loadAppLockFaceIDEnabled()) ?? true
            },
            setFaceIDEnabled: { isEnabled in
                let valueToSave = biometricAuthService.isFaceIDAvailable() ? isEnabled : false
                try keychainService.saveAppLockFaceIDEnabled(valueToSave)
            },
            authenticateWithFaceID: {
                guard biometricAuthService.isFaceIDAvailable() else {
                    return false
                }
                return await biometricAuthService.authenticate("Unlock RTK Pass")
            }
        )
    }

    static func isValid(pin: String) -> Bool {
        pin.count == 4 && pin.allSatisfy(\.isNumber)
    }

    static func hash(pin: String) -> String {
        let digest = SHA256.hash(data: Data(pin.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension AppLockService: DependencyKey {
    static let liveValue = AppLockService.live(keychainService: .liveValue, biometricAuthService: .liveValue)
    static let testValue = AppLockService(
        isPinConfigured: { false },
        setInitialPin: { _ in },
        verifyPin: { _ in false },
        changePin: { _, _ in },
        isFaceIDAvailable: { false },
        isFaceIDEnabled: { false },
        setFaceIDEnabled: { _ in },
        authenticateWithFaceID: { false }
    )
}

extension DependencyValues {
    var appLockService: AppLockService {
        get { self[AppLockService.self] }
        set { self[AppLockService.self] = newValue }
    }
}
