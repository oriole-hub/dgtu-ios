import XCTest
@testable import rtk_pass

final class QRRepositoryTests: XCTestCase {
    func testGeneratePassReturnsDomainModel() async throws {
        let expectedDate = Date().addingTimeInterval(120)
        let service = QRService(
            generatePass: { token in
                XCTAssertEqual(token, "access-token")
                return QRPass(token: "qr-token-1", status: "active", expiresAt: expectedDate)
            }
        )
        let repository = QRRepository.live(qrService: service)

        let session = AuthSession(
            token: AuthToken(accessToken: "access-token", refreshToken: nil, tokenType: "bearer"),
            user: AuthUser(id: 1, fullName: "Jane", email: "jane@example.com", login: "jane", role: .employee)
        )
        let result = try await repository.generatePass(session)

        XCTAssertEqual(result.token, "qr-token-1")
        XCTAssertEqual(result.status, "active")
        XCTAssertEqual(result.expiresAt, expectedDate)
    }

    func testGeneratePassMapsUnauthorizedError() async {
        let service = QRService(
            generatePass: { _ in
                throw AuthError.unauthorized
            }
        )
        let repository = QRRepository.live(qrService: service)
        let session = AuthSession(
            token: AuthToken(accessToken: "access-token", refreshToken: nil, tokenType: "bearer"),
            user: AuthUser(id: 1, fullName: "Jane", email: "jane@example.com", login: "jane", role: .employee)
        )

        do {
            _ = try await repository.generatePass(session)
            XCTFail("Expected unauthorized mapping")
        } catch let error as QRError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
