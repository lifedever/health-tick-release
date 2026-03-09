import AppKit
import SwiftUI
import Foundation

// MARK: - Shared Break Card View (single source of truth for ALL break UIs)

struct BreakCardView: View {
    @EnvironmentObject var state: AppState
    var fullscreen: Bool = false

    private var timerProgress: Double {
        guard state.phase == .breaking else { return 0 }
        let total = state.config.breakMinutes * 60
        guard total > 0 else { return 0 }
        return Double(state.remainingSeconds) / Double(total)
    }

    var body: some View {
        VStack(spacing: fullscreen ? 20 : 12) {
            switch state.phase {
            case .alerting:
                alertingBody
            case .waiting:
                waitingBody
            case .breaking:
                breakBody
            default:
                EmptyView()
            }
        }
        .padding(fullscreen ? 40 : 16)
        .frame(width: fullscreen ? nil : 240)
    }

    // MARK: - Alerting (pre-break confirmation)

    @ViewBuilder
    private var alertingBody: some View {
        Image(systemName: "bell.badge.fill")
            .font(.system(size: fullscreen ? 64 : 44))
            .foregroundStyle(.orange)
            .padding(.top, fullscreen ? 16 : 8)

        if let reminder = state.currentReminder {
            Text(reminder)
                .font(fullscreen ? .title3.bold() : .callout.bold())
                .foregroundStyle(fullscreen ? .white.opacity(0.85) : .primary.opacity(0.8))
                .multilineTextAlignment(.center)
        }

        Button {
            state.confirmBreak()
        } label: {
            Text(L.alertConfirmBreak)
                .font(.system(size: fullscreen ? 18 : 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: fullscreen ? 280 : .infinity)
                .padding(.vertical, fullscreen ? 12 : 8)
                .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, fullscreen ? 0 : 20)

        if state.config.shortcutEnabled {
            Text(L.shortcutQuickConfirm(state.config.shortcutDisplay))
                .font(.system(size: fullscreen ? 12 : 10))
                .foregroundStyle(.secondary.opacity(0.6))
        }
    }

    // MARK: - Break content (circular timer)

    @ViewBuilder
    private var breakBody: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(fullscreen ? 0.3 : 0.2), lineWidth: fullscreen ? 5 : 3)
            Circle()
                .trim(from: 0, to: timerProgress)
                .stroke(
                    Color.orange.gradient,
                    style: StrokeStyle(lineWidth: fullscreen ? 5 : 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: fullscreen ? 6 : 2) {
                Text(state.formattedTime)
                    .font(.system(size: fullscreen ? 64 : 28, weight: .light, design: .monospaced))
                    .foregroundStyle(fullscreen ? .white : .primary)
                Text(state.phaseLabel)
                    .font(.system(size: fullscreen ? 18 : 13))
                    .foregroundStyle(fullscreen ? .white.opacity(0.5) : .primary.opacity(0.6))
            }
        }
        .frame(width: fullscreen ? 240 : 120, height: fullscreen ? 240 : 120)
        .padding(.top, fullscreen ? 8 : 4)

        if let reminder = state.currentReminder {
            Text(reminder)
                .font(fullscreen ? .title3.bold() : .callout.bold())
                .foregroundStyle(fullscreen ? .white.opacity(0.85) : .primary.opacity(0.7))
                .multilineTextAlignment(.center)
        }

        if let activity = state.currentBreakActivity {
            HStack(spacing: fullscreen ? 8 : 6) {
                Image(systemName: activity.icon)
                    .font(.system(size: fullscreen ? 18 : 14))
                    .foregroundStyle(.orange)
                Text(activity.text)
                    .font(fullscreen ? .title3 : .callout)
                    .foregroundStyle(.orange)
            }
        }

        if !state.breakWarning.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: fullscreen ? 14 : 11))
                    .foregroundStyle(.orange)
                Text(state.breakWarning)
                    .font(fullscreen ? .callout : .caption)
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, fullscreen ? 14 : 10)
            .padding(.vertical, fullscreen ? 6 : 4)
            .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
        }

        Button {
            state.skipBreakClicked()
        } label: {
            Text(L.skipButton(state.breakSkipCount, state.breakSkipNeeded))
                .font(.system(size: fullscreen ? 14 : 11, weight: .medium))
                .foregroundStyle(fullscreen ? .white.opacity(0.4) : .secondary)
                .padding(.horizontal, fullscreen ? 20 : 12)
                .padding(.vertical, fullscreen ? 8 : 4)
                .background(
                    Color.gray.opacity(fullscreen ? 0.25 : 0.15),
                    in: RoundedRectangle(cornerRadius: 8)
                )
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Waiting (post-break confirmation)

    @ViewBuilder
    private var waitingBody: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: fullscreen ? 64 : 44))
            .foregroundStyle(.green)
            .padding(.top, fullscreen ? 16 : 8)

        Text(L.breakOverReturnPrompt)
            .font(fullscreen ? .title3 : .callout)
            .foregroundStyle(fullscreen ? .white.opacity(0.7) : .secondary)
            .multilineTextAlignment(.center)

        Button {
            state.confirmReturn()
        } label: {
            Text(L.alertImBack)
                .font(.system(size: fullscreen ? 18 : 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: fullscreen ? 280 : .infinity)
                .padding(.vertical, fullscreen ? 12 : 8)
                .background(.green.gradient, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, fullscreen ? 0 : 20)

        if state.config.shortcutEnabled {
            Text(L.shortcutQuickConfirm(state.config.shortcutDisplay))
                .font(.system(size: fullscreen ? 12 : 10))
                .foregroundStyle(.secondary.opacity(0.6))
        }
    }
}

// MARK: - Panel

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - Idle Detection

func getUserIdleSeconds() -> Double {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
    process.arguments = ["-c", "IOHIDSystem", "-d", "4"]
    let pipe = Pipe()
    process.standardOutput = pipe
    try? process.run()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    guard let output = String(data: data, encoding: .utf8) else { return 0 }
    for line in output.split(separator: "\n") {
        if line.contains("HIDIdleTime") {
            let parts = line.split(separator: "=")
            if let last = parts.last, let val = Double(last.trimmingCharacters(in: .whitespaces)) {
                return val / 1_000_000_000
            }
        }
    }
    return 0
}

// MARK: - Overlay Manager

@MainActor
final class BreakOverlayManager {
    private var windows: [NSPanel] = []
    private var timer: Timer?
    private var remaining: Int = 0
    weak var appState: AppState?
    var onForceEnd: (() -> Void)?
    var onBreakDone: (() -> Void)?

    // Menu window pinning
    private var menuPinTimer: Timer?
    private weak var menuBarExtraPanel: NSPanel?
    private var isMenuWindowMode = false
    private var originalPanelLevel: NSWindow.Level?
    private var originalHidesOnDeactivate: Bool?

    func show(seconds: Int) {
        remaining = seconds
        isMenuWindowMode = false
        let position = appState?.config.breakPosition ?? .topRight
        if position == .fullscreen {
            createFullscreen()
        } else {
            createFloating(position: position)
        }
        startMonitoring()
    }

    func showMenuWindow(seconds: Int) {
        remaining = seconds
        isMenuWindowMode = true
        startMonitoring()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.pinMenuBarExtra()
        }
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        unpinMenuBarExtra()
        isMenuWindowMode = false
    }

    func hideAll() {
        hide()
        closeMenuBarExtra()
    }

    func dismissMenuPanel() {
        unpinMenuBarExtra()
        isMenuWindowMode = false
        closeMenuBarExtra()
    }

    func pinForAlert() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.pinMenuBarExtra()
        }
    }

    func preview(position: BreakPosition) {
        hide()
        remaining = 65

        let savedActivity = appState?.currentBreakActivity
        let savedReminder = appState?.currentReminder
        let savedPhase = appState?.phase
        let savedRemaining = appState?.remainingSeconds
        let savedWarning = appState?.breakWarning

        appState?.currentBreakActivity = breakActivities.randomElement()
        appState?.currentReminder = appState?.config.reminders.randomElement() ?? L.defaultBreakReminder
        appState?.phase = .breaking
        appState?.remainingSeconds = remaining
        appState?.breakWarning = ""

        if position == .menuWindow {
            isMenuWindowMode = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.pinMenuBarExtra()
            }
        } else if position == .fullscreen {
            createFullscreen()
        } else {
            createFloating(position: position)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.hide()
            self?.appState?.currentBreakActivity = savedActivity
            self?.appState?.currentReminder = savedReminder
            self?.appState?.phase = savedPhase ?? .working
            self?.appState?.remainingSeconds = savedRemaining ?? 0
            self?.appState?.breakWarning = savedWarning ?? ""
        }
    }

    // MARK: - Menu window pinning

    private func pinMenuBarExtra() {
        findMenuBarExtraPanel()

        menuPinTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.ensureMenuPinned()
            }
        }
    }

    private func findMenuBarExtraPanel() {
        for window in NSApp.windows {
            guard let panel = window as? NSPanel else { continue }
            if panel is KeyablePanel { continue }
            if panel.styleMask.contains(.nonactivatingPanel)
                && panel.styleMask.contains(.fullSizeContentView)
                && panel.frame.width < 350 {
                menuBarExtraPanel = panel
                originalPanelLevel = panel.level
                originalHidesOnDeactivate = panel.hidesOnDeactivate
                panel.hidesOnDeactivate = false
                panel.level = .floating
                panel.orderFrontRegardless()
                // Activate app so keyboard shortcuts work
                NSApp.activate(ignoringOtherApps: true)
                panel.makeKey()
                return
            }
        }
    }

    private func ensureMenuPinned() {
        guard isMenuWindowMode else { return }
        if let panel = menuBarExtraPanel, panel.isVisible {
            panel.level = .floating
            return
        }
        findMenuBarExtraPanel()
    }

    private func unpinMenuBarExtra() {
        menuPinTimer?.invalidate()
        menuPinTimer = nil
        if let panel = menuBarExtraPanel {
            panel.hidesOnDeactivate = originalHidesOnDeactivate ?? true
            panel.level = originalPanelLevel ?? .statusBar
            panel.orderOut(nil)
        }
        menuBarExtraPanel = nil
        originalPanelLevel = nil
        originalHidesOnDeactivate = nil
    }

    private func closeMenuBarExtra() {
        for window in NSApp.windows {
            guard let panel = window as? NSPanel else { continue }
            if panel is KeyablePanel { continue }
            if panel.styleMask.contains(.nonactivatingPanel),
               panel.styleMask.contains(.fullSizeContentView),
               panel.frame.width < 350 {
                panel.orderOut(nil)
                break
            }
        }
    }

    // MARK: - Floating window (SwiftUI BreakCardView)

    private func createFloating(position: BreakPosition) {
        guard let screen = NSScreen.main, let state = appState else { return }

        // Auto-size from SwiftUI content
        let cardView = BreakCardView()
            .environmentObject(state)
        let sizingView = NSHostingView(rootView: cardView)
        let fitted = sizingView.fittingSize
        let pw = ceil(fitted.width)
        let ph = ceil(fitted.height)

        let margin: CGFloat = 20
        let vis = screen.visibleFrame

        let x: CGFloat
        let y: CGFloat
        switch position {
        case .topRight:
            x = vis.maxX - pw - margin
            y = vis.maxY - ph - margin
        case .topLeft:
            x = vis.minX + margin
            y = vis.maxY - ph - margin
        case .center:
            x = vis.midX - pw / 2
            y = vis.midY - ph / 2
        case .fullscreen, .menuWindow:
            x = 0; y = 0
        }

        let p = KeyablePanel(
            contentRect: NSMakeRect(x, y, pw, ph),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.isMovableByWindowBackground = true
        p.hasShadow = true

        let hostingView = NSHostingView(
            rootView: cardView
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        )
        hostingView.frame = NSMakeRect(0, 0, pw, ph)
        p.contentView!.addSubview(hostingView)

        p.makeKeyAndOrderFront(nil)
        windows.append(p)
    }

    // MARK: - Fullscreen (SwiftUI BreakCardView on dark background)

    private func createFullscreen() {
        guard let state = appState else { return }

        for screen in NSScreen.screens {
            let frame = screen.frame
            let p = KeyablePanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            p.isOpaque = false
            p.backgroundColor = NSColor.black.withAlphaComponent(0.75)
            p.ignoresMouseEvents = false

            let fullscreenView = BreakCardView(fullscreen: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environmentObject(state)

            let hostingView = NSHostingView(rootView: fullscreenView)
            hostingView.frame = frame
            hostingView.autoresizingMask = [.width, .height]
            p.contentView!.addSubview(hostingView)

            p.makeKeyAndOrderFront(nil)
            windows.append(p)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in self?.monitorTick() }
        }
    }

    private func monitorTick() {
        let idle = getUserIdleSeconds()
        if idle < 3 && remaining > 0 {
            appState?.breakWarning = L.breakDetectedPause
            appState?.playBreakDetectSound()
        } else {
            appState?.breakWarning = ""
            remaining -= 1
        }

        appState?.remainingSeconds = max(0, remaining)

        if remaining <= 0 {
            timer?.invalidate()
            timer = nil
            onBreakDone?()
            return
        }
    }
}
