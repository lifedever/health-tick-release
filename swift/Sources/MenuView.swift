import SwiftUI

struct MenuView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            // Circular timer
            ZStack {
                // Track
                Circle()
                    .stroke(.quaternary, lineWidth: 5)
                // Progress
                Circle()
                    .trim(from: 0, to: timerProgress)
                    .stroke(
                        phaseColor.gradient,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timerProgress)

                VStack(spacing: 2) {
                    Text(state.formattedTime)
                        .font(.system(size: 32, weight: .light, design: .monospaced))
                    Text(state.phaseLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 110, height: 110)
            .padding(.top, 4)

            // Today progress
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(state.todayDone)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(.green)
                    Text("已完成")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 2) {
                    Text("\(state.config.dailyGoal)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("目标")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
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
                    Text("连续")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            // 7-day pixels
            let week = Database.shared.recent7DaysCounts()
            HStack(spacing: 4) {
                ForEach(Array(week.enumerated()), id: \.offset) { _, item in
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
                            .foregroundStyle(.tertiary)
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
                HStack(spacing: 0) {
                    Text("🎯 距 ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(next.icon)\(next.name)")
                        .font(.callout.bold())
                        .foregroundStyle(.green)
                    Text(" 还差 ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(next.days - state.currentStreak)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.orange)
                    Text(" 天")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                        Text("v\(ver) 可用，点击更新")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.borderless)
            }

            Divider().padding(.horizontal, 4)

            // Controls
            HStack {
                controlButton(
                    title: state.phase == .paused ? "继续" : "暂停",
                    icon: state.phase == .paused ? "play.fill" : "pause.fill"
                ) {
                    state.togglePause()
                }
                .disabled(state.phase == .alerting || state.phase == .waiting)

                controlButton(title: "重置", icon: "arrow.counterclockwise") {
                    state.reset()
                }

                Spacer()

                controlButton(title: "成就", icon: "trophy") {
                    openWindow(id: "stats")
                    bringToFront()
                }

                controlButton(title: "帮助", icon: "questionmark.circle") {
                    openWindow(id: "helpguide")
                    bringToFront()
                }

                controlButton(title: "设置", icon: "gear") {
                    openWindow(id: "settings")
                    bringToFront()
                }
            }

            Divider().padding(.horizontal, 4)

            Button {
                NSApp.terminate(nil)
            } label: {
                Text("退出 HealthTick")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 240)
    }

    private var timerProgress: Double {
        let total: Int
        if state.phase == .working || (state.phase == .paused && state.remainingSeconds > 0) {
            total = state.config.workMinutes * 60
        } else if state.phase == .breaking {
            total = state.config.breakMinutes * 60
        } else {
            return 0
        }
        guard total > 0 else { return 0 }
        return 1.0 - Double(state.remainingSeconds) / Double(total)
    }

    private var phaseColor: Color {
        switch state.phase {
        case .working: return .green
        case .breaking: return .orange
        case .alerting: return .red
        case .paused: return .gray
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
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
    }

    private func bringToFront() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
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
