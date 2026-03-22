import XCTest
@testable import rtk_pass

final class AuthRepositoryTests: XCTestCase {
    func testLoginStoresTokenAndReturnsSession() async throws {
        let keychain = InMemoryKeychainService()
        let authService = AuthService(
            login: { login, _ in
                XCTAssertEqual(login, "john")
                return AuthToken(accessToken: "access-1", refreshToken: "refresh-1", tokenType: "bearer")
            },
            me: { token in
                XCTAssertEqual(token, "access-1")
                return AuthUser(id: 7, fullName: "John", email: "john@example.com", login: "john", role: .employee)
            },
            logout: { _ in },
            refresh: { _ in
                AuthToken(accessToken: "access-2", refreshToken: "refresh-2", tokenType: "bearer")
            }
        )

        let repository = AuthRepository.live(authService: authService, keychainService: keychain.service)

        let session = try await repository.login("john", "secret123")

        XCTAssertEqual(session.user.login, "john")
        XCTAssertEqual(session.token.accessToken, "access-1")
        XCTAssertEqual(try keychain.loadValue(for: KeychainKey.accessToken), "access-1")
        XCTAssertEqual(try keychain.loadValue(for: KeychainKey.refreshToken), "refresh-1")
    }

    func testRestoreSessionWithSavedTokenReturnsAuthenticatedSession() async throws {
        let keychain = InMemoryKeychainService(initialValues: [KeychainKey.accessToken: "access-token"])
        let authService = AuthService(
            login: { _, _ in fatalError("unused") },
            me: { token in
                XCTAssertEqual(token, "access-token")
                return AuthUser(id: 1, fullName: "Jane", email: "jane@example.com", login: "jane", role: .admin)
            },
            logout: { _ in },
            refresh: { _ in fatalError("unused") }
        )

        let repository = AuthRepository.live(authService: authService, keychainService: keychain.service)

        let restored = await repository.restoreSession()

        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.user.login, "jane")
    }

    func testLogoutClearsSavedTokens() async throws {
        let keychain = InMemoryKeychainService(initialValues: [
            KeychainKey.accessToken: "access-token",
            KeychainKey.refreshToken: "refresh-token"
        ])
        let authService = AuthService(
            login: { _, _ in fatalError("unused") },
            me: { _ in fatalError("unused") },
            logout: { _ in },
            refresh: { _ in fatalError("unused") }
        )

        let repository = AuthRepository.live(authService: authService, keychainService: keychain.service)

        let session = AuthSession(
            token: AuthToken(accessToken: "access-token", refreshToken: "refresh-token", tokenType: "bearer"),
            user: AuthUser(id: 1, fullName: "Jane", email: "jane@example.com", login: "jane", role: .admin)
        )

        await repository.logout(session)

        XCTAssertNil(try keychain.loadValue(for: KeychainKey.accessToken))
        XCTAssertNil(try keychain.loadValue(for: KeychainKey.refreshToken))
    }

    func testRefreshWithoutRefreshTokenThrows() async {
        let keychain = InMemoryKeychainService()
        let authService = AuthService(
            login: { _, _ in fatalError("unused") },
            me: { _ in fatalError("unused") },
            logout: { _ in },
            refresh: { _ in fatalError("unused") }
        )

        let repository = AuthRepository.live(authService: authService, keychainService: keychain.service)
        let session = AuthSession(
            token: AuthToken(accessToken: "access-token", refreshToken: nil, tokenType: "bearer"),
            user: AuthUser(id: 1, fullName: "Jane", email: "jane@example.com", login: "jane", role: .admin)
        )

        do {
            _ = try await repository.refreshSession(session)
            XCTFail("Expected refresh unavailable error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .refreshUnavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchProfileCallsMeWithToken() async throws {
        let keychain = InMemoryKeychainService()
        let authService = AuthService(
            login: { _, _ in fatalError("unused") },
            me: { token in
                XCTAssertEqual(token, "my-access")
                return AuthUser(id: 42, fullName: "Alex", email: "alex@example.com", login: "alex", role: .employee)
            },
            logout: { _ in },
            refresh: { _ in fatalError("unused") }
        )

        let repository = AuthRepository.live(authService: authService, keychainService: keychain.service)

        let user = try await repository.fetchProfile("my-access")

        XCTAssertEqual(user.id, 42)
        XCTAssertEqual(user.login, "alex")
        XCTAssertEqual(user.role, .employee)
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

    func loadValue(for key: String) throws -> String? {
        storage[key]
    }
}
