import Dependencies
import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var status: AuthStatus = .checkingSession
    @Published var login = ""
    @Published var password = ""

    @Published var errorMessage: String?

    @Dependency(\.authRepository) private var authRepository

    func restoreSessionIfNeeded() async {
        guard case .checkingSession = status else { return }
        if let session = await authRepository.restoreSession() {
            status = .authenticated(session)
        } else {
            status = .unauthenticated
        }
    }

    func signIn() async {
        errorMessage = nil
        guard !login.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !password.isEmpty else {
            errorMessage = "Login and password are required."
            return
        }

        status = .authenticating
        do {
            let session = try await authRepository.login(login, password)
            status = .authenticated(session)
            self.password = ""
        } catch let authError as AuthError {
            status = .unauthenticated
            errorMessage = authError.localizedDescription
        } catch {
            status = .unauthenticated
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        let session: AuthSession?
        if case let .authenticated(currentSession) = status {
            session = currentSession
        } else {
            session = nil
        }

        await authRepository.logout(session)
        status = .unauthenticated
        clearSensitiveFields()
    }

    func refreshCurrentSession() async {
        guard case let .authenticated(session) = status else { return }
        do {
            let refreshed = try await authRepository.refreshSession(session)
            status = .authenticated(refreshed)
            errorMessage = nil
        } catch let authError as AuthError {
            errorMessage = authError.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearSensitiveFields() {
        password = ""
    }
}
