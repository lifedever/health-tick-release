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

// MARK: - Mirror of production logic (AppState.checkQuietHours + maybeShowOffWorkSummary)
//
// Mirrors the off-work-summary trigger 1:1. If the production edge-detection / dedup logic
// changes, update this mirror so the regression net stays accurate.
//
// Production: the false→true edge of the "outside_work_hours" quiet reason fires the summary,
// gated by enabled toggles, work-day, and once-per-day dedup. The first check after launch only
// establishes the baseline (lastOutsideWorkActive starts nil) so launching after work hours
// never replays a stale summary.

struct OffWorkTrigger {
    var offWorkSummaryEnabled: Bool
    var workHoursEnabled: Bool
    var lastOutsideWorkActive: Bool? = nil
    var offWorkSummaryShownDate: String? = nil

    /// Returns true if the summary fires on this check.
    mutating func check(outsideNow: Bool, today: String, isWorkDay: Bool) -> Bool {
        var fired = false
        if let wasOutside = lastOutsideWorkActive, !wasOutside, outsideNow {
            fired = maybeShow(today: today, isWorkDay: isWorkDay)
        }
        lastOutsideWorkActive = outsideNow
        return fired
    }

    private mutating func maybeShow(today: String, isWorkDay: Bool) -> Bool {
        guard offWorkSummaryEnabled, workHoursEnabled else { return false }
        guard isWorkDay else { return false }
        guard offWorkSummaryShownDate != today else { return false }
        offWorkSummaryShownDate = today
        return true
    }
}

// MARK: - Tests

print("=== Off-Work Summary Trigger ===\n")

// Stale startup: app launched AFTER work hours — first check sees outsideNow=true but must not fire.
do {
    var t = OffWorkTrigger(offWorkSummaryEnabled: true, workHoursEnabled: true)
    let fired = t.check(outsideNow: true, today: "2026-06-22", isWorkDay: true)
    assertEqual(fired, false, "first check after launch (stale startup) never fires")
}

// Normal flow: working (false) then work hours end (true) → fires once.
do {
    var t = OffWorkTrigger(offWorkSummaryEnabled: true, workHoursEnabled: true)
    _ = t.check(outsideNow: false, today: "2026-06-22", isWorkDay: true)   // baseline: in work hours
    let fired = t.check(outsideNow: true, today: "2026-06-22", isWorkDay: true)
    assertEqual(fired, true, "false→true edge (work just ended) fires")
}

// Steady state after firing: repeated true checks (incl. overtime) do not re-fire same day.
do {
    var t = OffWorkTrigger(offWorkSummaryEnabled: true, workHoursEnabled: true)
    _ = t.check(outsideNow: false, today: "2026-06-22", isWorkDay: true)
    _ = t.check(outsideNow: true, today: "2026-06-22", isWorkDay: true)    // fires
    let again = t.check(outsideNow: true, today: "2026-06-22", isWorkDay: true)
    assertEqual(again, false, "true→true steady state (overtime) does not re-fire")
}

// Once per day: a second false→true edge on the same day is deduped.
do {
    var t = OffWorkTrigger(offWorkSummaryEnabled: true, workHoursEnabled: true)
    _ = t.check(outsideNow: false, today: "2026-06-22", isWorkDay: true)
    let first = t.check(outsideNow: true, today: "2026-06-22", isWorkDay: true)
    _ = t.check(outsideNow: false, today: "2026-06-22", isWorkDay: true)   // back inside (e.g. config change)
    let second = t.check(outsideNow: true, today: "2026-06-22", isWorkDay: true)
    assertEqual(first, true, "first edge of the day fires")
    assertEqual(second, false, "second edge same day is deduped")
}

// New day: fires again after the date rolls over.
do {
    var t = OffWorkTrigger(offWorkSummaryEnabled: true, workHoursEnabled: true)
    _ = t.check(outsideNow: false, today: "2026-06-22", isWorkDay: true)
    _ = t.check(outsideNow: true, today: "2026-06-22", isWorkDay: true)    // fires day 1
    _ = t.check(outsideNow: false, today: "2026-06-23", isWorkDay: true)   // day 2 in work hours
    let day2 = t.check(outsideNow: true, today: "2026-06-23", isWorkDay: true)
    assertEqual(day2, true, "fires again on a new work day")
}

// Non-work day: edge present but must not fire (weekend / holiday).
do {
    var t = OffWorkTrigger(offWorkSummaryEnabled: true, workHoursEnabled: true)
    _ = t.check(outsideNow: false, today: "2026-06-27", isWorkDay: false)
    let fired = t.check(outsideNow: true, today: "2026-06-27", isWorkDay: false)
    assertEqual(fired, false, "non-work day never fires")
}

// Toggle off: never fires.
do {
    var t = OffWorkTrigger(offWorkSummaryEnabled: false, workHoursEnabled: true)
    _ = t.check(outsideNow: false, today: "2026-06-22", isWorkDay: true)
    let fired = t.check(outsideNow: true, today: "2026-06-22", isWorkDay: true)
    assertEqual(fired, false, "summary toggle off never fires")
}

// Work hours disabled: never fires.
do {
    var t = OffWorkTrigger(offWorkSummaryEnabled: true, workHoursEnabled: false)
    _ = t.check(outsideNow: false, today: "2026-06-22", isWorkDay: true)
    let fired = t.check(outsideNow: true, today: "2026-06-22", isWorkDay: true)
    assertEqual(fired, false, "work hours disabled never fires")
}

// MARK: - Summary

print("\n=== Results ===")
print("Total: \(testCount), Passed: \(passCount), Failed: \(failCount)")
exit(failCount == 0 ? 0 : 1)
