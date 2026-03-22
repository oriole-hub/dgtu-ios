import Dependencies
import Foundation

struct AttendanceRepository: Sendable {
    var fetchMyAttendance: @Sendable (_ accessToken: String, _ from: String, _ to: String) async throws -> AttendanceCalendarData
}

extension AttendanceRepository {
    static func live(attendanceService: AttendanceService) -> AttendanceRepository {
        AttendanceRepository(
            fetchMyAttendance: { accessToken, from, to in
                do {
                    let dto = try await attendanceService.fetchMyAttendance(accessToken, from, to)
                    let tz = TimeZone(identifier: dto.ianaTimezone) ?? .current
                    return AttendanceDTOMapper.calendarData(from: dto, officeTimeZone: tz)
                } catch let error as AuthError {
                    switch error {
                    case .unauthorized:
                        throw AttendanceError.unauthorized
                    case let .network(message):
                        throw AttendanceError.network(message)
                    default:
                        throw AttendanceError.invalidResponse
                    }
                } catch is DecodingError {
                    throw AttendanceError.invalidResponse
                } catch {
                    throw AttendanceError.network(error.localizedDescription)
                }
            }
        )
    }
}

extension AttendanceRepository: DependencyKey {
    static let liveValue = AttendanceRepository.live(attendanceService: .liveValue)
    static let testValue = AttendanceRepository(
        fetchMyAttendance: { _, _, _ in
            AttendanceCalendarData(
                ianaTimezone: "Europe/Moscow",
                workStartTime: "09:00:00",
                punctualDaysTotal: 0,
                daysByDate: [:]
            )
        }
    )
}

extension DependencyValues {
    var attendanceRepository: AttendanceRepository {
        get { self[AttendanceRepository.self] }
        set { self[AttendanceRepository.self] = newValue }
    }
}
