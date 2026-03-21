import Dependencies
import Foundation

struct AuthService: Sendable {
    var login: @Sendable (_ login: String, _ password: String) async throws -> AuthToken
    var me: @Sendable (_ accessToken: String) async throws -> AuthUser
    var logout: @Sendable (_ accessToken: String) async throws -> Void
    var refresh: @Sendable (_ refreshToken: String) async throws -> AuthToken
}

extension AuthService {
    static func live(apiClient: APIClient) -> AuthService {
        AuthService(
            login: { login, password in
                let body = try JSONEncoder().encode(LoginRequest(login: login, pwd: password))
                let data = try await apiClient.send(.init(path: "/auth/login", method: .post, body: body))
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                return AuthToken(
                    accessToken: tokenResponse.accessToken,
                    refreshToken: nil,
                    tokenType: tokenResponse.tokenType
                )
            },
            me: { accessToken in
                let data = try await apiClient.send(.init(path: "/auth/me", method: .get, bearerToken: accessToken))
                let user = try JSONDecoder().decode(UserResponse.self, from: data)
                return user.toDomain()
            },
            logout: { accessToken in
                _ = try await apiClient.send(.init(path: "/auth/logout", method: .post, bearerToken: accessToken))
            },
            refresh: { refreshToken in
                let body = try JSONEncoder().encode(["refresh_token": refreshToken])
                let data = try await apiClient.send(.init(path: "/auth/refresh", method: .post, body: body))
                let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
                return AuthToken(
                    accessToken: tokenResponse.accessToken,
                    refreshToken: refreshToken,
                    tokenType: tokenResponse.tokenType
                )
            }
        )
    }
}

extension AuthService: DependencyKey {
    static let liveValue = AuthService.live(apiClient: .liveValue)
    static let testValue = AuthService(
        login: { _, _ in AuthToken(accessToken: "", refreshToken: nil, tokenType: "bearer") },
        me: { _ in AuthUser(id: 0, fullName: "", email: "", login: "", role: .guest) },
        logout: { _ in },
        refresh: { _ in throw AuthError.refreshUnavailable }
    )
}

extension DependencyValues {
    var authService: AuthService {
        get { self[AuthService.self] }
        set { self[AuthService.self] = newValue }
    }
}
