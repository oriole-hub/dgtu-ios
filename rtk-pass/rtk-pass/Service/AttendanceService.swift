import Dependencies
import Foundation

struct AttendanceService: Sendable {
    var fetchMyAttendance: @Sendable (_ accessToken: String, _ from: String, _ to: String) async throws -> AttendanceOutDTO
}

extension AttendanceService {
    static func live(apiClient: APIClient) -> AttendanceService {
        AttendanceService(
            fetchMyAttendance: { accessToken, from, to in
                let items = [
                    URLQueryItem(name: "from", value: from),
                    URLQueryItem(name: "to", value: to)
                ]
                let data = try await apiClient.send(
                    .init(
                        path: "/auth/me/attendance",
                        method: .get,
                        bearerToken: accessToken,
                        queryItems: items
                    )
                )
                return try JSONDecoder().decode(AttendanceOutDTO.self, from: data)
            }
        )
    }
}

extension AttendanceService: DependencyKey {
    static let liveValue = AttendanceService.live(apiClient: .liveValue)
    static let testValue = AttendanceService(
        fetchMyAttendance: { _, _, _ in
            AttendanceOutDTO(
                ianaTimezone: "Europe/Moscow",
                workStartTime: "09:00:00",
                punctualDaysTotal: 0,
                days: []
            )
        }
    )
}

extension DependencyValues {
    var attendanceService: AttendanceService {
        get { self[AttendanceService.self] }
        set { self[AttendanceService.self] = newValue }
    }
}
