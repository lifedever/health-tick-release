#!/usr/bin/env swift
import Foundation

// MARK: - Test helpers

var testCount = 0
var passCount = 0
var failCount = 0

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ msg: String, line: Int = #line) {
    testCount += 1
    if actual == expected {
        passCount += 1
        print("  PASS: \(msg)")
    } else {
        failCount += 1
        print("  FAIL: \(msg) -- expected \(expected), got \(actual) (line \(line))")
    }
}

// MARK: - Mirror of production types (HolidayCalendar.swift)
//
// These mirror the production logic 1:1; if production behavior changes,
// update this test mirror so the regression net stays accurate.

enum DayKind: String { case rest, makeupWork, defaultWork, defaultOff }

extension DayKind {
    var countsAsWorkDay: Bool {
        switch self {
        case .makeupWork, .defaultWork: return true
        case .rest, .defaultOff: return false
        }
    }
}

let chinaTZ = TimeZone(identifier: "Asia/Shanghai")!

func dateKey(for date: Date) -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.timeZone = chinaTZ
    fmt.calendar = Calendar(identifier: .gregorian)
    return fmt.string(from: date)
}

func holidayDayKind(
    at date: Date,
    holidaySyncEnabled: Bool,
    holidayCalendar: [String: Bool],
    workDays: Set<Int>
) -> DayKind {
    let key = dateKey(for: date)
    if holidaySyncEnabled, let explicit = holidayCalendar[key] {
        return explicit ? .makeupWork : .rest
    }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = chinaTZ
    cal.firstWeekday = 1
    let weekday = cal.component(.weekday, from: date)
    return workDays.contains(weekday) ? .defaultWork : .defaultOff
}

func isWorkDay(
    at date: Date,
    holidaySyncEnabled: Bool,
    holidayCalendar: [String: Bool],
    workDays: Set<Int>
) -> Bool {
    holidayDayKind(at: date, holidaySyncEnabled: holidaySyncEnabled,
                   holidayCalendar: holidayCalendar, workDays: workDays).countsAsWorkDay
}

// MARK: - Fixtures

func dateAt(_ ymd: String, hour: Int = 12) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = chinaTZ
    let parts = ymd.split(separator: "-").compactMap { Int($0) }
    var comps = DateComponents()
    comps.year = parts[0]; comps.month = parts[1]; comps.day = parts[2]
    comps.hour = hour
    return cal.date(from: comps)!
}

let mondayToFriday: Set<Int> = [2, 3, 4, 5, 6]  // Calendar.weekday: 1=Sun ... 7=Sat

// Sample timor.tech-shaped calendar:
//   2026-01-01 (Thu) 元旦放假
//   2026-02-17 (Tue) 春节放假
//   2026-02-22 (Sun) 春节后调休补班
//   2026-05-01 (Fri) 劳动节放假
//   2026-04-26 (Sun) 劳动节前调休补班
//   2026-10-01 (Thu) 国庆放假
//   2026-10-11 (Sun) 国庆后调休补班
let sampleCalendar: [String: Bool] = [
    "2026-01-01": false,
    "2026-02-17": false,
    "2026-02-22": true,
    "2026-05-01": false,
    "2026-04-26": true,
    "2026-10-01": false,
    "2026-10-11": true,
]

print("=== Holiday work-day logic ===\n")

// 1. Sync OFF: weekday-only rule applies
do {
    let mon = dateAt("2026-05-04")  // Monday
    let sat = dateAt("2026-05-02")  // Saturday
    assertEqual(
        isWorkDay(at: mon, holidaySyncEnabled: false, holidayCalendar: sampleCalendar, workDays: mondayToFriday),
        true, "1a. sync OFF: Monday is workday"
    )
    assertEqual(
        isWorkDay(at: sat, holidaySyncEnabled: false, holidayCalendar: sampleCalendar, workDays: mondayToFriday),
        false, "1b. sync OFF: Saturday is rest"
    )
}

// 2. Sync OFF + calendar populated: calendar IGNORED (toggle gates the override)
do {
    let laborDay = dateAt("2026-05-01")  // Friday, in table as 放假
    assertEqual(
        isWorkDay(at: laborDay, holidaySyncEnabled: false, holidayCalendar: sampleCalendar, workDays: mondayToFriday),
        true, "2. sync OFF: Labor Day Friday still counts as workday (override skipped)"
    )
}

// 3. Sync ON + date in table as 放假 → rest, regardless of weekday
do {
    let newYear = dateAt("2026-01-01")  // Thursday
    let laborDay = dateAt("2026-05-01")  // Friday
    let nationalDay = dateAt("2026-10-01")  // Thursday
    for (date, label) in [(newYear, "元旦"), (laborDay, "劳动节"), (nationalDay, "国庆")] {
        assertEqual(
            isWorkDay(at: date, holidaySyncEnabled: true, holidayCalendar: sampleCalendar, workDays: mondayToFriday),
            false, "3. sync ON: \(label) (weekday) becomes rest"
        )
    }
}

// 4. Sync ON + date in table as 调休 → workday, even if Sunday
do {
    let makeupBeforeLaborDay = dateAt("2026-04-26")  // Sunday
    let makeupAfterNationalDay = dateAt("2026-10-11")  // Sunday
    assertEqual(
        isWorkDay(at: makeupBeforeLaborDay, holidaySyncEnabled: true, holidayCalendar: sampleCalendar, workDays: mondayToFriday),
        true, "4a. sync ON: 4-26 Sunday becomes workday (劳动节调休)"
    )
    assertEqual(
        isWorkDay(at: makeupAfterNationalDay, holidaySyncEnabled: true, holidayCalendar: sampleCalendar, workDays: mondayToFriday),
        true, "4b. sync ON: 10-11 Sunday becomes workday (国庆调休)"
    )
}

// 5. Sync ON + date NOT in table → falls back to weekday rule
do {
    let normalTue = dateAt("2026-05-05")  // Tuesday, not in table
    let normalSun = dateAt("2026-05-03")  // Sunday, not in table
    assertEqual(
        isWorkDay(at: normalTue, holidaySyncEnabled: true, holidayCalendar: sampleCalendar, workDays: mondayToFriday),
        true, "5a. sync ON, off-calendar Tuesday → workday (weekday fallback)"
    )
    assertEqual(
        isWorkDay(at: normalSun, holidaySyncEnabled: true, holidayCalendar: sampleCalendar, workDays: mondayToFriday),
        false, "5b. sync ON, off-calendar Sunday → rest (weekday fallback)"
    )
}

// 6. User customized workDays (e.g., 4-day week Tue-Fri) — holiday still overrides
do {
    let tueFri: Set<Int> = [3, 4, 5, 6]  // skip Monday
    let monday = dateAt("2026-05-04")
    let laborDayFri = dateAt("2026-05-01")
    assertEqual(
        isWorkDay(at: monday, holidaySyncEnabled: true, holidayCalendar: sampleCalendar, workDays: tueFri),
        false, "6a. custom Mon-off, sync ON: Monday is rest by weekday fallback"
    )
    assertEqual(
        isWorkDay(at: laborDayFri, holidaySyncEnabled: true, holidayCalendar: sampleCalendar, workDays: tueFri),
        false, "6b. custom workdays + sync ON: holiday in table beats weekday → rest"
    )
}

// 7. dateKey timezone: a moment that's 2026-05-01 23:30 UTC is already 2026-05-02 in Shanghai
do {
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let comps = DateComponents(timeZone: TimeZone(identifier: "UTC"),
                               year: 2026, month: 5, day: 1, hour: 23, minute: 30)
    let lateUTC = utc.date(from: comps)!
    assertEqual(dateKey(for: lateUTC), "2026-05-02",
                "7. dateKey uses Asia/Shanghai (UTC 23:30 → next CN day)")
}

// 8. holidayDayKind labels (not just isWorkDay) — UI relies on the four-way split
do {
    let labor = dateAt("2026-05-01")
    let makeup = dateAt("2026-04-26")
    let normalMon = dateAt("2026-05-04")
    let normalSat = dateAt("2026-05-02")
    assertEqual(
        holidayDayKind(at: labor, holidaySyncEnabled: true, holidayCalendar: sampleCalendar, workDays: mondayToFriday).rawValue,
        "rest", "8a. Labor Day → rest"
    )
    assertEqual(
        holidayDayKind(at: makeup, holidaySyncEnabled: true, holidayCalendar: sampleCalendar, workDays: mondayToFriday).rawValue,
        "makeupWork", "8b. 4-26 Sunday → makeupWork"
    )
    assertEqual(
        holidayDayKind(at: normalMon, holidaySyncEnabled: true, holidayCalendar: sampleCalendar, workDays: mondayToFriday).rawValue,
        "defaultWork", "8c. normal Monday → defaultWork"
    )
    assertEqual(
        holidayDayKind(at: normalSat, holidaySyncEnabled: true, holidayCalendar: sampleCalendar, workDays: mondayToFriday).rawValue,
        "defaultOff", "8d. normal Saturday → defaultOff"
    )
}

// MARK: - Summary

print("\n============================")
print("Total: \(testCount), Passed: \(passCount), Failed: \(failCount)")
if failCount > 0 {
    print("SOME TESTS FAILED!")
    exit(1)
} else {
    print("ALL TESTS PASSED!")
}
