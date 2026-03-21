import Dependencies
import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var currentPin = ""
    @Published var newPin = ""
    @Published var confirmPin = ""

    @Published private(set) var isFaceIDAvailable = false
    @Published var isFaceIDEnabled = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    @Dependency(\.appLockService) private var appLockService

    func load() {
        isFaceIDAvailable = appLockService.isFaceIDAvailable()
        isFaceIDEnabled = appLockService.isFaceIDEnabled()
    }

    func updateFaceIDEnabled(_ isEnabled: Bool) {
        do {
            try appLockService.setFaceIDEnabled(isEnabled)
            isFaceIDEnabled = appLockService.isFaceIDEnabled()
            statusMessage = "Face ID preference updated."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changePin() {
        guard AppLockService.isValid(pin: currentPin),
              AppLockService.isValid(pin: newPin),
              AppLockService.isValid(pin: confirmPin) else {
            errorMessage = "Each PIN must contain exactly 4 digits."
            statusMessage = nil
            return
        }

        guard newPin == confirmPin else {
            errorMessage = "New PIN and confirmation do not match."
            statusMessage = nil
            return
        }

        do {
            try appLockService.changePin(currentPin, newPin)
            currentPin = ""
            newPin = ""
            confirmPin = ""
            statusMessage = "PIN changed successfully."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }
}
