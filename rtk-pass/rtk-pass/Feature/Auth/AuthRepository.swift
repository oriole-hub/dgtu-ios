import Dependencies
import Foundation

struct AuthRepository: Sendable {
    var restoreSession: @Sendable () async -> AuthSession?
    var login: @Sendable (_ login: String, _ password: String) async throws -> AuthSession
    var logout: @Sendable (_ session: AuthSession?) async -> Void
    var refreshSession: @Sendable (_ session: AuthSession) async throws -> AuthSession
    var fetchProfile: @Sendable (_ accessToken: String) async throws -> AuthUser
}

extension AuthRepository {
    static func live(authService: AuthService, keychainService: KeychainService) -> AuthRepository {
        AuthRepository(
            restoreSession: {
                do {
                    guard let accessToken = try keychainService.load(KeychainKey.accessToken) else {
                        return nil
                    }
                    let refreshToken = try keychainService.load(KeychainKey.refreshToken)
                    let user = try await authService.me(accessToken)
                    return AuthSession(
                        token: AuthToken(accessToken: accessToken, refreshToken: refreshToken, tokenType: "bearer"),
                        user: user
                    )
                } catch {
                    try? keychainService.remove(KeychainKey.accessToken)
                    try? keychainService.remove(KeychainKey.refreshToken)
                    return nil
                }
            },
            login: { login, password in
                let token = try await authService.login(login, password)
                let user = try await authService.me(token.accessToken)

                try keychainService.save(token.accessToken, KeychainKey.accessToken)
                if let refreshToken = token.refreshToken {
                    try keychainService.save(refreshToken, KeychainKey.refreshToken)
                }

                return AuthSession(token: token, user: user)
            },
            logout: { session in
                if let token = session?.token.accessToken {
                    try? await authService.logout(token)
                }
                try? keychainService.remove(KeychainKey.accessToken)
                try? keychainService.remove(KeychainKey.refreshToken)
            },
            refreshSession: { session in
                guard let refreshToken = session.token.refreshToken, !refreshToken.isEmpty else {
                    throw AuthError.refreshUnavailable
                }
                let token = try await authService.refresh(refreshToken)
                let user = try await authService.me(token.accessToken)

                try keychainService.save(token.accessToken, KeychainKey.accessToken)
                if let nextRefreshToken = token.refreshToken {
                    try keychainService.save(nextRefreshToken, KeychainKey.refreshToken)
                }

                return AuthSession(token: token, user: user)
            },
            fetchProfile: { accessToken in
                try await authService.me(accessToken)
            }
        )
    }
}

extension AuthRepository: DependencyKey {
    static let liveValue = AuthRepository.live(authService: .liveValue, keychainService: .liveValue)
    static let testValue = AuthRepository(
        restoreSession: { nil },
        login: { _, _ in
            AuthSession(
                token: AuthToken(accessToken: "token", refreshToken: nil, tokenType: "bearer"),
                user: AuthUser(id: 1, fullName: "Test", email: "test@example.com", login: "test", role: .guest)
            )
        },
        logout: { _ in },
        refreshSession: { _ in throw AuthError.refreshUnavailable },
        fetchProfile: { _ in
            AuthUser(id: 1, fullName: "Test", email: "test@example.com", login: "test", role: .guest)
        }
    )
}

extension DependencyValues {
    var authRepository: AuthRepository {
        get { self[AuthRepository.self] }
        set { self[AuthRepository.self] = newValue }
    }
}
