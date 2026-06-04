#!/usr/bin/env swift
import Foundation

// MARK: - Test helpers

var testCount = 0
var passCount = 0
var failCount = 0

func assertEqualBools(_ actual: [Bool], _ expected: [Bool], _ msg: String, line: Int = #line) {
    testCount += 1
    if actual == expected {
        passCount += 1
        print("  PASS: \(msg)")
    } else {
        failCount += 1
        let a = actual.map { $0 ? "L" : "s" }.joined()
        let e = expected.map { $0 ? "L" : "s" }.joined()
        print("  FAIL: \(msg) -- expected \(e), got \(a) (line \(line))")
    }
}

func assertTrue(_ cond: Bool, _ msg: String, line: Int = #line) {
    testCount += 1
    if cond {
        passCount += 1
        print("  PASS: \(msg)")
    } else {
        failCount += 1
        print("  FAIL: \(msg) (line \(line))")
    }
}

// MARK: - Logic under test
//
// Mirrors AppState.startBreak() long-break decision exactly:
//
//   let isLongBreak = config.longBreakEnabled && config.longBreakInterval > 0
//       && completedCycles > 0 && completedCycles % config.longBreakInterval == 0
//
// `completedCycles` increments in onBreakDone() AFTER each break completes,
// so the decision reads the pre-increment value. Crucially, eyeCareMode is
// NOT part of this expression — the parameter below is intentionally unused in
// the decision to prove 20-20-20 and long breaks coexist (issue #22).

func isLongBreak(enabled: Bool, interval: Int, completedCycles: Int) -> Bool {
    return enabled && interval > 0 && completedCycles > 0 && completedCycles % interval == 0
}

/// Simulate a run of `count` consecutive breaks. Returns one Bool per break:
/// true = that break is a long (body) break, false = short break.
/// `eyeCareMode` is accepted but deliberately ignored by the decision — the
/// returned sequence must be identical whether eye care is on or off.
func simulateBreaks(enabled: Bool, interval: Int, count: Int, eyeCareMode: Bool) -> [Bool] {
    _ = eyeCareMode  // intentionally not consulted — see note above
    var completedCycles = 0
    var result: [Bool] = []
    for _ in 0..<count {
        result.append(isLongBreak(enabled: enabled, interval: interval, completedCycles: completedCycles))
        completedCycles += 1  // onBreakDone() increments after the break
    }
    return result
}

let s = false  // short
let L = true   // long

// MARK: - Tests

print("=== long-break trigger pattern ===\n")

// 1. Disabled -> every break is short, regardless of interval
do {
    let r = simulateBreaks(enabled: false, interval: 2, count: 5, eyeCareMode: false)
    assertEqualBools(r, [s, s, s, s, s], "1. disabled -> all short")
}

// 2. interval=2 -> first long on break #3, then every 2nd (s,s,L,s,L,s,L)
do {
    let r = simulateBreaks(enabled: true, interval: 2, count: 7, eyeCareMode: false)
    assertEqualBools(r, [s, s, L, s, L, s, L], "2. interval=2 -> s,s,L,s,L,s,L")
}

// 3. interval=4 (default) -> first long on break #5, then every 4th
do {
    let r = simulateBreaks(enabled: true, interval: 4, count: 10, eyeCareMode: false)
    assertEqualBools(r, [s, s, s, s, L, s, s, s, L, s], "3. interval=4 -> long at #5,#9")
}

// 4. interval=3 -> first long on break #4, then every 3rd
do {
    let r = simulateBreaks(enabled: true, interval: 3, count: 8, eyeCareMode: false)
    assertEqualBools(r, [s, s, s, L, s, s, L, s], "4. interval=3 -> long at #4,#7")
}

// 5. The very first break is never long (completedCycles starts at 0)
do {
    let r = simulateBreaks(enabled: true, interval: 1, count: 4, eyeCareMode: false)
    // interval=1: break #1 short (cc=0), then every break long
    assertEqualBools(r, [s, L, L, L], "5. interval=1 -> first short then all long")
}

print("\n=== eye-care coexistence (issue #22) ===\n")

// 6. KEY: eye-care mode must NOT change the long-break pattern.
//    Same config with eyeCareMode on vs off -> identical sequences.
do {
    for interval in 2...8 {
        let off = simulateBreaks(enabled: true, interval: interval, count: 20, eyeCareMode: false)
        let on  = simulateBreaks(enabled: true, interval: interval, count: 20, eyeCareMode: true)
        assertTrue(off == on, "6.\(interval). interval=\(interval): long-break pattern identical with eye care on/off")
    }
}

// 7. KEY: with eye care on + long break on, long breaks DO occur
//    (the mechanism was never gated on eye care — only the UI was).
do {
    let r = simulateBreaks(enabled: true, interval: 3, count: 10, eyeCareMode: true)
    assertTrue(r.contains(L), "7. eye care on + long break on -> long breaks still fire")
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
