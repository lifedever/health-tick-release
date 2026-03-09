import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            SystemTab()
                .tabItem { Label(L.tabSystem, systemImage: "gearshape") }
            AppTab()
                .tabItem { Label(L.tabApp, systemImage: "slider.horizontal.3") }
            ReminderTab()
                .tabItem { Label(L.tabReminders, systemImage: "text.bubble") }
            AboutTab()
                .tabItem { Label(L.tabAbout, systemImage: "info.circle") }
        }
        .frame(width: 440)
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

// MARK: - System Tab

struct SystemTab: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow
    @State private var resetSettingsDone = false
    @State private var resetDataDone = false

    var body: some View {
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
}

// MARK: - App Tab

struct AppTab: View {
    @EnvironmentObject var state: AppState
    @State private var showQuietHelp = false
    @State private var showShortcutHelp = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Timer sliders
                VStack(spacing: 16) {
                    sliderRow(icon: "deskclock.fill", label: L.workDuration, value: Binding(
                        get: { Double(state.config.workMinutes) },
                        set: { state.config.workMinutes = Int($0) }
                    ), range: 1...120, unit: L.unitMinutes, color: .green)

                    sliderRow(icon: "cup.and.saucer.fill", label: L.breakDuration, value: Binding(
                        get: { Double(state.config.breakMinutes) },
                        set: { state.config.breakMinutes = Int($0) }
                    ), range: 1...15, unit: L.unitMinutes, color: .orange)

                    sliderRow(icon: "target", label: L.dailyGoal, value: Binding(
                        get: { Double(state.config.dailyGoal) },
                        set: { state.config.dailyGoal = Int($0) }
                    ), range: 1...20, unit: L.unitTimes, color: .blue)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

                // Break position + confirm + sounds
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
                    toggleRow(icon: "hand.raised.fill", label: L.breakConfirm, isOn: $state.config.breakConfirm)
                    Divider().padding(.leading, 44)
                    soundRow(
                        icon: "speaker.wave.2.fill",
                        label: L.reminderSound,
                        isOn: $state.config.soundEnabled,
                        sound: $state.config.alertSound
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
                }
                .padding(.vertical, 10)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

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

                    ForEach(Array(state.config.quietHours.enumerated()), id: \.offset) { i, period in
                        HStack(spacing: 8) {
                            DatePicker("", selection: Binding(
                                get: { dateFromHHmm(period.start) },
                                set: { state.config.quietHours[i].start = hhmmFromDate($0) }
                            ), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .frame(width: 80)

                            Text("—")
                                .foregroundStyle(.secondary)

                            DatePicker("", selection: Binding(
                                get: { dateFromHHmm(period.end) },
                                set: { state.config.quietHours[i].end = hhmmFromDate($0) }
                            ), displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .frame(width: 80)

                            Spacer()

                            Button {
                                state.config.quietHours.remove(at: i)
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
                        .padding(.horizontal, 14)
                    }
                }
                .padding(.vertical, 10)
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
    }

    @ViewBuilder
    private var shortcutRow: some View {
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

    private func soundRow(icon: String, label: String, isOn: Binding<Bool>, sound: Binding<String>) -> some View {
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
                        NSSound(named: sound.wrappedValue)?.play()
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
                .padding(.bottom, 6)
            }
        }
    }
}

// MARK: - Reminders

struct ReminderTab: View {
    @EnvironmentObject var state: AppState
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
    @EnvironmentObject var state: AppState
    @StateObject private var updater = UpdateChecker.shared

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

            if let err = updater.checkError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 6) {
                Button {
                    if let url = URL(string: "https://github.com/lifedever/health-tick-release#-赞助支持") {
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

extension View {
    func handCursor() -> some View {
        self.onHover { inside in
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
