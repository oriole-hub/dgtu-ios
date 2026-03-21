import SwiftUI
import UIKit
import Combine

@MainActor
final class ScreenCaptureMonitor: ObservableObject {
    @Published private(set) var isScreenCaptured = UIScreen.main.isCaptured
    @Published private(set) var isAppActive = true
    @Published private(set) var didTakeScreenshotAt: Date?

    private var screenshotResetTask: Task<Void, Never>?
    private var notificationObservers: [NSObjectProtocol] = []
    private let notificationCenter: NotificationCenter

    var isProtectionOverlayVisible: Bool {
        isScreenCaptured || !isAppActive || didTakeScreenshotAt != nil
    }

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        observeScreenCaptureChanges(notificationCenter: notificationCenter)
        observeScreenshotEvents(notificationCenter: notificationCenter)
        observeAppState(notificationCenter: notificationCenter)
    }

    deinit {
        screenshotResetTask?.cancel()
        notificationObservers.forEach { notificationCenter.removeObserver($0) }
    }

    private func observeScreenCaptureChanges(notificationCenter: NotificationCenter) {
        let observer = notificationCenter.addObserver(
            forName: UIScreen.capturedDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isScreenCaptured = UIScreen.main.isCaptured
        }
        notificationObservers.append(observer)
    }

    private func observeScreenshotEvents(notificationCenter: NotificationCenter) {
        let observer = notificationCenter.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.didTakeScreenshotAt = Date()
            self.screenshotResetTask?.cancel()
            self.screenshotResetTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1))
                self?.didTakeScreenshotAt = nil
            }
        }
        notificationObservers.append(observer)
    }

    private func observeAppState(notificationCenter: NotificationCenter) {
        let resignObserver = notificationCenter.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isAppActive = false
        }
        notificationObservers.append(resignObserver)

        let becomeObserver = notificationCenter.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isAppActive = true
        }
        notificationObservers.append(becomeObserver)
    }
}
