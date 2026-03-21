import Dependencies
import XCTest
@testable import rtk_pass

@MainActor
final class LockViewModelTests: XCTestCase {
    func testPrepareWithoutPinGoesToSetup() async {
        let viewModel = withDependencies {
            $0.appLockService = AppLockService(
                isPinConfigured: { false },
                setInitialPin: { _ in },
                verifyPin: { _ in false },
                changePin: { _, _ in },
                isFaceIDAvailable: { false },
                isFaceIDEnabled: { false },
                setFaceIDEnabled: { _ in },
                authenticateWithFaceID: { false }
            )
        } operation: {
            LockViewModel()
        }

        await viewModel.prepareForAuthenticatedLaunch()
        XCTAssertEqual(viewModel.mode, .needsSetup)
    }

    func testSetupFlowUnlocksAfterConfirmingPin() async {
        final class PinState: @unchecked Sendable {
            var savedPin: String?
        }
        let state = PinState()

        let viewModel = withDependencies {
            $0.appLockService = AppLockService(
                isPinConfigured: { state.savedPin != nil },
                setInitialPin: { pin in state.savedPin = pin },
                verifyPin: { pin in state.savedPin == pin },
                changePin: { _, _ in },
                isFaceIDAvailable: { false },
                isFaceIDEnabled: { false },
                setFaceIDEnabled: { _ in },
                authenticateWithFaceID: { false }
            )
        } operation: {
            LockViewModel()
        }

        await viewModel.prepareForAuthenticatedLaunch()
        XCTAssertEqual(viewModel.mode, .needsSetup)

        [1, 2, 3, 4].forEach(viewModel.appendDigit)
        if case .confirmSetup = viewModel.mode {} else {
            XCTFail("Expected confirm setup mode")
        }

        [1, 2, 3, 4].forEach(viewModel.appendDigit)
        XCTAssertEqual(viewModel.mode, .unlocked)
        XCTAssertEqual(state.savedPin, "1234")
    }

    func testLockedModeWithWrongPinShowsError() async {
        let viewModel = withDependencies {
            $0.appLockService = AppLockService(
                isPinConfigured: { true },
                setInitialPin: { _ in },
                verifyPin: { _ in false },
                changePin: { _, _ in },
                isFaceIDAvailable: { false },
                isFaceIDEnabled: { false },
                setFaceIDEnabled: { _ in },
                authenticateWithFaceID: { false }
            )
        } operation: {
            LockViewModel()
        }

        await viewModel.prepareForAuthenticatedLaunch()
        XCTAssertEqual(viewModel.mode, .locked)

        [0, 0, 0, 0].forEach(viewModel.appendDigit)
        XCTAssertEqual(viewModel.mode, .locked)
        XCTAssertEqual(viewModel.errorMessage, "Incorrect PIN. Try again.")
    }
}
