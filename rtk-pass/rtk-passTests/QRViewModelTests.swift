import Dependencies
import XCTest
@testable import rtk_pass

@MainActor
final class QRViewModelTests: XCTestCase {
    func testManualRefreshRequestsNewPass() async {
        var callCount = 0
        let session = makeSession()

        let viewModel = withDependencies {
            $0.qrRepository.generatePass = { _ in
                callCount += 1
                return QRPass(
                    token: "qr-\(callCount)",
                    status: "active",
                    expiresAt: Date().addingTimeInterval(300)
                )
            }
        } operation: {
            QRViewModel()
        }

        await viewModel.loadInitialPassIfNeeded(session: session)
        await viewModel.regeneratePass(session: session)

        XCTAssertEqual(callCount, 2)
        XCTAssertEqual(viewModel.pass?.token, "qr-2")
        XCTAssertNil(viewModel.errorMessage)
    }

    func testAutoRefreshTriggersAtExpiry() async {
        let refreshTriggered = expectation(description: "auto-refresh")
        var callCount = 0
        let session = makeSession()

        let viewModel = withDependencies {
            $0.qrRepository.generatePass = { _ in
                callCount += 1
                if callCount == 1 {
                    return QRPass(
                        token: "qr-1",
                        status: "active",
                        expiresAt: Date().addingTimeInterval(0.05)
                    )
                }
                refreshTriggered.fulfill()
                return QRPass(
                    token: "qr-2",
                    status: "active",
                    expiresAt: Date().addingTimeInterval(300)
                )
            }
        } operation: {
            QRViewModel()
        }

        await viewModel.loadInitialPassIfNeeded(session: session)
        await fulfillment(of: [refreshTriggered], timeout: 1.0)

        XCTAssertGreaterThanOrEqual(callCount, 2)
        XCTAssertEqual(viewModel.pass?.token, "qr-2")
    }

    func testStopCancelsScheduledAutoRefresh() async {
        var callCount = 0
        let session = makeSession()

        let viewModel = withDependencies {
            $0.qrRepository.generatePass = { _ in
                callCount += 1
                return QRPass(
                    token: "qr-\(callCount)",
                    status: "active",
                    expiresAt: Date().addingTimeInterval(0.2)
                )
            }
        } operation: {
            QRViewModel()
        }

        await viewModel.loadInitialPassIfNeeded(session: session)
        viewModel.stop()
        try? await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertEqual(callCount, 1)
    }

    private func makeSession() -> AuthSession {
        AuthSession(
            token: AuthToken(accessToken: "access-token", refreshToken: nil, tokenType: "bearer"),
            user: AuthUser(id: 1, fullName: "Jane", email: "jane@example.com", login: "jane", role: .employee)
        )
    }
}
