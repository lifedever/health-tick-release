import SwiftUI

struct MenuView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    /// Whether to show the shared BreakCardView (alerting, breaking, or waiting)
    private var isBreakPhase: Bool {
        state.phase == .alerting || state.phase == .breaking || state.phase == .waiting
    }

    var body: some View {
        VStack(spacing: 12) {
            // Quiet hours indicator
            if state.isInQuietHours {
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

            if isBreakPhase {
                // Shared break/alerting/waiting UI (same component used by floating & fullscreen)
                BreakCardView()
            } else {
                // Normal working/paused state
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

                    VStack(spacing: 2) {
                        Text(state.formattedTime)
                            .font(.system(size: 28, weight: .light, design: .monospaced))
                        Text(state.phaseLabel)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary.opacity(0.6))
                    }
                }
                .frame(width: 120, height: 120)
                .padding(.top, 4)

                normalContent

                Divider().padding(.horizontal, 4)

                normalControls
            }

            Divider().padding(.horizontal, 4)

            Button {
                NSApp.terminate(nil)
            } label: {
                Text(L.quitApp)
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.35))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 240)
        .onAppear {
            bringOtherWindowsToFront()
        }
    }

    // MARK: - Normal Content

    private var normalContent: some View {
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
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Text("\(state.currentStreak)")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                    Text(L.streak)
                        .font(.system(size: 9))
                        .foregroundStyle(.primary.opacity(0.5))
                }
            }

            // 7-day pixels
            HStack(spacing: 4) {
                ForEach(Array(state.weekData.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(pixelColor(count: item.1, goal: state.config.dailyGoal))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Text("\(item.1)")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(item.1 > 0 ? .white : .clear)
                            )
                        Text(shortDay(item.0))
                            .font(.system(size: 8))
                            .foregroundStyle(.primary.opacity(0.45))
                    }
                }
            }

            // Badge hint
            if let badge = state.earnedBadge {
                HStack(spacing: 4) {
                    Text(badge.icon)
                    Text(badge.name)
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            } else if let next = state.nextBadge {
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

    private var normalControls: some View {
        HStack {
            controlButton(
                title: state.phase == .paused ? L.resume : L.pause,
                icon: state.phase == .paused ? "play.fill" : "pause.fill"
            ) {
                state.togglePause()
            }

            controlButton(title: L.resetAction, icon: "arrow.counterclockwise") {
                state.reset()
            }

            Spacer()

            controlButton(title: L.achievements, icon: "trophy") {
                dismissMenuPanel()
                openWindow(id: "stats")
                bringToFront()
            }

            controlButton(title: L.help, icon: "questionmark.circle") {
                dismissMenuPanel()
                openWindow(id: "helpguide")
                bringToFront()
            }

            controlButton(title: L.settings, icon: "gear") {
                dismissMenuPanel()
                openWindow(id: "preferences")
                bringToFront()
            }
        }
    }

    // MARK: - Helpers

    private var timerProgress: Double {
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
        switch state.phase {
        case .working: return .green
        case .breaking: return .orange
        case .alerting: return .red
        case .paused: return .orange
        case .waiting: return .blue
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
    }

    private func dismissMenuPanel() {
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

    private func bringToFront() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func bringOtherWindowsToFront() {
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

    private func pixelColor(count: Int, goal: Int) -> Color {
        if count == 0 { return Color.gray.opacity(0.15) }
        let ratio = Double(count) / Double(max(goal, 1))
        if ratio >= 1.0 { return .green }
        if ratio >= 0.5 { return .green.opacity(0.55) }
        return .green.opacity(0.3)
    }

    private func shortDay(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        guard parts.count == 3, let d = Int(parts[2]) else { return "" }
        return "\(d)"
    }
}
