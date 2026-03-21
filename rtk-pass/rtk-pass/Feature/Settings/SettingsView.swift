import SwiftUI

struct SettingsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            if viewModel.isFaceIDAvailable {
                Section("Face ID") {
                    Toggle("Use Face ID", isOn: Binding(
                        get: { viewModel.isFaceIDEnabled },
                        set: { viewModel.updateFaceIDEnabled($0) }
                    ))
                }
            }

            Section("Change PIN") {
                SecureField("Current PIN", text: $viewModel.currentPin)
                    .keyboardType(.numberPad)
                SecureField("New PIN", text: $viewModel.newPin)
                    .keyboardType(.numberPad)
                SecureField("Confirm New PIN", text: $viewModel.confirmPin)
                    .keyboardType(.numberPad)

                Button("Update PIN") {
                    viewModel.changePin()
                }
                .buttonStyle(.borderedProminent)
            }

            Section {
                Button(role: .destructive) {
                    Task { await authViewModel.logout() }
                } label: {
                    Text("Logout")
                }
            }

            if let statusMessage = viewModel.statusMessage {
                Section {
                    Text(statusMessage)
                        .foregroundStyle(.green)
                        .font(.footnote)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("Settings")
        .toolbar(.visible, for: .navigationBar)
        .task {
            viewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(authViewModel: AuthViewModel())
    }
}
