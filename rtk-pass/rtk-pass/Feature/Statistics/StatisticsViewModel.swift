import Combine
import Dependencies
import Foundation

@MainActor
final class StatisticsViewModel: ObservableObject {
    @Published private(set) var profile: AuthUser?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    @Dependency(\.authRepository) private var authRepository

    func load(accessToken: String) async {
        errorMessage = nil
        profile = nil
        isLoading = true
        defer { isLoading = false }

        do {
            profile = try await authRepository.fetchProfile(accessToken)
        } catch is CancellationError {
            errorMessage = "Загрузка прервана."
        } catch let err as AuthError {
            errorMessage = err.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
