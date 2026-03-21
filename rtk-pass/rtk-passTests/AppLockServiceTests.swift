import XCTest
@testable import rtk_pass

final class AppLockServiceTests: XCTestCase {
    func testSetInitialPinAndVerifyPin() throws {
        let keychain = InMemoryKeychainService()
        let biometric = BiometricAuthService(
            isFaceIDAvailable: { true },
            authenticate: { _ in true }
        )
        let service = AppLockService.live(keychainService: keychain.service, biometricAuthService: biometric)

        XCTAssertFalse(service.isPinConfigured())
        try service.setInitialPin("1234")

        XCTAssertTrue(service.isPinConfigured())
        XCTAssertTrue(service.verifyPin("1234"))
        XCTAssertFalse(service.verifyPin("1111"))
    }

    func testChangePinRequiresCorrectCurrentPin() throws {
        let keychain = InMemoryKeychainService()
        let biometric = BiometricAuthService(
            isFaceIDAvailable: { false },
            authenticate: { _ in false }
        )
        let service = AppLockService.live(keychainService: keychain.service, biometricAuthService: biometric)

        try service.setInitialPin("1234")

        XCTAssertThrowsError(try service.changePin("0000", "5678"))
        XCTAssertTrue(service.verifyPin("1234"))

        try service.changePin("1234", "5678")
        XCTAssertFalse(service.verifyPin("1234"))
        XCTAssertTrue(service.verifyPin("5678"))
    }

    func testFaceIDDefaultEnabledAndCanBeUpdated() throws {
        let keychain = InMemoryKeychainService()
        let biometric = BiometricAuthService(
            isFaceIDAvailable: { true },
            authenticate: { _ in true }
        )
        let service = AppLockService.live(keychainService: keychain.service, biometricAuthService: biometric)

        XCTAssertTrue(service.isFaceIDEnabled())
        try service.setFaceIDEnabled(false)
        XCTAssertFalse(service.isFaceIDEnabled())
    }
}

private final class InMemoryKeychainService {
    private var storage: [String: String]

    init(initialValues: [String: String] = [:]) {
        storage = initialValues
    }

    var service: KeychainService {
        KeychainService(
            save: { [weak self] value, key in
                self?.storage[key] = value
            },
            load: { [weak self] key in
                self?.storage[key]
            },
            remove: { [weak self] key in
                self?.storage.removeValue(forKey: key)
            }
        )
    }
}
