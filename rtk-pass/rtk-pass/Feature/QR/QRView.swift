import SwiftUI

struct QRView: View {
    let session: AuthSession

    @StateObject private var viewModel = QRViewModel()

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
                    Text("Status: \(pass.status)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Updates in \(format(remainingSeconds: viewModel.remainingSeconds))")
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

            Button("Regenerate QR") {
                Task { await viewModel.regeneratePass(session: session) }
            }
            .buttonStyle(.borderedProminent)
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
    QRView(
        session: AuthSession(
            token: AuthToken(accessToken: "preview-token", refreshToken: nil, tokenType: "bearer"),
            user: AuthUser(id: 1, fullName: "Preview", email: "preview@example.com", login: "preview", role: .employee)
        )
    )
}
