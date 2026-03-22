import Dependencies
import SwiftUI

struct StatisticsSheetView: View {
    let accessToken: String

    @StateObject private var viewModel = StatisticsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.profile == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let profile = viewModel.profile {
                    Form {
                        Section {
                            LabeledContent("ФИО") {
                                Text(profile.fullName)
                            }
                            LabeledContent("Email") {
                                Text(profile.email)
                            }
                            LabeledContent("Логин") {
                                Text(profile.login)
                            }
                            LabeledContent("Роль") {
                                Text(profile.roleRawFromServer ?? profile.role.rawValue)
                            }
                            LabeledContent("ID") {
                                Text("\(profile.id)")
                            }
                            if let title = profile.jobTitle, !title.isEmpty {
                                LabeledContent("Должность") {
                                    Text(title)
                                }
                            }
                            if let office = profile.officeSummary, !office.isEmpty {
                                LabeledContent("Офис") {
                                    Text(office)
                                }
                            }
                        }
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Не удалось загрузить", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView {
                        Label("Нет данных", systemImage: "person.crop.questionmark")
                    } description: {
                        Text("Потяните вниз, чтобы закрыть, и откройте снова.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Статистика")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .task(id: accessToken) {
                await viewModel.load(accessToken: accessToken)
            }
        }
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    withDependencies {
        var repo = $0.authRepository
        repo.fetchProfile = { _ in
            AuthUser(
                id: 99,
                fullName: "Превью Пользователь",
                email: "preview@example.com",
                login: "preview",
                role: .employee
            )
        }
        $0.authRepository = repo
    } operation: {
        StatisticsSheetView(accessToken: "preview-token")
    }
}
