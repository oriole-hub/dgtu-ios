import SwiftUI

struct LockScreenView: View {
    @ObservedObject var viewModel: LockViewModel

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: 24) {
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
                    Label("Unlock with Face ID", systemImage: "faceid")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isBiometricInProgress)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.tint)
            Text(viewModel.title)
                .font(.title2.weight(.semibold))
            Text(viewModel.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
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
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(1...9, id: \.self) { number in
                keypadButton(title: "\(number)") {
                    viewModel.appendDigit(number)
                }
            }

            Color.clear
                .frame(height: 60)

            keypadButton(title: "0") {
                viewModel.appendDigit(0)
            }

            keypadButton(systemImage: "delete.left") {
                viewModel.deleteLastDigit()
            }
        }
        .frame(maxWidth: 320)
    }

    private func keypadButton(title: String? = nil, systemImage: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.secondary.opacity(0.15))
                    .frame(width: 60, height: 60)
                if let title {
                    Text(title)
                        .font(.title3.weight(.semibold))
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.title3)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LockScreenView(viewModel: LockViewModel())
}
