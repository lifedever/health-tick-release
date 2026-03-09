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
            ("break_minutes", "2"),
            ("daily_goal", "8"),
            ("reminders", "[]"),
            ("sound_enabled", "1"),
            ("break_detect_sound", "0"),
            ("break_position", "menu_window"),
            ("break_confirm", "1"),
            ("alert_sound", "Glass"),
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
                case "break_minutes": config.breakMinutes = Int(value) ?? 2
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
                case "break_confirm": config.breakConfirm = value == "1"
                case "alert_sound": config.alertSound = value
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
                case "shortcut_enabled": config.shortcutEnabled = value == "1"
                case "shortcut_keycode": config.shortcutKeyCode = UInt16(value) ?? 36
                case "shortcut_modifiers": config.shortcutModifiers = UInt(value) ?? 1048576
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
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('break_minutes', '\(config.breakMinutes)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('daily_goal', '\(config.dailyGoal)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('reminders', '\(remindersJSON.replacingOccurrences(of: "'", with: "''"))')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('sound_enabled', '\(config.soundEnabled ? "1" : "0")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('break_detect_sound', '\(config.breakDetectSound ? "1" : "0")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('break_position', '\(config.breakPosition.rawValue)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('break_confirm', '\(config.breakConfirm ? "1" : "0")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('alert_sound', '\(config.alertSound)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('break_detect_sound_name', '\(config.breakDetectSoundName)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('language', '\(config.language.rawValue)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('appearance', '\(config.appearance.rawValue)')")
        let quietJSON = (try? JSONEncoder().encode(config.quietHours))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('quiet_hours', '\(quietJSON.replacingOccurrences(of: "'", with: "''"))')")
        let workDaysJSON = (try? JSONEncoder().encode(config.workDays))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[2,3,4,5,6]"
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('work_days', '\(workDaysJSON)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('shortcut_enabled', '\(config.shortcutEnabled ? "1" : "0")')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('shortcut_keycode', '\(config.shortcutKeyCode)')")
        exec("INSERT OR REPLACE INTO config (key, value) VALUES ('shortcut_modifiers', '\(config.shortcutModifiers)')")
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
        let sql = "SELECT date, COUNT(*) as cnt FROM records GROUP BY date ORDER BY date DESC"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        var streak = 0
        let today = Self.todayString()
        var isFirst = true
        while sqlite3_step(stmt) == SQLITE_ROW {
            let dateStr = String(cString: sqlite3_column_text(stmt, 0))
            let cnt = Int(sqlite3_column_int(stmt, 1))
            if isFirst {
                if dateStr != today { break }
                isFirst = false
            }
            if cnt >= goal { streak += 1 } else { break }
        }
        sqlite3_finalize(stmt)
        return streak
    }

    func maxStreakDays(goal: Int) -> Int {
        var stmt: OpaquePointer?
        let sql = "SELECT date, COUNT(*) as cnt FROM records GROUP BY date ORDER BY date"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        var maxS = 0, curS = 0
        var prevDate: Date?
        let fmt = Self.dateFmt()
        while sqlite3_step(stmt) == SQLITE_ROW {
            let dateStr = String(cString: sqlite3_column_text(stmt, 0))
            let cnt = Int(sqlite3_column_int(stmt, 1))
            guard let d = fmt.date(from: dateStr) else { continue }
            if cnt >= goal {
                if let prev = prevDate, Calendar.current.dateComponents([.day], from: prev, to: d).day == 1 {
                    curS += 1
                } else {
                    curS = 1
                }
                maxS = max(maxS, curS)
            } else {
                curS = 0
            }
            prevDate = d
        }
        sqlite3_finalize(stmt)
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

    func startSession(workMinutes: Int, breakMinutes: Int, dailyGoal: Int) -> Int64 {
        let now = ISO8601DateFormatter().string(from: Date())
        let today = Self.todayString()
        let sql = "INSERT INTO sessions (date, work_start, work_minutes, break_minutes, daily_goal) VALUES ('\(today)', '\(now)', \(workMinutes), \(breakMinutes), \(dailyGoal))"
        exec(sql)
        return sqlite3_last_insert_rowid(db)
    }

    func endWork(sessionId: Int64) {
        let now = ISO8601DateFormatter().string(from: Date())
        exec("UPDATE sessions SET work_end = '\(now)' WHERE id = \(sessionId)")
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

    func clearTimerState() {
        exec("DELETE FROM config WHERE key IN ('timer_phase', 'timer_target_time', 'timer_paused_remaining')")
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

    // MARK: - Helpers

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
