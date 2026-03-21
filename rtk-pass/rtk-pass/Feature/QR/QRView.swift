import SwiftUI

struct QRView: View {
    let session: AuthSession
    /// Matches login-style primary actions when set from `AuthenticatedHomeView`.
    var glassButtonWidth: CGFloat? = nil

    @StateObject private var viewModel = QRViewModel()

    private let fieldHeight: CGFloat = 48
    private let fieldFontSize: CGFloat = 18

    private var regenerateButtonWidth: CGFloat {
        glassButtonWidth ?? 280
    }

    var body: some View {
        VStack(spacing: 16) {
            if let image = viewModel.qrImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260, maxHeight: 260)
                    .padding(8)
                    .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if viewModel.isLoading {
                ProgressView("Generating pass...")
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                placeholderView
            }

            if let pass = viewModel.pass {
                VStack(spacing: 6) {
                    Text("Статус: \(pass.status)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Истекает через \(format(remainingSeconds: viewModel.remainingSeconds))")
                        .font(.footnote)
                        .monospacedDigit()
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await viewModel.regeneratePass(session: session) }
            } label: {
                Text("Сгенерировать пропуск")
                    .font(.system(size: fieldFontSize, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: fieldHeight, maxHeight: fieldHeight)
            }
            .buttonStyle(.plain)
            .frame(width: regenerateButtonWidth, height: fieldHeight)
            .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .frame(maxWidth: .infinity)
            .disabled(viewModel.isLoading)
        }
        .task(id: session.token.accessToken) {
            await viewModel.loadInitialPassIfNeeded(session: session)
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.secondary.opacity(0.15))
            .frame(width: 220, height: 220)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 30))
                    Text("QR not generated yet")
                        .font(.footnote)
                }
                .foregroundStyle(.secondary)
            }
    }

    private func format(remainingSeconds: Int) -> String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        GeometryReader { geo in
            let contentWidth = geo.size.width * 0.8
            ZStack {
                AuthBubbleBackground()
                    .ignoresSafeArea()
                QRView(
                    session: AuthSession(
                        token: AuthToken(accessToken: "preview-token", refreshToken: nil, tokenType: "bearer"),
                        user: AuthUser(id: 1, fullName: "Preview", email: "preview@example.com", login: "preview", role: .employee)
                    ),
                    glassButtonWidth: contentWidth
                )
                .padding(.horizontal, 24)
                .padding(.top, geo.safeAreaInsets.top + 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}
