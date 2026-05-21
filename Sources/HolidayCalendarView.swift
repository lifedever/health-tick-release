import SwiftUI

struct HolidayCalendarView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var displayedYear: Int
    @State private var displayedMonth: Int
    @State private var selectedDate: Date?

    init(initialDate: Date = Date()) {
        let cal = HolidayCalendarService.chinaCalendar
        let y = cal.component(.year, from: initialDate)
        let m = cal.component(.month, from: initialDate)
        _displayedYear = State(initialValue: y)
        _displayedMonth = State(initialValue: m)
        _selectedDate = State(initialValue: cal.startOfDay(for: initialDate))
    }

    private var cal: Calendar { HolidayCalendarService.chinaCalendar }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if state.config.holidayCalendar.isEmpty {
                emptyState
            } else {
                calendarBody
            }
        }
        .frame(width: 420)
        .padding(.bottom, 12)
    }

    private var header: some View {
        HStack {
            Text(L.holidayCalendarTitle)
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(L.holidayCalendarEmpty)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var calendarBody: some View {
        VStack(spacing: 12) {
            monthNavigator
            weekdayHeader
            monthGrid
            legendView
            if let selectedDate {
                dayDetail(for: selectedDate)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var monthNavigator: some View {
        HStack {
            Button { shiftMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            Text(L.holidayMonthTitle(year: displayedYear, month: displayedMonth))
                .font(.callout.weight(.semibold))
                .frame(minWidth: 120)

            Button { shiftMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)

            Spacer()

            if !availableYears.isEmpty {
                Picker("", selection: $displayedYear) {
                    ForEach(availableYears, id: \.self) { y in
                        Text(L.isZhAccess ? "\(y)年" : "\(y)").tag(y)
                    }
                }
                .labelsHidden()
                .frame(width: 88)
                .onChange(of: displayedYear) { _, newYear in
                    clampMonthToYear(newYear)
                }
            }
        }
    }

    private var weekdayHeader: some View {
        let symbols = L.isZhAccess
            ? [L.sunday, L.monday, L.tuesday, L.wednesday, L.thursday, L.friday, L.saturday]
            : cal.shortWeekdaySymbols
        return HStack(spacing: 4) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, sym in
                Text(sym)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let cells = monthCells(year: displayedYear, month: displayedMonth)
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
            spacing: 4
        ) {
            ForEach(cells, id: \.id) { cell in
                dayCell(cell)
            }
        }
    }

    private func dayCell(_ cell: MonthCell) -> some View {
        Group {
            if let date = cell.date {
                let kind = state.config.holidayDayKind(at: date)
                let isSelected = selectedDate.map { cal.isDate($0, inSameDayAs: date) } ?? false
                let inOverride = state.config.holidayCalendar[AppConfig.dateKey(for: date)] != nil

                Button {
                    selectedDate = date
                } label: {
                    VStack(spacing: 2) {
                        Text("\(cal.component(.day, from: date))")
                            .font(.system(size: 12, weight: inOverride ? .bold : .regular))
                        if inOverride, state.config.holidayLabel(for: date) != nil {
                            Circle()
                                .fill(kind.color)
                                .frame(width: 4, height: 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .foregroundStyle(cellTextColor(kind: kind, date: date))
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(dayBackground(kind: kind, inOverride: inOverride, isSelected: isSelected))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .help(dayHelp(date: date, kind: kind))
            } else {
                Color.clear
                    .frame(height: 36)
            }
        }
    }

    private var legendView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            legendItem(kind: .rest)
            legendItem(kind: .makeupWork)
            legendItem(kind: .defaultWork)
            legendItem(kind: .defaultOff)
        }
        .padding(.top, 4)
    }

    private func legendItem(kind: HolidayDayKind) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(kind.color.opacity(kind == .defaultOff ? 1 : 0.85))
                .frame(width: 12, height: 12)
            Text(kind.label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private func dayDetail(for date: Date) -> some View {
        let kind = state.config.holidayDayKind(at: date)
        let inOverride = state.config.holidayCalendar[AppConfig.dateKey(for: date)] != nil
        let fmt = DateFormatter()
        fmt.dateStyle = .full
        fmt.timeStyle = .none
        fmt.calendar = cal
        fmt.timeZone = HolidayCalendarService.chinaTimeZone
        fmt.locale = Locale(identifier: L.isZhAccess ? "zh_CN" : "en_US")

        return VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text(fmt.string(from: date))
                .font(.callout.weight(.semibold))
            HStack(spacing: 8) {
                Text(kind.label)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(kind.color.opacity(0.2), in: Capsule())
                Text(kind.countsAsWorkDay ? L.holidayCountsAsWork : L.holidayCountsAsOff)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let name = state.config.holidayLabel(for: date) {
                Text(name)
                    .font(.callout)
            }
            Text(inOverride ? L.holidayInOfficialSchedule : L.holidayByWeekday)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private var availableYears: [Int] {
        let synced = state.config.holidayCalendarYears()
        if synced.isEmpty {
            let y = cal.component(.year, from: Date())
            return [y, y + 1]
        }
        return synced
    }

    private func shiftMonth(by delta: Int) {
        let comps = DateComponents(year: displayedYear, month: displayedMonth, day: 1)
        guard let start = cal.date(from: comps),
              let next = cal.date(byAdding: .month, value: delta, to: start) else { return }
        displayedYear = cal.component(.year, from: next)
        displayedMonth = cal.component(.month, from: next)
    }

    private func clampMonthToYear(_ year: Int) {
        if !availableYears.contains(year), let first = availableYears.first {
            displayedYear = first
        }
    }

    private struct MonthCell: Identifiable {
        let id: Int
        let date: Date?
    }

    private func monthCells(year: Int, month: Int) -> [MonthCell] {
        var comps = DateComponents(year: year, month: month, day: 1)
        guard let firstOfMonth = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return [] }

        let leading = cal.component(.weekday, from: firstOfMonth) - cal.firstWeekday
        let leadingBlanks = (leading + 7) % 7
        var cells: [MonthCell] = []
        var idx = 0
        for _ in 0..<leadingBlanks {
            cells.append(MonthCell(id: idx, date: nil))
            idx += 1
        }
        for day in range {
            comps.day = day
            if let date = cal.date(from: comps) {
                cells.append(MonthCell(id: idx, date: date))
            }
            idx += 1
        }
        while cells.count % 7 != 0 {
            cells.append(MonthCell(id: idx, date: nil))
            idx += 1
        }
        return cells
    }

    private func dayBackground(kind: HolidayDayKind, inOverride: Bool, isSelected: Bool) -> Color {
        if isSelected { return kind.color.opacity(0.35) }
        if inOverride { return kind.color.opacity(0.22) }
        switch kind {
        case .defaultWork: return Color.green.opacity(0.08)
        case .defaultOff: return Color.secondary.opacity(0.06)
        default: return .clear
        }
    }

    private func cellTextColor(kind: HolidayDayKind, date: Date) -> Color {
        if state.config.holidayCalendar[AppConfig.dateKey(for: date)] != nil {
            return .primary
        }
        return kind == .defaultOff ? .secondary : .primary
    }

    private func dayHelp(date: Date, kind: HolidayDayKind) -> String {
        var parts = [kind.label]
        if let name = state.config.holidayLabel(for: date) { parts.append(name) }
        parts.append(kind.countsAsWorkDay ? L.holidayCountsAsWork : L.holidayCountsAsOff)
        return parts.joined(separator: " · ")
    }
}
