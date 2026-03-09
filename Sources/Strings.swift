import Foundation

enum AppLanguage: String, CaseIterable, Equatable {
    case system = "system"
    case zh = "zh"
    case en = "en"

    var displayName: String {
        switch self {
        case .system: return resolved == .zh ? "跟随系统" : "System"
        case .zh: return "中文"
        case .en: return "English"
        }
    }

    var resolved: AppLanguage {
        if self != .system { return self }
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("zh") ? .zh : .en
    }
}

// MARK: - Localized Strings

struct L {
    static var lang: AppLanguage = .system

    private static var isZh: Bool { lang.resolved == .zh }
    static var isZhAccess: Bool { isZh }

    // MARK: - App General
    static var appName: String { "HealthTick" }
    static var appSubtitle: String { isZh ? "健康打卡" : "Health Check-in" }
    static var appSlogan: String { isZh ? "久坐提醒 · 强制休息 · 习惯养成" : "Sit Reminder · Forced Break · Habit Building" }

    // MARK: - Phases
    static var phaseWorking: String { isZh ? "工作中" : "Working" }
    static var phaseAlerting: String { isZh ? "该休息了！" : "Time to rest!" }
    static var phaseBreaking: String { isZh ? "休息中" : "On Break" }
    static var phaseWaiting: String { isZh ? "等待确认..." : "Waiting..." }
    static var phasePaused: String { isZh ? "已暂停" : "Paused" }

    // MARK: - Menu View
    static var done: String { isZh ? "已完成" : "Done" }
    static var goal: String { isZh ? "目标" : "Goal" }
    static var streak: String { isZh ? "连续" : "Streak" }
    static var pause: String { isZh ? "暂停" : "Pause" }
    static var resume: String { isZh ? "继续" : "Resume" }
    static var resetAction: String { isZh ? "重置" : "Reset" }
    static var achievements: String { isZh ? "成就" : "Stats" }
    static var help: String { isZh ? "帮助" : "Help" }
    static var settings: String { isZh ? "设置" : "Settings" }
    static var quitApp: String { isZh ? "退出 HealthTick" : "Quit HealthTick" }
    static func updateAvailable(_ ver: String) -> String {
        isZh ? "v\(ver) 可用，点击更新" : "v\(ver) available, click to update"
    }
    static func badgeNext(icon: String, name: String, days: Int) -> (prefix: String, badge: String, mid: String, count: String, suffix: String) {
        if isZh {
            return ("距 ", "\(icon)\(name)", " 还差 ", "\(days)", " 天")
        } else {
            return ("", "\(icon)\(name)", " in ", "\(days)", " days")
        }
    }

    // MARK: - Break Position
    static var posTopRight: String { isZh ? "右上角" : "Top Right" }
    static var posTopLeft: String { isZh ? "左上角" : "Top Left" }
    static var posCenter: String { isZh ? "屏幕中央" : "Center" }
    static var posFullscreen: String { isZh ? "全屏强制" : "Fullscreen" }
    static var posMenuWindow: String { isZh ? "主窗口提醒" : "Menu Window" }

    // MARK: - Break Overlay
    static var breakTimeTitle: String { isZh ? "休息时间" : "Break Time" }
    static var breakLeaveMsg: String { isZh ? "请离开电脑，起来走走" : "Please leave the computer and take a walk" }
    static var breakFloatMsg: String { isZh ? "起来走走，休息一下" : "Stand up and take a break" }
    static var breakDetectedPause: String { isZh ? "检测到操作，倒计时已暂停" : "Activity detected, countdown paused" }
    static func skipButton(_ current: Int, _ total: Int) -> String {
        isZh ? "跳过 (\(current)/\(total))" : "Skip (\(current)/\(total))"
    }

    // MARK: - Alerts
    static var healthCheckIn: String { isZh ? "健康打卡" : "Health Check-in" }
    static var defaultBreakReminder: String { isZh ? "该休息了" : "Time for a break" }
    static var alertConfirmBreak: String { isZh ? "好的，我去休息" : "OK, I'll take a break" }
    static var breakOverReturnPrompt: String { isZh ? "休息结束啦！准备好继续工作了吗？" : "Break is over! Ready to get back to work?" }
    static var alertImBack: String { isZh ? "我回来了" : "I'm back" }

    // MARK: - Settings - Tabs
    static var tabGeneral: String { isZh ? "通用" : "General" }
    static var tabSystem: String { isZh ? "系统" : "System" }
    static var tabApp: String { isZh ? "应用" : "App" }
    static var tabReminders: String { isZh ? "提醒" : "Reminders" }
    static var tabAbout: String { isZh ? "关于" : "About" }

    // MARK: - Settings - General
    static var workDuration: String { isZh ? "工作时长" : "Work Duration" }
    static var breakDuration: String { isZh ? "休息时长" : "Break Duration" }
    static var dailyGoal: String { isZh ? "每日目标" : "Daily Goal" }
    static var unitMinutes: String { isZh ? "分钟" : "min" }
    static var unitTimes: String { isZh ? "次" : "times" }
    static var breakWindow: String { isZh ? "休息窗口" : "Break Window" }
    static var preview: String { isZh ? "预览" : "Preview" }
    static var badgeUnlocked: String { isZh ? "恭喜解锁新徽章！" : "Badge Unlocked!" }
    static var breakConfirm: String { isZh ? "休息前确认" : "Confirm Before Break" }
    static var reminderSound: String { isZh ? "提醒声音" : "Reminder Sound" }
    static var activityDetectSound: String { isZh ? "操作检测提示音" : "Activity Detection Sound" }
    static var alertSoundLabel: String { isZh ? "提醒声音" : "Alert Sound" }
    static var detectSoundLabel: String { isZh ? "检测提示音" : "Detection Sound" }
    static var shortcutLabel: String { isZh ? "快捷键" : "Shortcut" }
    static var shortcutRecording: String { isZh ? "请按下按键…" : "Press a key…" }
    static var shortcutClickToChange: String { isZh ? "点击修改" : "Click to edit" }
    static func shortcutQuickConfirm(_ key: String) -> String { isZh ? "按下 \(key) 快速确认" : "Press \(key) to confirm" }
    static var shortcutHint: String { isZh ? "开启后，休息提醒弹出或休息结束时，可按快捷键快速确认，无需点击按钮。仅在应用窗口获得焦点时生效。" : "When enabled, press the shortcut to quickly confirm when the break reminder appears or when break ends. Only works when the app window is focused." }
    static var launchAtLogin: String { isZh ? "开机自启动" : "Launch at Login" }
    static var language: String { isZh ? "语言" : "Language" }
    static var appearance: String { isZh ? "外观" : "Appearance" }
    static var appearanceSystem: String { isZh ? "跟随系统" : "System" }
    static var appearanceLight: String { isZh ? "浅色" : "Light" }
    static var appearanceDark: String { isZh ? "深色" : "Dark" }
    static var durationChanged: String { isZh ? "时长已变更" : "Duration Changed" }
    static var durationChangedMsg: String { isZh ? "工作或休息时长已修改，是否按新设置重新开始计时？" : "Work or break duration has been changed. Restart the timer with new settings?" }
    static var restartTimer: String { isZh ? "重新计时" : "Restart Timer" }
    static var laterAction: String { isZh ? "稍后再说" : "Later" }

    // MARK: - Settings - Reminders
    static var reminderHint: String { isZh ? "休息时随机展示一条提醒" : "A random reminder is shown during breaks" }
    static var addReminderPlaceholder: String { isZh ? "添加新的提醒内容..." : "Add a new reminder..." }
    static var defaultReminder1: String { isZh ? "该起来走走了" : "Time to stand up and walk" }
    static var defaultReminder2: String { isZh ? "该喝水了" : "Time to drink water" }

    // MARK: - Settings - About
    static var checkUpdate: String { isZh ? "检查更新" : "Check for Updates" }
    static var checking: String { isZh ? "检查中..." : "Checking..." }
    static var sponsorSupport: String { isZh ? "请喝一杯咖啡 ☕" : "Buy me a coffee ☕" }
    static var resetAllData: String { isZh ? "重置数据" : "Reset Data" }
    static var resetWarning: String { isZh ? "此操作将删除所有打卡记录，不可恢复！" : "This will delete all check-in records. This cannot be undone!" }
    static var cancel: String { isZh ? "取消" : "Cancel" }
    static var confirmDelete: String { isZh ? "确认删除" : "Confirm Delete" }
    static var finalConfirm: String { isZh ? "最后确认：真的要清除全部数据吗？" : "Final confirmation: Really delete all data?" }
    static var thinkAgain: String { isZh ? "我再想想" : "Let me think" }
    static var deleteForever: String { isZh ? "彻底删除" : "Delete Forever" }
    static var dataCleared: String { isZh ? "数据已清除" : "Data Cleared" }
    static var resetSettings: String { isZh ? "重置设置" : "Reset Settings" }
    static var resetSettingsWarning: String { isZh ? "将恢复所有设置到默认值（不影响打卡数据）。" : "This will restore all settings to defaults (check-in data is not affected)." }
    static var resetSettingsConfirm: String { isZh ? "确认重置设置" : "Confirm Reset Settings" }
    static var settingsReset: String { isZh ? "设置已重置" : "Settings Reset" }
    static var resetDataWarning: String { isZh ? "将删除所有打卡记录，不可恢复！设置不受影响。" : "This will delete all check-in records permanently! Settings are not affected." }

    // MARK: - Stats Window
    static var todayDone: String { isZh ? "今日完成" : "Today" }
    static var currentStreak: String { isZh ? "当前连续" : "Current Streak" }
    static var maxStreak: String { isZh ? "最长连续" : "Best Streak" }
    static var weekGoal: String { isZh ? "本周达标" : "This Week" }
    static var monthGoal: String { isZh ? "本月达标" : "This Month" }
    static var last7Days: String { isZh ? "近 7 天" : "Last 7 Days" }
    static func totalTimes(_ n: Int) -> String { isZh ? "共 \(n) 次" : "\(n) total" }
    static var last30Days: String { isZh ? "近 30 天" : "Last 30 Days" }
    static func goalDays(_ n: Int) -> String { isZh ? "\(n) 天达标" : "\(n) days met" }
    static var less: String { isZh ? "少" : "Less" }
    static var more: String { isZh ? "多" : "More" }
    static func dayLabel(_ d: Int) -> String { isZh ? "\(d)日" : "\(d)" }
    static var activeDays: String { isZh ? "活跃天数" : "Active Days" }
    static var bestDay: String { isZh ? "单日最高" : "Best Day" }
    static var avgDaily: String { isZh ? "日均完成" : "Daily Avg" }
    static var usingDays: String { isZh ? "使用天数" : "Days Using" }
    static func timesUnit(_ n: Int) -> String { isZh ? "\(n) 次" : "\(n)" }
    static var tabStats: String { isZh ? "统计" : "Statistics" }
    static var tabBadges: String { isZh ? "徽章墙" : "Badges" }
    static var earnedBadges: String { isZh ? "已获得徽章" : "Badges Earned" }
    static func badgeCount(_ n: Int) -> String { isZh ? "\(n) 枚" : "\(n)" }
    static var noBadgesYet: String { isZh ? "坚持打卡解锁徽章" : "Keep checking in to unlock badges" }
    static func firstBadgeHint(_ days: Int) -> String {
        isZh ? "连续达标 \(days) 天即可获得第一枚" : "Reach \(days) consecutive days for your first badge"
    }
    static var nextGoal: String { isZh ? "下一个目标" : "Next Goal" }
    static func daysToUnlock(_ days: Int) -> String {
        isZh ? "再坚持 \(days) 天解锁新徽章" : "\(days) more days to unlock a new badge"
    }

    // MARK: - Encourage
    static var encourageGoalMet: String { isZh ? "今日已达标，继续保持！" : "Goal met today, keep it up!" }
    static var encourageNoRecord: String { isZh ? "还没有达标记录，今天开始吧！" : "No records yet. Start today!" }
    static var encourageYesterday: String { isZh ? "昨天达标了，今天也加油！" : "You met the goal yesterday, keep going!" }
    static func encourageGapShort(_ days: Int) -> String {
        isZh ? "已经 \(days) 天没达标了，重新开始！" : "It's been \(days) days. Time to restart!"
    }
    static func encourageGapLong(_ days: Int) -> String {
        isZh ? "距上次达标已 \(days) 天，今天是新的开始！" : "\(days) days since last goal. Today is a fresh start!"
    }

    // MARK: - Badges
    static func badgeName(_ days: Int) -> String {
        if isZh {
            switch days {
            case 3: return "迈出第一步"
            case 7: return "初心者"
            case 14: return "习惯养成"
            case 21: return "三周达人"
            case 30: return "健康卫士"
            case 50: return "半百之约"
            case 60: return "钢铁意志"
            case 90: return "季度王者"
            case 100: return "传奇坚持"
            case 180: return "半年之星"
            case 365: return "年度传说"
            default: return ""
            }
        } else {
            switch days {
            case 3: return "First Steps"
            case 7: return "Beginner"
            case 14: return "Habit Formed"
            case 21: return "3-Week Pro"
            case 30: return "Health Guardian"
            case 50: return "Half Century"
            case 60: return "Iron Will"
            case 90: return "Quarter King"
            case 100: return "Legendary"
            case 180: return "Half-Year Star"
            case 365: return "Annual Legend"
            default: return ""
            }
        }
    }

    static func badgeDesc(_ days: Int) -> String {
        if isZh {
            return "连续达标 \(days) 天"
        } else {
            return "\(days) consecutive days"
        }
    }

    // MARK: - Update Checker
    static var newVersionFound: String { isZh ? "发现新版本" : "New Version Available" }
    static func updateInfo(version: String, currentVersion: String, arch: String) -> String {
        if isZh {
            return "HealthTick v\(version) 已发布（当前 v\(currentVersion)）。\n将为你下载 \(arch) 版本到「下载」文件夹。"
        } else {
            return "HealthTick v\(version) is available (current v\(currentVersion)).\nThe \(arch) version will be downloaded to your Downloads folder."
        }
    }
    static var downloadNow: String { isZh ? "立即下载" : "Download Now" }
    static var downloadComplete: String { isZh ? "下载完成" : "Download Complete" }
    static var downloadCompleteMsg: String {
        if isZh {
            return "已保存到「下载」文件夹。\n点击「安装并退出」将打开 DMG 并退出当前应用，方便你拖入替换。"
        } else {
            return "Saved to your Downloads folder.\nClick \"Install & Quit\" to open the DMG and quit the app for replacement."
        }
    }
    static var installAndQuit: String { isZh ? "安装并退出" : "Install & Quit" }
    static var installLater: String { isZh ? "稍后安装" : "Install Later" }
    static func networkError(_ msg: String) -> String { isZh ? "网络错误: \(msg)" : "Network error: \(msg)" }
    static func alreadyLatest(_ ver: String) -> String { isZh ? "已是最新版本 v\(ver)" : "Already up to date v\(ver)" }
    static var noUpdateTitle: String { isZh ? "暂无更新" : "No Update Available" }
    static func noUpdateMsg(_ ver: String) -> String { isZh ? "当前版本 v\(ver) 已是最新。" : "Current version v\(ver) is already up to date." }
    static func currentIsLatest(_ ver: String) -> String { isZh ? "当前已是最新版本 v\(ver)" : "Already on the latest version v\(ver)" }
    static func downloadFailed(_ msg: String) -> String { isZh ? "下载失败: \(msg)" : "Download failed: \(msg)" }
    static func saveFailed(_ msg: String) -> String { isZh ? "保存失败: \(msg)" : "Save failed: \(msg)" }

    // MARK: - Menu Bar Commands
    static var checkForUpdates: String { isZh ? "检查更新..." : "Check for Updates..." }
    static var helpMenu: String { isZh ? "HealthTick 帮助" : "HealthTick Help" }

    // MARK: - Help View
    static var helpTitle: String { isZh ? "HealthTick 使用指南" : "HealthTick User Guide" }
    static var helpCoreWorkflow: String { isZh ? "核心工作流程" : "Core Workflow" }
    static var helpStep1Title: String { isZh ? "工作计时" : "Work Timer" }
    static var helpStep1Desc: String {
        isZh ? "启动后自动开始工作倒计时（默认 60 分钟），菜单栏图标显示为行走人物。"
            : "Automatically starts a work countdown (default 60 min). The menu bar icon shows a walking figure."
    }
    static var helpStep2Title: String { isZh ? "休息提醒" : "Break Reminder" }
    static var helpStep2Desc: String {
        isZh ? "倒计时结束后弹出提醒，可设置是否需要手动确认。"
            : "A reminder pops up when the countdown ends. You can configure whether manual confirmation is needed."
    }
    static var helpStep3Title: String { isZh ? "强制休息" : "Forced Break" }
    static var helpStep3Desc: String {
        isZh ? "进入休息倒计时（默认 2 分钟），弹出休息窗口。如果检测到你仍在操作，倒计时会暂停，直到你真正离开。"
            : "Enters a break countdown (default 2 min) with a break window. If activity is detected, the countdown pauses until you actually leave."
    }
    static var helpStep4Title: String { isZh ? "继续工作" : "Resume Work" }
    static var helpStep4Desc: String {
        isZh ? "休息结束后确认回来，自动开始下一轮工作计时。"
            : "After confirming you're back from break, the next work timer starts automatically."
    }
    static var helpFeatures: String { isZh ? "功能说明" : "Features" }
    static var helpFeatureWorkDuration: String { isZh ? "每轮工作的倒计时时间，范围 1-120 分钟。" : "Work countdown duration per round, range 1-120 minutes." }
    static var helpFeatureBreakDuration: String { isZh ? "每次休息的倒计时时间，范围 1-15 分钟。" : "Break countdown duration, range 1-15 minutes." }
    static var helpFeatureDailyGoal: String { isZh ? "每天需要完成的休息次数，范围 1-20 次。达标后连续天数 +1。" : "Daily required break count, range 1-20. Meeting the goal adds to your streak." }
    static var helpFeatureBreakPos: String { isZh ? "可选右上角、左上角、屏幕中央（悬浮）或全屏强制。" : "Options: top-right, top-left, center (floating), or fullscreen (forced)." }
    static var helpFeatureBreakPosTitle: String { isZh ? "休息窗口位置" : "Break Window Position" }
    static var helpFeatureBreakConfirm: String { isZh ? "开启后，工作结束需手动确认才进入休息；关闭则自动进入休息倒计时。" : "When enabled, you must confirm before entering break. When disabled, break starts automatically." }
    static var helpFeatureBreakConfirmTitle: String { isZh ? "休息确认" : "Break Confirmation" }
    static var helpFeatureSound: String { isZh ? "工作结束时播放提示音。" : "Plays a sound when work time ends." }
    static var helpFeatureSoundTitle: String { isZh ? "提醒声音" : "Reminder Sound" }
    static var helpFeatureDetectSound: String { isZh ? "休息期间检测到操作时播放提示音，提醒你停下来。" : "Plays a sound when activity is detected during break, reminding you to stop." }
    static var helpFeatureDetectSoundTitle: String { isZh ? "操作检测提示音" : "Activity Detection Sound" }
    static var helpFeatureReset: String { isZh ? "重新开始当前工作计时。" : "Restart the current work timer." }
    static var helpFeatureResetTitle: String { isZh ? "重置" : "Reset" }
    static var helpFeaturePause: String { isZh ? "暂停当前倒计时，恢复后从暂停处继续。" : "Pause the current countdown and resume from where you left off." }
    static var helpFeaturePauseTitle: String { isZh ? "暂停 / 继续" : "Pause / Resume" }
    static var helpFeatureResetData: String { isZh ? "在设置 > 关于中可清除所有打卡记录（需三次确认）。" : "Clear all check-in records in Settings > About (requires triple confirmation)." }
    static var helpFeatureResetDataTitle: String { isZh ? "重置数据" : "Reset Data" }
    static var helpBreakWindow: String { isZh ? "休息窗口" : "Break Window" }
    static var helpBreakWindowDesc: String { isZh ? "休息期间会弹出一个提示窗口，显示倒计时和随机提醒语。" : "A window pops up during breaks showing the countdown and a random reminder." }
    static var helpBreakWindowDetect: String {
        isZh ? "**操作检测**：如果你在休息期间继续使用电脑（空闲时间 < 3 秒），倒计时会自动暂停，确保你真正休息了足够时间。"
            : "**Activity Detection**: If you continue using the computer during break (idle < 3 sec), the countdown pauses to ensure you truly rest."
    }
    static var helpBreakWindowSkip: String {
        isZh ? "**强制跳过**：连续快速点击休息窗口 3 次可以强制关闭（紧急情况使用）。"
            : "**Force Skip**: Click the skip button 3 times quickly to force-close the break window (for emergencies)."
    }
    static var helpBadgeSystem: String { isZh ? "徽章激励体系" : "Badge System" }
    static var helpBadgeSystemDesc: String {
        isZh ? "通过连续达标或累计打卡解锁徽章。徽章只有获得后才会显示，保持神秘感！以下是完整的徽章列表："
            : "Unlock badges by consecutive streaks or cumulative check-ins. Badges are hidden until earned! Here's the complete list:"
    }
    static var helpBadgeStreak: String { isZh ? "连续打卡徽章" : "Streak Badges" }
    static var helpBadgeTotal: String { isZh ? "累计打卡徽章" : "Cumulative Badges" }
    static var helpTips: String { isZh ? "使用建议" : "Tips" }
    static var helpTip1: String { isZh ? "推荐工作 45-60 分钟，休息 2-5 分钟，符合番茄工作法理念。" : "Work 45-60 min, rest 2-5 min — aligns with the Pomodoro technique." }
    static var helpTip2: String { isZh ? "每日目标建议设为 6-8 次，对应 6-8 小时工作时间。" : "Set daily goal to 6-8 times, matching 6-8 hours of work." }
    static var helpTip3: String { isZh ? "休息时离开座位走动、远眺窗外、做简单拉伸效果最佳。" : "During breaks, walk around, look out the window, or do simple stretches." }
    static var helpTip4: String { isZh ? "连续达标的关键是坚持——即使忙碌的日子也尝试完成最低目标。" : "Consistency is key — try to meet the goal even on busy days." }
    static var helpTip5: String { isZh ? "使用全屏强制模式可以最大程度确保你去休息。" : "Use fullscreen forced mode to maximize your chance of actually resting." }
    static var helpUpdateSection: String { isZh ? "检查更新" : "Check for Updates" }
    static var helpUpdateDesc: String {
        isZh ? "HealthTick 支持通过 GitHub Releases 自动检查更新。在设置 > 关于页面可以手动检查，也会在启动时自动检查。发现新版本后会提示下载。"
            : "HealthTick checks for updates via GitHub Releases. You can manually check in Settings > About, or it checks automatically on launch."
    }
    static var helpSponsorSection: String { isZh ? "赞助支持" : "Sponsor" }
    static var helpSponsorDesc: String {
        isZh ? "HealthTick 完全免费。如果它对你的健康有帮助，欢迎赞助支持开发者继续维护和改进！"
            : "HealthTick is completely free. If it helps your health, consider sponsoring the developer!"
    }
    static var helpSponsorThanks: String { isZh ? "感谢每一位支持者" : "Thanks to every supporter" }
    static var wechatPay: String { isZh ? "微信支付" : "WeChat Pay" }
    static var alipay: String { isZh ? "支付宝" : "Alipay" }
    static var githubPage: String { "GitHub" }

    // MARK: - Window Titles
    static var settingsWindow: String { isZh ? "设置" : "Settings" }
    static var helpWindow: String { isZh ? "帮助" : "Help" }
    static var statsWindow: String { isZh ? "成就" : "Achievements" }
    static var onboardingWindow: String { isZh ? "欢迎" : "Welcome" }

    // MARK: - Quiet Hours
    static var quietHours: String { isZh ? "休息时段" : "Quiet Hours" }
    static var quietHoursActive: String { isZh ? "休息时段中" : "Quiet Hours" }
    static var addQuietHour: String { isZh ? "添加休息时段" : "Add Quiet Period" }
    static var quietHoursHelp: String { isZh ? "在休息时段内，计时器会自动暂停，不会弹出休息提醒。适合设置午休、会议等不需要提醒的时间段。" : "During quiet hours, the timer pauses automatically and no break reminders will appear. Use this for lunch breaks, meetings, or other times you don't need reminders." }
    static var workDays: String { isZh ? "工作日" : "Work Days" }
    static var monday: String { isZh ? "一" : "Mon" }
    static var tuesday: String { isZh ? "二" : "Tue" }
    static var wednesday: String { isZh ? "三" : "Wed" }
    static var thursday: String { isZh ? "四" : "Thu" }
    static var friday: String { isZh ? "五" : "Fri" }
    static var saturday: String { isZh ? "六" : "Sat" }
    static var sunday: String { isZh ? "日" : "Sun" }

    static func weekdayName(_ weekday: Int) -> String {
        switch weekday {
        case 1: return sunday
        case 2: return monday
        case 3: return tuesday
        case 4: return wednesday
        case 5: return thursday
        case 6: return friday
        case 7: return saturday
        default: return ""
        }
    }

    // MARK: - Onboarding
    static var onboardingWelcome: String { isZh ? "欢迎使用 HealthTick" : "Welcome to HealthTick" }
    static var onboardingWelcomeDesc: String { isZh ? "让我们花一分钟来设置你的工作节奏" : "Let's take a minute to set up your work rhythm" }
    static var onboardingWorkSchedule: String { isZh ? "工作时间" : "Work Schedule" }
    static var onboardingWorkStart: String { isZh ? "上班时间" : "Start Time" }
    static var onboardingWorkEnd: String { isZh ? "下班时间" : "End Time" }
    static var onboardingLunchBreak: String { isZh ? "午休时间" : "Lunch Break" }
    static var onboardingLunchStart: String { isZh ? "午休开始" : "Lunch Start" }
    static var onboardingLunchEnd: String { isZh ? "午休结束" : "Lunch End" }
    static var onboardingWorkDays: String { isZh ? "工作日" : "Work Days" }
    static var onboardingWorkRhythm: String { isZh ? "工作节奏" : "Work Rhythm" }
    static var onboardingWorkInterval: String { isZh ? "每次工作多久休息" : "Work before break" }
    static var onboardingBreakDuration: String { isZh ? "每次休息多久" : "Break duration" }
    static var onboardingSummary: String { isZh ? "推荐设置" : "Recommended Settings" }
    static var onboardingEffectiveWork: String { isZh ? "有效工作时间" : "Effective Work Time" }
    static var onboardingDailyGoal: String { isZh ? "每日目标" : "Daily Goal" }
    static var onboardingNext: String { isZh ? "下一步" : "Next" }
    static var onboardingBack: String { isZh ? "上一步" : "Back" }
    static var onboardingFinish: String { isZh ? "开始使用" : "Get Started" }
    static var onboardingSkip: String { isZh ? "跳过" : "Skip" }
    static func onboardingGoalRecommendation(_ n: Int) -> String {
        isZh ? "推荐每日 \(n) 次" : "Recommended: \(n) times/day"
    }
    static var reopenOnboarding: String { isZh ? "设置引导" : "Setup Guide" }
    static var onboardingOpen: String { isZh ? "打开" : "Open" }
    static var onboardingSettingsHint: String { isZh ? "以上设置随时可在「设置 → 应用」中修改" : "You can change these anytime in Settings → App" }

    // MARK: - Total Badges
    static var streakBadges: String { isZh ? "连续徽章" : "Streak Badges" }
    static var totalBadges: String { isZh ? "累计徽章" : "Total Badges" }

    static func totalBadgeName(_ count: Int) -> String {
        if isZh {
            switch count {
            case 50: return "半百积累"
            case 100: return "百次里程"
            case 200: return "双百突破"
            case 500: return "五百征途"
            case 1000: return "千次大师"
            case 2000: return "两千巅峰"
            case 5000: return "五千传奇"
            default: return ""
            }
        } else {
            switch count {
            case 50: return "Fifty Mark"
            case 100: return "Century"
            case 200: return "Double Century"
            case 500: return "Five Hundred"
            case 1000: return "Thousand Master"
            case 2000: return "Two Thousand Peak"
            case 5000: return "Five Thousand Legend"
            default: return ""
            }
        }
    }

    static func totalBadgeDesc(_ count: Int) -> String {
        isZh ? "累计打卡 \(count) 次" : "\(count) total check-ins"
    }

    // MARK: - Break Activities
    static var breakActivity: String { isZh ? "休息建议" : "Break Suggestion" }
}
