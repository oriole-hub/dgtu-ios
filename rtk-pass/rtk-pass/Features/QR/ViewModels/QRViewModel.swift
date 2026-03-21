import CoreImage
import CoreImage.CIFilterBuiltins
import Dependencies
import Foundation
import UIKit
import Combine

@MainActor
final class QRViewModel: ObservableObject {
    @Published var pass: QRPass?
    @Published var qrImage: UIImage?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var remainingSeconds: Int = 0

    @Dependency(\.qrRepository) private var qrRepository

    private let now: @Sendable () -> Date
    private let sleep: @Sendable (UInt64) async throws -> Void
    private var autoRefreshTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?

    init(
        now: @escaping @Sendable () -> Date = Date.init,
        sleep: @escaping @Sendable (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    ) {
        self.now = now
        self.sleep = sleep
    }

    deinit {
        autoRefreshTask?.cancel()
        countdownTask?.cancel()
    }

    func loadInitialPassIfNeeded(session: AuthSession) async {
        guard pass == nil else { return }
        await refresh(session: session, initiatedByUser: false)
    }

    func regeneratePass(session: AuthSession) async {
        await refresh(session: session, initiatedByUser: true)
    }

    func stop() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
        countdownTask?.cancel()
        countdownTask = nil
    }

    private func refresh(session: AuthSession, initiatedByUser: Bool) async {
        if initiatedByUser {
            isLoading = true
        } else if pass == nil {
            isLoading = true
        }
        errorMessage = nil

        do {
            let nextPass = try await qrRepository.generatePass(session)
            guard let image = QRCodeRenderer.image(from: nextPass.payload) else {
                throw QRError.generationFailed
            }

            pass = nextPass
            qrImage = image
            isLoading = false
            updateRemainingTime()
            startCountdown()
            scheduleAutoRefresh(session: session, expiresAt: nextPass.expiresAt)
        } catch let error as QRError {
            isLoading = false
            errorMessage = error.localizedDescription
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleAutoRefresh(session: AuthSession, expiresAt: Date) {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { [weak self] in
            guard let self else { return }
            let secondsToWait = max(0, expiresAt.timeIntervalSince(now()))
            let nanoseconds = UInt64(secondsToWait * 1_000_000_000)
            do {
                try await sleep(nanoseconds)
                guard !Task.isCancelled else { return }
                await refresh(session: session, initiatedByUser: false)
            } catch {
                return
            }
        }
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await updateRemainingTime()
                try? await sleep(1_000_000_000)
            }
        }
    }

    private func updateRemainingTime() {
        guard let pass else {
            remainingSeconds = 0
            return
        }
        remainingSeconds = max(0, Int(pass.expiresAt.timeIntervalSince(now())))
    }
}

enum QRCodeRenderer {
    static func image(from payload: String, sideLength: CGFloat = 260) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scaleX = sideLength / outputImage.extent.size.width
        let scaleY = sideLength / outputImage.extent.size.height
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
