import AppKit
import SwiftUI
import Foundation

// MARK: - Native Visual Effect Background (matches system MenuBarExtra)

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover
        v.state = .active
        v.blendingMode = .withinWindow
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Shared Break Card View (single source of truth for ALL break UIs)

struct BreakCardView: View {
    @Environment(AppState.self) var state
    var fullscreen: Bool = false

    private var timerProgress: Double {
        guard state.phase == .breaking else { return 0 }
        let total = state.config.breakSeconds
        guard total > 0 else { return 0 }
        return Double(state.remainingSeconds) / Double(total)
    }

    var body: some View {
        if fullscreen {
            VStack(spacing: 20) {
                switch state.phase {
                case .alerting: alertingBody
                case .waiting: waitingBody
                case .breaking: breakBody
                default: EmptyView()
                }
            }
            .padding(40)
        } else {
            VStack(spacing: 0) {
                switch state.phase {
                case .alerting: floatingAlertingBody
                case .waiting: floatingWaitingBody
                case .breaking: floatingBreakBody
                default: EmptyView()
                }
            }
            .frame(width: 240)
        }
    }

    // MARK: - Floating: Alerting

    @ViewBuilder
    private var floatingAlertingBody: some View {
        Image(systemName: "bell.badge.fill")
            .font(.system(size: 40))
            .foregroundStyle(.orange)
            .padding(.top, 28)

        if let reminder = state.currentReminder {
            Text(reminder)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 10)
        }

        Button {
            state.confirmBreak()
        } label: {
            Text(L.alertConfirmBreak)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 24)
        .padding(.top, 16)

        if state.config.shortcutEnabled {
            Text(L.shortcutQuickConfirm(state.config.shortcutDisplay))
                .font(.system(size: 10))
                .foregroundStyle(.secondary.opacity(0.5))
                .padding(.top, 6)
        }

        Spacer().frame(height: 24)
    }

    // MARK: - Floating: Break

    @ViewBuilder
    private var floatingBreakBody: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: timerProgress)
                .stroke(
                    Color.orange.gradient,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text(state.formattedTime)
                    .font(.system(size: 32, weight: .light, design: .monospaced))
                    .foregroundStyle(.primary)
                Text(state.phaseLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 130, height: 130)
        .padding(.top, 28)

        if let reminder = state.currentReminder {
            Text(reminder)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.top, 16)
        }

        VStack(spacing: 8) {
            if let activity = state.currentBreakActivity {
                Label {
                    Text(activity.text)
                        .font(.system(size: 12))
                } icon: {
                    Image(systemName: activity.icon)
                        .font(.system(size: 12))
                }
                .foregroundStyle(.green.opacity(0.75))
            }

            Label {
                Text(state.breakWarning.isEmpty ? " " : state.breakWarning)
                    .font(.system(size: 11))
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.orange.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
            .opacity(state.breakWarning.isEmpty ? 0 : 1)
        }
        .padding(.top, 14)

        Button {
            state.skipBreakClicked()
        } label: {
            Text(L.skipButton(state.breakSkipCount, state.breakSkipNeeded))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
        }
        .disabled(state.isPreview)
        .buttonStyle(.borderless)
        .padding(.top, 14)

        Spacer().frame(height: 10)
    }

    // MARK: - Floating: Waiting

    @ViewBuilder
    private var floatingWaitingBody: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 40))
            .foregroundStyle(.green)
            .padding(.top, 32)

        Text(L.breakOverReturnPrompt)
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .padding(.top, 14)

        Button {
            state.confirmReturn()
        } label: {
            Text(L.alertImBack)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.green.gradient, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 24)
        .padding(.top, 20)

        if state.config.shortcutEnabled {
            Text(L.shortcutQuickConfirm(state.config.shortcutDisplay))
                .font(.system(size: 10))
                .foregroundStyle(.secondary.opacity(0.5))
                .padding(.top, 8)
        }

        Spacer().frame(height: 28)
    }

    // MARK: - Fullscreen: Alerting

    @ViewBuilder
    private var alertingBody: some View {
        Image(systemName: "bell.badge.fill")
            .font(.system(size: 64))
            .foregroundStyle(.orange)
            .padding(.top, 16)

        if let reminder = state.currentReminder {
            Text(reminder)
                .font(.title3.bold())
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }

        Button {
            state.confirmBreak()
        } label: {
            Text(L.alertConfirmBreak)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: 280)
                .padding(.vertical, 12)
                .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.borderless)

        if state.config.shortcutEnabled {
            Text(L.shortcutQuickConfirm(state.config.shortcutDisplay))
                .font(.system(size: 12))
                .foregroundStyle(.secondary.opacity(0.6))
        }
    }

    // MARK: - Fullscreen: Break

    @ViewBuilder
    private var breakBody: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 5)
            Circle()
                .trim(from: 0, to: timerProgress)
                .stroke(
                    Color.orange.gradient,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 6) {
                Text(state.formattedTime)
                    .font(.system(size: 64, weight: .light, design: .monospaced))
                    .foregroundStyle(.white)
                Text(state.phaseLabel)
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: 240, height: 240)
        .padding(.top, 8)

        if let reminder = state.currentReminder {
            Text(reminder)
                .font(.title3.bold())
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }

        if let activity = state.currentBreakActivity {
            HStack(spacing: 8) {
                Image(systemName: activity.icon)
                    .font(.system(size: 18))
                Text(activity.text)
                    .font(.title3)
            }
            .foregroundStyle(.green.opacity(0.85))
        }

        if !state.breakWarning.isEmpty {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                Text(state.breakWarning)
                    .font(.callout)
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
        }

        Button {
            state.skipBreakClicked()
        } label: {
            Text(L.skipButton(state.breakSkipCount, state.breakSkipNeeded))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
        }
        .disabled(state.isPreview)
        .buttonStyle(.borderless)
    }

    // MARK: - Fullscreen: Waiting

    @ViewBuilder
    private var waitingBody: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 64))
            .foregroundStyle(.green)
            .padding(.top, 16)

        Text(L.breakOverReturnPrompt)
            .font(.title3)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)

        Button {
            state.confirmReturn()
        } label: {
            Text(L.alertImBack)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: 280)
                .padding(.vertical, 12)
                .background(.green.gradient, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.borderless)

        if state.config.shortcutEnabled {
            Text(L.shortcutQuickConfirm(state.config.shortcutDisplay))
                .font(.system(size: 12))
                .foregroundStyle(.secondary.opacity(0.6))
        }
    }
}

// MARK: - Panel

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// NSHostingView subclass for floating break overlay:
/// - Transparent background (isOpaque = false, clear layer)
/// - allowsVibrancy for proper NSVisualEffectView blending
/// - Auto-resizes its window when SwiftUI content changes
/// NSHostingView subclass that auto-resizes its window when SwiftUI content changes size.
private class AutoResizingHostingView<Content: View>: NSHostingView<Content> {
    override func layout() {
        super.layout()
        guard let window else { return }
        let fitted = fittingSize
        let fw = ceil(fitted.width)
        let fh = ceil(fitted.height)
        let cur = window.frame.size
        guard abs(cur.width - fw) > 1 || abs(cur.height - fh) > 1 else { return }
        var frame = window.frame
        frame.origin.y += cur.height - fh
        frame.size = NSSize(width: fw, height: fh)
        window.setFrame(frame, display: true, animate: false)
    }
}

// MARK: - Idle Detection

func getUserIdleSeconds() -> Double {
    // Use CoreGraphics API instead of spawning a subprocess every second.
    // CGEventSource.secondsSinceLastEventType is lightweight and synchronous.
    let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
    let idleKey = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
    return min(idle, idleKey)
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
    private var monitorStartTime: Date?
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
        appState?.isPreview = true
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
            self?.appState?.isPreview = false
            self?.appState?.currentBreakActivity = savedActivity
            self?.appState?.currentReminder = savedReminder
            self?.appState?.phase = savedPhase ?? .working
            self?.appState?.remainingSeconds = savedRemaining ?? 0
            self?.appState?.breakWarning = savedWarning ?? ""
        }
    }

    // MARK: - Menu window pinning

    private func pinMenuBarExtra() {
        findAndPinPanel()

        menuPinTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.ensureMenuPinned()
            }
        }
    }

    private func findAndPinPanel() {
        guard let app = NSApp else { return }
        for window in app.windows {
            guard let panel = window as? NSPanel else { continue }
            if panel is KeyablePanel { continue }
            if panel.styleMask.contains(.nonactivatingPanel)
                && panel.styleMask.contains(.fullSizeContentView)
                && panel.frame.width < 350 {
                menuBarExtraPanel = panel
                originalPanelLevel = panel.level
                originalHidesOnDeactivate = panel.hidesOnDeactivate
                panel.hidesOnDeactivate = false
                // Keep the panel's original level — changing to .floating
                // causes vibrancy compositing glitches on white backgrounds
                panel.orderFrontRegardless()
                NSApp.activate(ignoringOtherApps: true)
                panel.makeKey()
                return
            }
        }
    }

    private func ensureMenuPinned() {
        let isAlerting = appState?.phase == .alerting
        guard isMenuWindowMode || isAlerting else { return }
        if let panel = menuBarExtraPanel, panel.isVisible {
            return
        }
        // Panel was lost or hidden — re-show without activating
        guard let app = NSApp else { return }
        for window in app.windows {
            guard let panel = window as? NSPanel else { continue }
            if panel is KeyablePanel { continue }
            if panel.styleMask.contains(.nonactivatingPanel)
                && panel.styleMask.contains(.fullSizeContentView)
                && panel.frame.width < 350 {
                menuBarExtraPanel = panel
                panel.hidesOnDeactivate = false
                panel.orderFrontRegardless()
                return
            }
        }
    }

    private func unpinMenuBarExtra() {
        menuPinTimer?.invalidate()
        menuPinTimer = nil
        if let panel = menuBarExtraPanel {
            panel.hidesOnDeactivate = originalHidesOnDeactivate ?? true
            panel.orderOut(nil)
        }
        menuBarExtraPanel = nil
        originalPanelLevel = nil
        originalHidesOnDeactivate = nil
    }

    private func closeMenuBarExtra() {
        guard let app = NSApp else { return }
        for window in app.windows {
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

        let cornerRadius: CGFloat = 14

        let cardView = BreakCardView()
            .background(VisualEffectBackground())
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
            .environment(state)

        let hostingView = AutoResizingHostingView(rootView: cardView)
        let fitted = hostingView.fittingSize
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
        p.hasShadow = false
        p.appearance = NSApp?.appearance ?? NSApp?.effectiveAppearance

        hostingView.frame = NSMakeRect(0, 0, pw, ph)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = cornerRadius
        hostingView.layer?.masksToBounds = true
        p.contentView = hostingView

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
            .environment(state)

            let hostingView = NSHostingView(rootView: fullscreenView)
            hostingView.frame = frame
            hostingView.autoresizingMask = [.width, .height]
            p.contentView!.addSubview(hostingView)

            p.makeKeyAndOrderFront(nil)
            windows.append(p)
        }
        NSApp?.activate(ignoringOtherApps: true)
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        monitorStartTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in self?.monitorTick() }
        }
    }

    private func monitorTick() {
        let idle = getUserIdleSeconds()
        let gracePeriod = monitorStartTime.map { Date().timeIntervalSince($0) < 4 } ?? false
        let skipGrace = appState?.lastSkipClickTime.map { Date().timeIntervalSince($0) < 3 } ?? false
        let shouldWarn = idle < 3 && remaining > 0 && !gracePeriod && !skipGrace
        if shouldWarn {
            if appState?.breakWarning != L.breakDetectedPause {
                appState?.breakWarning = L.breakDetectedPause
            }
            appState?.playBreakDetectSound()
        } else {
            if appState?.breakWarning != "" {
                appState?.breakWarning = ""
            }
            remaining -= 1
        }

        let newRemaining = max(0, remaining)
        if appState?.remainingSeconds != newRemaining {
            appState?.remainingSeconds = newRemaining
        }

        if remaining <= 0 {
            timer?.invalidate()
            timer = nil
            onBreakDone?()
            return
        }
    }
}
