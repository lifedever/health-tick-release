import SwiftUI
import ServiceManagement
import AppKit

private enum SettingsTab: Hashable {
    case system, app, breakTab, reminders, about
}

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var selectedTab: SettingsTab = .system

    var body: some View {
        L.lang = state.config.language
        return TabView(selection: $selectedTab) {
            // Lazy: only build the selected tab's heavy content
            Group {
                if selectedTab == .system { SystemTab() } else { Color.clear }
            }
            .tag(SettingsTab.system)
            .tabItem { Label(L.tabSystem, systemImage: "gearshape") }

            Group {
                if selectedTab == .app { AppTab() } else { Color.clear }
            }
            .tag(SettingsTab.app)
            .tabItem { Label(L.tabApp, systemImage: "calendar.badge.clock") }

            Group {
                if selectedTab == .breakTab { BreakTab() } else { Color.clear }
            }
            .tag(SettingsTab.breakTab)
            .tabItem { Label(L.tabBreak, systemImage: "cup.and.saucer.fill") }

            Group {
                if selectedTab == .reminders { ReminderTab() } else { Color.clear }
            }
            .tag(SettingsTab.reminders)
            .tabItem { Label(L.tabReminders, systemImage: "text.bubble") }

            Group {
                if selectedTab == .about { AboutTab() } else { Color.clear }
            }
            .tag(SettingsTab.about)
            .tabItem { Label(L.tabAbout, systemImage: "info.circle") }
        }
        .frame(width: 640)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Shared helpers

private let systemSounds = ["Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"]

private func toggleRow(icon: String, label: String, isOn: Binding<Bool>) -> some View {
    HStack(spacing: 10) {
        Image(systemName: icon)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(width: 20)
        Text(label)
            .font(.callout)
        Spacer()
        Toggle("", isOn: isOn)
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(.green)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 6)
}

private func pickerRow<P: View>(icon: String, label: String, @ViewBuilder picker: () -> P) -> some View {
    HStack(spacing: 10) {
        Image(systemName: icon)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(width: 20)
        Text(label)
            .font(.callout)
        Spacer()
        picker()
            .fixedSize()
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 6)
}

private func dateFromHHmm(_ str: String) -> Date {
    let parts = str.split(separator: ":").compactMap { Int($0) }
    guard parts.count == 2 else { return Date() }
    var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    comps.hour = parts[0]
    comps.minute = parts[1]
    return Calendar.current.date(from: comps) ?? Date()
}

private func hhmmFromDate(_ date: Date) -> String {
    let cal = Calendar.current
    let h = cal.component(.hour, from: date)
    let m = cal.component(.minute, from: date)
    return String(format: "%02d:%02d", h, m)
}

private func quietWeekdaysSummary(_ period: QuietHourPeriod) -> String {
    guard let days = period.weekdays, !days.isEmpty else {
        return L.quietWeekdaysAll
    }
    let order = [2, 3, 4, 5, 6, 7, 1] // Mon-Sun
    let names = order.filter { days.contains($0) }.map { L.weekdayName($0) }
    return names.joined(separator: " ")
}

// MARK: - System Tab

struct SystemTab: View {
    @Environment(AppState.self) var state
    @Environment(\.openWindow) private var openWindow
    @State private var resetSettingsDone = false
    @State private var resetDataDone = false
    @State private var exportDone = false

    var body: some View {

        @Bindable var state = state
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
            VStack(spacing: 0) {
                pickerRow(icon: "globe", label: L.language) {
                    Picker("", selection: $state.config.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .labelsHidden()
                }
                Divider().padding(.leading, 44)
                pickerRow(icon: "circle.lefthalf.filled", label: L.appearance) {
                    Picker("", selection: $state.config.appearance) {
                        ForEach(AppAppearance.allCases, id: \.self) { a in
                            Text(a.label).tag(a)
                        }
                    }
                    .labelsHidden()
                }
                Divider().padding(.leading, 44)
                toggleRow(icon: "power", label: L.launchAtLogin, isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { enable in
                        try? enable ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }
                ))
                Divider().padding(.leading, 44)
                toggleRow(icon: "arrow.triangle.2.circlepath", label: L.autoCheckUpdate, isOn: $state.config.autoCheckUpdate)
                Divider().padding(.leading, 44)
                VStack(alignment: .leading, spacing: 2) {
                    toggleRow(icon: "lock.display", label: L.resetOnScreenLock, isOn: $state.config.resetOnScreenLock)
                    Text(L.resetOnScreenLockHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 46)
                        .padding(.bottom, 4)
                }
                Divider().padding(.leading, 44)
                HStack(spacing: 10) {
                    Image(systemName: "wand.and.stars")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text(L.reopenOnboarding)
                        .font(.callout)
                    Spacer()
                    Button {
                        Database.shared.setOnboardingIncomplete()
                        state.showOnboarding = true
                        openWindow(id: "onboarding")
                        NSApp.setActivationPolicy(.regular)
                        NSApp.activate(ignoringOtherApps: true)
                    } label: {
                        Text(L.onboardingOpen)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.green.gradient, in: Capsule())
                    }
                    .buttonStyle(.borderless)
                    .handCursor()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                Divider().padding(.leading, 44)
                HStack(spacing: 10) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    Text(L.resetSettings)
                        .font(.callout)
                    Spacer()
                    if resetSettingsDone {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            confirmReset(title: L.resetSettings, message: L.resetSettingsWarning) {
                                state.resetToDefaults()
                                withAnimation { resetSettingsDone = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { resetSettingsDone = false }
                                }
                            }
                        } label: {
                            Text(L.resetAction)
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.orange.gradient, in: Capsule())
                        }
                        .buttonStyle(.borderless)
                        .handCursor()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                Divider().padding(.leading, 44)
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.exportData)
                            .font(.callout)
                        Text(L.exportDataDesc)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if exportDone {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            exportData()
                        } label: {
                            Text(L.exportAction)
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.blue.gradient, in: Capsule())
                        }
                        .buttonStyle(.borderless)
                        .handCursor()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                Divider().padding(.leading, 44)
                HStack(spacing: 10) {
                    Image(systemName: "trash")
                        .font(.callout)
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(width: 20)
                    Text(L.resetAllData)
                        .font(.callout)
                    Spacer()
                    if resetDataDone {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            confirmReset(title: L.resetAllData, message: L.resetDataWarning) {
                                Database.shared.resetAllData()
                                state.refreshStats()
                                withAnimation { resetDataDone = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { resetDataDone = false }
                                }
                            }
                        } label: {
                            Text(L.resetAction)
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.red.gradient, in: Capsule())
                        }
                        .buttonStyle(.borderless)
                        .handCursor()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(16)
        }
    }

    private func confirmReset(title: String, message: String, action: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L.confirmDelete)
        alert.addButton(withTitle: L.cancel)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            action()
        }
    }

    private func exportData() {
        // 1. Password input
        let alert = NSAlert()
        alert.messageText = L.exportPasswordTitle
        alert.informativeText = L.exportPasswordMsg
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: L.cancel)

        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        passwordField.placeholderString = L.exportPasswordPlaceholder
        alert.accessoryView = passwordField
        alert.window.initialFirstResponder = passwordField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let password = passwordField.stringValue
        guard !password.isEmpty else {
            let warn = NSAlert()
            warn.messageText = L.passwordEmpty
            warn.alertStyle = .warning
            warn.runModal()
            return
        }

        // 2. Save panel
        let panel = NSSavePanel()
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.nameFieldStringValue = "HealthTick-\(Database.todayString()).htdata"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        // 3. Export
        do {
            let data = Database.shared.exportAllData()
            let encrypted = try DataExporter.export(data: data, password: password)
            try encrypted.write(to: url)
            withAnimation { exportDone = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { exportDone = false }
            }
        } catch {
            let errAlert = NSAlert()
            errAlert.messageText = L.exportFailed
            errAlert.informativeText = error.localizedDescription
            errAlert.alertStyle = .critical
            errAlert.runModal()
        }
    }
}

// MARK: - App Tab

struct AppTab: View {
    @Environment(AppState.self) var state
    @State private var showQuietHelp = false
    @State private var expandedQuietId: UUID? = nil
    @State private var showWorkHoursHelp = false
    @State private var isSyncingHolidays = false
    @State private var holidaySyncError: String?
    @State private var holidaySyncSuccess = false
    @State private var showHolidayCalendar = false

    var body: some View {
        @Bindable var state = state
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Timer sliders
                VStack(spacing: 16) {
                    sliderRow(icon: "deskclock.fill", label: L.workDuration, value: Binding(
                        get: { Double(state.config.workMinutes) },
                        set: { state.config.workMinutes = Int($0) }
                    ), range: 1...120, unit: L.unitMinutes, color: .green)
                    .opacity(state.config.eyeCareMode ? 0.5 : 1.0)
                    .disabled(state.config.eyeCareMode)

                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill").font(.callout).foregroundStyle(.orange).frame(width: 20)
                            Text(L.breakDuration).font(.callout)
                            Spacer()
                            Text(L.formatBreakDuration(state.config.breakSeconds))
                                .font(.callout.monospacedDigit().bold())
                                .foregroundStyle(.orange)
                                .frame(width: 90, alignment: .trailing)
                        }
                        Slider(value: Binding(
                            get: { Double(state.config.breakSeconds) },
                            set: { state.config.breakSeconds = Int($0) }
                        ), in: 20...900, step: 10).tint(.orange)
                    }
                    .opacity(state.config.eyeCareMode ? 0.5 : 1.0)
                    .disabled(state.config.eyeCareMode)

                    sliderRow(icon: "target", label: L.dailyGoal, value: Binding(
                        get: { Double(state.config.dailyGoal) },
                        set: { state.config.dailyGoal = Int($0) }
                    ), range: 1...20, unit: L.unitTimes, color: .blue)

                    Divider().padding(.vertical, 4)

                    // Long Break
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "cup.and.saucer").font(.callout).foregroundStyle(.purple).frame(width: 20)
                            Text(L.longBreak).font(.callout)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { state.config.longBreakEnabled },
                                set: { state.config.longBreakEnabled = $0 }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .tint(.purple)
                        }
                        Text(L.longBreakDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 24)

                        if state.config.longBreakEnabled {
                            HStack(spacing: 6) {
                                Text(L.longBreakEvery).font(.callout).foregroundStyle(.secondary)
                                Picker("", selection: Binding(
                                    get: { state.config.longBreakInterval },
                                    set: { state.config.longBreakInterval = $0 }
                                )) {
                                    ForEach(2...8, id: \.self) { n in
                                        Text("\(n)").tag(n)
                                    }
                                }
                                .fixedSize()
                                Text(L.longBreakCycles).font(.callout).foregroundStyle(.secondary)
                                Spacer()
                                Text(L.formatBreakDuration(state.config.longBreakSeconds))
                                    .font(.callout.monospacedDigit().bold())
                                    .foregroundStyle(.purple)
                                    .frame(width: 90, alignment: .trailing)
                            }
                            .padding(.leading, 24)
                            .padding(.top, 4)

                            Slider(value: Binding(
                                get: { Double(state.config.longBreakSeconds) },
                                set: { state.config.longBreakSeconds = Int($0) }
                            ), in: 300...1800, step: 60)
                            .tint(.purple)
                            .padding(.leading, 24)
                        }
                    }
                    .opacity(state.config.eyeCareMode ? 0.5 : 1.0)
                    .disabled(state.config.eyeCareMode)

                    Divider().padding(.vertical, 4)

                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "eye").font(.callout).foregroundStyle(.cyan).frame(width: 20)
                            Text(L.eyeCareMode).font(.callout)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { state.config.eyeCareMode },
                                set: { newValue in
                                    state.suppressNextRestartPrompt = true
                                    if newValue {
                                        state.config.savedWorkMinutes = state.config.workMinutes
                                        state.config.savedBreakSeconds = state.config.breakSeconds
                                        state.config.savedBreakConfirm = state.config.breakConfirm
                                        state.config.eyeCareMode = true
                                        state.config.workMinutes = 20
                                        state.config.breakSeconds = 20
                                        state.config.breakConfirm = false
                                    } else {
                                        state.config.eyeCareMode = false
                                        state.config.workMinutes = state.config.savedWorkMinutes
                                        state.config.breakSeconds = state.config.savedBreakSeconds
                                        state.config.breakConfirm = state.config.savedBreakConfirm
                                    }
                                    state.restartCurrentPhase()
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        Text(L.eyeCareDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 24)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

                // Work Days + Work Hours + Quiet Hours
                VStack(spacing: 0) {
                    // Work Days
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "calendar")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(L.workDays)
                                .font(.callout)
                            Spacer()
                        }
                        .padding(.horizontal, 14)

                        HStack(spacing: 10) {
                            Image(systemName: "flag.fill")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(L.holidaySync)
                                .font(.callout)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { state.config.holidaySyncEnabled },
                                set: { enabled in
                                    state.config.holidaySyncEnabled = enabled
                                    if enabled && state.config.holidayCalendar.isEmpty {
                                        syncNationalHolidays()
                                    }
                                }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(.green)
                        }
                        .padding(.horizontal, 14)

                        if state.config.holidaySyncEnabled {
                            Text(L.holidaySyncDesc)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)

                            HStack(spacing: 8) {
                                Button {
                                    syncNationalHolidays()
                                } label: {
                                    if isSyncingHolidays {
                                        HStack(spacing: 6) {
                                            ProgressView().controlSize(.small)
                                            Text(L.holidaySyncing)
                                        }
                                    } else {
                                        Text(L.holidaySyncNow)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(isSyncingHolidays)

                                Button {
                                    showHolidayCalendar = true
                                } label: {
                                    Text(L.holidayViewCalendar)
                                }
                                .buttonStyle(.bordered)
                                .disabled(state.config.holidayCalendar.isEmpty)

                                if holidaySyncSuccess {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text(L.holidaySyncSuccess)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .transition(.opacity)
                                } else {
                                    Text(holidaySyncStatusText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14)

                            if let holidaySyncError {
                                Text(holidaySyncError)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 14)
                            }

                            Text(L.holidayWeekdayFallback)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                        }

                        HStack(spacing: 6) {
                            ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                                Button {
                                    if state.config.workDays.contains(day) {
                                        state.config.workDays.remove(day)
                                    } else {
                                        state.config.workDays.insert(day)
                                    }
                                } label: {
                                    Text(L.weekdayName(day))
                                        .font(.system(size: 12, weight: .medium))
                                        .frame(width: 36, height: 28)
                                        .foregroundStyle(state.config.workDays.contains(day) ? .white : .primary)
                                        .background(
                                            state.config.workDays.contains(day) ? Color.green : Color.gray.opacity(0.15),
                                            in: RoundedRectangle(cornerRadius: 6)
                                        )
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.horizontal, 14)
                        .opacity(state.config.holidaySyncEnabled ? 0.85 : 1)
                    }
                    .padding(.vertical, 10)

                    Divider().padding(.leading, 44)

                    // Work Hours
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "clock.fill")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text(L.workHoursLabel)
                                .font(.callout)
                            Button {
                                showWorkHoursHelp.toggle()
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.borderless)
                            .popover(isPresented: $showWorkHoursHelp) {
                                Text(L.workHoursHelp)
                                    .font(.callout)
                                    .padding(12)
                                    .frame(width: 260)
                            }
                            Spacer()
                            Toggle("", isOn: $state.config.workHoursEnabled)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .tint(.green)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)

                        if state.config.workHoursEnabled {
                            HStack(spacing: 8) {
                                DatePicker("", selection: Binding(
                                    get: { dateFromHHmm(state.config.workStartTime) },
                                    set: { state.config.workStartTime = hhmmFromDate($0) }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .frame(width: 80)

                                Text("—")
                                    .foregroundStyle(.secondary)

                                DatePicker("", selection: Binding(
                                    get: { dateFromHHmm(state.config.workEndTime) },
                                    set: { state.config.workEndTime = hhmmFromDate($0) }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .frame(width: 80)

                                Spacer()
                            }
                            .padding(.horizontal, 14)
                        }
                    }
                    .padding(.vertical, 4)

                    Divider().padding(.leading, 44)

                    // Quiet Hours
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "moon.fill")
                                .font(.callout)
                                .foregroundStyle(.purple)
                                .frame(width: 20)
                            Text(L.quietHours)
                                .font(.callout)
                            Button {
                                showQuietHelp.toggle()
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.borderless)
                            .popover(isPresented: $showQuietHelp) {
                                Text(L.quietHoursHelp)
                                    .font(.callout)
                                    .padding(12)
                                    .frame(width: 260)
                            }
                            Spacer()
                            Button {
                                state.config.quietHours.append(QuietHourPeriod(start: "12:00", end: "13:00"))
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.borderless)
                            .handCursor()
                        }
                        .padding(.horizontal, 14)

                        ForEach($state.config.quietHours) { $period in
                            let periodId = period.id
                            QuietHourRow(
                                period: $period,
                                isExpanded: expandedQuietId == periodId,
                                onToggleExpand: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        expandedQuietId = expandedQuietId == periodId ? nil : periodId
                                    }
                                },
                                onDelete: {
                                    if expandedQuietId == periodId { expandedQuietId = nil }
                                    state.config.quietHours.removeAll { $0.id == periodId }
                                }
                            )
                            .padding(.horizontal, 14)
                        }
                    }
                    .padding(.vertical, 10)
                }
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

            }
            .padding(16)
        }
        .alert(L.durationChanged, isPresented: $state.showRestartPrompt) {
            Button(L.restartTimer) { state.restartCurrentPhase() }
            Button(L.laterAction, role: .cancel) {}
        } message: {
            Text(L.durationChangedMsg)
        }
        .sheet(isPresented: $showHolidayCalendar) {
            HolidayCalendarView()
                .environment(state)
        }
    }

    private static let syncedAtDisplayFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt
    }()

    private var holidaySyncStatusText: String {
        guard let synced = state.config.holidayCalendarSyncedAt,
              let date = HolidayCalendarService.iso8601.date(from: synced) else {
            return L.holidaySyncNever
        }
        return "\(L.holidaySyncLast): \(Self.syncedAtDisplayFormatter.string(from: date))"
    }

    private func syncNationalHolidays() {
        guard !isSyncingHolidays else { return }
        isSyncingHolidays = true
        holidaySyncError = nil
        holidaySyncSuccess = false
        Task {
            do {
                let result = try await HolidayCalendarService.syncNationalHolidays()
                await MainActor.run {
                    state.config.holidayCalendar = result.workDayOverrides
                    state.config.holidayCalendarNames = result.labels
                    state.config.holidayCalendarSyncedAt = HolidayCalendarService.iso8601.string(from: Date())
                    isSyncingHolidays = false
                    withAnimation(.easeInOut(duration: 0.2)) { holidaySyncSuccess = true }
                }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) { holidaySyncSuccess = false }
                }
            } catch {
                await MainActor.run {
                    holidaySyncError = error.localizedDescription
                    isSyncingHolidays = false
                }
            }
        }
    }

    private func sliderRow(icon: String, label: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon).font(.callout).foregroundStyle(color).frame(width: 20)
                Text(label).font(.callout)
                Spacer()
                Text("\(Int(value.wrappedValue)) \(unit)")
                    .font(.callout.monospacedDigit().bold())
                    .foregroundStyle(color)
                    .frame(width: 70, alignment: .trailing)
            }
            Slider(value: value, in: range, step: 1).tint(color)
        }
    }


}

// MARK: - Break Tab

struct BreakTab: View {
    @Environment(AppState.self) var state
    @State private var showShortcutHelp = false

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                pickerRow(icon: "rectangle.inset.filled", label: L.breakWindow) {
                    Picker("", selection: $state.config.breakPosition) {
                        ForEach(BreakPosition.allCases, id: \.self) { pos in
                            Text(pos.label).tag(pos)
                        }
                    }
                    .labelsHidden()
                    Button {
                        state.overlayManager.preview(position: state.config.breakPosition)
                    } label: {
                        Text(L.preview)
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.borderless)
                }
                Divider().padding(.leading, 44)
                displayTargetRow
                Divider().padding(.leading, 44)
                toggleRow(icon: "hand.raised.fill", label: L.breakConfirm, isOn: $state.config.breakConfirm)
                    .opacity(state.config.eyeCareMode ? 0.5 : 1.0)
                    .disabled(state.config.eyeCareMode)
                Divider().padding(.leading, 44)
                toggleRow(icon: "flag.checkered", label: L.autoPauseOnGoal, isOn: $state.config.autoPauseOnGoal)
                Divider().padding(.leading, 44)
                soundRow(
                    icon: "speaker.wave.2.fill",
                    label: L.reminderSound,
                    isOn: $state.config.soundEnabled,
                    sound: $state.config.alertSound,
                    repeatCount: $state.config.alertSoundRepeatCount
                )
                Divider().padding(.leading, 44)
                soundRow(
                    icon: "ear.fill",
                    label: L.activityDetectSound,
                    isOn: $state.config.breakDetectSound,
                    sound: $state.config.breakDetectSoundName
                )
                Divider().padding(.leading, 44)
                shortcutRow
            }
            .padding(.vertical, 4)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
    }

    @ViewBuilder
    private var displayTargetRow: some View {
        @Bindable var state = state
        // macOS MenuBarExtra is a system singleton — "all displays" can't be
        // honored in menu mode, so hide that option there.
        let isMenuMode = state.config.breakPosition == .menuWindow
        let availableTargets: [BreakDisplayTarget] = isMenuMode
            ? [.activeScreen, .specific]
            : BreakDisplayTarget.allCases

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "display.2")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(L.displayTargetLabel)
                    .font(.callout)
                Spacer()
                Picker("", selection: $state.config.breakDisplayTarget) {
                    ForEach(availableTargets, id: \.self) { t in
                        Text(t.label).tag(t)
                    }
                }
                .labelsHidden()
                .fixedSize()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            if state.config.breakDisplayTarget == .specific {
                specificDisplayPicker
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
            }
        }
        .onChange(of: state.config.breakPosition) { _, newPos in
            // Switching INTO menu mode while "all" is selected → coerce to active
            if newPos == .menuWindow && state.config.breakDisplayTarget == .allScreens {
                state.config.breakDisplayTarget = .activeScreen
            }
        }
        .onAppear {
            // Repair any pre-existing invalid combo from earlier versions / DB
            if isMenuMode && state.config.breakDisplayTarget == .allScreens {
                state.config.breakDisplayTarget = .activeScreen
            }
        }
    }

    @ViewBuilder
    private var specificDisplayPicker: some View {
        @Bindable var state = state
        let screens = NSScreen.screens
        let savedUUID = state.config.breakDisplaySpecificUUID
        let savedConnected = savedUUID.map { uuid in
            screens.contains { $0.stableUUID == uuid }
        } ?? false

        HStack(spacing: 10) {
            Spacer()
            Picker("", selection: Binding<String>(
                get: { savedUUID ?? screens.first?.stableUUID ?? "" },
                set: { state.config.breakDisplaySpecificUUID = $0.isEmpty ? nil : $0 }
            )) {
                ForEach(screens, id: \.stableUUID) { screen in
                    Text(screenDisplayName(screen)).tag(screen.stableUUID ?? "")
                }
                if let uuid = savedUUID, !savedConnected {
                    Text(L.displayTargetDisconnected(String(uuid.prefix(8))))
                        .tag(uuid)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    private func screenDisplayName(_ screen: NSScreen) -> String {
        let name = screen.localizedName
        return name.isEmpty ? L.displayTargetUnknownName : name
    }

    @ViewBuilder
    private var shortcutRow: some View {
        @Bindable var state = state
        HStack(spacing: 10) {
            Image(systemName: "keyboard.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(L.shortcutLabel)
                .font(.callout)
            Button {
                showShortcutHelp.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $showShortcutHelp) {
                Text(L.shortcutHint)
                    .font(.callout)
                    .padding(12)
                    .frame(width: 260)
            }
            Spacer()
            if state.config.shortcutEnabled {
                ShortcutRecorderView(
                    keyCode: $state.config.shortcutKeyCode,
                    modifiers: $state.config.shortcutModifiers
                )
            }
            Toggle("", isOn: $state.config.shortcutEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.green)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func soundRow(
        icon: String,
        label: String,
        isOn: Binding<Bool>,
        sound: Binding<String>,
        repeatCount: Binding<Int>? = nil
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(label)
                    .font(.callout)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(.green)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            if isOn.wrappedValue {
                HStack(spacing: 10) {
                    Spacer().frame(width: 20)
                    Picker("", selection: sound) {
                        ForEach(systemSounds, id: \.self) { s in
                            Text(s).tag(s)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()

                    Button {
                        if let repeatCount {
                            self.state.previewSoundBurst(
                                soundName: sound.wrappedValue,
                                repeatCount: repeatCount.wrappedValue
                            )
                        } else {
                            NSSound(named: sound.wrappedValue)?.play()
                        }
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.borderless)
                    .handCursor()

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.bottom, repeatCount == nil ? 6 : 0)

                if let repeatCount {
                    HStack(spacing: 10) {
                        Spacer().frame(width: 20)
                        Text(L.alertSoundRepeatCount)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Stepper(
                            L.alertSoundRepeatTimes(repeatCount.wrappedValue),
                            value: repeatCount,
                            in: 1...10
                        )
                        .fixedSize()
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
                }
            }
        }
    }
}

// MARK: - Reminders

struct ReminderTab: View {
    @Environment(AppState.self) var state
    @State private var newReminder = ""
    @State private var editingIndex: Int? = nil
    @State private var editingText = ""

    var body: some View {

        VStack(spacing: 16) {
            HStack {
                Text(L.reminderHint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }

            VStack(spacing: 0) {
                ForEach(Array(state.config.reminders.enumerated()), id: \.offset) { i, reminder in
                    if i > 0 { Divider().padding(.leading, 14) }
                    HStack(spacing: 10) {
                        Circle()
                            .fill(.green.opacity(0.7))
                            .frame(width: 6, height: 6)

                        if editingIndex == i {
                            TextField("", text: $editingText)
                                .textFieldStyle(.plain)
                                .font(.callout)
                                .onSubmit { saveEdit(at: i) }
                                .onExitCommand { editingIndex = nil }
                        } else {
                            Text(reminder)
                                .font(.callout)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingIndex = i
                                    editingText = reminder
                                }
                                .handCursor()
                        }

                        Spacer()
                        if state.config.reminders.count > 1 {
                            Button {
                                if editingIndex == i { editingIndex = nil }
                                _ = state.config.reminders.remove(at: i)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 18, height: 18)
                                    .background(.quaternary, in: Circle())
                            }
                            .buttonStyle(.borderless)
                            .handCursor()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                TextField(L.addReminderPlaceholder, text: $newReminder)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .onSubmit { addReminder() }

                if !newReminder.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        addReminder()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.borderless)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

            Spacer()
        }
        .padding(24)
        .animation(.easeInOut(duration: 0.15), value: newReminder)
    }

    private func addReminder() {
        let text = newReminder.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        withAnimation { state.config.reminders.append(text) }
        newReminder = ""
    }

    private func saveEdit(at index: Int) {
        let text = editingText.trimmingCharacters(in: .whitespaces)
        if !text.isEmpty && index < state.config.reminders.count {
            state.config.reminders[index] = text
        }
        editingIndex = nil
    }
}

// MARK: - About

struct AboutTab: View {
    @Environment(AppState.self) var state
    @ObservedObject private var updater = UpdateChecker.shared

    var body: some View {

        VStack(spacing: 14) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18))

            Text("HealthTick")
                .font(.title2.bold())

            Text(L.appSubtitle)
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("v\(appVersion)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())

            Text(L.appSlogan)
                .font(.callout)
                .foregroundStyle(.tertiary)

            Button {
                updater.check(silent: false)
            } label: {
                HStack(spacing: 6) {
                    if updater.isChecking {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text(updater.isChecking ? L.checking : L.checkUpdate)
                }
            }
            .controlSize(.regular)
            .disabled(updater.isChecking)
            .handCursor()

            if updater.hasUpdate, let ver = updater.latestVersion {
                Button {
                    updater.showUpdateAlertPublic()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.blue)
                        Text(L.updateAvailable(ver))
                            .font(.callout)
                            .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.borderless)
                .handCursor()
            }

            if let err = updater.checkError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 6) {
                Button {
                    if let url = URL(string: "https://www.lifedever.com/") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text(L.sponsorSupport)
                        .font(.callout)
                }
                .buttonStyle(.borderless)
                .handCursor()

                Text("·")
                    .font(.callout)
                    .foregroundStyle(.quaternary)

                Button {
                    if let url = URL(string: "https://github.com/lifedever/health-tick-release") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text(L.githubPage)
                        .font(.callout)
                }
                .buttonStyle(.borderless)
                .handCursor()
            }

            Spacer()

            HStack(spacing: 4) {
                Text("Made with")
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red.opacity(0.6))
                Text("for your health")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shortcut Recorder

struct ShortcutRecorderView: View {
    @Binding var keyCode: UInt16
    @Binding var modifiers: UInt
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            if isRecording {
                stopRecording()
            } else {
                isRecording = true
                startRecording()
            }
        } label: {
            if isRecording {
                Text(L.shortcutRecording)
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            } else {
                let config = AppConfig(shortcutKeyCode: keyCode, shortcutModifiers: modifiers)
                HStack(spacing: 4) {
                    Text(config.shortcutDisplay)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                    Text(L.shortcutClickToChange)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.borderless)
        .handCursor()
        .onDisappear {
            // Prevent NSEvent monitor leak if view is destroyed while recording
            stopRecording()
        }
    }

    private func startRecording() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape to cancel
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            let mods = event.modifierFlags.intersection([.command, .option, .shift, .control])
            keyCode = event.keyCode
            modifiers = mods.rawValue
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        isRecording = false
    }
}

// MARK: - Hand Cursor

// MARK: - Quiet Hour Row

private struct QuietHourRow: View {
    @Binding var period: QuietHourPeriod
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                DatePicker("", selection: startBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(width: 80)

                Text("—").foregroundStyle(.secondary)

                DatePicker("", selection: endBinding, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(width: 80)

                weekdayBadge

                Spacer()

                deleteButton
            }

            if isExpanded {
                QuietWeekdayPicker(weekdays: $period.weekdays)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var startBinding: Binding<Date> {
        Binding(
            get: { dateFromHHmm(period.start) },
            set: { period.start = hhmmFromDate($0) }
        )
    }

    private var endBinding: Binding<Date> {
        Binding(
            get: { dateFromHHmm(period.end) },
            set: { period.end = hhmmFromDate($0) }
        )
    }

    private var weekdayBadge: some View {
        let hasWeekdays = period.weekdays != nil
        let summary = quietWeekdaysSummary(period)
        return Button(action: onToggleExpand) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                Text(summary)
                    .font(.system(size: 11, weight: hasWeekdays ? .medium : .regular))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(hasWeekdays ? Color.purple : Color.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                hasWeekdays ? Color.purple.opacity(0.1) : Color.gray.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(hasWeekdays ? Color.purple.opacity(0.3) : Color.gray.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.borderless)
        .handCursor()
    }

    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)
                .frame(width: 18, height: 18)
                .background(.quaternary, in: Circle())
        }
        .buttonStyle(.borderless)
        .handCursor()
    }
}

// MARK: - Quiet Weekday Picker

private struct QuietWeekdayPicker: View {
    @Binding var weekdays: Set<Int>?

    private let dayOrder = [2, 3, 4, 5, 6, 7, 1]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(dayOrder, id: \.self) { day in
                dayButton(day)
            }
        }
    }

    private func dayButton(_ day: Int) -> some View {
        let isSelected = weekdays?.contains(day) ?? false
        return Button {
            var days = weekdays ?? []
            if days.contains(day) {
                days.remove(day)
            } else {
                days.insert(day)
            }
            weekdays = days.isEmpty ? nil : days
        } label: {
            Text(L.weekdayName(day))
                .font(.system(size: 10, weight: .medium))
                .frame(width: 28, height: 20)
                .foregroundStyle(isSelected ? .white : .secondary)
                .background(
                    isSelected ? Color.purple.opacity(0.8) : Color.gray.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 4)
                )
        }
        .buttonStyle(.borderless)
    }
}

extension View {
    func handCursor() -> some View {
        self.onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
