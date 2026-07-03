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
        if let summary = state.offWorkSummary {
            summaryBody(summary)
        } else if fullscreen {
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

    // MARK: - Off-Work Summary (shares the break popup rendering path)

    @ViewBuilder
    private func summaryBody(_ summary: OffWorkSummaryData) -> some View {
        let iconSize: CGFloat = fullscreen ? 60 : 40
        let titleSize: CGFloat = fullscreen ? 26 : 16
        VStack(spacing: 0) {
            Image(systemName: "sunset.fill")
                .font(.system(size: iconSize))
                .foregroundStyle(.orange)
                .padding(.top, fullscreen ? 0 : 28)

            Text(L.offWorkSummaryTitle)
                .font(.system(size: titleSize, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.top, 12)

            Text(L.offWorkSummaryStats(summary.workMinutes, summary.breakCount))
                .font(.system(size: fullscreen ? 16 : 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            Text(L.offWorkSummaryFooter)
                .font(.system(size: fullscreen ? 14 : 12))
                .foregroundStyle(.primary.opacity(0.7))
                .padding(.top, 6)

            Button {
                state.dismissOffWorkSummary()
            } label: {
                Text(L.offWorkSummaryDismiss)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 24)
            .padding(.top, 16)

            if !fullscreen { Spacer().frame(height: 24) }
        }
        .frame(width: fullscreen ? 360 : 240)
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

/// Last screen frame of the SYSTEM MenuBarExtra panel, recorded whenever the
/// user opens it (see MenuPanelFrameRecorder in MenuView). Menu-bar managers
/// (iBar / Bartender) pull the real status icon out of the window server and
/// draw a proxy — the icon is untraceable at popup time, but the system panel
/// always opens under that proxy, so its last frame is the best anchor for
/// the auto-popup.
@MainActor
enum MenuPanelAnchor {
    private static let key = "menuPanelLastFrame"

    static var lastFrame: NSRect? {
        get {
            guard let s = UserDefaults.standard.string(forKey: key) else { return nil }
            let r = NSRectFromString(s)
            return r.isEmpty ? nil : r
        }
        set {
            guard let f = newValue else { return }
            UserDefaults.standard.set(NSStringFromRect(f), forKey: key)
        }
    }
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

// MARK: - Screen helpers

extension NSScreen {
    /// Stable identifier across reboots and reconnects.
    /// Built from CGDisplayCreateUUIDFromDisplayID — survives system restarts unlike CGDirectDisplayID.
    var stableUUID: String? {
        guard let did = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
              let cfUUID = CGDisplayCreateUUIDFromDisplayID(did)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, cfUUID) as String?
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

    private var monitorStartTime: Date?

    // Track current position for repositioning after screen changes
    private var currentPosition: BreakPosition?
    private var screenObservers: [NSObjectProtocol] = []

    init() {
        let wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.repositionWindows()
            }
        }
        let screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.repositionWindows()
            }
        }
        screenObservers = [wakeObserver, screenObserver]
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(screenObservers[0])
        NotificationCenter.default.removeObserver(screenObservers[1])
    }

    func show(seconds: Int) {
        remaining = seconds
        let position = appState?.config.breakPosition ?? .topRight
        // Clear the fallback alert card (if any) before building the break UI.
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        currentPosition = position
        if position == .fullscreen {
            createFullscreen()
        } else {
            createFloating(position: position)
        }
        startMonitoring()
    }

    // MARK: - Display target resolution

    /// Returns the screen the mouse cursor is currently on, falling back to NSScreen.main.
    private func activeScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    }

    /// Returns the set of screens to overlay based on user's display-target config.
    /// `.specific` with a missing/disconnected UUID silently falls back to active-screen behavior.
    private func targetScreens() -> [NSScreen] {
        let target = appState?.config.breakDisplayTarget ?? .activeScreen
        switch target {
        case .activeScreen:
            return [activeScreen()].compactMap { $0 }
        case .allScreens:
            return NSScreen.screens
        case .specific:
            if let uuid = appState?.config.breakDisplaySpecificUUID,
               let s = NSScreen.screens.first(where: { $0.stableUUID == uuid }) {
                return [s]
            }
            return [activeScreen()].compactMap { $0 }
        }
    }

    /// Auto-show the break reminder in the system MenuBarExtra panel via
    /// orderFrontRegardless, then immediately repair the panel frame to the
    /// content's fitting size — the missing step that caused issue #24 (a
    /// hidden panel keeps its stale frame; new, shorter content leaves a
    /// transparent gap). Never activates the app or takes key focus.
    func showAlert() {
        pinMenuPanel()
    }

    /// Break countdown in menuWindow mode: keep the pinned system panel and
    /// let MenuView morph in place; the frame repair runs on each appear.
    func showMenuBreak(seconds: Int) {
        remaining = seconds
        pinMenuPanel()
        startMonitoring()
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        unpinMenuPanel()
        currentPosition = nil
    }

    func hideAll() {
        hide()
        dismissMenuPanel()
    }

    // MARK: - Off-Work Summary

    /// Show the off-work summary through the SAME dispatch the break popup uses, honoring the
    /// user's `breakPosition`: menu-bar dropdown, a floating corner card, or a fullscreen overlay.
    /// Content comes from `BreakCardView` (driven by `appState.offWorkSummary`); no break countdown.
    func showOffWorkSummary() {
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        let position = appState?.config.breakPosition ?? .menuWindow
        switch position {
        case .menuWindow:
            pinMenuPanel()
        case .fullscreen:
            currentPosition = .fullscreen
            createFullscreen()
        default:
            currentPosition = position
            createFloating(position: position)
        }
    }

    // MARK: - Menu panel pinning (direct orderFront + frame repair)

    private var menuPinTimer: Timer?

    /// Pin the SYSTEM MenuBarExtra panel: order it front (no activation, no
    /// key focus) and repair its frame to the content's fitting size. Falls
    /// back to a self-drawn dropdown card if the panel object can't be found.
    func pinMenuPanel() {
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        currentPosition = .menuWindow
        guard let panel = findMenuBarPanel(includeHidden: true) else {
            createFloating(position: .menuWindow)
            return
        }
        panel.hidesOnDeactivate = false
        panel.orderFrontRegardless()
        repositionMenuPanelIfNeeded(panel)
        fixMenuPanelFrame(panel)
        startMenuWatchdog()
    }

    /// Close the user-opened MenuBarExtra panel (if visible) and stop pinning.
    func dismissMenuPanel() {
        unpinMenuPanel()
        guard let panel = findMenuBarPanel(), panel.isVisible else { return }
        panel.orderOut(nil)
    }

    private func unpinMenuPanel() {
        menuPinTimer?.invalidate()
        menuPinTimer = nil
        findMenuBarPanel(includeHidden: true)?.hidesOnDeactivate = true
    }

    /// The system dismisses the panel on outside clicks; while an alert /
    /// menu-mode break rides it, re-show it (orderFront only — no focus).
    private func startMenuWatchdog() {
        menuPinTimer?.invalidate()
        menuPinTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.ensureMenuPanelVisible() }
        }
    }

    private func ensureMenuPanelVisible() {
        guard shouldKeepMenuPanelPinned else { return }
        guard let panel = findMenuBarPanel(includeHidden: true), !panel.isVisible else { return }
        panel.orderFrontRegardless()
        fixMenuPanelFrame(panel)
    }

    private var shouldKeepMenuPanelPinned: Bool {
        guard let state = appState, !state.isPreview else { return false }
        if state.phase == .alerting { return true }
        guard state.config.breakPosition == .menuWindow else { return false }
        if state.offWorkSummary != nil { return true }
        return state.phase == .breaking || state.phase == .waiting
    }

    /// Resize the panel to its SwiftUI content's fitting size, keeping the
    /// top edge anchored. A hidden MenuBarExtra panel keeps its stale frame
    /// when content changes underneath — this repair is what prevents the
    /// transparent-gap bug (issue #24). Runs async so SwiftUI can commit the
    /// current phase's content first.
    private func fixMenuPanelFrame(_ panel: NSPanel) {
        DispatchQueue.main.async { [weak panel] in
            guard let panel, let content = panel.contentView else { return }
            let hosting = Self.findHostingView(in: content) ?? content
            let fit = hosting.fittingSize
            guard fit.width > 100, fit.height > 100, fit.height < 2000 else { return }
            var f = panel.frame
            guard abs(f.height - fit.height) > 2 || abs(f.width - fit.width) > 2 else { return }
            let topY = f.maxY
            f.size = NSSize(width: ceil(fit.width), height: ceil(fit.height))
            f.origin.y = topY - f.size.height
            panel.setFrame(f, display: true)
        }
    }

    private static func findHostingView(in view: NSView) -> NSView? {
        if String(describing: type(of: view)).contains("NSHostingView") { return view }
        for sub in view.subviews {
            if let h = findHostingView(in: sub) { return h }
        }
        return nil
    }

    /// If the panel has never been positioned (or its frame is off every
    /// screen), place it under the recorded anchor — the spot where the user
    /// last opened it (covers iBar-proxied icons) — or the top-right corner.
    private func repositionMenuPanelIfNeeded(_ panel: NSPanel) {
        if NSScreen.screens.contains(where: { $0.frame.intersects(panel.frame) }) { return }
        guard let screen = activeScreen() else { return }
        let vis = screen.visibleFrame
        let origin: NSPoint
        if let cached = MenuPanelAnchor.lastFrame, cached.midX > vis.minX, cached.midX < vis.maxX {
            origin = NSPoint(x: cached.midX - panel.frame.width / 2,
                             y: vis.maxY - panel.frame.height - 4)
        } else {
            origin = NSPoint(x: vis.maxX - panel.frame.width - 8,
                             y: vis.maxY - panel.frame.height - 8)
        }
        panel.setFrameOrigin(origin)
    }

    /// Called from MenuView.onAppear on every presentation / content rebuild
    /// of the system panel: record the anchor and repair the frame.
    func noteSystemMenuPanelOpened() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, let panel = self.findMenuBarPanel() else { return }
            MenuPanelAnchor.lastFrame = panel.frame
            self.fixMenuPanelFrame(panel)
        }
    }

    /// Screen-coordinate frame of this app's status-bar icon, captured from
    /// the label view's own host window (see StatusItemLocator). Off-screen
    /// frames (icon hidden by menu-bar managers) are rejected by callers via
    /// the on-screen midX check.
    private func statusItemIconFrame() -> NSRect? {
        guard let w = StatusItemLocator.window, w.frame.width > 0 else { return nil }
        return w.frame
    }

    /// Find the MenuBarExtra panel by searching app windows.
    private func findMenuBarPanel(includeHidden: Bool = false) -> NSPanel? {
        NSApp?.windows.first(where: { w in
            w is NSPanel
                && !(w is KeyablePanel)
                && w.styleMask.contains(.nonactivatingPanel)
                && w.styleMask.contains(.fullSizeContentView)
                && w.frame.width < 350
                && (includeHidden || w.isVisible)
        }) as? NSPanel
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

        currentPosition = position
        if position == .menuWindow {
            pinMenuPanel()
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

    // MARK: - Reposition after screen change / wake

    private func repositionWindows() {
        guard !windows.isEmpty, let position = currentPosition else { return }
        // Display topology may have changed (hot-plug, wake) — rebuild from scratch
        // so window count matches the current target-screen set.
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        if position == .fullscreen {
            createFullscreen()
        } else {
            createFloating(position: position)
        }
    }

    // MARK: - Floating window (SwiftUI BreakCardView)

    private func createFloating(position: BreakPosition) {
        guard let state = appState else { return }
        let screens: [NSScreen]
        if position == .menuWindow {
            // Single dropdown card, on the display that hosts the icon (or
            // where the system panel last opened when the icon is proxied).
            let anchorFrame = statusItemIconFrame() ?? MenuPanelAnchor.lastFrame
            let anchorScreen = anchorFrame.flatMap { f in
                NSScreen.screens.first { $0.frame.intersects(f) }
            }
            screens = [anchorScreen ?? activeScreen()].compactMap { $0 }
        } else {
            screens = targetScreens()
        }
        guard !screens.isEmpty else { return }

        let cornerRadius: CGFloat = 14
        let margin: CGFloat = 20

        for screen in screens {
            // menuWindow mode reproduces the old MenuBarExtra dropdown verbatim:
            // same content (MenuView with quit button / header banners), anchored
            // under the status icon. Other positions keep the bare break card.
            let inner: AnyView = position == .menuWindow
                ? AnyView(MenuView())
                : AnyView(BreakCardView())
            let cardView = inner
                .background(VisualEffectBackground())
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .environment(state)

            let hostingView = AutoResizingHostingView(rootView: cardView)
            let fitted = hostingView.fittingSize
            let pw = ceil(fitted.width)
            let ph = ceil(fitted.height)

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
            case .menuWindow:
                // Flush under the menu bar, centered like the real dropdown.
                // Anchor priority: live icon frame → last system-panel frame
                // (covers iBar-proxied icons) → right corner.
                y = vis.maxY - ph - 4
                let anchorX: CGFloat? = {
                    if let icon = statusItemIconFrame(),
                       icon.midX > vis.minX, icon.midX < vis.maxX { return icon.midX }
                    if let cached = MenuPanelAnchor.lastFrame,
                       cached.midX > vis.minX, cached.midX < vis.maxX { return cached.midX }
                    return nil
                }()
                if let anchorX {
                    x = min(max(anchorX - pw / 2, vis.minX + 8), vis.maxX - pw - 8)
                } else {
                    x = vis.maxX - pw - 8
                }
            case .fullscreen:
                x = vis.minX; y = vis.minY
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
            // NSPanel hides on app deactivation by default — the reminder must
            // survive the user switching apps or it silently disappears.
            p.hidesOnDeactivate = false
            if position == .menuWindow {
                // Match the system dropdown: visible above fullscreen Spaces
                // too (the reminder must reach users working fullscreen).
                p.level = .statusBar
                p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            }
            p.appearance = NSApp?.appearance ?? NSApp?.effectiveAppearance

            hostingView.frame = NSMakeRect(0, 0, pw, ph)
            hostingView.autoresizingMask = [.width, .height]
            hostingView.wantsLayer = true
            hostingView.layer?.cornerRadius = cornerRadius
            hostingView.layer?.masksToBounds = true
            p.contentView = hostingView

            if position == .menuWindow {
                // Never touch keyboard focus for the auto-popup — buttons
                // work on plain clicks; the quick-confirm shortcut is global.
                p.orderFrontRegardless()
            } else {
                p.makeKeyAndOrderFront(nil)
            }
            windows.append(p)
        }
    }

    // MARK: - Fullscreen (SwiftUI BreakCardView on dark background)

    private func createFullscreen() {
        guard let state = appState else { return }

        for screen in targetScreens() {
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
