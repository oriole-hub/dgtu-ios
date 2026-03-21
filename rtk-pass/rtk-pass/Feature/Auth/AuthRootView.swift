import SwiftUI

struct AuthRootView: View {
    @StateObject private var viewModel = AuthViewModel()
    @StateObject private var lockViewModel = LockViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.status {
                case .checkingSession:
                    ProgressView("Restoring session...")
                case .authenticating:
                    ProgressView("Authorizing...")
                case .unauthenticated:
                    AuthLoginScreen(viewModel: viewModel)
                case let .authenticated(session):
                    authenticatedGateView(session)
                }
            }
            .padding(outerPadding)
            .navigationTitle(navigationTitle)
        }
        .toolbar(toolbarVisibility, for: .navigationBar)
        .toolbarBackground(toolbarBackgroundVisibility, for: .navigationBar)
        .task {
            await viewModel.restoreSessionIfNeeded()
        }
    }

    private var outerPadding: CGFloat {
        switch viewModel.status {
        case .unauthenticated:
            return 0
        case .authenticated:
            return 0
        default:
            return 16
        }
    }

    private var navigationTitle: String {
        switch viewModel.status {
        case .unauthenticated:
            return ""
        case .authenticated:
            return ""
        default:
            return "RTK Pass"
        }
    }

    private var toolbarVisibility: Visibility {
        switch viewModel.status {
        case .unauthenticated:
            return .hidden
        case .authenticated:
            return .hidden
        default:
            return .automatic
        }
    }

    private var toolbarBackgroundVisibility: Visibility {
        switch viewModel.status {
        case .checkingSession, .authenticating:
            return .automatic
        case .unauthenticated, .authenticated:
            return .hidden
        }
    }

    private func authenticatedGateView(_ session: AuthSession) -> some View {
        Group {
            if lockViewModel.mode == .unlocked {
                AuthenticatedHomeView(session: session, authViewModel: viewModel)
            } else {
                LockScreenView(viewModel: lockViewModel)
            }
        }
        .task(id: session.token.accessToken) {
            await lockViewModel.prepareForAuthenticatedLaunch()
        }
    }

}

// MARK: - Authenticated home (QR)

private struct AuthenticatedHomeView: View {
    let session: AuthSession
    @ObservedObject var authViewModel: AuthViewModel

    private let fieldHeight: CGFloat = 48
    private let fieldFontSize: CGFloat = 18
    private let titleFontSize: CGFloat = 36
    private let contentWidthFraction: CGFloat = 0.8

    var body: some View {
        GeometryReader { geo in
            let contentWidth = geo.size.width * contentWidthFraction
            ZStack {
                AuthBubbleBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Text("Привет, \(session.user.fullName)")
                            .font(.system(size: titleFontSize, weight: .bold))
                            .multilineTextAlignment(.center)

                        Text("Роль: \(session.user.role.rawValue)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        QRView(session: session, glassButtonWidth: contentWidth)

                        NavigationLink {
                            SettingsView(authViewModel: authViewModel)
                        } label: {
                            Text("Настройки")
                                .font(.system(size: fieldFontSize, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: fieldHeight, maxHeight: fieldHeight)
                        }
                        .buttonStyle(.plain)
                        .frame(width: contentWidth, height: fieldHeight)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.top, geo.safeAreaInsets.top + 8)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 16)
                }
            }
        }
    }
}

// MARK: - Login screen

private struct AuthLoginScreen: View {
    @ObservedObject var viewModel: AuthViewModel

    private let fieldHeight: CGFloat = 48
    private let fieldFontSize: CGFloat = 18
    private let titleFontSize: CGFloat = 36
    private let bottomPadding: CGFloat = 76
    private let contentWidthFraction: CGFloat = 0.8

    var body: some View {
        GeometryReader { geo in
            let contentWidth = geo.size.width * contentWidthFraction
            let safeTop = geo.safeAreaInsets.top
            let safeBottom = geo.safeAreaInsets.bottom

            ZStack {
                AuthBubbleBackground()
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("Вход в аккаунт")
                        .font(.system(size: titleFontSize, weight: .bold))
                        .multilineTextAlignment(.center)
                    Spacer()
                        .frame(height: 1)
                    TextField("Логин", text: $viewModel.login)
                        .font(.system(size: fieldFontSize))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 14)
                        .frame(width: contentWidth, height: fieldHeight, alignment: .leading)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    SecureField("Пароль", text: $viewModel.password)
                        .font(.system(size: fieldFontSize))
                        .padding(.horizontal, 14)
                        .frame(width: contentWidth, height: fieldHeight, alignment: .leading)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: contentWidth)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack {
                    Image("rt-logo-long")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 152, height: 53)
                        .accessibilityLabel("RTK Pass")
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 12)

                VStack {
                    Spacer()
                    Button {
                        Task { await viewModel.signIn() }
                    } label: {
                        Text("Sign In")
                            .font(.system(size: fieldFontSize, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: fieldHeight, maxHeight: fieldHeight)
                    }
                    .buttonStyle(.plain)
                    .frame(width: contentWidth, height: fieldHeight)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.bottom, safeBottom + bottomPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

#Preview {
    AuthRootView()
}
