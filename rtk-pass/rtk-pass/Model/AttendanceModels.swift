import Foundation

enum AttendanceDayStatus: String, Codable, Sendable, Equatable {
    case onTime = "on_time"
    case late
    case absent
}

struct AttendanceDayOutDTO: Decodable, Sendable {
    let date: String
    let status: AttendanceDayStatus
    let firstInAt: String?

    enum CodingKeys: String, CodingKey {
        case date
        case status
        case firstInAt = "first_in_at"
    }
}

struct AttendanceOutDTO: Decodable, Sendable {
    let ianaTimezone: String
    let workStartTime: String
    let punctualDaysTotal: Int
    let days: [AttendanceDayOutDTO]

    enum CodingKeys: String, CodingKey {
        case ianaTimezone = "iana_timezone"
        case workStartTime = "work_start_time"
        case punctualDaysTotal = "punctual_days_total"
        case days
    }
}

struct AttendanceCalendarData: Equatable, Sendable {
    let ianaTimezone: String
    let workStartTime: String
    let punctualDaysTotal: Int
    /// Calendar-day keys in the office timezone (start of day).
    let daysByDate: [Date: AttendanceDayStatus]
}

enum AttendanceError: Error, LocalizedError, Equatable, Sendable {
    case unauthorized
    case network(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired. Please sign in again."
        case let .network(message):
            return message
        case .invalidResponse:
            return "Unexpected server response."
        }
    }
}

enum AttendanceDTOMapper {
    private static func startOfDay(fromApiDate string: String, calendar: Calendar) -> Date? {
        let parts = string.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2])
        else {
            return nil
        }
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        return calendar.date(from: comps)
    }

    static func calendarData(from dto: AttendanceOutDTO, officeTimeZone: TimeZone) -> AttendanceCalendarData {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = officeTimeZone

        var daysByDate: [Date: AttendanceDayStatus] = [:]
        daysByDate.reserveCapacity(dto.days.count)

        for day in dto.days {
            guard let start = startOfDay(fromApiDate: day.date, calendar: calendar) else { continue }
            daysByDate[start] = day.status
        }

        return AttendanceCalendarData(
            ianaTimezone: dto.ianaTimezone,
            workStartTime: dto.workStartTime,
            punctualDaysTotal: dto.punctualDaysTotal,
            daysByDate: daysByDate
        )
    }
}
