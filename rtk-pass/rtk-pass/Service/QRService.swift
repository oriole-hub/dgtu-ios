import Dependencies
import Foundation

struct QRService: Sendable {
    var generatePass: @Sendable (_ accessToken: String) async throws -> QRPass
}

extension QRService {
    static func live(apiClient: APIClient) -> QRService {
        QRService(
            generatePass: { accessToken in
                let data = try await apiClient.send(.init(path: "/passes/generate", method: .post, bearerToken: accessToken))
                let response = try JSONDecoder().decode(PassResponse.self, from: data)
                return try response.toDomain()
            }
        )
    }
}

extension QRService: DependencyKey {
    static let liveValue = QRService.live(apiClient: .liveValue)
    static let testValue = QRService(
        generatePass: { _ in
            QRPass(token: "test-token", status: "active", expiresAt: Date().addingTimeInterval(300))
        }
    )
}

extension DependencyValues {
    var qrService: QRService {
        get { self[QRService.self] }
        set { self[QRService.self] = newValue }
    }
}
