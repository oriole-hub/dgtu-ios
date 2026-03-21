import SwiftUI

struct LockScreenView: View {
    @ObservedObject var viewModel: LockViewModel

    private let titleFontSize: CGFloat = 36
    private let pinpadButtonSize: CGFloat = 70
    private let digitFontSize: CGFloat = 24
    private let gridSpacing: CGFloat = 24

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AuthBubbleBackground()
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    header

                    pinIndicators

                    keypad

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if viewModel.canUseFaceID {
                        Button {
                            Task { await viewModel.unlockWithFaceID() }
                        } label: {
                            Label("Разблокировать с Face ID", systemImage: "faceid")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .disabled(viewModel.isBiometricInProgress)
                        .opacity(viewModel.isBiometricInProgress ? 0.5 : 1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, geo.safeAreaInsets.top + 8)
                .padding(.bottom, geo.safeAreaInsets.bottom + 16)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(viewModel.title)
                .font(.system(size: titleFontSize, weight: .bold))
                .multilineTextAlignment(.center)
            if !viewModel.subtitle.isEmpty {
                Text(viewModel.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var pinIndicators: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index < viewModel.enteredPin.count ? Color.primary : Color.secondary.opacity(0.2))
                    .frame(width: 14, height: 14)
            }
        }
        .padding(.vertical, 8)
    }

    private var keypad: some View {
        LazyVGrid(columns: columns, spacing: gridSpacing) {
            ForEach(1...9, id: \.self) { number in
                keypadButton(title: "\(number)") {
                    viewModel.appendDigit(number)
                }
            }

            Color.clear
                .frame(width: pinpadButtonSize, height: pinpadButtonSize)

            keypadButton(title: "0") {
                viewModel.appendDigit(0)
            }

            keypadButton(systemImage: "delete.left") {
                viewModel.deleteLastDigit()
            }
        }
        .frame(maxWidth: 3 * pinpadButtonSize + 2 * gridSpacing)
    }

    private func keypadButton(title: String? = nil, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                if let title {
                    Text(title)
                        .font(.system(size: digitFontSize, weight: .semibold))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: digitFontSize, weight: .medium))
                }
            }
            .frame(width: pinpadButtonSize, height: pinpadButtonSize)
            .glassEffect(in: Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LockScreenView(viewModel: LockViewModel())
}
