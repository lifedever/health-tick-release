import Foundation
import Combine
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
final class AppState: ObservableObject {
    @Published var config: AppConfig
    @Published var phase: AppPhase = .working
    @Published var remainingSeconds: Int = 0
    @Published var todayDone: Int = 0
    @Published var currentStreak: Int = 0
    @Published var maxStreak: Int = 0
    @Published var breakWarning: String = ""
    @Published var breakSkipCount: Int = 0
    let breakSkipNeeded = 3
    @Published var weekData: [(String, Int)] = []
    @Published var totalCount: Int = 0
    @Published var isInQuietHours: Bool = false
    @Published var showOnboarding: Bool = false
    @Published var currentBreakActivity: BreakActivity?
    @Published var currentReminder: String?
    @Published var celebrateBadge: Badge?

    private var currentSessionId: Int64?
    private var breakStartDate: Date?
    private var targetTime: Date = Date()
    private var pausedRemaining: Int = 0
    private var pausedPhase: AppPhase?
    private var timer: Timer?
    private var alertRepeatTimer: Timer?
    private var quietCheckTimer: Timer?
    private var autoQuietPaused: Bool = false
    private let db = Database.shared
    var overlayManager = BreakOverlayManager()

    private var configWatcher: AnyCancellable?
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
        Self.applyAppearance(config.appearance)
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


        // Save timer state on app quit
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            self?.saveTimerState()
        }

        // Auto-save when config changes
        configWatcher = $config
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newConfig in
                self?.autoSave(newConfig)
            }
    }

    // MARK: - Timer State Persistence

    private func restoreTimerState() {
        let saved = db.loadTimerState()
        let secs = saved.pausedRemaining ?? 0
        switch saved.phase {
        case "working" where secs > 0:
            phase = .working
            remainingSeconds = secs
            targetTime = Date().addingTimeInterval(Double(secs))
            currentSessionId = db.startSession(workMinutes: config.workMinutes, breakMinutes: config.breakMinutes, dailyGoal: config.dailyGoal)
            startTicking()
        case "paused" where secs > 0:
            phase = .paused
            pausedRemaining = secs
            pausedPhase = .working
            remainingSeconds = secs
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
        default:
            db.clearTimerState()
        }
    }

    // MARK: - Timer

    func startWork() {
        phase = .working
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

    @Published var showRestartPrompt = false
    var suppressNextRestartPrompt = false

    private func autoSave(_ newConfig: AppConfig) {
        guard let old = lastSavedConfig, newConfig != old else { return }
        db.saveConfig(newConfig)
        refreshStats()
        lastSavedConfig = newConfig

        if newConfig.language != old.language {
            L.lang = newConfig.language
        }
        if newConfig.appearance != old.appearance {
            Self.applyAppearance(newConfig.appearance)
        }

        if suppressNextRestartPrompt {
            suppressNextRestartPrompt = false
        } else if !isInQuietHours &&
           ((newConfig.workMinutes != old.workMinutes && (phase == .working || phase == .paused)) ||
            (newConfig.breakMinutes != old.breakMinutes && phase == .breaking)) {
            showRestartPrompt = true
        }

        if newConfig.quietHours != old.quietHours || newConfig.workDays != old.workDays {
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
        startWork()
        refreshStats()
    }

    func restartCurrentPhase() {
        timer?.invalidate()
        alertRepeatTimer?.invalidate()
        overlayManager.hide()
        pausedPhase = nil
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

        startWork()
    }

    // MARK: - Quiet Hours

    private func startQuietCheckTimer() {
        quietCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in self?.checkQuietHours() }
        }
        checkQuietHours()
    }

    private func checkQuietHours() {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        let isWorkDay = config.workDays.contains(weekday)
        let inQuietPeriod = config.quietHours.contains { $0.isActive(at: now) }
        let shouldPause = !isWorkDay || inQuietPeriod

        if shouldPause && !isInQuietHours {
            isInQuietHours = true
            if phase == .breaking { forceEndBreak() }
            if phase == .working { togglePause(); autoQuietPaused = true }
        } else if !shouldPause && isInQuietHours {
            isInQuietHours = false
            if phase == .paused && autoQuietPaused { togglePause(); autoQuietPaused = false }
        }
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
