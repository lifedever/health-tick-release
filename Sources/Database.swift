import Foundation
import SQLite3

final class Database {
    static let shared = Database()
    private var db: OpaquePointer?
    private let dbPath: String

    private init() {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.lifedever.healthtick"
        let suffix = bundleId.hasSuffix(".dev") ? "-dev" : ""
        let dir = NSHomeDirectory() + "/.health-tick\(suffix)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        dbPath = dir + "/data.db"
        open()
        createTables()
    }

    init(path: String) {
        dbPath = path
        open()
        createTables()
    }

    func addRecord(date: String, count: Int = 1) {
        let now = ISO8601DateFormatter().string(from: Date())
        for _ in 0..<count {
            exec("INSERT INTO records (timestamp, date) VALUES ('\(now)', '\(date)')")
        }
    }

    private func open() {
        sqlite3_open(dbPath, &db)
        exec("PRAGMA journal_mode=WAL")
    }

    private func createTables() {
        exec("""
            CREATE TABLE IF NOT EXISTS records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                date TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_records_date ON records(date);
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
            CREATE INDEX IF NOT EXISTS idx_sessions_date ON sessions(date);
            CREATE TABLE IF NOT EXISTS config (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
        """)
        let defaults: [(String, String)] = [
            ("work_minutes", "60"),
            ("break_seconds", "120"),
            ("eye_care_mode", "0"),
            ("saved_work_minutes", "60"),
            ("saved_break_seconds", "120"),
            ("saved_break_confirm", "1"),
            ("daily_goal", "8"),
            ("reminders", "[]"),
            ("sound_enabled", "1"),
            ("break_detect_sound", "0"),
            ("break_position", "menu_window"),
            ("break_confirm", "1"),
            ("alert_sound", "Glass"),
            ("alert_sound_repeat_count", "1"),
            ("break_detect_sound_name", "Tink"),
            ("language", "system"),
            ("appearance", "system"),
            ("quiet_hours", "[]"),
            ("work_days", "[2,3,4,5,6]"),
            ("onboarding_completed", "0"),
        ]
        for (key, value) in defaults {
            exec("INSERT OR IGNORE INTO config (key, value) VALUES ('\(key)', '\(value)')")
        }
    }

    @discardableResult
    private func exec(_ sql: String) -> Bool {
        sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }

    // MARK: - Config

    func loadConfig() -> AppConfig {
        var config = AppConfig()
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT key, value FROM config", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let key = String(cString: sqlite3_column_text(stmt, 0))
                let value = String(cString: sqlite3_column_text(stmt, 1))
                switch key {
                case "work_minutes": config.workMinutes = Int(value) ?? 60
                case "break_minutes":
                    // Migration: old key → convert minutes to seconds
                    config.breakSeconds = (Int(value) ?? 2) * 60
                case "break_seconds": config.breakSeconds = Int(value) ?? 120
                case "eye_care_mode": config.eyeCareMode = value == "1"
                case "saved_work_minutes": config.savedWorkMinutes = Int(value) ?? 60
                case "saved_break_seconds": config.savedBreakSeconds = Int(value) ?? 120
                case "saved_break_confirm": config.savedBreakConfirm = value == "1"
                case "daily_goal": config.dailyGoal = Int(value) ?? 8
                case "reminders":
                    if let data = value.data(using: .utf8),
                       let arr = try? JSONDecoder().decode([String].self, from: data),
                       !arr.isEmpty {
                        config.reminders = arr
                    }
                case "sound_enabled": config.soundEnabled = value == "1"
                case "break_detect_sound": config.breakDetectSound = value == "1"
                case "break_position": config.breakPosition = BreakPosition(rawValue: value) ?? .menuWindow
                case "break_display_target": config.breakDisplayTarget = BreakDisplayTarget(rawValue: value) ?? .activeScreen
                case "break_display_specific_uuid": config.breakDisplaySpecificUUID = value.isEmpty ? nil : value
                case "break_confirm": config.breakConfirm = value == "1"
                case "alert_sound": config.alertSound = value
                case "alert_sound_repeat_count":
                    config.alertSoundRepeatCount = min(max(Int(value) ?? 1, 1), 10)
                case "break_detect_sound_name": config.breakDetectSoundName = value
                case "language": config.language = AppLanguage(rawValue: value) ?? .system
                case "appearance": config.appearance = AppAppearance(rawValue: value) ?? .system
                case "quiet_hours":
                    if let data = value.data(using: .utf8),
                       let arr = try? JSONDecoder().decode([QuietHourPeriod].self, from: data) {
                        config.quietHours = arr
                    }
                case "work_days":
                    if let data = value.data(using: .utf8),
                       let arr = try? JSONDecoder().decode(Set<Int>.self, from: data) {
                        config.workDays = arr
                    }
                case "holiday_sync_enabled": config.holidaySyncEnabled = value == "1"
                case "holiday_calendar":
                    if let data = value.data(using: .utf8),
                       let map = try? JSONDecoder().decode([String: Bool].self, from: data) {
                        config.holidayCalendar = map
                    }
                case "holiday_calendar_names":
                    if let data = value.data(using: .utf8),
                       let map = try? JSONDecoder().decode([String: String].self, from: data) {
                        config.holidayCalendarNames = map
                    }
                case "holiday_calendar_synced_at":
                    config.holidayCalendarSyncedAt = value.isEmpty ? nil : value
                case "work_hours_enabled": config.workHoursEnabled = value == "1"
                case "work_start_time": config.workStartTime = value
                case "work_end_time": config.workEndTime = value
                case "off_work_summary_enabled": config.offWorkSummaryEnabled = value == "1"
                case "long_break_enabled": config.longBreakEnabled = value == "1"
                case "long_break_interval": config.longBreakInterval = Int(value) ?? 4
                case "long_break_seconds": config.longBreakSeconds = Int(value) ?? 900
                case "pre_break_notice_enabled": config.preBreakNoticeEnabled = value == "1"
                case "pre_break_notice_seconds": config.preBreakNoticeSeconds = Int(value) ?? 60
                case "pre_break_notice_long_seconds": config.preBreakNoticeLongSeconds = Int(value) ?? 120
                case "auto_pause_on_goal": config.autoPauseOnGoal = value == "1"
                case "shortcut_enabled": config.shortcutEnabled = value == "1"
                case "shortcut_keycode": config.shortcutKeyCode = UInt16(value) ?? 36
                case "shortcut_modifiers": config.shortcutModifiers = UInt(value) ?? 1048576
                case "auto_check_update": config.autoCheckUpdate = value == "1"
                case "reset_on_screen_lock": config.resetOnScreenLock = value == "1"
                default: break
                }
            }
        }
        sqlite3_finalize(stmt)

        // Set global language immediately
        L.lang = config.language

        // If reminders are empty (fresh DB), set defaults based on resolved language
        if config.reminders.isEmpty || config.reminders == ["[]"] {
            config.reminders = [L.defaultReminder1, L.defaultReminder2]
        }

        return config
    }

    func saveConfig(_ config: AppConfig) {
        let remindersJSON = (try? JSONEncoder().encode(config.reminders))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('work_minutes', '\(config.workMinutes)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('break_seconds', '\(config.breakSeconds)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('eye_care_mode', '\(config.eyeCareMode ? "1" : "0")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('saved_work_minutes', '\(config.savedWorkMinutes)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('saved_break_seconds', '\(config.savedBreakSeconds)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('saved_break_confirm', '\(config.savedBreakConfirm ? "1" : "0")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('daily_goal', '\(config.dailyGoal)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('reminders', '\(remindersJSON.replacingOccurrences(of: "'", with: "''"))')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('sound_enabled', '\(config.soundEnabled ? "1" : "0")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('break_detect_sound', '\(config.breakDetectSound ? "1" : "0")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('break_position', '\(config.breakPosition.rawValue)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('break_display_target', '\(config.breakDisplayTarget.rawValue)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('break_display_specific_uuid', '\(config.breakDisplaySpecificUUID ?? "")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('break_confirm', '\(config.breakConfirm ? "1" : "0")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('alert_sound', '\(config.alertSound)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('alert_sound_repeat_count', '\(min(max(config.alertSoundRepeatCount, 1), 10))')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('break_detect_sound_name', '\(config.breakDetectSoundName)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('language', '\(config.language.rawValue)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('appearance', '\(config.appearance.rawValue)')")
        let quietJSON = (try? JSONEncoder().encode(config.quietHours))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('quiet_hours', '\(quietJSON.replacingOccurrences(of: "'", with: "''"))')")
        let workDaysJSON = (try? JSONEncoder().encode(config.workDays))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[2,3,4,5,6]"
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('work_days', '\(workDaysJSON)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('holiday_sync_enabled', '\(config.holidaySyncEnabled ? "1" : "0")')")
        let holidayJSON = (try? JSONEncoder().encode(config.holidayCalendar))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('holiday_calendar', '\(holidayJSON.replacingOccurrences(of: "'", with: "''"))')")
        let holidayNamesJSON = (try? JSONEncoder().encode(config.holidayCalendarNames))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('holiday_calendar_names', '\(holidayNamesJSON.replacingOccurrences(of: "'", with: "''"))')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('holiday_calendar_synced_at', '\(config.holidayCalendarSyncedAt ?? "")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('long_break_enabled', '\(config.longBreakEnabled ? "1" : "0")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('long_break_interval', '\(config.longBreakInterval)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('long_break_seconds', '\(config.longBreakSeconds)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('pre_break_notice_enabled', '\(config.preBreakNoticeEnabled ? "1" : "0")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('pre_break_notice_seconds', '\(config.preBreakNoticeSeconds)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('pre_break_notice_long_seconds', '\(config.preBreakNoticeLongSeconds)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('auto_pause_on_goal', '\(config.autoPauseOnGoal ? "1" : "0")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('shortcut_enabled', '\(config.shortcutEnabled ? "1" : "0")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('shortcut_keycode', '\(config.shortcutKeyCode)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('shortcut_modifiers', '\(config.shortcutModifiers)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('auto_check_update', '\(config.autoCheckUpdate ? "1" : "0")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('reset_on_screen_lock', '\(config.resetOnScreenLock ? "1" : "0")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('work_hours_enabled', '\(config.workHoursEnabled ? "1" : "0")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('work_start_time', '\(config.workStartTime)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('work_end_time', '\(config.workEndTime)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('off_work_summary_enabled', '\(config.offWorkSummaryEnabled ? "1" : "0")')")
        exec("DELETE FROM config WHERE key = 'break_minutes'")
    }

    // MARK: - Records

    func addRecord() {
        let now = ISO8601DateFormatter().string(from: Date())
        let today = Self.todayString()
        exec("INSERT INTO records (timestamp, date) VALUES ('\(now)', '\(today)')")
    }

    func todayCount() -> Int {
        queryInt("SELECT COUNT(*) FROM records WHERE date = '\(Self.todayString())'")
    }

    func streakDays(goal: Int) -> Int {
        var stmt: OpaquePointer?
        let sql = """
            SELECT r.date, r.cnt, COALESCE(s.goal, \(goal)) as day_goal
            FROM (SELECT date, COUNT(*) as cnt FROM records GROUP BY date) r
            LEFT JOIN (SELECT date, daily_goal as goal FROM sessions GROUP BY date HAVING id = MAX(id)) s ON r.date = s.date
            ORDER BY r.date DESC
            """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }

        let today = Self.todayString()
        var streak = 0

        while sqlite3_step(stmt) == SQLITE_ROW {
            let dateStr = String(cString: sqlite3_column_text(stmt, 0))
            let cnt = Int(sqlite3_column_int(stmt, 1))
            let dayGoal = Int(sqlite3_column_int(stmt, 2))

            // Today hasn't met goal yet — skip (still in progress)
            if dateStr == today && cnt < dayGoal { continue }

            if cnt >= dayGoal {
                streak += 1
            } else {
                break // used app but didn't meet goal = streak broken
            }
        }

        return streak
    }

    func maxStreakDays(goal: Int) -> Int {
        var stmt: OpaquePointer?
        let sql = """
            SELECT r.date, r.cnt, COALESCE(s.goal, \(goal)) as day_goal
            FROM (SELECT date, COUNT(*) as cnt FROM records GROUP BY date) r
            LEFT JOIN (SELECT date, daily_goal as goal FROM sessions GROUP BY date HAVING id = MAX(id)) s ON r.date = s.date
            ORDER BY r.date
            """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        var maxS = 0, curS = 0

        while sqlite3_step(stmt) == SQLITE_ROW {
            let cnt = Int(sqlite3_column_int(stmt, 1))
            let dayGoal = Int(sqlite3_column_int(stmt, 2))
            if cnt >= dayGoal {
                curS += 1
                maxS = max(maxS, curS)
            } else {
                curS = 0
            }
        }

        return maxS
    }

    func recent7DaysCounts() -> [(String, Int)] {
        let today = Date()
        let fmt = Self.dateFmt()
        var map: [String: Int] = [:]
        var stmt: OpaquePointer?
        let start = fmt.string(from: Calendar.current.date(byAdding: .day, value: -6, to: today)!)
        let sql = "SELECT date, COUNT(*) FROM records WHERE date >= '\(start)' GROUP BY date"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let d = String(cString: sqlite3_column_text(stmt, 0))
                map[d] = Int(sqlite3_column_int(stmt, 1))
            }
        }
        sqlite3_finalize(stmt)
        var result: [(String, Int)] = []
        for i in stride(from: 6, through: 0, by: -1) {
            let d = fmt.string(from: Calendar.current.date(byAdding: .day, value: -i, to: today)!)
            result.append((d, map[d] ?? 0))
        }
        return result
    }

    func last30DaysCounts() -> [(String, Int)] {
        let today = Date()
        let fmt = Self.dateFmt()
        var map: [String: Int] = [:]
        var stmt: OpaquePointer?
        let start = fmt.string(from: Calendar.current.date(byAdding: .day, value: -29, to: today)!)
        let sql = "SELECT date, COUNT(*) FROM records WHERE date >= '\(start)' GROUP BY date"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let d = String(cString: sqlite3_column_text(stmt, 0))
                map[d] = Int(sqlite3_column_int(stmt, 1))
            }
        }
        sqlite3_finalize(stmt)
        var result: [(String, Int)] = []
        for i in stride(from: 29, through: 0, by: -1) {
            let d = fmt.string(from: Calendar.current.date(byAdding: .day, value: -i, to: today)!)
            result.append((d, map[d] ?? 0))
        }
        return result
    }

    func weekCompletionRate(goal: Int) -> (Int, Int) {
        let today = Date()
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: today)
        let monday = cal.date(byAdding: .day, value: -(weekday == 1 ? 6 : weekday - 2), to: today)!
        return completionRate(from: Self.dateFmt().string(from: monday), goal: goal, daysPassed: cal.dateComponents([.day], from: monday, to: today).day! + 1)
    }

    func monthCompletionRate(goal: Int) -> (Int, Int) {
        let today = Date()
        let cal = Calendar.current
        let first = cal.date(from: cal.dateComponents([.year, .month], from: today))!
        return completionRate(from: Self.dateFmt().string(from: first), goal: goal, daysPassed: cal.dateComponents([.day], from: first, to: today).day! + 1)
    }

    private func completionRate(from start: String, goal: Int, daysPassed: Int) -> (Int, Int) {
        var stmt: OpaquePointer?
        let sql = "SELECT date, COUNT(*) FROM records WHERE date >= '\(start)' GROUP BY date"
        var completed = 0
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if Int(sqlite3_column_int(stmt, 1)) >= goal { completed += 1 }
            }
        }
        sqlite3_finalize(stmt)
        return (completed, daysPassed)
    }

    func daysSinceLastGoal(goal: Int) -> Int {
        var stmt: OpaquePointer?
        let sql = "SELECT date, COUNT(*) as cnt FROM records GROUP BY date ORDER BY date DESC"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return -1 }
        let fmt = Self.dateFmt()
        let today = Date()
        while sqlite3_step(stmt) == SQLITE_ROW {
            let dateStr = String(cString: sqlite3_column_text(stmt, 0))
            let cnt = Int(sqlite3_column_int(stmt, 1))
            if cnt >= goal, let d = fmt.date(from: dateStr) {
                sqlite3_finalize(stmt)
                return Calendar.current.dateComponents([.day], from: d, to: today).day ?? -1
            }
        }
        sqlite3_finalize(stmt)
        return -1
    }

    func allRecordsForStats() -> [[String: Any]] {
        var stmt: OpaquePointer?
        let sql = "SELECT date, COUNT(*) as cnt FROM records GROUP BY date ORDER BY date"
        var result: [[String: Any]] = []
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let d = String(cString: sqlite3_column_text(stmt, 0))
                let c = Int(sqlite3_column_int(stmt, 1))
                result.append(["date": d, "count": c])
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    // MARK: - Sessions

    func startSession(workMinutes: Int, breakSeconds: Int, dailyGoal: Int) -> Int64 {
        let now = ISO8601DateFormatter().string(from: Date())
        let today = Self.todayString()
        let breakMinutesValue = max(1, breakSeconds / 60)
        let sql = "INSERT INTO sessions (date, work_start, work_minutes, break_minutes, daily_goal) VALUES ('\(today)', '\(now)', \(workMinutes), \(breakMinutesValue), \(dailyGoal))"
        exec(sql)
        return sqlite3_last_insert_rowid(db)
    }

    func endWork(sessionId: Int64) {
        let now = ISO8601DateFormatter().string(from: Date())
        exec("UPDATE sessions SET work_end = '\(now)' WHERE id = \(sessionId)")
    }

    /// Close all sessions from previous days that were never properly ended
    /// (e.g. user closed laptop lid during alerting phase).
    /// Sets work_end = work_start so they contribute 0 work minutes.
    func closeOrphanSessions(beforeDate date: String) {
        exec("UPDATE sessions SET work_end = work_start WHERE date < '\(date)' AND work_end IS NULL")
    }

    /// Close orphan sessions for today (e.g. app crashed mid-work).
    /// Uses configured work_minutes as the elapsed estimate, capped by workMinutesForDate logic.
    func closeTodayOrphanSessions() {
        let today = Self.todayString()
        let now = ISO8601DateFormatter().string(from: Date())
        exec("UPDATE sessions SET work_end = '\(now)' WHERE date = '\(today)' AND work_end IS NULL")
    }

    func startSessionBreak(sessionId: Int64) {
        let now = ISO8601DateFormatter().string(from: Date())
        exec("UPDATE sessions SET break_start = '\(now)' WHERE id = \(sessionId)")
    }

    func endSessionBreak(sessionId: Int64, actualSeconds: Int?, skipped: Bool) {
        let now = ISO8601DateFormatter().string(from: Date())
        let actualStr = actualSeconds.map { "\($0)" } ?? "NULL"
        exec("UPDATE sessions SET break_end = '\(now)', break_actual_seconds = \(actualStr), skipped = \(skipped ? 1 : 0) WHERE id = \(sessionId)")
    }

    // MARK: - Skip Count

    func todaySkipCount() -> Int {
        let date = Self.todayString()
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM sessions WHERE date = '\(date)' AND skipped = 1", -1, &stmt, nil) == SQLITE_OK,
           sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }

    // MARK: - Work Minutes

    func todayWorkMinutes() -> Int {
        workMinutesForDate(Self.todayString())
    }

    func countForDate(_ date: String) -> Int {
        queryInt("SELECT COUNT(*) FROM records WHERE date = '\(date)'")
    }

    func recent7DaysCountsEndingOn(_ endDate: Date) -> [(String, Int)] {
        let fmt = Self.dateFmt()
        var map: [String: Int] = [:]
        var stmt: OpaquePointer?
        let start = fmt.string(from: Calendar.current.date(byAdding: .day, value: -6, to: endDate)!)
        let end = fmt.string(from: endDate)
        let sql = "SELECT date, COUNT(*) FROM records WHERE date >= '\(start)' AND date <= '\(end)' GROUP BY date"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let d = String(cString: sqlite3_column_text(stmt, 0))
                map[d] = Int(sqlite3_column_int(stmt, 1))
            }
        }
        sqlite3_finalize(stmt)
        var result: [(String, Int)] = []
        for i in stride(from: 6, through: 0, by: -1) {
            let d = fmt.string(from: Calendar.current.date(byAdding: .day, value: -i, to: endDate)!)
            result.append((d, map[d] ?? 0))
        }
        return result
    }

    func workMinutesForDate(_ date: String) -> Int {
        var stmt: OpaquePointer?
        // Only count completed sessions (work_end IS NOT NULL)
        let sql = "SELECT work_start, work_end, work_minutes FROM sessions WHERE date = '\(date)' AND work_end IS NOT NULL"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        let iso = ISO8601DateFormatter()
        var total = 0
        while sqlite3_step(stmt) == SQLITE_ROW {
            let startStr = String(cString: sqlite3_column_text(stmt, 0))
            guard let start = iso.date(from: startStr) else { continue }
            let configuredMinutes = Int(sqlite3_column_int(stmt, 2))
            let endStr = String(cString: sqlite3_column_text(stmt, 1))
            let end = iso.date(from: endStr) ?? start
            let elapsed = min(max(0, Int(end.timeIntervalSince(start) / 60)), configuredMinutes)
            total += elapsed
        }
        return total
    }

    func recent7DaysWorkMinutes() -> [(String, Int)] {
        rangeWorkMinutes(days: 7)
    }

    func last30DaysWorkMinutes() -> [(String, Int)] {
        rangeWorkMinutes(days: 30)
    }

    private func rangeWorkMinutes(days: Int) -> [(String, Int)] {
        let today = Date()
        let fmt = Self.dateFmt()
        let iso = ISO8601DateFormatter()
        let start = fmt.string(from: Calendar.current.date(byAdding: .day, value: -(days - 1), to: today)!)

        var map: [String: Int] = [:]
        var stmt: OpaquePointer?
        // Only count completed sessions (work_end IS NOT NULL)
        let sql = "SELECT date, work_start, work_end, work_minutes FROM sessions WHERE date >= '\(start)' AND work_end IS NOT NULL"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let d = String(cString: sqlite3_column_text(stmt, 0))
                let startStr = String(cString: sqlite3_column_text(stmt, 1))
                guard let startDate = iso.date(from: startStr) else { continue }
                let configuredMinutes = Int(sqlite3_column_int(stmt, 3))
                let endStr = String(cString: sqlite3_column_text(stmt, 2))
                let endDate = iso.date(from: endStr) ?? startDate
                let elapsed = min(max(0, Int(endDate.timeIntervalSince(startDate) / 60)), configuredMinutes)
                map[d, default: 0] += elapsed
            }
        }
        sqlite3_finalize(stmt)

        var result: [(String, Int)] = []
        for i in stride(from: days - 1, through: 0, by: -1) {
            let d = fmt.string(from: Calendar.current.date(byAdding: .day, value: -i, to: today)!)
            result.append((d, map[d] ?? 0))
        }
        return result
    }

    // MARK: - Total Count

    func totalCount() -> Int {
        queryInt("SELECT COUNT(*) FROM records")
    }

    func activeDays() -> Int {
        queryInt("SELECT COUNT(DISTINCT date) FROM records")
    }

    func bestDayCount() -> (String, Int) {
        var stmt: OpaquePointer?
        let sql = "SELECT date, COUNT(*) as cnt FROM records GROUP BY date ORDER BY cnt DESC LIMIT 1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return ("", 0) }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            let d = String(cString: sqlite3_column_text(stmt, 0))
            let c = Int(sqlite3_column_int(stmt, 1))
            return (d, c)
        }
        return ("", 0)
    }

    func firstRecordDate() -> String? {
        var stmt: OpaquePointer?
        let sql = "SELECT date FROM records ORDER BY date ASC LIMIT 1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return String(cString: sqlite3_column_text(stmt, 0))
        }
        return nil
    }

    // MARK: - Onboarding

    func isOnboardingCompleted() -> Bool {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT value FROM config WHERE key = 'onboarding_completed'", -1, &stmt, nil) == SQLITE_OK,
              sqlite3_step(stmt) == SQLITE_ROW else { return false }
        return String(cString: sqlite3_column_text(stmt, 0)) == "1"
    }

    func setOnboardingCompleted() {
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('onboarding_completed', '1')")
    }

    func setOnboardingIncomplete() {
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('onboarding_completed', '0')")
    }

    // MARK: - Timer State Persistence

    func saveTimerState(phase: String, targetTime: Date?, pausedRemaining: Int?) {
        let iso = ISO8601DateFormatter()
        let targetStr = targetTime.map { iso.string(from: $0) } ?? ""
        let pausedStr = pausedRemaining.map { "\($0)" } ?? ""
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('timer_phase', '\(phase)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('timer_target_time', '\(targetStr)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('timer_paused_remaining', '\(pausedStr)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('timer_save_date', '\(Self.todayString())')")
    }

    func loadTimerState() -> (phase: String, targetTime: Date?, pausedRemaining: Int?) {
        var phase = ""
        var targetStr = ""
        var pausedStr = ""
        var stmt: OpaquePointer?
        let sql = "SELECT key, value FROM config WHERE key IN ('timer_phase', 'timer_target_time', 'timer_paused_remaining')"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let key = String(cString: sqlite3_column_text(stmt, 0))
                let value = String(cString: sqlite3_column_text(stmt, 1))
                switch key {
                case "timer_phase": phase = value
                case "timer_target_time": targetStr = value
                case "timer_paused_remaining": pausedStr = value
                default: break
                }
            }
        }
        sqlite3_finalize(stmt)

        let iso = ISO8601DateFormatter()
        let targetTime = targetStr.isEmpty ? nil : iso.date(from: targetStr)
        let pausedRemaining = pausedStr.isEmpty ? nil : Int(pausedStr)
        return (phase, targetTime, pausedRemaining)
    }

    func timerSaveDate() -> String {
        var result = ""
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT value FROM config WHERE key = 'timer_save_date'", -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                result = String(cString: sqlite3_column_text(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    func clearTimerState() {
        exec("DELETE FROM config WHERE key IN ('timer_phase', 'timer_target_time', 'timer_paused_remaining', 'timer_save_date')")
    }

    func saveFlag(_ key: String, value: Bool) {
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('\(key)', '\(value ? "1" : "0")')")
    }

    func loadFlag(_ key: String) -> Bool {
        queryInt("SELECT CAST(value AS INTEGER) FROM config WHERE key = '\(key)'") == 1
    }

    // MARK: - Reset

    func resetAllData() {
        exec("DELETE FROM records")
        exec("DELETE FROM sessions")
    }

    func resetConfig() {
        exec("DELETE FROM config")
        createTables()
    }

    // MARK: - Export

    static let exportVersion = 1

    func exportAllData() -> [String: Any] {
        let iso = ISO8601DateFormatter()
        var result: [String: Any] = [
            "version": Self.exportVersion,
            "exportDate": iso.string(from: Date())
        ]

        // Records
        var records: [[String: Any]] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT id, timestamp, date FROM records ORDER BY id", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int64(stmt, 0))
                let ts = String(cString: sqlite3_column_text(stmt, 1))
                let date = String(cString: sqlite3_column_text(stmt, 2))
                records.append(["id": id, "timestamp": ts, "date": date])
            }
        }
        sqlite3_finalize(stmt)
        result["records"] = records

        // Sessions
        var sessions: [[String: Any]] = []
        stmt = nil
        if sqlite3_prepare_v2(db, "SELECT id, date, work_start, work_end, work_minutes, break_start, break_end, break_minutes, break_actual_seconds, skipped, daily_goal FROM sessions ORDER BY id", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                var s: [String: Any] = [
                    "id": Int(sqlite3_column_int64(stmt, 0)),
                    "date": String(cString: sqlite3_column_text(stmt, 1)),
                    "work_start": String(cString: sqlite3_column_text(stmt, 2)),
                    "work_minutes": Int(sqlite3_column_int(stmt, 4)),
                    "break_minutes": Int(sqlite3_column_int(stmt, 7)),
                    "skipped": Int(sqlite3_column_int(stmt, 9)),
                    "daily_goal": Int(sqlite3_column_int(stmt, 10))
                ]
                if sqlite3_column_type(stmt, 3) != SQLITE_NULL {
                    s["work_end"] = String(cString: sqlite3_column_text(stmt, 3))
                }
                if sqlite3_column_type(stmt, 5) != SQLITE_NULL {
                    s["break_start"] = String(cString: sqlite3_column_text(stmt, 5))
                }
                if sqlite3_column_type(stmt, 6) != SQLITE_NULL {
                    s["break_end"] = String(cString: sqlite3_column_text(stmt, 6))
                }
                if sqlite3_column_type(stmt, 8) != SQLITE_NULL {
                    s["break_actual_seconds"] = Int(sqlite3_column_int(stmt, 8))
                }
                sessions.append(s)
            }
        }
        sqlite3_finalize(stmt)
        result["sessions"] = sessions

        // Config (exclude transient timer state)
        let excludeKeys: Set<String> = ["timer_phase", "timer_target_time", "timer_paused_remaining", "overtime_active"]
        var config: [String: String] = [:]
        stmt = nil
        if sqlite3_prepare_v2(db, "SELECT key, value FROM config", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let key = String(cString: sqlite3_column_text(stmt, 0))
                let value = String(cString: sqlite3_column_text(stmt, 1))
                if !excludeKeys.contains(key) {
                    config[key] = value
                }
            }
        }
        sqlite3_finalize(stmt)
        result["config"] = config

        return result
    }

    // MARK: - Import

    struct ImportSummary {
        var recordsAdded = 0
        var recordsSkipped = 0
        var sessionsAdded = 0
        var sessionsSkipped = 0
        var rejected = 0
        var configApplied = false
        var backupPath = ""
    }

    enum ImportError: LocalizedError {
        case malformed
        case unsupportedVersion(Int)
        case backupFailed
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .malformed: return L.importMalformed
            case .unsupportedVersion(let v): return L.importUnsupportedVersion(v)
            case .backupFailed: return L.importBackupFailed
            case .writeFailed: return L.importWriteFailed
            }
        }
    }

    /// Snapshot the live DB into `backups/`. VACUUM INTO folds the WAL into the
    /// copy, so it stays complete even though the connection never checkpoints.
    @discardableResult
    func backupDatabase() throws -> String {
        let dir = (dbPath as NSString).deletingLastPathComponent + "/backups"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let fmt = DateFormatter()
        // Pinned locale: this is a file name, and a non-Gregorian system calendar
        // would otherwise stamp it with that calendar's year.
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = fmt.string(from: Date())
        var path = dir + "/data-\(stamp).db"
        var suffix = 2
        while FileManager.default.fileExists(atPath: path) {
            path = dir + "/data-\(stamp)-\(suffix).db"
            suffix += 1
        }
        // VACUUM INTO takes no parameters, so the path is quoted by hand.
        guard exec("VACUUM INTO '\(path.replacingOccurrences(of: "'", with: "''"))'") else {
            throw ImportError.backupFailed
        }
        return path
    }

    func importData(_ payload: [String: Any], includeConfig: Bool) throws -> ImportSummary {
        guard let version = (payload["version"] as? NSNumber)?.intValue, version >= 1 else {
            throw ImportError.malformed
        }
        guard version <= Self.exportVersion else { throw ImportError.unsupportedVersion(version) }

        var summary = ImportSummary()
        summary.backupPath = try backupDatabase()

        guard exec("BEGIN IMMEDIATE") else { throw ImportError.writeFailed }
        do {
            if let rows = payload["records"] as? [[String: Any]] {
                try importRecords(rows, into: &summary)
            }
            if let rows = payload["sessions"] as? [[String: Any]] {
                try importSessions(rows, into: &summary)
            }
            if includeConfig, let config = payload["config"] as? [String: String] {
                try importConfig(config)
                summary.configApplied = true
            }
        } catch {
            exec("ROLLBACK")
            throw error
        }
        guard exec("COMMIT") else {
            exec("ROLLBACK")
            throw ImportError.writeFailed
        }
        return summary
    }

    /// Rows are matched as a multiset on (timestamp, date): a day that legitimately
    /// holds several identical rows keeps all of them, and re-importing the same
    /// file twice adds nothing.
    private func importRecords(_ rows: [[String: Any]], into summary: inout ImportSummary) throws {
        var existing = countMap("SELECT timestamp || char(1) || date FROM records")
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT INTO records (timestamp, date) VALUES (?, ?)", -1, &stmt, nil) == SQLITE_OK else {
            throw ImportError.writeFailed
        }
        defer { sqlite3_finalize(stmt) }

        let latestDate = Self.latestImportableDate()
        for row in rows {
            guard let ts = row["timestamp"] as? String, let date = row["date"] as? String else { continue }
            guard Self.isImportableDate(date, notAfter: latestDate) else {
                summary.rejected += 1
                continue
            }
            let key = ts + "\u{01}" + date
            if let n = existing[key], n > 0 {
                existing[key] = n - 1
                summary.recordsSkipped += 1
                continue
            }
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            bindText(stmt, 1, ts)
            bindText(stmt, 2, date)
            guard sqlite3_step(stmt) == SQLITE_DONE else { throw ImportError.writeFailed }
            summary.recordsAdded += 1
        }
    }

    /// Same multiset rule, keyed on (date, work_start).
    private func importSessions(_ rows: [[String: Any]], into summary: inout ImportSummary) throws {
        var existing = countMap("SELECT date || char(1) || work_start FROM sessions")
        let sql = """
            INSERT INTO sessions (date, work_start, work_end, work_minutes, break_start, break_end,
                                  break_minutes, break_actual_seconds, skipped, daily_goal)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw ImportError.writeFailed }
        defer { sqlite3_finalize(stmt) }

        let latestDate = Self.latestImportableDate()
        for row in rows {
            guard let date = row["date"] as? String, let workStart = row["work_start"] as? String else { continue }
            guard Self.isImportableDate(date, notAfter: latestDate) else {
                summary.rejected += 1
                continue
            }
            let key = date + "\u{01}" + workStart
            if let n = existing[key], n > 0 {
                existing[key] = n - 1
                summary.sessionsSkipped += 1
                continue
            }
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            bindText(stmt, 1, date)
            bindText(stmt, 2, workStart)
            bindOptionalText(stmt, 3, row["work_end"] as? String)
            sqlite3_bind_int(stmt, 4, int32(row["work_minutes"]))
            bindOptionalText(stmt, 5, row["break_start"] as? String)
            bindOptionalText(stmt, 6, row["break_end"] as? String)
            sqlite3_bind_int(stmt, 7, int32(row["break_minutes"]))
            if let secs = (row["break_actual_seconds"] as? NSNumber)?.intValue {
                sqlite3_bind_int(stmt, 8, Int32(clamping: secs))
            } else {
                sqlite3_bind_null(stmt, 8)
            }
            sqlite3_bind_int(stmt, 9, int32(row["skipped"]))
            sqlite3_bind_int(stmt, 10, int32(row["daily_goal"], default: 8))
            guard sqlite3_step(stmt) == SQLITE_DONE else { throw ImportError.writeFailed }
            summary.sessionsAdded += 1
        }
    }

    /// `streakDays` walks records by `date DESC` and stops at the first day that
    /// missed its goal, so one row dated "2099-01-01" — or anything that isn't a
    /// date at all — would sort to the front and wipe the streak. Only well-formed
    /// dates up to tomorrow (leaving slack for time zones) get in.
    private static func isImportableDate(_ s: String, notAfter latest: String) -> Bool {
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
        // yyyy-MM-dd sorts lexicographically the same way it sorts chronologically
        return s <= latest
    }

    private static func latestImportableDate() -> String {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return dateFmt().string(from: tomorrow)
    }

    /// Values the timer runs on, clamped to the ranges the settings UI allows —
    /// an imported `work_minutes` of 999999999 would otherwise schedule a tick
    /// that never fires.
    private static let configRanges: [String: ClosedRange<Int>] = [
        "work_minutes": 1...120,
        "saved_work_minutes": 1...120,
        "break_seconds": 20...900,
        "saved_break_seconds": 20...900,
        "daily_goal": 1...20,
        "long_break_interval": 2...8,
        "long_break_seconds": 300...1800,
        "pre_break_notice_seconds": 0...3600,
        "pre_break_notice_long_seconds": 0...3600,
        "alert_sound_repeat_count": 1...10,
    ]

    private func importConfig(_ config: [String: String]) throws {
        let excludeKeys: Set<String> = ["timer_phase", "timer_target_time", "timer_paused_remaining", "overtime_active"]
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO config (key, value) VALUES (?, ?)", -1, &stmt, nil) == SQLITE_OK else {
            throw ImportError.writeFailed
        }
        defer { sqlite3_finalize(stmt) }

        for (key, rawValue) in config where !excludeKeys.contains(key) {
            var value = rawValue
            if let range = Self.configRanges[key] {
                guard let n = Int(rawValue) else { continue }
                value = String(min(max(n, range.lowerBound), range.upperBound))
            }
            sqlite3_reset(stmt)
            sqlite3_clear_bindings(stmt)
            bindText(stmt, 1, key)
            bindText(stmt, 2, value)
            guard sqlite3_step(stmt) == SQLITE_DONE else { throw ImportError.writeFailed }
        }
    }

    // MARK: - Helpers

    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// How many times each key occurs — the existing side of the multiset merge.
    private func countMap(_ sql: String) -> [String: Int] {
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

    private func bindText(_ stmt: OpaquePointer?, _ idx: Int32, _ value: String) {
        sqlite3_bind_text(stmt, idx, value, -1, Self.sqliteTransient)
    }

    private func bindOptionalText(_ stmt: OpaquePointer?, _ idx: Int32, _ value: String?) {
        if let value {
            bindText(stmt, idx, value)
        } else {
            sqlite3_bind_null(stmt, idx)
        }
    }

    /// Clamping instead of `Int32(...)` — the value comes from an imported file
    /// and an out-of-range one would trap.
    private func int32(_ value: Any?, default def: Int32 = 0) -> Int32 {
        guard let n = (value as? NSNumber)?.intValue else { return def }
        return Int32(clamping: n)
    }

    private func queryInt(_ sql: String) -> Int {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
              sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    static func todayString() -> String {
        dateFmt().string(from: Date())
    }

    static func dateFmt() -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
}
