import SwiftUI

struct AuthRootView: View {
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.status {
                case .checkingSession:
                    ProgressView("Restoring session...")
                case .authenticating:
                    ProgressView("Authorizing...")
                case .unauthenticated:
                    unauthenticatedView
                case let .authenticated(session):
                    authenticatedView(session)
                }
            }
            .padding()
            .navigationTitle("RTK Pass")
        }
        .task {
            await viewModel.restoreSessionIfNeeded()
        }
    }

    private var unauthenticatedView: some View {
        VStack(spacing: 16) {
            loginForm

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.leading)
            }

            Button("Sign In") {
                Task { await viewModel.signIn() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var loginForm: some View {
        VStack(spacing: 12) {
            TextField("Login", text: $viewModel.login)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $viewModel.password)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func authenticatedView(_ session: AuthSession) -> some View {
        VStack(spacing: 16) {
            Text("Welcome, \(session.user.fullName)")
                .font(.headline)

            Text("Role: \(session.user.role.rawValue)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            QRView(session: session)

            Button("Refresh Session") {
                Task { await viewModel.refreshCurrentSession() }
            }
            .buttonStyle(.bordered)

            Button("Logout") {
                Task { await viewModel.logout() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }
}

#Preview {
    AuthRootView()
}
