import SwiftUI
import UIKit

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
            .padding(viewModel.status == .unauthenticated ? 0 : 16)
            .navigationTitle(viewModel.status == .unauthenticated ? "" : "RTK Pass")
        }
        .toolbar(viewModel.status == .unauthenticated ? .hidden : .automatic, for: .navigationBar)
        .task {
            await viewModel.restoreSessionIfNeeded()
        }
    }

    private func authenticatedGateView(_ session: AuthSession) -> some View {
        Group {
            if lockViewModel.mode == .unlocked {
                authenticatedView(session)
            } else {
                LockScreenView(viewModel: lockViewModel)
            }
        }
        .task(id: session.token.accessToken) {
            await lockViewModel.prepareForAuthenticatedLaunch()
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

            NavigationLink("Settings") {
                SettingsView()
            }
            .buttonStyle(.bordered)

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

private struct AuthBubbleBackground: View {
    private static let leftCropFactor: CGFloat = 0.45

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            // Design frame sizes (points)
            let p1w: CGFloat = 231
            let p1h: CGFloat = 270
            let o1w: CGFloat = 231
            let o1h: CGFloat = 238
            let p3w: CGFloat = 247
            let p3h: CGFloat = 203
            let p2w: CGFloat = 186
            let p2h: CGFloat = 217
            let o2w: CGFloat = 288
            let o2h: CGFloat = 263

            let leftStack = p1h + o1h + p3h
            let sLeft = max(0, (h - leftStack) / 2)
            let leftTopY = p1h / 2
            let leftMidY = p1h + sLeft + o1h / 2
            let leftBotY = p1h + sLeft + o1h + sLeft + p3h / 2

            let rightStack = p2h + o2h + p3h
            let sRight = max(0, (h - rightStack) / 2)
            let rightTopY = p2h / 2
            let rightMidY = p2h + sRight + o2h / 2
            let rightBotY = p2h + sRight + o2h + sRight + p3h / 2

            let leftCX: (CGFloat) -> CGFloat = { width in
                width / 2 - Self.leftCropFactor * width
            }
            let rightCX: (CGFloat) -> CGFloat = { width in
                w - width / 2 + Self.leftCropFactor * width
            }

            ZStack {
                Color(UIColor.systemBackground)

                Image("bubble-purple-1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: p1w, height: p1h)
                    .position(x: leftCX(p1w)-30, y: leftTopY+20)

                Image("bubble-orange-1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: o1w, height: o1h)
                    .position(x: leftCX(o1w)-40, y: leftMidY+50)

                Image("bubble-purple-3")
                    .resizable()
                    .scaledToFit()
                    .frame(width: p3w, height: p3h)
                    .position(x: leftCX(p3w), y: leftBotY+40)

                Image("bubble-purple-2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: p2w, height: p2h)
                    .position(x: rightCX(p2w)+40, y: rightTopY+50)

                Image("bubble-orange-2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: o2w, height: o2h)
                    .position(x: rightCX(o2w), y: rightMidY+80)

//                Image("bubble-purple-3")
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: p3w, height: p3h)
//                    .position(x: rightCX(p3w), y: rightBotY)
            }
            .frame(width: w, height: h)
            .clipped()
        }
    }
}

#Preview {
    AuthRootView()
}
