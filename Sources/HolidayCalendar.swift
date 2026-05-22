import Foundation
import SwiftUI

// MARK: - China national holiday API (timor.tech)

private struct TimorHolidayDay: Codable {
    let holiday: Bool
    let date: String
    let name: String?
}

struct HolidaySyncResult {
    /// "yyyy-MM-dd" → true = 调休上班，false = 放假
    var workDayOverrides: [String: Bool]
    /// 国务院安排中的日期名称（仅覆盖表内日期）
    var labels: [String: String]
}

enum HolidayDayKind: Equatable {
    case rest
    case makeupWork
    case defaultWork
    case defaultOff

    var label: String {
        switch self {
        case .rest: return L.holidayKindRest
        case .makeupWork: return L.holidayKindMakeup
        case .defaultWork: return L.holidayKindDefaultWork
        case .defaultOff: return L.holidayKindDefaultOff
        }
    }

    var color: Color {
        switch self {
        case .rest: return .orange
        case .makeupWork: return .blue
        case .defaultWork: return .green.opacity(0.75)
        case .defaultOff: return Color.secondary.opacity(0.35)
        }
    }
}

private struct TimorYearResponse: Codable {
    let code: Int
    let holiday: [String: TimorHolidayDay]?
}

enum HolidayCalendarService {
    static let chinaTimeZone = TimeZone(identifier: "Asia/Shanghai")!

    private static let apiBase = "https://timor.tech/api/holiday/year"

    /// Fetches current and next year, merges holiday overrides and labels.
    static func syncNationalHolidays() async throws -> HolidaySyncResult {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = chinaTimeZone
        let year = cal.component(.year, from: Date())
        var workDayOverrides: [String: Bool] = [:]
        var labels: [String: String] = [:]
        for y in [year, year + 1] {
            let partial = try await fetchYear(y)
            for (k, v) in partial.workDayOverrides { workDayOverrides[k] = v }
            for (k, v) in partial.labels { labels[k] = v }
        }
        return HolidaySyncResult(workDayOverrides: workDayOverrides, labels: labels)
    }

    static var chinaCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = chinaTimeZone
        cal.firstWeekday = 1
        cal.locale = Locale(identifier: L.isZhAccess ? "zh_CN" : "en_US_POSIX")
        return cal
    }

    static let iso8601: ISO8601DateFormatter = ISO8601DateFormatter()

    private static func fetchYear(_ year: Int) async throws -> HolidaySyncResult {
        guard let url = URL(string: "\(apiBase)/\(year)") else {
            throw HolidayCalendarError.invalidURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw HolidayCalendarError.network
        }

        let decoded = try JSONDecoder().decode(TimorYearResponse.self, from: data)
        guard decoded.code == 0, let days = decoded.holiday else {
            throw HolidayCalendarError.api(decoded.code)
        }

        var workDayOverrides: [String: Bool] = [:]
        var labels: [String: String] = [:]
        for (_, entry) in days {
            // holiday: true = 放假；false = 调休上班
            workDayOverrides[entry.date] = !entry.holiday
            if let name = entry.name, !name.isEmpty {
                labels[entry.date] = name
            }
        }
        return HolidaySyncResult(workDayOverrides: workDayOverrides, labels: labels)
    }
}

enum HolidayCalendarError: LocalizedError {
    case invalidURL
    case network
    case api(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return L.holidaySyncErrorInvalid
        case .network: return L.holidaySyncErrorNetwork
        case .api: return L.holidaySyncErrorAPI
        }
    }
}

// MARK: - AppConfig work-day resolution

extension AppConfig {
    static func dateKey(for date: Date, timeZone: TimeZone = HolidayCalendarService.chinaTimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter.string(from: date)
    }

    /// Whether the given calendar day counts as a work day for quiet-hour / timer logic.
    func isWorkDay(at date: Date) -> Bool {
        holidayDayKind(at: date).countsAsWorkDay
    }

    func holidayDayKind(at date: Date) -> HolidayDayKind {
        let key = Self.dateKey(for: date)
        if holidaySyncEnabled, let explicit = holidayCalendar[key] {
            return explicit ? .makeupWork : .rest
        }
        let weekday = HolidayCalendarService.chinaCalendar.component(.weekday, from: date)
        return workDays.contains(weekday) ? .defaultWork : .defaultOff
    }

    func holidayLabel(for date: Date) -> String? {
        let key = Self.dateKey(for: date)
        return holidayCalendarNames[key]
    }

    /// Sorted unique years present in synced holiday data.
    func holidayCalendarYears() -> [Int] {
        let years = holidayCalendar.keys.compactMap { key -> Int? in
            guard key.count >= 4, let y = Int(key.prefix(4)) else { return nil }
            return y
        }
        return Array(Set(years)).sorted()
    }
}

extension HolidayDayKind {
    var countsAsWorkDay: Bool {
        switch self {
        case .makeupWork, .defaultWork: return true
        case .rest, .defaultOff: return false
        }
    }
}
