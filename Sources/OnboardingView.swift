import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) var state
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0

    // Step 0: Work schedule
    @State private var workStart = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    @State private var workEnd = Calendar.current.date(from: DateComponents(hour: 18, minute: 0)) ?? Date()

    // Step 1: Lunch + work days
    @State private var lunchStart = Calendar.current.date(from: DateComponents(hour: 12, minute: 0)) ?? Date()
    @State private var lunchEnd = Calendar.current.date(from: DateComponents(hour: 13, minute: 0)) ?? Date()
    @State private var workDays: Set<Int> = [2, 3, 4, 5, 6]

    // Step 2: Work rhythm
    @State private var workInterval: Double = 60
    @State private var breakDuration: Double = 120  // now in seconds

    private var effectiveMinutes: Int {
        let totalMin = Int(workEnd.timeIntervalSince(workStart)) / 60
        let lunchMin = Int(lunchEnd.timeIntervalSince(lunchStart)) / 60
        return max(0, totalMin - max(0, lunchMin))
    }

    private var recommendedGoal: Int {
        let cycle = Int(workInterval) + Int(breakDuration) / 60
        guard cycle > 0 else { return 1 }
        return max(1, effectiveMinutes / cycle)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: step dots + skip
            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule()
                            .fill(i <= step ? Color.green : Color.gray.opacity(0.2))
                            .frame(width: i == step ? 20 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.25), value: step)
                    }
                }
                Spacer()
                Button(L.onboardingSkip) {
                    finishOnboarding()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.tertiary)
                .font(.caption)
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 8)

            // Content area
            Group {
                switch step {
                case 0: step1View
                case 1: step2View
                case 2: step3View
                case 3: step4View
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 32)

            // Bottom navigation
            HStack {
                if step > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { step -= 1 }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text(L.onboardingBack)
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                Spacer()
                if step < 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { step += 1 }
                    } label: {
                        HStack(spacing: 4) {
                            Text(L.onboardingNext)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .font(.callout.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(.green.gradient, in: Capsule())
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button {
                        applySettings()
                        finishOnboarding()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                            Text(L.onboardingFinish)
                        }
                        .font(.callout.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(.green.gradient, in: Capsule())
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
            .padding(.top, 12)
        }
        .frame(width: 460, height: 420)
    }

    // MARK: - Step 1: Welcome + Work Schedule

    private var step1View: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon + welcome
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .shadow(color: .black.opacity(0.1), radius: 6, y: 2)

            Text(L.onboardingWelcome)
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 12)

            Text(L.onboardingWelcomeDesc)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            // Work schedule card
            VStack(spacing: 0) {
                HStack {
                    Label(L.onboardingWorkStart, systemImage: "sunrise.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    DatePicker("", selection: $workStart, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider().padding(.leading, 44)

                HStack {
                    Label(L.onboardingWorkEnd, systemImage: "sunset.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    DatePicker("", selection: $workEnd, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            .padding(.top, 20)

            Spacer()
        }
    }

    // MARK: - Step 2: Lunch + Work Days

    private var step2View: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 32))
                .foregroundStyle(.orange.gradient)

            Text(L.onboardingLunchBreak)
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 10)

            // Lunch card
            VStack(spacing: 0) {
                HStack {
                    Label(L.onboardingLunchStart, systemImage: "clock")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    DatePicker("", selection: $lunchStart, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider().padding(.leading, 44)

                HStack {
                    Label(L.onboardingLunchEnd, systemImage: "clock.badge.checkmark")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    DatePicker("", selection: $lunchEnd, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            .padding(.top, 16)

            // Work days
            Text(L.onboardingWorkDays)
                .font(.callout.bold())
                .padding(.top, 20)

            HStack(spacing: 6) {
                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                    Button {
                        if workDays.contains(day) {
                            workDays.remove(day)
                        } else {
                            workDays.insert(day)
                        }
                    } label: {
                        Text(L.weekdayName(day))
                            .font(.system(size: 13, weight: .medium))
                            .frame(width: 42, height: 32)
                            .foregroundStyle(workDays.contains(day) ? .white : .primary.opacity(0.6))
                            .background(
                                workDays.contains(day) ? Color.green : Color.gray.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Step 3: Work Rhythm

    private var step3View: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "metronome.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green.gradient)

            Text(L.onboardingWorkRhythm)
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 10)

            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "deskclock.fill")
                            .foregroundStyle(.green)
                            .frame(width: 18)
                        Text(L.onboardingWorkInterval)
                            .font(.callout)
                        Spacer()
                        Text("\(Int(workInterval)) \(L.unitMinutes)")
                            .font(.callout.bold().monospacedDigit())
                            .foregroundStyle(.green)
                            .frame(width: 65, alignment: .trailing)
                    }
                    Slider(value: $workInterval, in: 10...90, step: 5)
                        .tint(.green)
                }

                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: "cup.and.saucer.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 18)
                        Text(L.onboardingBreakDuration)
                            .font(.callout)
                        Spacer()
                        Text(formatBreakDuration(Int(breakDuration)))
                            .font(.callout.bold().monospacedDigit())
                            .foregroundStyle(.orange)
                            .frame(width: 80, alignment: .trailing)
                    }
                    Slider(value: $breakDuration, in: 20...900, step: 10)
                        .tint(.orange)
                }
            }
            .padding(16)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            .padding(.top, 20)

            Spacer()
        }
    }

    // MARK: - Step 4: Summary

    private var step4View: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green.gradient)

            Text(L.onboardingSummary)
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 10)

            // Summary card
            VStack(spacing: 0) {
                summaryRow(icon: "clock.fill", color: .blue, label: L.onboardingEffectiveWork, value: "\(effectiveMinutes) \(L.unitMinutes)")
                Divider().padding(.leading, 44)
                summaryRow(icon: "deskclock.fill", color: .green, label: L.workDuration, value: "\(Int(workInterval)) \(L.unitMinutes)")
                Divider().padding(.leading, 44)
                summaryRow(icon: "cup.and.saucer.fill", color: .orange, label: L.breakDuration, value: formatBreakDuration(Int(breakDuration)))
                Divider().padding(.leading, 44)
                summaryRow(icon: "target", color: .purple, label: L.onboardingDailyGoal, value: "\(recommendedGoal) \(L.unitTimes)")
            }
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            .padding(.top, 20)

            Text(L.onboardingGoalRecommendation(recommendedGoal))
                .font(.caption)
                .foregroundStyle(.green)
                .padding(.top, 10)

            Text(L.onboardingSettingsHint)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)

            Spacer()
        }
    }

    private func summaryRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.bold().monospacedDigit())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func formatBreakDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds) \(L.unitSeconds)"
        } else if seconds % 60 == 0 {
            return "\(seconds / 60) \(L.unitMinutes)"
        } else {
            return "\(seconds / 60)\(L.unitMinutes)\(seconds % 60)\(L.unitSeconds)"
        }
    }

    // MARK: - Actions

    private func applySettings() {
        state.config.workMinutes = Int(workInterval)
        state.config.breakSeconds = Int(breakDuration)
        state.config.dailyGoal = recommendedGoal
        state.config.workDays = workDays

        let cal = Calendar.current
        let lunchStartStr = String(format: "%02d:%02d", cal.component(.hour, from: lunchStart), cal.component(.minute, from: lunchStart))
        let lunchEndStr = String(format: "%02d:%02d", cal.component(.hour, from: lunchEnd), cal.component(.minute, from: lunchEnd))
        state.config.quietHours = [QuietHourPeriod(start: lunchStartStr, end: lunchEndStr)]

        // Save work hours
        let workStartStr = String(format: "%02d:%02d", cal.component(.hour, from: workStart), cal.component(.minute, from: workStart))
        let workEndStr = String(format: "%02d:%02d", cal.component(.hour, from: workEnd), cal.component(.minute, from: workEnd))
        state.config.workHoursEnabled = true
        state.config.workStartTime = workStartStr
        state.config.workEndTime = workEndStr
    }

    private func finishOnboarding() {
        Database.shared.setOnboardingCompleted()
        state.suppressNextRestartPrompt = true
        state.showOnboarding = false
        state.reset()
        dismiss()
    }
}
