import Dependencies
import Foundation
import LocalAuthentication

struct BiometricAuthService: Sendable {
    var isFaceIDAvailable: @Sendable () -> Bool
    var authenticate: @Sendable (_ reason: String) async -> Bool
}

extension BiometricAuthService {
    static let liveValue = BiometricAuthService(
        isFaceIDAvailable: {
            let context = LAContext()
            var error: NSError?
            let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            return canEvaluate && context.biometryType == .faceID
        },
        authenticate: { reason in
            let context = LAContext()
            context.localizedFallbackTitle = ""

            var error: NSError?
            let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            guard canEvaluate, context.biometryType == .faceID else {
                return false
            }

            return await withCheckedContinuation { continuation in
                context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                    continuation.resume(returning: success)
                }
            }
        }
    )

    static let testValue = BiometricAuthService(
        isFaceIDAvailable: { false },
        authenticate: { _ in false }
    )
}

extension BiometricAuthService: DependencyKey {}

extension DependencyValues {
    var biometricAuthService: BiometricAuthService {
        get { self[BiometricAuthService.self] }
        set { self[BiometricAuthService.self] = newValue }
    }
}
