import Foundation

struct AuthToken: Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
}

struct AuthUser: Equatable, Sendable {
    let id: Int
    let fullName: String
    let email: String
    let login: String
    let role: UserRole
}

struct AuthSession: Equatable, Sendable {
    let token: AuthToken
    let user: AuthUser
}

enum AuthStatus: Equatable, Sendable {
    case checkingSession
    case unauthenticated
    case authenticating
    case authenticated(AuthSession)
}

enum UserRole: String, Codable, Equatable, Sendable {
    case officeHead = "office_head"
    case admin
    case employee
    case guest
}

struct LoginRequest: Encodable, Sendable {
    let login: String
    let pwd: String
}

struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

struct UserResponse: Decodable, Sendable {
    let id: Int
    let fullName: String
    let email: String
    let login: String
    let role: UserRole

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case login
        case role
    }

    func toDomain() -> AuthUser {
        AuthUser(id: id, fullName: fullName, email: email, login: login, role: role)
    }
}

struct EmptyResponse: Decodable, Sendable {}

struct APIValidationErrorResponse: Decodable, Sendable {
    struct ValidationDetail: Decodable, Sendable {
        let msg: String
    }

    let detail: [ValidationDetail]
}

enum AuthError: Error, LocalizedError, Equatable, Sendable {
    case invalidCredentials
    case unauthorized
    case validation(String)
    case network(String)
    case refreshUnavailable
    case invalidResponse
    case secureStorageFailure

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid login or password."
        case .unauthorized:
            return "Session expired. Please sign in again."
        case let .validation(message):
            return message
        case let .network(message):
            return message
        case .refreshUnavailable:
            return "Refresh token flow is unavailable for current backend contract."
        case .invalidResponse:
            return "Unexpected server response."
        case .secureStorageFailure:
            return "Failed to access secure storage."
        }
    }
}
