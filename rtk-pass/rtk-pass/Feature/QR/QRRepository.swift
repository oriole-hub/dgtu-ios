import Dependencies
import Foundation

struct QRRepository: Sendable {
    var generatePass: @Sendable (_ session: AuthSession) async throws -> QRPass
}

extension QRRepository {
    static func live(qrService: QRService) -> QRRepository {
        QRRepository(
            generatePass: { session in
                do {
                    return try await qrService.generatePass(session.token.accessToken)
                } catch let error as AuthError {
                    switch error {
                    case .unauthorized:
                        throw QRError.unauthorized
                    case let .network(message):
                        throw QRError.network(message)
                    default:
                        throw QRError.generationFailed
                    }
                } catch let error as QRError {
                    throw error
                } catch {
                    throw QRError.network(error.localizedDescription)
                }
            }
        )
    }
}

extension QRRepository: DependencyKey {
    static let liveValue = QRRepository.live(qrService: .liveValue)
    static let testValue = QRRepository(
        generatePass: { _ in
            QRPass(token: "test-token", status: "active", expiresAt: Date().addingTimeInterval(300))
        }
    )
}

extension DependencyValues {
    var qrRepository: QRRepository {
        get { self[QRRepository.self] }
        set { self[QRRepository.self] = newValue }
    }
}
