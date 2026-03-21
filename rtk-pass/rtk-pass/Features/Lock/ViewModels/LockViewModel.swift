import Dependencies
import Foundation
import Combine

@MainActor
final class LockViewModel: ObservableObject {
    enum Mode: Equatable {
        case needsSetup
        case confirmSetup(firstPin: String)
        case locked
        case unlocked
    }

    @Published private(set) var mode: Mode = .locked
    @Published private(set) var enteredPin = ""
    @Published var errorMessage: String?
    @Published var isBiometricInProgress = false

    @Dependency(\.appLockService) private var appLockService
    private var hasEvaluatedForCurrentLaunch = false

    func prepareForAuthenticatedLaunch() async {
        guard !hasEvaluatedForCurrentLaunch else { return }
        hasEvaluatedForCurrentLaunch = true

        if appLockService.isPinConfigured() {
            mode = .locked
            if appLockService.isFaceIDEnabled() {
                await unlockWithFaceID()
            }
        } else {
            mode = .needsSetup
        }
    }

    var canUseFaceID: Bool {
        mode == .locked && appLockService.isFaceIDAvailable() && appLockService.isFaceIDEnabled()
    }

    var title: String {
        switch mode {
        case .needsSetup:
            return "Create PIN"
        case .confirmSetup:
            return "Confirm PIN"
        case .locked:
            return "Enter PIN"
        case .unlocked:
            return "Unlocked"
        }
    }

    var subtitle: String {
        switch mode {
        case .needsSetup:
            return "Set a 4-digit PIN to protect your app."
        case .confirmSetup:
            return "Enter the same 4-digit PIN again."
        case .locked:
            return "Unlock RTK Pass."
        case .unlocked:
            return ""
        }
    }

    func appendDigit(_ digit: Int) {
        guard enteredPin.count < 4 else { return }
        enteredPin.append(String(digit))
        if enteredPin.count == 4 {
            processPin()
        }
    }

    func deleteLastDigit() {
        guard !enteredPin.isEmpty else { return }
        enteredPin.removeLast()
    }

    func unlockWithFaceID() async {
        guard canUseFaceID else { return }
        isBiometricInProgress = true
        defer { isBiometricInProgress = false }

        let success = await appLockService.authenticateWithFaceID()
        if success {
            errorMessage = nil
            enteredPin = ""
            mode = .unlocked
        } else {
            errorMessage = "Face ID failed. Enter your PIN."
        }
    }

    private func processPin() {
        switch mode {
        case .needsSetup:
            let first = enteredPin
            enteredPin = ""
            errorMessage = nil
            mode = .confirmSetup(firstPin: first)
        case let .confirmSetup(firstPin):
            let confirmation = enteredPin
            enteredPin = ""
            guard confirmation == firstPin else {
                mode = .needsSetup
                errorMessage = "PINs do not match. Try again."
                return
            }
            do {
                try appLockService.setInitialPin(confirmation)
                if appLockService.isFaceIDAvailable() {
                    try appLockService.setFaceIDEnabled(true)
                }
                errorMessage = nil
                mode = .unlocked
            } catch {
                mode = .needsSetup
                errorMessage = error.localizedDescription
            }
        case .locked:
            let pin = enteredPin
            enteredPin = ""
            if appLockService.verifyPin(pin) {
                errorMessage = nil
                mode = .unlocked
            } else {
                errorMessage = "Incorrect PIN. Try again."
            }
        case .unlocked:
            break
        }
    }
}
