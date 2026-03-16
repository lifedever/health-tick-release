import Foundation
import AppKit
import SwiftUI

enum BreakPosition: String, CaseIterable, Equatable {
    case menuWindow = "menu_window"
    case topRight = "top_right"
    case topLeft = "top_left"
    case center = "center"
    case fullscreen = "fullscreen"

    var label: String {
        switch self {
        case .menuWindow: return L.posMenuWindow
        case .topRight: return L.posTopRight
        case .topLeft: return L.posTopLeft
        case .center: return L.posCenter
        case .fullscreen: return L.posFullscreen
        }
    }
}

enum AppAppearance: String, CaseIterable, Equatable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var label: String {
        switch self {
        case .system: return L.appearanceSystem
        case .light: return L.appearanceLight
        case .dark: return L.appearanceDark
        }
    }
}

struct QuietHourPeriod: Codable, Equatable {
    var start: String  // "HH:mm"
    var end: String    // "HH:mm"

    func isActive(at date: Date) -> Bool {
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        let now = h * 60 + m

        let startParts = start.split(separator: ":").compactMap { Int($0) }
        let endParts = end.split(separator: ":").compactMap { Int($0) }
        guard startParts.count == 2, endParts.count == 2 else { return false }

        let s = startParts[0] * 60 + startParts[1]
        let e = endParts[0] * 60 + endParts[1]

        if s <= e {
            return now >= s && now < e
        } else {
            // Crosses midnight
            return now >= s || now < e
        }
    }

    /// Returns the Date when this period ends, given a reference date
    func endDate(from date: Date) -> Date? {
        let cal = Calendar.current
        let endParts = end.split(separator: ":").compactMap { Int($0) }
        guard endParts.count == 2 else { return nil }
        var endDate = cal.date(bySettingHour: endParts[0], minute: endParts[1], second: 0, of: date)!
        // If end is before now (crosses midnight), it's tomorrow
        if endDate <= date {
            endDate = cal.date(byAdding: .day, value: 1, to: endDate)!
        }
        return endDate
    }

    /// Returns the Date when this period starts next, given a reference date (for work hours: when work resumes)
    func startDate(from date: Date) -> Date? {
        let cal = Calendar.current
        let startParts = start.split(separator: ":").compactMap { Int($0) }
        guard startParts.count == 2 else { return nil }
        var startDate = cal.date(bySettingHour: startParts[0], minute: startParts[1], second: 0, of: date)!
        // If start is before now, it's tomorrow
        if startDate <= date {
            startDate = cal.date(byAdding: .day, value: 1, to: startDate)!
        }
        return startDate
    }
}

struct BreakActivity {
    let icon: String
    let textZh: String
    let textEn: String

    var text: String { L.isZhAccess ? textZh : textEn }
}

let breakActivities: [BreakActivity] = [
    BreakActivity(icon: "figure.walk", textZh: "起来走走，活动一下身体", textEn: "Take a walk and stretch your body"),
    BreakActivity(icon: "eye", textZh: "远眺窗外，放松眼睛", textEn: "Look out the window, relax your eyes"),
    BreakActivity(icon: "drop.fill", textZh: "喝杯水，补充水分", textEn: "Drink some water, stay hydrated"),
    BreakActivity(icon: "figure.flexibility", textZh: "做几个简单的拉伸动作", textEn: "Do some simple stretches"),
    BreakActivity(icon: "wind", textZh: "深呼吸，放松身心", textEn: "Take deep breaths, relax your mind"),
    BreakActivity(icon: "hand.raised.fingers.spread", textZh: "活动手腕，预防鼠标手", textEn: "Flex your wrists to prevent strain"),
    BreakActivity(icon: "moon.fill", textZh: "闭眼休息，让大脑放松", textEn: "Close your eyes and rest your mind"),
    BreakActivity(icon: "arrow.up.and.down", textZh: "伸展脊柱，改善坐姿", textEn: "Stretch your spine, improve posture"),
]

func keyCodeToString(_ keyCode: UInt16) -> String {
    switch keyCode {
    case 36: return "↩"
    case 48: return "⇥"
    case 49: return "␣"
    case 51: return "⌫"
    case 53: return "⎋"
    case 76: return "⌅"
    case 123: return "←"
    case 124: return "→"
    case 125: return "↓"
    case 126: return "↑"
    case 0: return "A"; case 1: return "S"; case 2: return "D"; case 3: return "F"
    case 4: return "H"; case 5: return "G"; case 6: return "Z"; case 7: return "X"
    case 8: return "C"; case 9: return "V"; case 11: return "B"; case 12: return "Q"
    case 13: return "W"; case 14: return "E"; case 15: return "R"; case 16: return "Y"
    case 17: return "T"; case 18: return "1"; case 19: return "2"; case 20: return "3"
    case 21: return "4"; case 22: return "6"; case 23: return "5"; case 24: return "="
    case 25: return "9"; case 26: return "7"; case 27: return "-"; case 28: return "8"
    case 29: return "0"; case 31: return "O"; case 32: return "U"; case 34: return "I"
    case 35: return "P"; case 37: return "L"; case 38: return "J"; case 40: return "K"
    case 45: return "N"; case 46: return "M"
    case 122: return "F1"; case 120: return "F2"; case 99: return "F3"; case 118: return "F4"
    case 96: return "F5"; case 97: return "F6"; case 98: return "F7"; case 100: return "F8"
    default: return "?"
    }
}

struct AppConfig: Equatable {
    var workMinutes: Int = 60
    var breakMinutes: Int = 2
    var dailyGoal: Int = 8
    var reminders: [String] = [L.defaultReminder1, L.defaultReminder2]
    var soundEnabled: Bool = true
    var breakDetectSound: Bool = false
    var breakPosition: BreakPosition = .menuWindow
    var breakConfirm: Bool = true
    var alertSound: String = "Glass"
    var breakDetectSoundName: String = "Tink"
    var language: AppLanguage = .system
    var appearance: AppAppearance = .system
    var quietHours: [QuietHourPeriod] = []
    var workDays: Set<Int> = [2, 3, 4, 5, 6]  // Calendar weekday: 2=Mon...6=Fri
    var workHoursEnabled: Bool = false
    var workStartTime: String = "09:00"
    var workEndTime: String = "18:00"
    var shortcutEnabled: Bool = false
    var shortcutKeyCode: UInt16 = 36  // Return
    var shortcutModifiers: UInt = 1048576  // Command

    var shortcutDisplay: String {
        var parts: [String] = []
        let mods = NSEvent.ModifierFlags(rawValue: shortcutModifiers)
        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.option) { parts.append("⌥") }
        if mods.contains(.shift) { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }
        parts.append(keyCodeToString(shortcutKeyCode))
        return parts.joined()
    }
}

struct Badge {
    let days: Int
    let icon: String
    let isTotal: Bool

    init(days: Int, icon: String, isTotal: Bool = false) {
        self.days = days
        self.icon = icon
        self.isTotal = isTotal
    }

    var name: String { isTotal ? L.totalBadgeName(days) : L.badgeName(days) }
    var desc: String { isTotal ? L.totalBadgeDesc(days) : L.badgeDesc(days) }
}

let allBadges: [Badge] = [
    Badge(days: 3, icon: "👣"),
    Badge(days: 7, icon: "🌱"),
    Badge(days: 14, icon: "🌿"),
    Badge(days: 21, icon: "🌳"),
    Badge(days: 30, icon: "🛡️"),
    Badge(days: 50, icon: "⭐"),
    Badge(days: 60, icon: "💪"),
    Badge(days: 90, icon: "👑"),
    Badge(days: 100, icon: "🏆"),
    Badge(days: 180, icon: "💎"),
    Badge(days: 365, icon: "🐉"),
]

let allTotalBadges: [Badge] = [
    Badge(days: 10, icon: "📌", isTotal: true),
    Badge(days: 20, icon: "✌️", isTotal: true),
    Badge(days: 50, icon: "🎖️", isTotal: true),
    Badge(days: 100, icon: "💯", isTotal: true),
    Badge(days: 200, icon: "🎯", isTotal: true),
    Badge(days: 500, icon: "🚀", isTotal: true),
    Badge(days: 1000, icon: "🌟", isTotal: true),
    Badge(days: 2000, icon: "🔥", isTotal: true),
    Badge(days: 5000, icon: "🏅", isTotal: true),
]

enum AppPhase: String {
    case working
    case alerting
    case breaking
    case waiting
    case paused
}

@MainActor
@Observable
final class AppState {
    var config: AppConfig {
        didSet { scheduleAutoSave() }
    }
    var phase: AppPhase = .working
    var remainingSeconds: Int = 0
    var todayDone: Int = 0
    var currentStreak: Int = 0
    var maxStreak: Int = 0
    var breakWarning: String = ""
    var breakSkipCount: Int = 0
    let breakSkipNeeded = 3
    var lastSkipClickTime: Date?
    var weekData: [(String, Int)] = []
    var totalCount: Int = 0
    var todayWorkMinutes: Int = 0
    var weekWorkData: [(String, Int)] = []
    var isInQuietHours: Bool = false

    var overtimeActive: Bool = false
    var showOnboarding: Bool = false
    var currentBreakActivity: BreakActivity?
    var currentReminder: String?
    var celebrateBadge: Badge?
    var todaySkipCount: Int = 0
    var quietRemainingSeconds: Int = 0

    private var currentSessionId: Int64?
    private var currentSessionWorkConfig: Int = 0  // work_minutes at session creation
    private var breakStartDate: Date?
    private var targetTime: Date = Date()
    private var pausedRemaining: Int = 0
    private var pausedPhase: AppPhase?
    private var timer: Timer?
    private var alertRepeatTimer: Timer?
    private var quietCheckTimer: Timer?
    private var quietCountdownTimer: Timer?
    private var autoQuietPaused: Bool = false
    private var lastActiveDate: String = Database.todayString()
    private var lastWorkMinutesRefresh: Date = .distantPast
    private let db = Database.shared
    var overlayManager = BreakOverlayManager()

    private var autoSaveTimer: Timer?
    private var restartPromptTimer: Timer?
    private var lastSavedConfig: AppConfig?
    private var localMonitor: Any?

    var earnedTotalBadges: [Badge] {
        allTotalBadges.filter { totalCount >= $0.days }
    }

    var nextTotalBadge: Badge? {
        allTotalBadges.first(where: { totalCount < $0.days })
    }

    init() {
        config = db.loadConfig()
        L.lang = config.language
        // Defer appearance application — NSApp may not be ready during init
        DispatchQueue.main.async { [config] in
            Self.applyAppearance(config.appearance)
        }
        lastSavedConfig = config
        overlayManager.appState = self
        overlayManager.onForceEnd = { [weak self] in
            self?.forceEndBreak()
        }
        overlayManager.onBreakDone = { [weak self] in
            self?.onBreakDone()
        }
        restoreTimerState()
        refreshStats()

        startQuietCheckTimer()
        setupShortcutMonitors()

        // Delay so onChange in HealthTickApp can catch the transition
        if !db.isOnboardingCompleted() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showOnboarding = true
            }
        }


        // Save timer state and close current session on app quit
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if let sid = self.currentSessionId {
                    self.db.endWork(sessionId: sid)
                    self.currentSessionId = nil
                }
                self.saveTimerState()
            }
        }

        // Detect day change after system wake from sleep
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.checkDayChange()
                self.checkQuietHours()
                // Re-sync stats after wake (e.g. work minutes, streak)
                self.refreshStats()
            }
        }

    }

    // MARK: - Timer State Persistence

    private func restoreTimerState() {
        overtimeActive = db.loadFlag("overtime_active")
        let savedDate = db.timerSaveDate()
        let today = Database.todayString()

        // Day changed since last save — start fresh
        if !savedDate.isEmpty && savedDate != today {
            db.clearTimerState()
            handleDayChange()
            return
        }

        // Close any orphan sessions from today (e.g. app crashed mid-work)
        db.closeTodayOrphanSessions()

        let saved = db.loadTimerState()
        let secs = saved.pausedRemaining ?? 0
        switch saved.phase {
        case "working" where secs > 0:
            phase = .working
            currentSessionWorkConfig = config.workMinutes
            remainingSeconds = secs
            targetTime = Date().addingTimeInterval(Double(secs))
            currentSessionId = db.startSession(workMinutes: config.workMinutes, breakMinutes: config.breakMinutes, dailyGoal: config.dailyGoal)
            startTicking()
        case "paused" where secs > 0:
            phase = .paused
            currentSessionWorkConfig = config.workMinutes
            pausedRemaining = secs
            pausedPhase = .working
            remainingSeconds = secs
        case "alerting":
            // Was in alerting/breaking/waiting — restore to alerting without sound
            currentReminder = config.reminders.randomElement() ?? L.defaultBreakReminder
            if config.breakConfirm {
                phase = .alerting
                remainingSeconds = 0
                saveTimerState()
            } else {
                // No confirm needed — go straight to break
                currentSessionId = db.startSession(workMinutes: config.workMinutes, breakMinutes: config.breakMinutes, dailyGoal: config.dailyGoal)
                startBreak()
            }
        default:
            startWork()
        }
    }

    private func saveTimerState() {
        switch phase {
        case .working:
            db.saveTimerState(phase: "working", targetTime: nil, pausedRemaining: remainingSeconds)
        case .paused:
            db.saveTimerState(phase: "paused", targetTime: nil, pausedRemaining: pausedRemaining)
        case .alerting, .breaking, .waiting:
            db.saveTimerState(phase: "alerting", targetTime: nil, pausedRemaining: 0)
        }
        db.saveFlag("overtime_active", value: overtimeActive)
    }

    // MARK: - Timer

    func startWork() {
        phase = .working
        currentSessionWorkConfig = config.workMinutes
        targetTime = Date().addingTimeInterval(Double(config.workMinutes * 60))
        remainingSeconds = config.workMinutes * 60
        currentSessionId = db.startSession(workMinutes: config.workMinutes, breakMinutes: config.breakMinutes, dailyGoal: config.dailyGoal)
        saveTimerState()
        startTicking()
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func tick() {
        guard phase == .working else { return }
        let newVal = max(0, Int(targetTime.timeIntervalSinceNow))
        if newVal != remainingSeconds {
            remainingSeconds = newVal
        }
        // Refresh work minutes every 60 seconds
        if Date().timeIntervalSince(lastWorkMinutesRefresh) >= 60 {
            let dbMinutes = db.todayWorkMinutes()
            let sessionMinutes = currentSessionWorkMinutes
            todayWorkMinutes = dbMinutes + sessionMinutes
            // Sync today's entry in week work data for the chart
            let today = Database.todayString()
            if let idx = weekWorkData.firstIndex(where: { $0.0 == today }) {
                weekWorkData[idx].1 = dbMinutes + sessionMinutes
            }
            lastWorkMinutesRefresh = Date()
        }
        if remainingSeconds <= 0 {
            onWorkDone()
        }
    }

    // MARK: - Work Done -> Alert

    private func onWorkDone() {
        currentReminder = config.reminders.randomElement() ?? L.defaultBreakReminder
        playSound()

        if config.breakConfirm {
            phase = .alerting
            remainingSeconds = 0
            saveTimerState()
            overlayManager.pinForAlert()
        } else {
            startBreak()
        }
    }

    func confirmBreak() {
        alertRepeatTimer?.invalidate()
        alertRepeatTimer = nil
        overlayManager.dismissMenuPanel()
        startBreak()
    }

    // MARK: - Break

    private func startBreak() {
        phase = .breaking
        timer?.invalidate()  // Stop work timer; overlay manager handles break countdown
        breakWarning = ""
        breakSkipCount = 0
        breakStartDate = Date()
        currentBreakActivity = breakActivities.randomElement()
        currentReminder = config.reminders.randomElement()
        let secs = config.breakMinutes * 60
        remainingSeconds = secs

        if let sid = currentSessionId {
            db.endWork(sessionId: sid)
            db.startSessionBreak(sessionId: sid)
        }

        if config.breakPosition == .menuWindow {
            overlayManager.showMenuWindow(seconds: secs)
        } else {
            overlayManager.dismissMenuPanel()
            overlayManager.show(seconds: secs)
        }
    }

    private func onBreakDone() {
        phase = .waiting
        remainingSeconds = 0
        breakWarning = ""
        // For fullscreen: close overlay, pin menu bar to show waiting UI
        // For floating/menuWindow: keep panels open, SwiftUI shows waiting content
        if config.breakPosition == .fullscreen {
            overlayManager.hide()
        }
        overlayManager.pinForAlert()

        let actualSeconds: Int?
        if let start = breakStartDate {
            actualSeconds = Int(Date().timeIntervalSince(start))
        } else {
            actualSeconds = nil
        }
        if let sid = currentSessionId {
            db.endSessionBreak(sessionId: sid, actualSeconds: actualSeconds, skipped: false)
        }

        let oldStreak = maxStreak
        let oldTotal = totalCount
        db.addRecord()
        refreshStats()
        pendingBadge = detectNewBadge(oldStreak: oldStreak, oldTotal: oldTotal)
    }

    private var pendingBadge: Badge?

    func confirmReturn() {
        overlayManager.hideAll()
        let badge = pendingBadge
        pendingBadge = nil

        startWork()

        if let badge {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showBadgeCelebration(badge)
            }
        }
    }

    // MARK: - Pause / Reset

    func togglePause() {
        if phase == .paused, let prev = pausedPhase {
            // Don't allow manual resume during quiet hours
            if isInQuietHours { return }
            phase = prev
            pausedPhase = nil
            targetTime = Date().addingTimeInterval(Double(pausedRemaining))
            remainingSeconds = pausedRemaining
            startTicking()
            saveTimerState()
        } else if phase == .working || phase == .breaking {
            pausedRemaining = remainingSeconds
            pausedPhase = phase
            phase = .paused
            timer?.invalidate()
            saveTimerState()
        }
    }

    func reset() {
        timer?.invalidate()
        alertRepeatTimer?.invalidate()
        overlayManager.hide()
        pausedPhase = nil
        autoQuietPaused = false

        // Close current session so its work time is not lost
        if let sid = currentSessionId {
            db.endWork(sessionId: sid)
            currentSessionId = nil
        }

        isInQuietHours = false
        startWork()
        checkQuietHours()
    }

    // MARK: - Stats

    func refreshStats() {
        todayDone = db.todayCount()
        currentStreak = db.streakDays(goal: config.dailyGoal)
        maxStreak = db.maxStreakDays(goal: config.dailyGoal)
        weekData = db.recent7DaysCounts()
        totalCount = db.totalCount()
        todayWorkMinutes = db.todayWorkMinutes() + currentSessionWorkMinutes
        weekWorkData = db.recent7DaysWorkMinutes()
        todaySkipCount = db.todaySkipCount()
        // Add current session's contribution to today's entry in week data
        if currentSessionWorkMinutes > 0 {
            let today = Database.todayString()
            if let idx = weekWorkData.firstIndex(where: { $0.0 == today }) {
                weekWorkData[idx].1 += currentSessionWorkMinutes
            }
        }
    }

    /// Accurate work minutes for the current in-progress session, calculated from timer state
    private var currentSessionWorkMinutes: Int {
        guard currentSessionId != nil else { return 0 }
        if phase == .working {
            return max(0, currentSessionWorkConfig * 60 - remainingSeconds) / 60
        } else if phase == .paused, pausedPhase == .working {
            return max(0, currentSessionWorkConfig * 60 - pausedRemaining) / 60
        }
        return 0
    }

    private func detectNewBadge(oldStreak: Int, oldTotal: Int) -> Badge? {
        for badge in allBadges {
            if maxStreak >= badge.days && oldStreak < badge.days { return badge }
        }
        for badge in allTotalBadges {
            if totalCount >= badge.days && oldTotal < badge.days { return badge }
        }
        return nil
    }

    private var celebrationWindow: NSPanel?
    private var celebrationId: UUID?

    func showBadgeCelebration(_ badge: Badge) {
        // Close existing
        celebrationWindow?.orderOut(nil)
        celebrationWindow = nil
        celebrateBadge = nil
        celebrationId = nil

        // Small delay if replacing, so the old one visually clears
        let delay: Double = 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.doShowCelebration(badge)
        }
    }

    private func doShowCelebration(_ badge: Badge) {
        let thisId = UUID()
        celebrationId = thisId
        celebrateBadge = badge
        playSound("Glass")

        guard let screen = NSScreen.main else { return }
        let w: CGFloat = 420
        let h: CGFloat = 500
        let x = screen.visibleFrame.midX - w / 2
        let y = screen.visibleFrame.midY - h / 2

        let panel = NSPanel(
            contentRect: NSMakeRect(x, y, w, h),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false

        let dismissAction = { [weak self] in
            // Only dismiss if this is still the active celebration
            guard self?.celebrationId == thisId else { return }
            self?.celebrationWindow?.orderOut(nil)
            self?.celebrationWindow = nil
            self?.celebrateBadge = nil
            self?.celebrationId = nil
        }

        let view = BadgeCelebrationView(badge: badge, onDismiss: dismissAction)

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSMakeRect(0, 0, w, h)
        panel.contentView!.addSubview(hostingView)
        panel.orderFront(nil)

        celebrationWindow = panel
    }

    var showRestartPrompt = false
    var suppressNextRestartPrompt = false

    private func scheduleAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.autoSave(self.config)
            }
        }
    }

    private func autoSave(_ newConfig: AppConfig) {
        guard let old = lastSavedConfig, newConfig != old else { return }
        db.saveConfig(newConfig)
        // Only refresh stats when goal changes (affects streak/progress display)
        if newConfig.dailyGoal != old.dailyGoal {
            refreshStats()
        }
        lastSavedConfig = newConfig

        if newConfig.language != old.language {
            L.lang = newConfig.language
        }
        if newConfig.appearance != old.appearance {
            Self.applyAppearance(newConfig.appearance)
        }

        if suppressNextRestartPrompt {
            suppressNextRestartPrompt = false
            restartPromptTimer?.invalidate()
        } else if !isInQuietHours &&
           ((newConfig.workMinutes != old.workMinutes && (phase == .working || phase == .paused)) ||
            (newConfig.breakMinutes != old.breakMinutes && phase == .breaking)) {
            // Delay prompt so rapid edits (typing, stepper clicks) don't spam it
            restartPromptTimer?.invalidate()
            restartPromptTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.showRestartPrompt = true
                }
            }
        }

        if newConfig.quietHours != old.quietHours || newConfig.workDays != old.workDays ||
           newConfig.workHoursEnabled != old.workHoursEnabled ||
           newConfig.workStartTime != old.workStartTime ||
           newConfig.workEndTime != old.workEndTime {
            checkQuietHours()
        }

        if newConfig.shortcutEnabled != old.shortcutEnabled ||
           newConfig.shortcutKeyCode != old.shortcutKeyCode ||
           newConfig.shortcutModifiers != old.shortcutModifiers {
            setupShortcutMonitors()
        }
    }

    func resetToDefaults() {
        db.resetConfig()
        config = db.loadConfig()
        lastSavedConfig = config
        L.lang = config.language
        timer?.invalidate()
        alertRepeatTimer?.invalidate()
        overlayManager.hide()
        pausedPhase = nil
        // Close current session so its work time is not lost
        if let sid = currentSessionId {
            db.endWork(sessionId: sid)
            currentSessionId = nil
        }
        startWork()
        refreshStats()
    }

    func restartCurrentPhase() {
        timer?.invalidate()
        alertRepeatTimer?.invalidate()
        overlayManager.hide()
        pausedPhase = nil
        // Close current session so its work time is not lost
        if let sid = currentSessionId {
            db.endWork(sessionId: sid)
            currentSessionId = nil
        }
        startWork()
        checkQuietHours()
    }

    // MARK: - Helpers

    var formattedTime: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var phaseIcon: String {
        switch phase {
        case .working: return "🟢"
        case .alerting, .breaking: return "🟡"
        case .waiting: return "🔴"
        case .paused: return "⏸"
        }
    }

    var phaseLabel: String {
        switch phase {
        case .working: return L.phaseWorking
        case .alerting: return L.phaseAlerting
        case .breaking: return L.phaseBreaking
        case .waiting: return L.phaseWaiting
        case .paused: return L.phasePaused
        }
    }

    var goalProgress: Double {
        Double(min(todayDone, config.dailyGoal)) / Double(config.dailyGoal)
    }

    var encourageText: String {
        let gap = db.daysSinceLastGoal(goal: config.dailyGoal)
        if gap == 0 { return L.encourageGoalMet }
        if gap == -1 { return L.encourageNoRecord }
        if gap == 1 { return L.encourageYesterday }
        if gap <= 3 { return L.encourageGapShort(gap) }
        return L.encourageGapLong(gap)
    }

    var earnedBadge: Badge? {
        allBadges.last(where: { maxStreak >= $0.days })
    }

    var nextBadge: Badge? {
        allBadges.first(where: { maxStreak < $0.days })
    }

    func playSound(_ name: String? = nil) {
        guard config.soundEnabled else { return }
        NSSound(named: name ?? config.alertSound)?.play()
    }

    func playBreakDetectSound() {
        guard config.breakDetectSound else { return }
        NSSound(named: config.breakDetectSoundName)?.play()
    }

    func skipBreakClicked() {
        lastSkipClickTime = Date()
        breakSkipCount += 1
        if breakSkipCount >= breakSkipNeeded {
            forceEndBreak()
        }
    }

    func forceEndBreak() {
        guard phase == .breaking else { return }
        timer?.invalidate()
        alertRepeatTimer?.invalidate()
        alertRepeatTimer = nil
        breakWarning = ""
        overlayManager.hide()

        let actualSeconds: Int?
        if let start = breakStartDate {
            actualSeconds = Int(Date().timeIntervalSince(start))
        } else {
            actualSeconds = nil
        }
        if let sid = currentSessionId {
            db.endSessionBreak(sessionId: sid, actualSeconds: actualSeconds, skipped: true)
        }
        todaySkipCount = db.todaySkipCount()

        startWork()
    }

    // MARK: - Day Change

    /// Day changed — treat as a completely fresh start.
    /// All previous state (timers, sessions, overlays, quiet hours) is wiped.
    private func handleDayChange() {
        lastActiveDate = Database.todayString()

        // 1. Stop all timers
        timer?.invalidate()
        alertRepeatTimer?.invalidate()
        alertRepeatTimer = nil

        // 2. Dismiss all overlays immediately
        overlayManager.hideAll()

        // 3. Force phase to neutral before any UI can render stale state
        phase = .paused

        // 4. Clear all break / alerting / waiting state
        pausedPhase = nil
        autoQuietPaused = false
        breakWarning = ""
        breakSkipCount = 0
        currentBreakActivity = nil
        currentReminder = nil
        pendingBadge = nil
        breakStartDate = nil

        // 5. Close orphan session from previous day (e.g. alerting when lid closed)
        if let sid = currentSessionId {
            db.endWork(sessionId: sid)
            currentSessionId = nil
        }
        db.closeOrphanSessions(beforeDate: Database.todayString())

        // 6. Reset overtime & quiet hours
        overtimeActive = false
        db.saveFlag("overtime_active", value: false)
        isInQuietHours = false
        stopQuietCountdown()

        // 7. Clear persisted timer state
        db.clearTimerState()

        // 8. Refresh stats for the new day, then start fresh
        refreshStats()
        startWork()
        checkQuietHours()
    }

    private func checkDayChange() {
        let today = Database.todayString()
        if today != lastActiveDate {
            handleDayChange()
        }
    }

    // MARK: - Quiet Hours

    private func startQuietCheckTimer() {
        quietCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.checkDayChange()
                self?.checkQuietHours()
            }
        }
        checkQuietHours()
    }

    func activateOvertime() {
        overtimeActive = true
        db.saveFlag("overtime_active", value: true)
        if isInQuietHours {
            isInQuietHours = false
            stopQuietCountdown()
            autoQuietPaused = false
    
            startWork()
        }
    }

    private func checkQuietHours() {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        let isWorkDay = config.workDays.contains(weekday)
        let inQuietPeriod = config.quietHours.contains { $0.isActive(at: now) }

        // Check if outside configured work hours
        var outsideWorkHours = false
        if config.workHoursEnabled {
            let workPeriod = QuietHourPeriod(start: config.workStartTime, end: config.workEndTime)
            outsideWorkHours = !workPeriod.isActive(at: now)
        }

        let shouldPause = !isWorkDay || inQuietPeriod || (outsideWorkHours && !overtimeActive)

        // Reset overtime when entering work hours again
        if overtimeActive && !outsideWorkHours && isWorkDay {
            overtimeActive = false
            db.saveFlag("overtime_active", value: false)
        }

        if shouldPause && !isInQuietHours {
            isInQuietHours = true
            if phase == .breaking {
                // End break cleanly without creating a new session
                timer?.invalidate()
                alertRepeatTimer?.invalidate()
                alertRepeatTimer = nil
                breakWarning = ""
                overlayManager.hide()
                let actualSeconds: Int?
                if let start = breakStartDate {
                    actualSeconds = Int(Date().timeIntervalSince(start))
                } else {
                    actualSeconds = nil
                }
                if let sid = currentSessionId {
                    db.endSessionBreak(sessionId: sid, actualSeconds: actualSeconds, skipped: false)
                    currentSessionId = nil
                }
                phase = .paused
                autoQuietPaused = true
            }
            if phase == .alerting {
                alertRepeatTimer?.invalidate()
                alertRepeatTimer = nil
                overlayManager.hideAll()
                phase = .paused
                autoQuietPaused = true
            }
            if phase == .waiting {
                overlayManager.hideAll()
                pendingBadge = nil
                phase = .paused
                autoQuietPaused = true
            }
            if phase == .working {
                timer?.invalidate()
                if let sid = currentSessionId {
                    db.endWork(sessionId: sid)
                    currentSessionId = nil
                }
                phase = .paused
                autoQuietPaused = true
            }
            startQuietCountdown()
        } else if !shouldPause && isInQuietHours {
            isInQuietHours = false
            stopQuietCountdown()
            autoQuietPaused = false
    
            startWork()
        }

        if isInQuietHours {
            updateQuietRemaining()
        }
    }

    // MARK: - Quiet Countdown

    private func startQuietCountdown() {
        quietCountdownTimer?.invalidate()
        updateQuietRemaining()
        // Update every 30s — quiet hours last hours, second-level precision is unnecessary
        // and avoids triggering a full MenuView redraw every second via @Published.
        quietCountdownTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isInQuietHours else { return }
                self.updateQuietRemaining()
                if self.quietRemainingSeconds <= 0 {
                    self.checkQuietHours()
                }
            }
        }
    }

    private func stopQuietCountdown() {
        quietCountdownTimer?.invalidate()
        quietCountdownTimer = nil
        quietRemainingSeconds = 0
    }

    private func updateQuietRemaining() {
        let cal = Calendar.current
        let now = Date()
        var endDates: [Date] = []

        // Check quiet hour periods
        for period in config.quietHours where period.isActive(at: now) {
            if let endDate = period.endDate(from: now) {
                endDates.append(endDate)
            }
        }

        // Check work hours (outside work hours = quiet)
        if config.workHoursEnabled && !overtimeActive {
            let workPeriod = QuietHourPeriod(start: config.workStartTime, end: config.workEndTime)
            if !workPeriod.isActive(at: now), let endDate = workPeriod.startDate(from: now) {
                endDates.append(endDate)
            }
        }

        // Check non-work day — ends at midnight
        let weekday = cal.component(.weekday, from: now)
        if !config.workDays.contains(weekday) {
            if let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) {
                endDates.append(tomorrow)
            }
        }

        if let nearest = endDates.min() {
            quietRemainingSeconds = max(0, Int(nearest.timeIntervalSince(now)))
        } else {
            quietRemainingSeconds = 0
        }
    }

    var formattedQuietTime: String {
        let h = quietRemainingSeconds / 3600
        let m = (quietRemainingSeconds % 3600) / 60
        let s = quietRemainingSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Keyboard Shortcut

    func setupShortcutMonitors() {
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        guard config.shortcutEnabled else { return }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let targetMods = NSEvent.ModifierFlags(rawValue: self.config.shortcutModifiers)
                .intersection([.command, .option, .shift, .control])
            let eventMods = event.modifierFlags.intersection([.command, .option, .shift, .control])
            guard event.keyCode == self.config.shortcutKeyCode && eventMods == targetMods else { return event }
            if self.phase == .alerting || self.phase == .waiting {
                self.handleShortcutAction()
                return nil  // consume the event
            }
            return event
        }
    }

    private func handleShortcutAction() {
        switch phase {
        case .alerting:
            confirmBreak()
        case .waiting:
            confirmReturn()
        default:
            break
        }
    }

    static func applyAppearance(_ appearance: AppAppearance) {
        switch appearance {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
