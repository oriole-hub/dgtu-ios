import Dependencies
import XCTest
@testable import rtk_pass

@MainActor
final class AuthViewModelTests: XCTestCase {
    func testRestoreSessionUpdatesStatusToAuthenticated() async {
        let viewModel = withDependencies {
            $0.authRepository.restoreSession = {
                AuthSession(
                    token: AuthToken(accessToken: "token", refreshToken: nil, tokenType: "bearer"),
                    user: AuthUser(id: 1, fullName: "Jane", email: "jane@example.com", login: "jane", role: .admin)
                )
            }
        } operation: {
            AuthViewModel()
        }

        await viewModel.restoreSessionIfNeeded()

        if case let .authenticated(session) = viewModel.status {
            XCTAssertEqual(session.user.login, "jane")
        } else {
            XCTFail("Expected authenticated state")
        }
    }

    func testSignInSuccessSetsAuthenticatedState() async {
        let viewModel = withDependencies {
            $0.authRepository.login = { login, _ in
                XCTAssertEqual(login, "john")
                return AuthSession(
                    token: AuthToken(accessToken: "token", refreshToken: nil, tokenType: "bearer"),
                    user: AuthUser(id: 2, fullName: "John", email: "john@example.com", login: "john", role: .employee)
                )
            }
        } operation: {
            AuthViewModel()
        }

        viewModel.status = .unauthenticated
        viewModel.login = "john"
        viewModel.password = "secret123"

        await viewModel.signIn()

        if case let .authenticated(session) = viewModel.status {
            XCTAssertEqual(session.user.login, "john")
        } else {
            XCTFail("Expected authenticated state")
        }
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSignInValidationFailureSetsError() async {
        let viewModel = AuthViewModel()
        viewModel.status = .unauthenticated
        viewModel.login = ""
        viewModel.password = ""

        await viewModel.signIn()

        XCTAssertEqual(viewModel.status, .unauthenticated)
        XCTAssertNotNil(viewModel.errorMessage)
    }
}
