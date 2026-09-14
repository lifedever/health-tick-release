#!/usr/bin/env swift
import Foundation
import SQLite3

// Mirrors the merge semantics of Database.importRecords / importSessions
// (multiset match on (timestamp, date) and (date, work_start)) plus the
// VACUUM INTO backup, which has to capture rows still sitting in the WAL.

// MARK: - Test helpers

var testCount = 0
var passCount = 0
var failCount = 0

func assertEqual(_ actual: Int, _ expected: Int, _ msg: String, line: Int = #line) {
    testCount += 1
    if actual == expected {
        passCount += 1
        print("  PASS: \(msg)")
    } else {
        failCount += 1
        print("  FAIL: \(msg) -- expected \(expected), got \(actual) (line \(line))")
    }
}

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

func exec(_ db: OpaquePointer?, _ sql: String) -> Bool {
    sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
}

func queryInt(_ db: OpaquePointer?, _ sql: String) -> Int {
    var stmt: OpaquePointer?
    defer { sqlite3_finalize(stmt) }
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
          sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
    return Int(sqlite3_column_int(stmt, 0))
}

func createTables(_ db: OpaquePointer?) {
    _ = exec(db, """
        CREATE TABLE IF NOT EXISTS records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            date TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            work_start TEXT NOT NULL,
            work_end TEXT,
            work_minutes INTEGER NOT NULL,
            break_start TEXT,
            break_end TEXT,
            break_minutes INTEGER NOT NULL,
            break_actual_seconds INTEGER,
            skipped INTEGER NOT NULL DEFAULT 0,
            daily_goal INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS config (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
    """)
}

func openFileDB(_ path: String) -> OpaquePointer? {
    var db: OpaquePointer?
    sqlite3_open(path, &db)
    _ = exec(db, "PRAGMA journal_mode=WAL")
    createTables(db)
    return db
}

// MARK: - Merge logic under test

func countMap(_ db: OpaquePointer?, _ sql: String) -> [String: Int] {
    var map: [String: Int] = [:]
    var stmt: OpaquePointer?
    if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 0) {
                map[String(cString: c), default: 0] += 1
            }
        }
    }
    sqlite3_finalize(stmt)
    return map
}

struct Summary {
    var added = 0
    var skipped = 0
}

func importRecords(_ db: OpaquePointer?, _ rows: [[String: Any]]) -> Summary {
    var summary = Summary()
    var existing = countMap(db, "SELECT timestamp || char(1) || date FROM records")
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, "INSERT INTO records (timestamp, date) VALUES (?, ?)", -1, &stmt, nil) == SQLITE_OK else {
        return summary
    }
    defer { sqlite3_finalize(stmt) }

    for row in rows {
        guard let ts = row["timestamp"] as? String, let date = row["date"] as? String else { continue }
        let key = ts + "\u{01}" + date
        if let n = existing[key], n > 0 {
            existing[key] = n - 1
            summary.skipped += 1
            continue
        }
        sqlite3_reset(stmt)
        sqlite3_clear_bindings(stmt)
        sqlite3_bind_text(stmt, 1, ts, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, date, -1, SQLITE_TRANSIENT)
        if sqlite3_step(stmt) == SQLITE_DONE { summary.added += 1 }
    }
    return summary
}

func importSessions(_ db: OpaquePointer?, _ rows: [[String: Any]]) -> Summary {
    var summary = Summary()
    var existing = countMap(db, "SELECT date || char(1) || work_start FROM sessions")
    let sql = """
        INSERT INTO sessions (date, work_start, work_end, work_minutes, break_start, break_end,
                              break_minutes, break_actual_seconds, skipped, daily_goal)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return summary }
    defer { sqlite3_finalize(stmt) }

    for row in rows {
        guard let date = row["date"] as? String, let workStart = row["work_start"] as? String else { continue }
        let key = date + "\u{01}" + workStart
        if let n = existing[key], n > 0 {
            existing[key] = n - 1
            summary.skipped += 1
            continue
        }
        sqlite3_reset(stmt)
        sqlite3_clear_bindings(stmt)
        sqlite3_bind_text(stmt, 1, date, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, workStart, -1, SQLITE_TRANSIENT)
        sqlite3_bind_null(stmt, 3)
        sqlite3_bind_int(stmt, 4, Int32(clamping: (row["work_minutes"] as? NSNumber)?.intValue ?? 0))
        sqlite3_bind_null(stmt, 5)
        sqlite3_bind_null(stmt, 6)
        sqlite3_bind_int(stmt, 7, 0)
        sqlite3_bind_null(stmt, 8)
        sqlite3_bind_int(stmt, 9, 0)
        sqlite3_bind_int(stmt, 10, Int32(clamping: (row["daily_goal"] as? NSNumber)?.intValue ?? 8))
        if sqlite3_step(stmt) == SQLITE_DONE { summary.added += 1 }
    }
    return summary
}

func rec(_ ts: String, _ date: String) -> [String: Any] {
    ["timestamp": ts, "date": date]
}

// MARK: - Tests

print("\n=== Import merge ===")

// 1. Fresh database takes everything
do {
    var db: OpaquePointer?
    sqlite3_open(":memory:", &db)
    createTables(db)
    let s = importRecords(db, [
        rec("2026-09-01T10:00:00Z", "2026-09-01"),
        rec("2026-09-01T11:00:00Z", "2026-09-01"),
        rec("2026-09-02T10:00:00Z", "2026-09-02"),
    ])
    assertEqual(s.added, 3, "1. empty db -> all 3 added")
    assertEqual(s.skipped, 0, "1. empty db -> nothing skipped")
    assertEqual(queryInt(db, "SELECT COUNT(*) FROM records"), 3, "1. table holds 3")
    sqlite3_close(db)
}

// 2. Importing the same file twice adds nothing the second time
do {
    var db: OpaquePointer?
    sqlite3_open(":memory:", &db)
    createTables(db)
    let rows = [
        rec("2026-09-01T10:00:00Z", "2026-09-01"),
        rec("2026-09-02T10:00:00Z", "2026-09-02"),
    ]
    _ = importRecords(db, rows)
    let second = importRecords(db, rows)
    assertEqual(second.added, 0, "2. re-import -> 0 added")
    assertEqual(second.skipped, 2, "2. re-import -> 2 skipped")
    assertEqual(queryInt(db, "SELECT COUNT(*) FROM records"), 2, "2. still 2 rows, no duplication")
    sqlite3_close(db)
}

// 3. Partial overlap tops up only the difference
do {
    var db: OpaquePointer?
    sqlite3_open(":memory:", &db)
    createTables(db)
    _ = importRecords(db, [
        rec("2026-09-01T10:00:00Z", "2026-09-01"),
        rec("2026-09-02T10:00:00Z", "2026-09-02"),
    ])
    let s = importRecords(db, [
        rec("2026-09-02T10:00:00Z", "2026-09-02"), // already here
        rec("2026-09-03T10:00:00Z", "2026-09-03"), // new
        rec("2026-09-04T10:00:00Z", "2026-09-04"), // new
    ])
    assertEqual(s.added, 2, "3. partial overlap -> 2 added")
    assertEqual(s.skipped, 1, "3. partial overlap -> 1 skipped")
    assertEqual(queryInt(db, "SELECT COUNT(*) FROM records"), 4, "3. union has 4 rows")
    sqlite3_close(db)
}

// 4. Identical rows are a multiset, not a set: addRecord(count:) writes several
//    rows sharing one timestamp, and all of them have to survive a round trip.
do {
    var db: OpaquePointer?
    sqlite3_open(":memory:", &db)
    createTables(db)
    let burst = Array(repeating: rec("2026-09-01T10:00:00Z", "2026-09-01"), count: 3)
    let s = importRecords(db, burst)
    assertEqual(s.added, 3, "4. 3 identical rows -> all 3 added, not collapsed")
    assertEqual(queryInt(db, "SELECT COUNT(*) FROM records"), 3, "4. table holds all 3")

    let again = importRecords(db, burst)
    assertEqual(again.added, 0, "4. same burst again -> 0 added")
    assertEqual(queryInt(db, "SELECT COUNT(*) FROM records"), 3, "4. still 3, no growth")
    sqlite3_close(db)
}

// 5. Existing 2 vs imported 3 of the same key -> top up by exactly 1
do {
    var db: OpaquePointer?
    sqlite3_open(":memory:", &db)
    createTables(db)
    _ = importRecords(db, Array(repeating: rec("2026-09-01T10:00:00Z", "2026-09-01"), count: 2))
    let s = importRecords(db, Array(repeating: rec("2026-09-01T10:00:00Z", "2026-09-01"), count: 3))
    assertEqual(s.added, 1, "5. 2 existing vs 3 imported -> 1 added")
    assertEqual(s.skipped, 2, "5. 2 existing vs 3 imported -> 2 skipped")
    assertEqual(queryInt(db, "SELECT COUNT(*) FROM records"), 3, "5. multiset max wins")
    sqlite3_close(db)
}

// 6. Sessions key on (date, work_start)
do {
    var db: OpaquePointer?
    sqlite3_open(":memory:", &db)
    createTables(db)
    let rows: [[String: Any]] = [
        ["date": "2026-09-01", "work_start": "2026-09-01T09:00:00Z", "work_minutes": 60, "daily_goal": 8],
        ["date": "2026-09-01", "work_start": "2026-09-01T10:00:00Z", "work_minutes": 60, "daily_goal": 8],
    ]
    let first = importSessions(db, rows)
    assertEqual(first.added, 2, "6. two sessions same day, different start -> both added")
    let second = importSessions(db, rows)
    assertEqual(second.added, 0, "6. re-import -> 0 added")
    assertEqual(queryInt(db, "SELECT COUNT(*) FROM sessions"), 2, "6. still 2 sessions")
    sqlite3_close(db)
}

// 7. Malformed rows are skipped, not fatal
do {
    var db: OpaquePointer?
    sqlite3_open(":memory:", &db)
    createTables(db)
    let s = importRecords(db, [
        rec("2026-09-01T10:00:00Z", "2026-09-01"),
        ["timestamp": "2026-09-02T10:00:00Z"],           // no date
        ["date": "2026-09-03"],                          // no timestamp
        ["timestamp": 12345, "date": "2026-09-04"],      // wrong type
    ])
    assertEqual(s.added, 1, "7. only the well-formed row is added")
    assertEqual(queryInt(db, "SELECT COUNT(*) FROM records"), 1, "7. table holds 1")
    sqlite3_close(db)
}

// 8. Values that would trap a plain Int32(...) are clamped instead
do {
    var db: OpaquePointer?
    sqlite3_open(":memory:", &db)
    createTables(db)
    let s = importSessions(db, [
        ["date": "2026-09-01", "work_start": "2026-09-01T09:00:00Z",
         "work_minutes": 99_999_999_999, "daily_goal": 8],
    ])
    assertEqual(s.added, 1, "8. oversized work_minutes still imports (clamped)")
    assertEqual(queryInt(db, "SELECT work_minutes FROM sessions"), Int(Int32.max), "8. clamped to Int32.max")
    sqlite3_close(db)
}

// 9. A quote in the data must not break the insert (bound, not interpolated)
do {
    var db: OpaquePointer?
    sqlite3_open(":memory:", &db)
    createTables(db)
    let s = importRecords(db, [rec("2026-09-01T10:00:00Z'); DROP TABLE records;--", "2026-09-01")])
    assertEqual(s.added, 1, "9. quote-laden timestamp is stored as data")
    assertEqual(queryInt(db, "SELECT COUNT(*) FROM records"), 1, "9. records table survives")
    sqlite3_close(db)
}

print("\n=== hostile dates (streakDays walks date DESC and breaks on a miss) ===")

// Mirrors Database.isImportableDate
func isImportableDate(_ s: String, notAfter latest: String) -> Bool {
    let b = Array(s.utf8)
    guard b.count == 10 else { return false }
    for (i, ch) in b.enumerated() {
        if i == 4 || i == 7 {
            guard ch == UInt8(ascii: "-") else { return false }
        } else {
            guard ch >= UInt8(ascii: "0"), ch <= UInt8(ascii: "9") else { return false }
        }
    }
    let month = Int(s[s.index(s.startIndex, offsetBy: 5)..<s.index(s.startIndex, offsetBy: 7)]) ?? 0
    let day = Int(s[s.index(s.startIndex, offsetBy: 8)...]) ?? 0
    guard (1...12).contains(month), (1...31).contains(day) else { return false }
    return s <= latest
}

func assertTrue(_ cond: Bool, _ msg: String, line: Int = #line) {
    assertEqual(cond ? 1 : 0, 1, msg, line: line)
}

do {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    let latest = fmt.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
    let today = fmt.string(from: Date())
    let lastYear = fmt.string(from: Calendar.current.date(byAdding: .day, value: -365, to: Date())!)

    assertTrue(isImportableDate(today, notAfter: latest), "11. today is importable")
    assertTrue(isImportableDate(lastYear, notAfter: latest), "11. a year ago is importable")
    assertTrue(isImportableDate(latest, notAfter: latest), "11. tomorrow is allowed (time-zone slack)")
    assertTrue(!isImportableDate("2099-01-01", notAfter: latest), "11. far-future date rejected")
    assertTrue(!isImportableDate("abc", notAfter: latest), "11. garbage rejected")
    assertTrue(!isImportableDate("9999", notAfter: latest), "11. short string rejected")
    assertTrue(!isImportableDate("2026-13-01", notAfter: latest), "11. month 13 rejected")
    assertTrue(!isImportableDate("2026-01-32", notAfter: latest), "11. day 32 rejected")
    assertTrue(!isImportableDate("2026/09/14", notAfter: latest), "11. wrong separator rejected")
    assertTrue(!isImportableDate("", notAfter: latest), "11. empty string rejected")
    assertTrue(!isImportableDate("zzzz-zz-zz", notAfter: latest), "11. letters sorting above digits rejected")
}

// 12. The actual streak damage a bad date would do, if it got in
do {
    var db: OpaquePointer?
    sqlite3_open(":memory:", &db)
    createTables(db)
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    let goal = 3
    // three good days in a row, goal met each day
    for back in 0..<3 {
        let d = fmt.string(from: Calendar.current.date(byAdding: .day, value: -back, to: Date())!)
        _ = importRecords(db, (1...goal).map { rec("ts-\(back)-\($0)", d) })
    }

    func streak(_ db: OpaquePointer?) -> Int {
        var stmt: OpaquePointer?
        let sql = """
            SELECT r.date, r.cnt FROM (SELECT date, COUNT(*) as cnt FROM records GROUP BY date) r
            ORDER BY r.date DESC
            """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        let today = fmt.string(from: Date())
        var s = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            let d = String(cString: sqlite3_column_text(stmt, 0))
            let cnt = Int(sqlite3_column_int(stmt, 1))
            if d == today && cnt < goal { continue }
            if cnt >= goal { s += 1 } else { break }
        }
        return s
    }

    assertEqual(streak(db), 3, "12. baseline streak is 3")

    // inject one under-goal row dated in the far future, as an unvalidated import would
    _ = importRecords(db, [rec("evil", "2099-01-01")])
    assertEqual(streak(db), 0, "12. one future row wipes the streak -- this is what validation prevents")
}

print("\n=== config clamping ===")

// 13. Timer-driving values are pinned to the ranges the settings UI allows
do {
    let ranges: [String: ClosedRange<Int>] = [
        "work_minutes": 1...120,
        "break_seconds": 20...900,
        "daily_goal": 1...20,
        "long_break_interval": 2...8,
        "long_break_seconds": 300...1800,
    ]
    func clamp(_ key: String, _ raw: String) -> String? {
        guard let range = ranges[key] else { return raw }
        guard let n = Int(raw) else { return nil }
        return String(min(max(n, range.lowerBound), range.upperBound))
    }
    assertEqual(Int(clamp("work_minutes", "999999999") ?? "0")!, 120, "13. huge work_minutes clamped to 120")
    assertEqual(Int(clamp("work_minutes", "-5") ?? "0")!, 1, "13. negative work_minutes clamped to 1")
    assertEqual(Int(clamp("work_minutes", "45") ?? "0")!, 45, "13. legit value passes through")
    assertEqual(Int(clamp("break_seconds", "0") ?? "0")!, 20, "13. zero break clamped to 20")
    assertEqual(Int(clamp("daily_goal", "100000") ?? "0")!, 20, "13. huge goal clamped to 20")
    assertTrue(clamp("work_minutes", "abc") == nil, "13. non-numeric ranged value dropped")
    assertTrue(clamp("language", "zh") == "zh", "13. unranged key passes through untouched")
}

print("\n=== VACUUM INTO backup captures the WAL ===")

// 10. The app never checkpoints, so most recent rows live in the -wal file.
//     A plain file copy of data.db loses them; VACUUM INTO must not.
do {
    let tmp = NSTemporaryDirectory() + "ht-import-test-\(UUID().uuidString)"
    try? FileManager.default.createDirectory(atPath: tmp, withIntermediateDirectories: true)
    let dbPath = tmp + "/data.db"
    let db = openFileDB(dbPath)

    // Rows written but never checkpointed
    _ = importRecords(db, (1...20).map { rec("2026-09-01T10:00:\(String(format: "%02d", $0))Z", "2026-09-01") })

    // (a) naive copy of the main file only
    let naivePath = tmp + "/naive.db"
    try? FileManager.default.copyItem(atPath: dbPath, toPath: naivePath)
    var naiveDB: OpaquePointer?
    sqlite3_open(naivePath, &naiveDB)
    let naiveCount = queryInt(naiveDB, "SELECT COUNT(*) FROM records")
    sqlite3_close(naiveDB)

    // (b) VACUUM INTO, the path backupDatabase() takes
    let backupPath = tmp + "/backup.db"
    let ok = exec(db, "VACUUM INTO '\(backupPath)'")
    var backupDB: OpaquePointer?
    sqlite3_open(backupPath, &backupDB)
    let backupCount = queryInt(backupDB, "SELECT COUNT(*) FROM records")
    sqlite3_close(backupDB)

    assertEqual(ok ? 1 : 0, 1, "10. VACUUM INTO succeeds")
    assertEqual(backupCount, 20, "10. backup has all 20 rows (WAL folded in)")
    assertEqual(naiveCount, 0, "10. plain copy of data.db alone has 0 -- the bug this avoids")

    sqlite3_close(db)
    try? FileManager.default.removeItem(atPath: tmp)
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
