import Combine
import Dependencies
import Foundation

@MainActor
final class AttendanceViewModel: ObservableObject {
    @Published var visibleMonth: Date
    @Published private(set) var calendarData: AttendanceCalendarData?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    @Dependency(\.attendanceRepository) private var attendanceRepository

    private var officeTimeZone: TimeZone?

    /// Timezone for calendar grid and “today”; prefers office TZ after a successful load.
    var displayTimeZone: TimeZone {
        officeTimeZone ?? .current
    }

    init() {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        visibleMonth = cal.date(from: comps) ?? Date()
    }

    func load(accessToken: String) async {
        errorMessage = nil
        calendarData = nil
        isLoading = true
        defer { isLoading = false }

        let calendar = makeCalendar()
        guard let from = monthRange(for: visibleMonth, calendar: calendar) else {
            errorMessage = AttendanceError.invalidResponse.localizedDescription
            return
        }

        do {
            let data = try await attendanceRepository.fetchMyAttendance(accessToken, from.from, from.to)
            calendarData = data
            if let tz = TimeZone(identifier: data.ianaTimezone) {
                officeTimeZone = tz
            }
        } catch let err as AttendanceError {
            errorMessage = err.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func previousMonth() {
        shiftMonth(by: -1)
    }

    func nextMonth() {
        shiftMonth(by: 1)
    }

    private func shiftMonth(by value: Int) {
        let calendar = makeCalendar()
        if let next = calendar.date(byAdding: .month, value: value, to: visibleMonth) {
            let comps = calendar.dateComponents([.year, .month], from: next)
            visibleMonth = calendar.date(from: comps) ?? next
        }
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale.current
        calendar.timeZone = officeTimeZone ?? .current
        return calendar
    }

    private func monthRange(for monthContaining: Date, calendar: Calendar) -> (from: String, to: String)? {
        let df = DateFormatter()
        df.calendar = calendar
        df.timeZone = calendar.timeZone
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"

        guard let interval = calendar.dateInterval(of: .month, for: monthContaining) else {
            return nil
        }
        let start = interval.start
        let endExclusive = interval.end
        guard let lastDay = calendar.date(byAdding: .day, value: -1, to: endExclusive) else {
            return nil
        }
        return (df.string(from: start), df.string(from: lastDay))
    }
}
