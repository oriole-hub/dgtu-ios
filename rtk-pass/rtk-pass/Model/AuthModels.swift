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
    /// Populated when decoded from full `/auth/me` payload.
    let jobTitle: String?
    let officeSummary: String?
    /// Original `role` string from API when present (for display if it does not map to `UserRole`).
    let roleRawFromServer: String?

    init(
        id: Int,
        fullName: String,
        email: String,
        login: String,
        role: UserRole,
        jobTitle: String? = nil,
        officeSummary: String? = nil,
        roleRawFromServer: String? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.login = login
        self.role = role
        self.jobTitle = jobTitle
        self.officeSummary = officeSummary
        self.roleRawFromServer = roleRawFromServer
    }
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
    let roleRawFromServer: String?
    let jobTitle: String?
    let officeSummary: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case login
        case role
        case jobTitle = "job_title"
        case office
    }

    private struct OfficePayload: Decodable, Sendable {
        let address: String?
        let city: String?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        fullName = try c.decode(String.self, forKey: .fullName)
        email = try c.decodeIfPresent(String.self, forKey: .email) ?? ""
        login = try c.decodeIfPresent(String.self, forKey: .login) ?? ""
        let roleDecoded = Self.decodeRoleAndRaw(container: c)
        role = roleDecoded.role
        roleRawFromServer = roleDecoded.raw
        jobTitle = try c.decodeIfPresent(String.self, forKey: .jobTitle)
        officeSummary = (try? c.decodeIfPresent(OfficePayload.self, forKey: .office)).flatMap(Self.summarizeOffice)
    }

    func toDomain() -> AuthUser {
        AuthUser(
            id: id,
            fullName: fullName,
            email: email,
            login: login,
            role: role,
            jobTitle: jobTitle,
            officeSummary: officeSummary,
            roleRawFromServer: roleRawFromServer
        )
    }

    private static func decodeRoleAndRaw(container c: KeyedDecodingContainer<CodingKeys>) -> (role: UserRole, raw: String?) {
        guard c.contains(.role) else { return (.guest, nil) }
        if let isNil = try? c.decodeNil(forKey: .role), isNil { return (.guest, nil) }
        guard let raw = try? c.decode(String.self, forKey: .role) else { return (.guest, nil) }
        let mapped = UserRole(rawValue: raw) ?? .guest
        return (mapped, raw)
    }

    private static func summarizeOffice(_ office: OfficePayload) -> String? {
        let parts = [office.city, office.address]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if parts.isEmpty { return nil }
        return parts.joined(separator: " · ")
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
