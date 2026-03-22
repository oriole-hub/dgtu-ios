import SwiftUI
import UIKit

struct AttendanceCalendarSection: View {
    let accessToken: String

    @StateObject private var viewModel = AttendanceViewModel()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Посещаемость")
                .font(.system(size: 20, weight: .bold))

            if let data = viewModel.calendarData {
                Text(subtitle(for: data))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    viewModel.previousMonth()
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .accessibilityLabel("Предыдущий месяц")
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthYearTitle)
                    .font(.headline)

                Spacer()

                Button {
                    viewModel.nextMonth()
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .accessibilityLabel("Следующий месяц")
                }
                .buttonStyle(.plain)
            }

            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            weekdayHeader

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(gridCells, id: \.id) { cell in
                    gridCellView(cell)
                }
            }

            legend
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: taskIdentity) {
            await viewModel.load(accessToken: accessToken)
        }
    }

    private var taskIdentity: String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = viewModel.displayTimeZone
        let y = cal.component(.year, from: viewModel.visibleMonth)
        let m = cal.component(.month, from: viewModel.visibleMonth)
        return "\(accessToken)-\(y)-\(m)"
    }

    private var monthYearTitle: String {
        let cal = calendarForDisplay
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.timeZone = cal.timeZone
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: viewModel.visibleMonth)
    }

    private func subtitle(for data: AttendanceCalendarData) -> String {
        "Без опозданий: \(data.punctualDaysTotal) · Начало дня: \(data.workStartTime.prefix(5))"
    }

    private var weekdayHeader: some View {
        let cal = calendarForDisplay
        return HStack(spacing: 6) {
            ForEach(0 ..< 7, id: \.self) { column in
                let shifted = (cal.firstWeekday - 1 + column) % 7
                Text(String(cal.shortWeekdaySymbols[shifted].prefix(2)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            legendRow(color: Color("accent"), title: "Во время")
            legendRow(color: Color("secondary"), title: "Опоздание")
            legendRow(color: Color(uiColor: .secondarySystemFill), title: "Не был")
        }
        .padding(.top, 4)
    }

    private func legendRow(color: Color, title: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 16, height: 16)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var calendarForDisplay: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale.current
        cal.timeZone = viewModel.displayTimeZone
        return cal
    }

    private var gridCells: [AttendanceGridCell] {
        let cal = calendarForDisplay
        guard
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: viewModel.visibleMonth)),
            let daysInMonth = cal.range(of: .day, in: .month, for: monthStart)?.count
        else {
            return []
        }

        let weekday = cal.component(.weekday, from: monthStart)
        let leading = (weekday - cal.firstWeekday + 7) % 7

        var cells: [AttendanceGridCell] = []
        cells.reserveCapacity(leading + daysInMonth + 7)

        for _ in 0 ..< leading {
            cells.append(.init(id: "p\(cells.count)", kind: .padding))
        }

        for day in 1 ... daysInMonth {
            var comps = cal.dateComponents([.year, .month], from: monthStart)
            comps.day = day
            guard let date = cal.date(from: comps) else { continue }
            cells.append(.init(id: "d\(day)", kind: .day(date, dayNumber: day)))
        }

        while cells.count % 7 != 0 {
            cells.append(.init(id: "t\(cells.count)", kind: .padding))
        }

        return cells
    }

    @ViewBuilder
    private func gridCellView(_ cell: AttendanceGridCell) -> some View {
        switch cell.kind {
        case .padding:
            Color.clear
                .frame(height: 36)

        case let .day(date, dayNumber):
            let cal = calendarForDisplay
            let dayStart = cal.startOfDay(for: date)
            let today = cal.startOfDay(for: Date())
            let attendance = viewModel.calendarData

            let status: AttendanceDayStatus? = {
                if dayStart > today {
                    return nil
                }
                guard let attendance else {
                    return nil
                }
                return attendance.daysByDate[dayStart] ?? .absent
            }()

            Text("\(dayNumber)")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(background(for: status))
                .foregroundStyle(foreground(for: status))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func background(for status: AttendanceDayStatus?) -> Color {
        switch status {
        case .onTime:
            return Color("accent")
        case .late:
            return Color("secondary")
        case .absent:
            return Color(uiColor: .secondarySystemFill)
        case nil:
            return Color.clear
        }
    }

    private func foreground(for status: AttendanceDayStatus?) -> Color {
        switch status {
        case .onTime, .late:
            return .white
        case .absent:
            return .primary
        case nil:
            return .primary
        }
    }
}

private struct AttendanceGridCell: Identifiable {
    let id: String
    let kind: Kind

    enum Kind {
        case padding
        case day(Date, dayNumber: Int)
    }
}

#Preview {
    AttendanceCalendarSection(accessToken: "preview")
        .padding()
}
