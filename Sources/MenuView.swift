import SwiftUI
import AppKit

// MARK: - Menu View (parent shell — reads only phase & isInQuietHours, both change infrequently)

struct MenuView: View {
    @Environment(AppState.self) var state
    @Environment(\.openWindow) private var openWindow

    private var isBreakPhase: Bool {
        !state.isInQuietHours && !state.goalAutoStopped && (state.phase == .alerting || state.phase == .breaking || state.phase == .waiting)
    }

    var body: some View {

        VStack(spacing: 12) {
            // Header indicators (own observation scope)
            MenuHeaderView()

            if isBreakPhase {
                BreakCardView()
            } else {
                // Timer circle — only this re-renders every second
                MenuTimerCircle()

                // Stats — re-renders only when stats change (infrequent)
                MenuStatsContent()

                Divider().padding(.horizontal, 4)

                MenuControls()
            }

            Divider().padding(.horizontal, 4)

            Button {
                NSApp.terminate(nil)
            } label: {
                Text(L.quitApp)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.75))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .handCursor()
        }
        .padding(16)
        .frame(width: 240)
        .onAppear {
            menuBringOtherWindowsToFront()
        }
        .onChange(of: state.phase) { _, _ in
            // macOS 14: MenuBarExtra panel vibrancy background doesn't update
            // when content height changes. Nudge the panel frame to force redraw.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                nudgeMenuBarExtraPanel()
            }
        }
    }
}

// MARK: - Header Indicators (goal reached, skip warning, quiet hours)

private struct MenuHeaderView: View {
    @Environment(AppState.self) var state

    var body: some View {

        Group {
            if state.todayDone >= state.config.dailyGoal {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                    Text(L.dailyGoalReached)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            if state.todaySkipCount >= 3 {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text(L.skipWarningMenu)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            if state.isInQuietHours || state.goalAutoStopped {
                HStack(spacing: 6) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.purple)
                    Text(L.quietHoursActive)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.purple)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Timer Circle (the ONLY view that re-renders every second)

private struct MenuTimerCircle: View {
    @Environment(AppState.self) var state

    private var isOffDuty: Bool {
        state.isInQuietHours || state.goalAutoStopped
    }

    private var timerProgress: Double {
        if isOffDuty {
            guard state.quietRemainingSeconds > 0 else { return 0 }
            let maxDisplay = 3600.0
            return min(1.0, Double(state.quietRemainingSeconds) / maxDisplay)
        }
        let total: Int
        if state.phase == .working || (state.phase == .paused && state.remainingSeconds > 0) {
            total = state.config.workMinutes * 60
        } else {
            return 0
        }
        guard total > 0 else { return 0 }
        return Double(state.remainingSeconds) / Double(total)
    }

    private var phaseColor: Color {
        if isOffDuty { return .orange }
        switch state.phase {
        case .working: return .green
        case .breaking: return .orange
        case .alerting: return .red
        case .paused: return .orange
        case .waiting: return .blue
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 3)
            Circle()
                .trim(from: 0, to: timerProgress)
                .stroke(
                    phaseColor.gradient,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 6) {
                if isOffDuty {
                    Button {
                        if state.goalAutoStopped {
                            state.resumeFromGoalStop()
                        } else {
                            state.activateOvertime()
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 18))
                            Text(L.continueWorking)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.borderless)
                    .handCursor()
                } else {
                    Text(state.formattedTime)
                        .font(.system(size: 28, weight: .light, design: .monospaced))
                    if state.phase == .working {
                        Button {
                            state.manualBreak()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.system(size: 10))
                                Text(L.manualBreak)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.primary.opacity(0.5))
                        }
                        .buttonStyle(.borderless)
                        .handCursor()
                    } else {
                        Text(state.phaseLabel)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary.opacity(0.6))
                    }
                }
            }
        }
        .frame(width: 120, height: 120)
        .padding(.top, 4)
    }
}

// MARK: - Stats Content (re-renders only when stats/config change — NOT every second)

private struct MenuStatsContent: View {
    @Environment(AppState.self) var state

    var body: some View {

        Group {
            // Today progress
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(state.todayDone)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(.green)
                    Text(L.done)
                        .font(.system(size: 9))
                        .foregroundStyle(.primary.opacity(0.5))
                }

                VStack(spacing: 2) {
                    Text("\(state.config.dailyGoal)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(.primary.opacity(0.6))
                    Text(L.goal)
                        .font(.system(size: 9))
                        .foregroundStyle(.primary.opacity(0.5))
                }

                VStack(spacing: 2) {
                    Text("\(state.currentStreak)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(.orange)
                    Text(L.streak)
                        .font(.system(size: 9))
                        .foregroundStyle(.primary.opacity(0.5))
                }

                if state.todaySkipCount > 0 {
                    VStack(spacing: 2) {
                        Text("\(state.todaySkipCount)")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(state.todaySkipCount >= 3 ? .red : .red.opacity(0.6))
                        Text(L.todaySkipped)
                            .font(.system(size: 9))
                            .foregroundStyle(.primary.opacity(0.5))
                    }
                }
            }

            // Today work time + share button
            HStack(spacing: 4) {
                Text("✍️")
                    .font(.system(size: 12))
                Text(L.todayWorkedPrefix)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.6))
                Text(L.formatWorkTime(state.todayWorkMinutes))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.blue)

                Spacer().frame(width: 6)

                Button {
                    ShareManager.showPreview(state: state)
                    menuDismissPanel()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 10))
                        .foregroundStyle(.primary.opacity(0.35))
                }
                .buttonStyle(.borderless)
                .handCursor()
                .help(L.share)
            }

            // 7-day pixels
            HStack(spacing: 4) {
                ForEach(Array(state.weekData.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(menuPixelColor(count: item.1, goal: state.config.dailyGoal))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Text("\(item.1)")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(item.1 > 0 ? .white : .clear)
                            )
                        Text(menuShortDay(item.0))
                            .font(.system(size: 8))
                            .foregroundStyle(.primary.opacity(0.45))
                    }
                }
            }

            // Badge hint — prefer next goal, fallback to earned badge
            if let next = state.nextBadge {
                let hint = L.badgeNext(icon: next.icon, name: next.name, days: next.days - state.currentStreak)
                HStack(spacing: 0) {
                    Text("🎯 \(hint.prefix)")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.5))
                    Text(hint.badge)
                        .font(.callout.bold())
                        .foregroundStyle(.green)
                    Text(hint.mid)
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.5))
                    Text(hint.count)
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.orange)
                    Text(hint.suffix)
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.5))
                }
            } else if let badge = state.earnedBadge {
                HStack(spacing: 4) {
                    Text(badge.icon)
                    Text(badge.name)
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }

            // Update hint
            if UpdateChecker.shared.hasUpdate, let ver = UpdateChecker.shared.latestVersion {
                Button {
                    UpdateChecker.shared.showUpdateAlertPublic()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.blue)
                        Text(L.updateAvailable(ver))
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

// MARK: - Controls (pause/reset/achievements/help/settings)

private struct MenuControls: View {
    @Environment(AppState.self) var state
    @Environment(\.openWindow) private var openWindow

    var body: some View {

        HStack {
            controlButton(
                title: state.phase == .paused ? L.resume : L.pause,
                icon: state.phase == .paused ? "play.fill" : "pause.fill"
            ) {
                if state.goalAutoStopped {
                    state.resumeFromGoalStop()
                } else {
                    state.togglePause()
                }
            }

            controlButton(title: L.resetAction, icon: "arrow.counterclockwise") {
                state.reset()
            }

            Spacer()

            controlButton(title: L.achievements, icon: "trophy") {
                menuDismissPanel()
                openWindow(id: "stats")
                menuBringToFront()
            }

            controlButton(title: L.help, icon: "questionmark.circle") {
                menuDismissPanel()
                openWindow(id: "helpguide")
                menuBringToFront()
            }

            controlButton(title: L.settings, icon: "gear") {
                menuDismissPanel()
                openWindow(id: "preferences")
                menuBringToFront()
            }
        }
    }

    private func controlButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                Text(title)
                    .font(.system(size: 9))
            }
            .frame(width: 36, height: 32)
            .foregroundStyle(.primary.opacity(0.5))
        }
        .buttonStyle(.borderless)
        .handCursor()
    }
}

// MARK: - File-level helpers (shared by sub-views)

/// Nudge the MenuBarExtra panel frame by 1px to force macOS to recalculate
/// the vibrancy background. Works around a macOS 14 bug where the
/// NSVisualEffectView doesn't resize when SwiftUI content height changes.
private func nudgeMenuBarExtraPanel() {
    guard let panel = NSApp.windows.first(where: { w in
        w is NSPanel
        && w.styleMask.contains(.nonactivatingPanel)
        && w.styleMask.contains(.fullSizeContentView)
        && w.frame.width < 350
        && w.isVisible
    }) as? NSPanel else { return }
    var f = panel.frame
    f.size.height += 1
    panel.setFrame(f, display: false)
    DispatchQueue.main.async {
        f.size.height -= 1
        panel.setFrame(f, display: true)
    }
}

private func menuDismissPanel() {
    for window in NSApp.windows {
        guard let panel = window as? NSPanel else { continue }
        if panel.styleMask.contains(.nonactivatingPanel),
           panel.styleMask.contains(.fullSizeContentView),
           panel.frame.width < 350 {
            panel.orderOut(nil)
            break
        }
    }
}

private func menuBringToFront() {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
}

private func menuBringOtherWindowsToFront() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        let hasVisible = NSApp.windows.contains { w in
            w.isVisible && !(w is NSPanel) && !w.title.isEmpty && w.styleMask.contains(.titled)
        }
        if hasVisible {
            for w in NSApp.windows where w.isVisible && !(w is NSPanel) && !w.title.isEmpty && w.styleMask.contains(.titled) {
                w.orderFrontRegardless()
            }
        }
    }
}

private func menuPixelColor(count: Int, goal: Int) -> Color {
    if count == 0 { return Color.gray.opacity(0.15) }
    let ratio = Double(count) / Double(max(goal, 1))
    if ratio >= 1.0 { return .green }
    if ratio >= 0.5 { return .green.opacity(0.55) }
    return .green.opacity(0.3)
}

private func menuShortDay(_ dateStr: String) -> String {
    let parts = dateStr.split(separator: "-")
    guard parts.count == 3, let d = Int(parts[2]) else { return "" }
    return "\(d)"
}
