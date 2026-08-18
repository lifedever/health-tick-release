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

// MARK: - Snooze Duration Pill (issue #35)

/// One-click snooze duration chip. Own struct so each pill keeps its own
/// hover state. Explicit whites on the fullscreen shield — semantic colors
/// render near-black in light appearance there (issue #31).
private struct SnoozePillButton: View {
    let minutes: Int
    let fullscreen: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(L.alertSnoozeMinutes(minutes))
                .font(.system(size: fullscreen ? 13 : 11, weight: .medium))
                .foregroundStyle(fullscreen
                    ? AnyShapeStyle(.white.opacity(hovering ? 0.95 : 0.72))
                    : AnyShapeStyle(.primary.opacity(hovering ? 0.9 : 0.68)))
                .padding(.horizontal, fullscreen ? 14 : 10)
                .padding(.vertical, fullscreen ? 6 : 5)
                .background(Capsule().fill(fullscreen
                    ? AnyShapeStyle(.white.opacity(hovering ? 0.22 : 0.14))
                    : AnyShapeStyle(.primary.opacity(hovering ? 0.16 : 0.10))))
        }
        .buttonStyle(.plain)
        .handCursor()
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
    }
}

// MARK: - Shared Break Card View (single source of truth for ALL break UIs)

struct BreakCardView: View {
    @Environment(AppState.self) var state
    var fullscreen: Bool = false

    /// Hover state for the alert's secondary action ("skip this break").
    @State private var skipHovering = false

    private var timerProgress: Double {
        guard state.phase == .breaking else { return 0 }
        // Divide by the break actually in progress (may be a long break),
        // not the fixed normal-break setting (issue #28).
        let total = state.currentBreakTotalSeconds
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

    // MARK: - Shared Controls

    /// Primary confirm button for the alerting / waiting phases. The keyboard
    /// shortcut rides inside it as a badge: as a separate gray line below it
    /// read as body copy (and sat right next to the secondary action, making
    /// that one look like caption text too).
    @ViewBuilder
    private func primaryActionButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fullscreen ? 18 : 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: fullscreen ? 280 : .infinity)
                .padding(.vertical, fullscreen ? 12 : 10)
                // Trailing overlay, not an HStack member: the title stays
                // optically centered in the button (an inline badge shoved it
                // off-center) and the key sits where macOS puts shortcuts.
                .overlay(alignment: .trailing) {
                    if state.config.shortcutEnabled {
                        Text(state.config.shortcutDisplay)
                            .font(.system(size: fullscreen ? 14 : 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(.trailing, fullscreen ? 16 : 12)
                    }
                }
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .handCursor()
    }

    /// Secondary action pill (currently "skip this break"): soft tonal fill,
    /// narrower and lighter than the primary so the two never read as twins.
    /// On the fullscreen shield it must use explicit whites — semantic colors
    /// render near-black in light appearance and vanish there (issue #31).
    @ViewBuilder
    private func secondaryActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                // Says what the user is choosing instead of resting, which
                // reads faster than a skip glyph. Deliberately not ✍️ (already
                // the menu's "worked today" marker); 🧑‍💻 is the gender-neutral
                // technologist — not 👨‍💻/👩‍💻, which carry a gender.
                Text("🧑‍💻")
                    .font(.system(size: fullscreen ? 13 : 11))
                Text(title)
                    .font(.system(size: fullscreen ? 14 : 12, weight: .medium))
            }
            .foregroundStyle(fullscreen
                ? AnyShapeStyle(.white.opacity(skipHovering ? 0.95 : 0.72))
                : AnyShapeStyle(.primary.opacity(skipHovering ? 0.9 : 0.68)))
            .padding(.horizontal, fullscreen ? 22 : 16)
            .padding(.vertical, fullscreen ? 8 : 6)
            .background(Capsule().fill(fullscreen
                ? AnyShapeStyle(.white.opacity(skipHovering ? 0.22 : 0.14))
                : AnyShapeStyle(.primary.opacity(skipHovering ? 0.16 : 0.10))))
        }
        .buttonStyle(.plain)
        .handCursor()
        .onHover { skipHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: skipHovering)
    }

    @ViewBuilder
    private func completedBreakActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "checkmark.circle")
                .font(.system(size: fullscreen ? 14 : 12, weight: .medium))
                .foregroundStyle(fullscreen
                    ? AnyShapeStyle(.white.opacity(0.78))
                    : AnyShapeStyle(.primary.opacity(0.72)))
        }
        .buttonStyle(.plain)
        .handCursor()
    }

    /// Snooze row for the alerting phase (issue #35): a small label above
    /// three one-click duration pills. Sits between the primary confirm and
    /// the skip pill — a middle tier: unlike skipping, the break is still
    /// coming, so it deserves more visual weight than the skip escape hatch
    /// but must never compete with "go take the break".
    @ViewBuilder
    private var snoozeRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Text("⏰")
                    .font(.system(size: fullscreen ? 12 : 10))
                Text(L.alertSnoozeLabel)
                    .font(.system(size: fullscreen ? 13 : 11, weight: .medium))
            }
            .foregroundStyle(fullscreen
                ? AnyShapeStyle(.white.opacity(0.55))
                : AnyShapeStyle(.secondary))

            HStack(spacing: 8) {
                ForEach(Self.snoozeOptionsMinutes, id: \.self) { minutes in
                    SnoozePillButton(minutes: minutes, fullscreen: fullscreen) {
                        state.snoozeBreakFromAlert(minutes: minutes)
                    }
                }
            }
        }
    }

    /// 2 = "let me finish this line", 5 = the classic snooze, 10 = "the
    /// meeting has one more section". Roughly doubling steps so picking one
    /// under pressure takes no thought.
    private static let snoozeOptionsMinutes = [2, 5, 10]

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
            .handCursor()
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

        primaryActionButton(L.alertConfirmBreak, color: .orange) {
            state.confirmBreak()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)

        snoozeRow
            .padding(.top, 12)

        secondaryActionButton(L.alertSkipBreak) {
            state.skipBreakFromAlert()
        }
        .padding(.top, 12)

        completedBreakActionButton(L.alertAlreadyRested) {
            state.markBreakCompleted()
        }
        .padding(.top, 10)

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
        .handCursor()
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

        primaryActionButton(L.alertImBack, color: .green) {
            state.confirmReturn()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)

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

        primaryActionButton(L.alertConfirmBreak, color: .orange) {
            state.confirmBreak()
        }

        snoozeRow

        secondaryActionButton(L.alertSkipBreak) {
            state.skipBreakFromAlert()
        }

        completedBreakActionButton(L.alertAlreadyRested) {
            state.markBreakCompleted()
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
        .handCursor()
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

        primaryActionButton(L.alertImBack, color: .green) {
            state.confirmReturn()
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

    /// The user's configured "specific display", if connected. A nil UUID
    /// (config written before the issue #31 fix) resolves to screens.first —
    /// the display the settings picker showed as selected. nil when the
    /// target isn't `.specific` or the display is disconnected.
    private func specificScreen() -> NSScreen? {
        guard appState?.config.breakDisplayTarget == .specific else { return nil }
        guard let uuid = appState?.config.breakDisplaySpecificUUID else {
            Probe.log("specificScreen: uuid=nil (pre-#31 config) → screens.first")
            return NSScreen.screens.first
        }
        return NSScreen.screens.first { $0.stableUUID == uuid }
    }

    /// Returns the set of screens to overlay based on user's display-target config.
    /// `.specific` with a disconnected UUID falls back to active-screen behavior.
    private func targetScreens() -> [NSScreen] {
        let target = appState?.config.breakDisplayTarget ?? .activeScreen
        switch target {
        case .activeScreen:
            return [activeScreen()].compactMap { $0 }
        case .allScreens:
            return NSScreen.screens
        case .specific:
            if let s = specificScreen() { return [s] }
            Probe.log("targetScreens .specific: configured display not connected → activeScreen fallback")
            return [activeScreen()].compactMap { $0 }
        }
    }

    /// Present the break-time alert in the user's chosen break-window style —
    /// the same dispatch showOffWorkSummary uses. The system MenuBarExtra
    /// panel is pinned ONLY when the rest window IS the main window; for
    /// floating/fullscreen users the alert rides the window the break itself
    /// will use. Auto-popping the panel for them left it stranded next to the
    /// break window after confirming (issue #24 final round: the panel was
    /// auto-popped, so the system-path dismiss added for issue #25 is a
    /// no-op on it — two windows on screen at once).
    func showAlert() {
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        let position = appState?.config.breakPosition ?? .menuWindow
        Probe.log("showAlert position=\(position.rawValue)")
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

    /// Break countdown in menuWindow mode: keep the pinned system panel and
    /// let MenuView morph in place; the frame repair runs on each appear.
    /// NOTE: menuWindow mode intentionally ignores breakDisplayTarget — the
    /// dropdown is the status bar's extension and lives where the icon is
    /// (issue #31 follow-up: the system owns the panel's frame; a
    /// cross-display setFrame is silently reverted, probe 2026-07-31). The
    /// settings hide the screen picker in this mode.
    func showMenuBreak(seconds: Int) {
        remaining = seconds
        pinMenuPanel()
        startMonitoring()
    }

    func hide() {
        Probe.log("hide()")
        timer?.invalidate()
        timer = nil
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        // Always end a flow by explicitly ordering the system panel out. The
        // watchdog re-shows it behind the system's back (orderFront while the
        // system considers it dismissed); leaving that desync in place makes
        // later icon clicks toggle state without ever re-attaching the window
        // to the active Space (issue #25, macOS 26). 1.6.16 healed this
        // accidentally via an outside-click monitor — this is the same reset,
        // made deterministic.
        dismissMenuPanel()
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

    // MARK: - Panel warm-up (force-create the lazily-built system panel)

    /// SwiftUI builds the MenuBarExtra panel lazily on its FIRST presentation:
    /// until the user clicks the icon once, the NSPanel object doesn't exist,
    /// pinMenuPanel has nothing to order front, and a menuWindow-mode alert in
    /// a fresh session is invisible (probe log 2026-07-06). Warm it up at
    /// launch: performClick the status button once with the panel forced
    /// transparent, then dismiss through the system path — the system creates
    /// the panel, books a clean presented→dismissed cycle, and the user sees
    /// nothing. One-shot at launch; NOT the repeated performClick pinning
    /// rejected in issue #24 (focus stealing / toggle desync came from using
    /// it on a timer against an already-presented panel).
    func warmUpMenuPanelIfNeeded(attempt: Int = 0) {
        guard appState?.config.breakPosition == .menuWindow else { return }
        guard findMenuBarPanel(includeHidden: true) == nil else {
            Probe.log("warmUp: panel already exists, nothing to do")
            return
        }
        guard attempt < 20 else {
            Probe.log("warmUp: giving up — status button never materialized")
            return
        }
        guard let button = statusItemButton() else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.warmUpMenuPanelIfNeeded(attempt: attempt + 1)
            }
            return
        }
        Probe.log("warmUp: performClick on status button (attempt \(attempt))")
        button.performClick(nil)
        guard let panel = findMenuBarPanel(includeHidden: true) else {
            Probe.log("warmUp: performClick did NOT create the panel")
            return
        }
        // Always run the full hidden present→dismiss cycle, even when a
        // pinned flow is already waiting for the panel. Leaving the
        // performClick presentation up poisons the ledgers: the system books
        // it "presented", later tears it down behind AppKit's back, and the
        // window ends up gone from the window server while isVisible /
        // isOnActiveSpace still say true (probe log 2026-07-07). The auto-pop
        // orderFront path after a CLEANLY dismissed cycle is the proven-
        // stable way to show pinned content — so finish the cycle, then
        // re-present through pinMenuPanel.
        panel.alphaValue = 0
        unpinMenuPanel()  // keep the watchdog from re-fronting mid-cycle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak panel] in
            self?.appState?.requestMenuPanelDismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let panel else { return }
                Probe.log("warmUp: dismissed, visible=\(panel.isVisible) — restoring alpha")
                if panel.isVisible { panel.orderOut(nil) }
                panel.alphaValue = 1
                // Re-present for a waiting pinned flow — but NOT immediately:
                // ordering front while the system is still tearing the
                // dismissed presentation down leaves the window permanently
                // detached from the window server with isVisible lying true
                // (probe log 2026-07-07; only a real user click heals it).
                // 1.5s matches the empirically clean gap.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    guard let self, self.shouldKeepMenuPanelPinned else { return }
                    Probe.log("warmUp: teardown settled — re-presenting via pinMenuPanel")
                    self.pinMenuPanel()
                }
            }
        }
    }

    /// The status-bar button hosting our icon. Primary source: the window
    /// StatusItemLocator grabbed from inside the label view. Fallback: scan
    /// NSApp.windows for the status-bar window class — menu-bar managers
    /// (iBar) can detach the icon in ways that keep the grabber from ever
    /// seeing a window. performClick works either way: the action fires
    /// in-process regardless of where the window is.
    private func statusItemButton() -> NSButton? {
        func findButton(in v: NSView) -> NSButton? {
            if let b = v as? NSButton { return b }
            for s in v.subviews {
                if let b = findButton(in: s) { return b }
            }
            return nil
        }
        if let w = StatusItemLocator.window, let c = w.contentView, let b = findButton(in: c) {
            return b
        }
        for w in NSApp?.windows ?? [] {
            if String(describing: type(of: w)).contains("StatusBar"),
               let c = w.contentView, let b = findButton(in: c) {
                return b
            }
        }
        Probe.log("statusItemButton: none — locator=\(StatusItemLocator.window.map { String(describing: type(of: $0)) } ?? "nil") appWindows=\((NSApp?.windows ?? []).map { String(describing: type(of: $0)) }.joined(separator: ","))")
        return nil
    }

    // MARK: - Menu panel pinning (direct orderFront + frame repair)

    private var menuPinTimer: Timer?

    /// Pin the SYSTEM MenuBarExtra panel: order it front (no activation, no
    /// key focus) and repair its frame to the content's fitting size.
    /// The main-window popup is always the REAL panel — never a look-alike
    /// floating card (issue #24: users want the panel itself). If the panel
    /// object doesn't exist yet (fresh launch, icon never clicked), the alert
    /// sound + status icon carry the reminder and the watchdog pins the panel
    /// the moment it materializes.
    func pinMenuPanel() {
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        currentPosition = .menuWindow
        startMenuWatchdog()
        guard let panel = findMenuBarPanel(includeHidden: true) else {
            Probe.log("pinMenuPanel: panel NOT FOUND (not created yet) — watchdog waiting")
            return
        }
        Probe.log("pinMenuPanel: panel found visible=\(panel.isVisible) onSpace=\(panel.isOnActiveSpace) frame=\(panel.frame)")
        // macOS 26: after the system dismisses the panel once, a plain
        // orderFront no longer re-attaches it to any Space — the window stays
        // ordered-in but invisible (issue #25). moveToActiveSpace makes the
        // order-front re-space it onto the user's current Space.
        panel.collectionBehavior.insert(.moveToActiveSpace)
        // Fix a stale position BEFORE the panel becomes visible: the frame
        // survives orderOut across breaks and display-topology changes, and
        // the auto-pop shows it verbatim (issues #29/#30).
        repositionMenuPanelIfNeeded(panel)
        enforceMenuBand(panel, context: "pin")
        panel.orderFrontRegardless()
        // Every pin presents possibly-new content (alert card, break
        // countdown, summary): size reports from before this moment describe
        // the previous content and must not drive the repair.
        noteMenuContentChanged()
        repairMenuPanelFrame(panel, reason: "pin")
    }

    /// Close the user-opened MenuBarExtra panel (if visible) and stop pinning.
    /// Close the panel through the system's own path (SwiftUI dismiss), and
    /// fall back to real-menu UX for auto-popped flows the system never
    /// "presented": stay up until the next outside click, then order out.
    /// The re-space repair in noteSystemMenuPanelOpened keeps icon clicks
    /// alive after that orderOut (issue #25).
    ///
    /// force: deterministic close for flow hand-offs — the break continues in
    /// a separate floating/fullscreen window, so a lingering auto-popped
    /// panel (where the system-path dismiss is a no-op) would sit next to
    /// the new break window until the next outside click (issue #24 final
    /// round). The system path still runs first; orderOut only fires if the
    /// panel is still up after the grace period, and the Space-detach it
    /// causes on macOS 26 is healed by the noteSystemMenuPanelOpened repair.
    func dismissMenuPanel(force: Bool = false) {
        unpinMenuPanel()
        guard let panel = findMenuBarPanel(), panel.isVisible else {
            Probe.log("dismissMenuPanel(force=\(force)): panel not visible, no-op")
            return
        }
        Probe.log("dismissMenuPanel(force=\(force)): panel visible, requesting system dismiss")
        // Defer one runloop turn: callers (confirmReturn etc.) change phase
        // in the same transaction, and `.id(phase)` rebuilds the content —
        // a bump inside that transaction gets swallowed by the identity swap
        // and replayed at the NEXT presentation, killing it (issue #25 tail).
        DispatchQueue.main.async { [weak self] in
            self?.appState?.requestMenuPanelDismiss()
        }
        if force {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak panel] in
                if let panel, panel.isVisible {
                    Probe.log("dismissMenuPanel force: grace elapsed, panel still visible -> orderOut")
                    panel.orderOut(nil)
                } else {
                    Probe.log("dismissMenuPanel force: system dismiss worked, no orderOut needed")
                }
            }
        } else {
            setupOutsideClickDismiss(for: panel)
        }
    }

    private func unpinMenuPanel() {
        menuPinTimer?.invalidate()
        menuPinTimer = nil
    }

    private var outsideClickMonitor: Any?

    /// One-shot: dismiss the lingering panel on the next click outside it —
    /// same behavior as a real menu (and as 1.6.16).
    private func setupOutsideClickDismiss(for panel: NSPanel) {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak panel] event in
            guard let self else { return }
            guard let panel, panel.isVisible else {
                if let monitor = self.outsideClickMonitor {
                    NSEvent.removeMonitor(monitor)
                    self.outsideClickMonitor = nil
                }
                return
            }
            // Global monitor events carry screen coordinates.
            if !panel.frame.contains(event.locationInWindow) {
                Probe.log("outsideClickMonitor: outside click at \(event.locationInWindow) -> dismiss + delayed orderOut")
                // System path first: if the system still books the panel as
                // presented, dismiss() closes it and keeps the toggle in
                // sync. Only orderOut if the panel is still up after that
                // (the repair in noteSystemMenuPanelOpened covers the rest).
                self.appState?.requestMenuPanelDismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak panel] in
                    if let panel, panel.isVisible {
                        panel.orderOut(nil)
                    }
                }
                if let monitor = self.outsideClickMonitor {
                    NSEvent.removeMonitor(monitor)
                    self.outsideClickMonitor = nil
                }
            }
        }
    }

    /// The system dismisses the panel on outside clicks; while an alert /
    /// menu-mode break rides it, re-show it (orderFront only — no focus).
    private func startMenuWatchdog() {
        menuPinTimer?.invalidate()
        // 0.5s, not 2s: macOS dismisses a system-presented panel on any
        // outside click while we're pinning it; a 2s re-front gap reads as
        // "the reminder flashed and died" (probe log 2026-07-06). The check
        // is a cheap window scan and a no-op while the panel is up.
        menuPinTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.ensureMenuPanelVisible() }
        }
    }

    private func ensureMenuPanelVisible() {
        guard shouldKeepMenuPanelPinned else { return }
        guard let panel = findMenuBarPanel(includeHidden: true) else {
            Probe.log("watchdog: panel still not created")
            return
        }
        // Three ledgers must agree (issue #25 and its 2026-07-07 sequel):
        // isVisible (AppKit cache), isOnActiveSpace, AND the window server.
        // A system-side teardown can drop the window from the server while
        // AppKit still books it visible+onSpace — the user sees nothing and
        // the two cheap checks pass forever.
        let appKitOK = panel.isVisible && panel.isOnActiveSpace
        if appKitOK && isOnScreenPerWindowServer(panel) { return }
        Probe.log("watchdog: re-front (visible=\(panel.isVisible) onSpace=\(panel.isOnActiveSpace) server=\(isOnScreenPerWindowServer(panel)))")
        if appKitOK {
            // Poisoned state: AppKit thinks the panel is up, so a plain
            // orderFront may no-op. Detach first so the re-order is real.
            panel.orderOut(nil)
        }
        panel.collectionBehavior.insert(.moveToActiveSpace)
        panel.orderFrontRegardless()
        repairMenuPanelFrame(panel, reason: "watchdogRefront")
    }

    /// Ground truth from the window server: is this window actually ordered
    /// in on screen? NSWindow.isVisible is a process-local cache and can lie
    /// after the system tears a presentation down behind AppKit's back.
    /// Scans the onscreen list rather than querying by ID —
    /// CGWindowListCreateDescriptionFromArray returns nothing for windows
    /// that the onscreen list provably contains (macOS 26, 2026-07-07).
    private func isOnScreenPerWindowServer(_ panel: NSPanel) -> Bool {
        let target = panel.windowNumber
        guard target > 0 else { return false }
        let on = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return on.contains { ($0[kCGWindowNumber as String] as? NSNumber)?.intValue == target }
    }

    private var shouldKeepMenuPanelPinned: Bool {
        guard let state = appState, !state.isPreview else { return false }
        // Every pinned flow — alert included — requires menuWindow mode now:
        // floating/fullscreen users get their alert in their own break
        // window, and re-fronting the panel here would recreate the
        // double-window bug the watchdog's caller just avoided.
        guard state.config.breakPosition == .menuWindow else { return false }
        if state.phase == .alerting { return true }
        if state.offWorkSummary != nil { return true }
        return state.phase == .breaking || state.phase == .waiting
    }

    // MARK: - Menu panel frame repair (issue #24 / #9)
    //
    // A pinned (auto-popped) MenuBarExtra panel keeps its stale frame when the
    // `.id(phase)` content changes underneath: on auto-popped panels SwiftUI
    // defers onAppear/onGeometryChange until the next SYSTEM presentation
    // (probe 2026-07-21, macOS 15 AND 26), so no view-layer callback fires
    // for in-place phase morphs like breaking→waiting — the shorter waiting
    // card shows a transparent gap below (issue #9). Repair timing is
    // therefore driven EXPLICITLY (pin calls + AppState phase changes), and
    // measurement uses two sources:
    //   1. SwiftUI-reported size (MenuView.onGeometryChange) — exact when it
    //      arrives, but deferred on auto-popped panels; only trusted when it
    //      arrived after the last known content change.
    //   2. Offscreen self-hosted measurement (measureMenuContentOffscreen) —
    //      the panel's own content view is a MenuBarExtraHostingView (NOT
    //      named "NSHostingView"!) whose fittingSize AND intrinsicContentSize
    //      report .zero on macOS 15.7 and 26 alike (user + local probes,
    //      2026-07-21), so the only reliable measurement is one we host
    //      ourselves.
    // No usable source → leave the panel alone: on macOS 26 the system
    // tracks the panel's content size itself (probe 2026-07-21), and a wrong
    // setFrame would be worse than the gap. The ≤2pt delta guard keeps every
    // repair a no-op when the frame is already correct, so systems that
    // self-heal never see a visual difference. (User-log fidelity check: the
    // panel frame equals MenuView's ideal size exactly — 436→436, 408→409 —
    // so measuring the same view with the same state reproduces the frame.)

    /// Latest MenuView content size reported from the SwiftUI layer, with its
    /// arrival time (freshness gate against deferred/replayed callbacks).
    private var lastMenuContentSize: CGSize?
    private var lastMenuSizeReportAt = Date.distantPast
    /// Set whenever the panel's content is known to have changed identity
    /// (phase change / pin of possibly-new content); size reports older than
    /// this describe the PREVIOUS content and must not be trusted.
    private var lastMenuContentChangeAt = Date.distantPast
    /// Panel size recorded at the same moment: if the panel's size has moved
    /// away from this by the time a repair pass runs — and not to a size WE
    /// set — the system is tracking the content size itself (macOS 26).
    /// Fighting it triple-flashes the panel (probe 2026-07-21: our setFrame
    /// vs the system's own resize, alternating), so the repair yields.
    private var menuSizeAtContentChange: CGSize?
    private var lastRepairSetSize: CGSize?

    private func sizesRoughlyEqual(_ a: CGSize, _ b: CGSize) -> Bool {
        abs(a.width - b.width) <= 1 && abs(a.height - b.height) <= 1
    }

    /// Record a content-identity change: timestamp (invalidates older SwiftUI
    /// size reports) plus the panel's current size (baseline for the
    /// system-tracking gate above).
    private func noteMenuContentChanged() {
        lastMenuContentChangeAt = Date()
        menuSizeAtContentChange = findMenuBarPanel(includeHidden: true)?.frame.size
        lastRepairSetSize = nil
    }

    func noteMenuContentSize(_ size: CGSize) {
        lastMenuContentSize = size
        lastMenuSizeReportAt = Date()
        Probe.log("noteMenuContentSize: reported=\(size)")
        guard shouldKeepMenuPanelPinned, let panel = findMenuBarPanel(), panel.isVisible else { return }
        repairMenuPanelFrame(panel, reason: "sizeReport")
    }

    /// Explicit repair trigger for in-place content morphs that come with no
    /// pin call (breaking→waiting, issue #9): schedule two idempotent repair
    /// passes so a slow SwiftUI commit can't outrun a single-shot measurement.
    func menuPanelContentDidChange() {
        noteMenuContentChanged()
        guard shouldKeepMenuPanelPinned else { return }
        for delay in [0.15, 0.7] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.shouldKeepMenuPanelPinned else { return }
                guard let panel = self.findMenuBarPanel(), panel.isVisible else { return }
                self.repairMenuPanelFrame(panel, reason: "contentChange+\(delay)")
            }
        }
    }

    /// Resize the panel to its content's measured size, keeping the top edge
    /// anchored. Runs async so SwiftUI can commit the current phase's content
    /// first. Geometry-only: never touches the present/dismiss ledgers that
    /// the issue #25 repairs depend on, and never activates or takes focus.
    /// Every exit enforces the menu band (issues #29/#30): the size logic may
    /// rightfully leave the frame alone, but a drifted POSITION must never
    /// survive a repair pass — top-anchoring to a wrong top edge just pins
    /// the drift in place.
    private func repairMenuPanelFrame(_ panel: NSPanel, reason: String) {
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let self, let panel else { return }
            var f = panel.frame
            // System-tracking gate: the panel size moved since the content
            // change, and not to a size we set — the system is resizing the
            // panel itself (macOS 26 does this even for auto-popped panels).
            // Yield to it; our job is only the frozen-frame case (macOS 15).
            if let base = self.menuSizeAtContentChange,
               !self.sizesRoughlyEqual(base, f.size),
               self.lastRepairSetSize.map({ !self.sizesRoughlyEqual($0, f.size) }) ?? true {
                Probe.log("repairFrame(\(reason)): system moved \(base) -> \(f.size), yielding")
                self.enforceMenuBand(panel, context: "\(reason)/yield")
                return
            }
            var size: CGSize?
            var source = "none"
            if let s = self.lastMenuContentSize, self.lastMenuSizeReportAt > self.lastMenuContentChangeAt {
                size = s
                source = "swiftui"
            } else if let measured = self.measureMenuContentOffscreen() {
                size = measured
                source = "offscreen"
            }
            if let cv = panel.contentView {
                let subs = cv.subviews.map { "\(type(of: $0)):\($0.frame.size)" }.joined(separator: " ")
                Probe.log("repairFrame(\(reason)): contentView=\(cv.frame.size) subs=[\(subs)]")
            }
            guard let fit = size, fit.height < 2000 else {
                Probe.log("repairFrame(\(reason)): no usable measurement — leaving panel alone, frame=\(panel.frame)")
                self.enforceMenuBand(panel, context: "\(reason)/noMeasure")
                return
            }
            guard abs(f.height - fit.height) > 2 || abs(f.width - fit.width) > 2 else {
                Probe.log("repairFrame(\(reason)): no-op [\(source)] delta ≤2pt, frame=\(f)")
                self.enforceMenuBand(panel, context: "\(reason)/noop")
                return
            }
            let topY = f.maxY
            f.size = NSSize(width: ceil(fit.width), height: ceil(fit.height))
            f.origin.y = topY - f.size.height
            if let screen = self.menuAnchorScreen(for: panel),
               let fixed = self.menuBandCorrection(for: f, on: screen) {
                Probe.log("repairFrame(\(reason)): band correction \(f) -> \(fixed)")
                f = fixed
            }
            panel.setFrame(f, display: true)
            self.lastRepairSetSize = f.size
            Probe.log("repairFrame(\(reason)): setFrame -> \(f) [\(source)]")
        }
    }

    // MARK: - Menu band invariant (issues #29 / #30)
    //
    // An auto-popped menu panel must hang just below the menu bar of its
    // anchor screen. The frame survives orderOut across breaks, Space moves,
    // and display-topology changes, and NOTHING in the pinned flow ever
    // corrected the position: the frame repair top-anchors to the CURRENT top
    // (right or wrong), the system re-anchors only on its own presentations,
    // and the off-screen rescue fired only when the panel intersected no
    // screen at all. A frame carried over from another display therefore
    // intrudes into the menu bar by exactly the bar-height difference
    // (issue #30: on this dev setup laptop visibleFrame.maxY=949 vs external
    // 982 — a 33pt intrusion) or floats mid-screen (issue #29 screenshot).
    // Window-server probe 2026-07-24: on macOS 26 every system auto-pop
    // resize is TOP-anchored (yTop constant across 253↔368↔396↔280), so an
    // in-band frame stays in band — the check below is a no-op on every
    // healthy path (issue #9 red line: zero setFrame when nothing is wrong).

    /// The screen that should host the auto-popped panel: the screen holding
    /// the status icon (live frame, else the last recorded system-panel
    /// frame — iBar-proxied icons have no live frame), falling back to the
    /// panel's own screen, then the mouse's.
    private func menuAnchorScreen(for panel: NSPanel) -> NSScreen? {
        for anchor in [statusItemIconFrame(), MenuPanelAnchor.lastFrame] {
            if let a = anchor, let s = NSScreen.screens.first(where: { $0.frame.intersects(a) }) {
                return s
            }
        }
        return panel.screen ?? activeScreen()
    }

    /// Returns the in-band frame for `f`, or nil when `f` is already fine.
    /// In band = top edge within 44pt below the screen's visibleFrame.maxY
    /// (native gap measured at 2pt on macOS 26; 44 = menu-bar height + slack
    /// so a legitimate system placement is never fought) and horizontally on
    /// screen. Corrections use the same 4pt gap and anchor-centered x as the
    /// dropdown-card layout in createFloating.
    private func menuBandCorrection(for f: NSRect, on screen: NSScreen) -> NSRect? {
        let vis = screen.visibleFrame
        let topOK = f.maxY <= vis.maxY && f.maxY >= vis.maxY - 44
        let xOK = f.minX >= vis.minX - 1 && f.maxX <= vis.maxX + 1
        if topOK && xOK { return nil }
        var out = f
        out.origin.y = (vis.maxY - 4) - f.height
        let anchorX = [statusItemIconFrame()?.midX, MenuPanelAnchor.lastFrame?.midX]
            .compactMap { $0 }
            .first { $0 > vis.minX && $0 < vis.maxX }
        if let anchorX { out.origin.x = anchorX - f.width / 2 }
        out.origin.x = min(max(out.origin.x, vis.minX + 8), vis.maxX - f.width - 8)
        return out
    }

    /// Position-only band enforcement for paths that keep the panel's size.
    private func enforceMenuBand(_ panel: NSPanel, context: String) {
        guard let screen = menuAnchorScreen(for: panel),
              let fixed = menuBandCorrection(for: panel.frame, on: screen) else { return }
        Probe.log("enforceMenuBand(\(context)): \(panel.frame) -> \(fixed)")
        panel.setFrame(fixed, display: true)
    }

    /// Measure MenuView's ideal size with a throwaway self-hosted
    /// NSHostingView sharing the live AppState. Never attached to a window,
    /// so none of MenuView's lifecycle callbacks (onAppear, onGeometryChange)
    /// fire — this is a pure synchronous layout query.
    private func measureMenuContentOffscreen() -> CGSize? {
        guard let state = appState else { return nil }
        let host = NSHostingView(rootView: MenuView().environment(state))
        let size = host.fittingSize
        guard size.width > 100, size.height > 100 else { return nil }
        return size
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
        Probe.log("noteSystemMenuPanelOpened (MenuView.onAppear)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, let panel = self.findMenuBarPanel() else { return }
            Probe.log("repairHook: visible=\(panel.isVisible) onSpace=\(panel.isOnActiveSpace) frame=\(panel.frame)")
            // Repair hook (issue #25): after any of our ordering ops, the
            // system's own present can leave the window detached from every
            // Space — ordered-in but invisible. Detect and re-space it so an
            // icon click always produces a visible panel.
            if !panel.isOnActiveSpace {
                panel.collectionBehavior.insert(.moveToActiveSpace)
                panel.orderFrontRegardless()
            }
            MenuPanelAnchor.lastFrame = panel.frame
            // Frame repair on system presentations. NOTE (probe 2026-07-21):
            // this hook only fires when the SYSTEM presents the panel (user
            // click / performClick) — on auto-popped panels SwiftUI defers
            // onAppear until the next system presentation, so in-place phase
            // morphs are covered by menuPanelContentDidChange instead.
            self.repairMenuPanelFrame(panel, reason: "onAppear")
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

    /// Dev-driver probe (healthtick.dev.dump): one-line snapshot of the
    /// system panel's frame plus all three visibility ledgers (issue #30).
    func probeDumpPanelFrame(context: String) {
        guard let panel = findMenuBarPanel(includeHidden: true) else {
            Probe.log("dump[\(context)]: panel nil")
            return
        }
        Probe.log("dump[\(context)]: frame=\(panel.frame) visible=\(panel.isVisible) onSpace=\(panel.isOnActiveSpace) server=\(isOnScreenPerWindowServer(panel))")
    }

    /// Dev-driver fault injection (healthtick.dev.corruptLow/corruptHigh):
    /// drag the system panel to a corrupted position so the band invariant
    /// can be regression-tested end to end. "low" reproduces issue #29 (panel
    /// adrift mid-screen), "high" reproduces issue #30 (top edge intruding
    /// into the menu bar, as a frame carried over from a screen with a
    /// higher visibleFrame.maxY would).
    func probeCorruptPanelFrame(mode: String) {
        guard let panel = findMenuBarPanel(includeHidden: true),
              let screen = panel.screen ?? NSScreen.main else { return }
        var f = panel.frame
        let vis = screen.visibleFrame
        if mode == "high" {
            f.origin.y = (vis.maxY + 33) - f.height
        } else {
            f.origin = NSPoint(x: vis.midX - 200, y: vis.midY - f.height / 2)
        }
        Probe.log("corrupt(\(mode)): setFrame \(panel.frame) -> \(f)")
        panel.setFrame(f, display: true)
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
        Probe.log("preview(\(position.rawValue))")
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

            if position == .menuWindow || appState?.phase == .alerting {
                // Never touch keyboard focus for the auto-popup — buttons
                // work on plain clicks; the quick-confirm shortcut is global.
                // Same rule for the alert card in any position: it pops up
                // mid-typing, before the user consented to stop working
                // (issue #24 round one: key-stealing reminders block input).
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
            // Window-local coordinates: screen.frame's global origin is
            // non-zero on secondary displays and would shift the content
            // clean out of the panel (issue #31 follow-up).
            hostingView.frame = NSRect(origin: .zero, size: frame.size)
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
