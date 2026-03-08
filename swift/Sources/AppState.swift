import Foundation
import Combine
import AppKit

enum BreakPosition: String, CaseIterable, Equatable {
    case topRight = "top_right"
    case topLeft = "top_left"
    case center = "center"
    case fullscreen = "fullscreen"

    var label: String {
        switch self {
        case .topRight: return "右上角"
        case .topLeft: return "左上角"
        case .center: return "屏幕中央"
        case .fullscreen: return "全屏强制"
        }
    }
}

struct AppConfig: Equatable {
    var workMinutes: Int = 60
    var breakMinutes: Int = 2
    var dailyGoal: Int = 8
    var reminders: [String] = ["该起来走走了", "该喝水了"]
    var soundEnabled: Bool = true
    var breakDetectSound: Bool = false
    var breakPosition: BreakPosition = .topRight
    var breakConfirm: Bool = true
}

struct Badge {
    let days: Int
    let name: String
    let desc: String
    let icon: String
}

let allBadges: [Badge] = [
    Badge(days: 3, name: "迈出第一步", desc: "连续达标 3 天", icon: "👣"),
    Badge(days: 7, name: "初心者", desc: "连续达标 7 天", icon: "🌱"),
    Badge(days: 14, name: "习惯养成", desc: "连续达标 14 天", icon: "🌿"),
    Badge(days: 21, name: "三周达人", desc: "连续达标 21 天", icon: "🌳"),
    Badge(days: 30, name: "健康卫士", desc: "连续达标 30 天", icon: "🛡️"),
    Badge(days: 50, name: "半百之约", desc: "连续达标 50 天", icon: "⭐"),
    Badge(days: 60, name: "钢铁意志", desc: "连续达标 60 天", icon: "💪"),
    Badge(days: 90, name: "季度王者", desc: "连续达标 90 天", icon: "👑"),
    Badge(days: 100, name: "传奇坚持", desc: "连续达标 100 天", icon: "🏆"),
    Badge(days: 180, name: "半年之星", desc: "连续达标 180 天", icon: "💎"),
    Badge(days: 365, name: "年度传说", desc: "连续达标 365 天", icon: "🐉"),
]

enum AppPhase: String {
    case working    // 工作倒计时
    case alerting   // 弹窗提醒中
    case breaking   // 休息倒计时（遮罩）
    case waiting    // 等用户确认回来
    case paused     // 手动暂停
}

@MainActor
final class AppState: ObservableObject {
    @Published var config: AppConfig
    @Published var phase: AppPhase = .working
    @Published var remainingSeconds: Int = 0
    @Published var todayDone: Int = 0
    @Published var currentStreak: Int = 0
    @Published var maxStreak: Int = 0

    private var targetTime: Date = Date()
    private var pausedRemaining: Int = 0
    private var pausedPhase: AppPhase?
    private var timer: Timer?
    private var alertRepeatTimer: Timer?
    private let db = Database.shared
    var overlayManager = BreakOverlayManager()

    private var configWatcher: AnyCancellable?
    private var lastSavedConfig: AppConfig?

    init() {
        config = db.loadConfig()
        lastSavedConfig = config
        overlayManager.appState = self
        overlayManager.onForceEnd = { [weak self] in
            self?.forceEndBreak()
        }
        startWork()
        refreshStats()

        // Auto-save when config changes
        configWatcher = $config
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] newConfig in
                self?.autoSave(newConfig)
            }
    }

    // MARK: - Timer

    func startWork() {
        phase = .working
        targetTime = Date().addingTimeInterval(Double(config.workMinutes * 60))
        remainingSeconds = config.workMinutes * 60
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
        guard phase == .working || phase == .breaking else { return }
        remainingSeconds = max(0, Int(targetTime.timeIntervalSinceNow))
        if remainingSeconds <= 0 {
            if phase == .working { onWorkDone() }
            else if phase == .breaking { onBreakDone() }
        }
    }

    // MARK: - Work Done → Alert

    private func onWorkDone() {
        let reminder = config.reminders.randomElement() ?? "该休息了"
        playSound("Glass")

        if config.breakConfirm {
            phase = .alerting
            remainingSeconds = 0
            alertRepeatTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor [weak self] in self?.playSound("Ping") }
            }
            showBreakAlert(reminder)
        } else {
            startBreak()
        }
    }

    private func showBreakAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "健康打卡"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好的，我去休息")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        NSApp.setActivationPolicy(.accessory)
        alertRepeatTimer?.invalidate()
        alertRepeatTimer = nil
        startBreak()
    }

    // MARK: - Break

    private func startBreak() {
        phase = .breaking
        let secs = config.breakMinutes * 60
        targetTime = Date().addingTimeInterval(Double(secs))
        remainingSeconds = secs
        overlayManager.show(seconds: secs)
        startTicking()
    }

    private func onBreakDone() {
        phase = .waiting
        remainingSeconds = 0
        overlayManager.hide()

        db.addRecord()
        refreshStats()

        showReturnDialog()
    }

    private func showReturnDialog() {
        let alert = NSAlert()
        alert.messageText = "健康打卡"
        alert.informativeText = "休息结束啦！准备好继续工作了吗？"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "我回来了")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        NSApp.setActivationPolicy(.accessory)
        startWork()
    }

    // MARK: - Pause / Reset

    func togglePause() {
        if phase == .paused, let prev = pausedPhase {
            phase = prev
            pausedPhase = nil
            targetTime = Date().addingTimeInterval(Double(pausedRemaining))
            remainingSeconds = pausedRemaining
            startTicking()
        } else if phase == .working || phase == .breaking {
            pausedRemaining = remainingSeconds
            pausedPhase = phase
            phase = .paused
            timer?.invalidate()
        }
    }

    func reset() {
        timer?.invalidate()
        alertRepeatTimer?.invalidate()
        overlayManager.hide()
        pausedPhase = nil
        startWork()
    }

    // MARK: - Stats

    func refreshStats() {
        todayDone = db.todayCount()
        currentStreak = db.streakDays(goal: config.dailyGoal)
        maxStreak = db.maxStreakDays(goal: config.dailyGoal)
    }

    @Published var showRestartPrompt = false

    private func autoSave(_ newConfig: AppConfig) {
        guard let old = lastSavedConfig, newConfig != old else { return }
        db.saveConfig(newConfig)
        refreshStats()
        lastSavedConfig = newConfig

        if (newConfig.workMinutes != old.workMinutes && (phase == .working || phase == .paused)) ||
           (newConfig.breakMinutes != old.breakMinutes && phase == .breaking) {
            showRestartPrompt = true
        }
    }

    func restartCurrentPhase() {
        timer?.invalidate()
        alertRepeatTimer?.invalidate()
        overlayManager.hide()
        pausedPhase = nil
        startWork()
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
        case .working: return "工作中"
        case .alerting: return "该休息了！"
        case .breaking: return "休息中"
        case .waiting: return "等待确认..."
        case .paused: return "已暂停"
        }
    }

    var goalProgress: Double {
        Double(min(todayDone, config.dailyGoal)) / Double(config.dailyGoal)
    }

    var encourageText: String {
        let gap = db.daysSinceLastGoal(goal: config.dailyGoal)
        if gap == 0 { return "今日已达标，继续保持！" }
        if gap == -1 { return "还没有达标记录，今天开始吧！" }
        if gap == 1 { return "昨天达标了，今天也加油！" }
        if gap <= 3 { return "已经 \(gap) 天没达标了，重新开始！" }
        return "距上次达标已 \(gap) 天，今天是新的开始！"
    }

    var earnedBadge: Badge? {
        allBadges.last(where: { maxStreak >= $0.days })
    }

    var nextBadge: Badge? {
        allBadges.first(where: { maxStreak < $0.days })
    }

    func playSound(_ name: String) {
        guard config.soundEnabled else { return }
        NSSound(named: name)?.play()
    }

    func playBreakDetectSound() {
        guard config.breakDetectSound else { return }
        NSSound(named: "Tink")?.play()
    }

    func forceEndBreak() {
        guard phase == .breaking else { return }
        timer?.invalidate()
        alertRepeatTimer?.invalidate()
        alertRepeatTimer = nil
        overlayManager.hide()
        startWork()
    }
}
