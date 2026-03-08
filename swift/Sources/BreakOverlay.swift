import AppKit
import Foundation

private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

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

@MainActor
final class BreakOverlayManager {
    private var windows: [NSPanel] = []
    private var timer: Timer?
    private var countdownLabel: NSTextField?
    private var warningLabel: NSTextField?
    private var skipButton: NSButton?
    private var remaining: Int = 0
    private var skipClickCount: Int = 0
    private let skipClicksNeeded = 3
    weak var appState: AppState?
    var onForceEnd: (() -> Void)?

    func show(seconds: Int) {
        remaining = seconds
        skipClickCount = 0
        let position = appState?.config.breakPosition ?? .topRight
        if position == .fullscreen {
            createFullscreen()
        } else {
            createFloating(position: position)
        }
        startMonitoring()
    }

    func hide() {
        timer?.invalidate()
        timer = nil
        for w in windows { w.orderOut(nil) }
        windows.removeAll()
        countdownLabel = nil
        warningLabel = nil
        skipButton = nil
    }

    // MARK: - Floating window

    private func createFloating(position: BreakPosition) {
        guard let screen = NSScreen.main else { return }

        let pw: CGFloat = 280
        let ph: CGFloat = 160
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
        case .fullscreen:
            x = 0; y = 0 // won't reach here
        }

        let p = KeyablePanel(
            contentRect: NSMakeRect(x, y, pw, ph),
            styleMask: [.titled, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.isMovableByWindowBackground = true
        p.title = "休息中"
        p.titlebarAppearsTransparent = true

        let content = p.contentView!
        layoutContent(in: content, width: pw, compact: true)

        p.makeKeyAndOrderFront(nil)
        windows.append(p)
    }

    // MARK: - Fullscreen

    private func createFullscreen() {
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
            p.alphaValue = 0.92
            p.backgroundColor = NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.1, alpha: 0.92)
            p.ignoresMouseEvents = false

            let content = p.contentView!
            let w = frame.size.width
            let h = frame.size.height
            let cy = h / 2

            let title = makeLabel("休息时间", frame: NSMakeRect(0, cy + 60, w, 44), size: 36)
            title.font = NSFont.systemFont(ofSize: 36, weight: .medium)
            title.textColor = .white
            content.addSubview(title)

            let countdown = makeLabel(formatTime(remaining), frame: NSMakeRect(0, cy - 10, w, 60), size: 52)
            countdown.font = NSFont.monospacedSystemFont(ofSize: 52, weight: .light)
            countdown.textColor = .white
            content.addSubview(countdown)
            if countdownLabel == nil { countdownLabel = countdown }

            let msg = makeLabel("请离开电脑，起来走走", frame: NSMakeRect(0, cy - 65, w, 30), size: 18)
            msg.textColor = NSColor(white: 0.7, alpha: 1)
            content.addSubview(msg)

            let warn = makeLabel("", frame: NSMakeRect(0, cy - 100, w, 26), size: 16)
            warn.textColor = NSColor.systemOrange
            content.addSubview(warn)
            if warningLabel == nil { warningLabel = warn }

            let btn = NSButton(frame: NSMakeRect(w / 2 - 70, cy - 150, 140, 32))
            btn.title = "跳过 (0/\(skipClicksNeeded))"
            btn.bezelStyle = .rounded
            btn.font = NSFont.systemFont(ofSize: 13)
            btn.contentTintColor = NSColor(white: 0.5, alpha: 1)
            btn.target = self
            btn.action = #selector(skipClicked)
            content.addSubview(btn)
            if skipButton == nil { skipButton = btn }

            p.makeKeyAndOrderFront(nil)
            windows.append(p)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Compact layout for floating

    private func layoutContent(in content: NSView, width pw: CGFloat, compact: Bool) {
        let countdown = makeLabel(formatTime(remaining), frame: NSMakeRect(0, 80, pw, 48), size: 38)
        countdown.font = NSFont.monospacedSystemFont(ofSize: 38, weight: .light)
        countdown.textColor = .white
        content.addSubview(countdown)
        if countdownLabel == nil { countdownLabel = countdown }

        let msg = makeLabel("起来走走，休息一下", frame: NSMakeRect(0, 58, pw, 20), size: 12)
        msg.textColor = NSColor.secondaryLabelColor
        content.addSubview(msg)

        let warn = makeLabel("", frame: NSMakeRect(0, 38, pw, 18), size: 11)
        warn.textColor = NSColor.systemOrange
        content.addSubview(warn)
        if warningLabel == nil { warningLabel = warn }

        let btn = NSButton(frame: NSMakeRect(pw / 2 - 55, 6, 110, 26))
        btn.title = "跳过 (0/\(skipClicksNeeded))"
        btn.bezelStyle = .rounded
        btn.font = NSFont.systemFont(ofSize: 11)
        btn.contentTintColor = NSColor.tertiaryLabelColor
        btn.target = self
        btn.action = #selector(skipClicked)
        content.addSubview(btn)
        if skipButton == nil { skipButton = btn }
    }

    @objc private func skipClicked() {
        skipClickCount += 1
        if skipClickCount >= skipClicksNeeded {
            onForceEnd?()
        } else {
            skipButton?.title = "跳过 (\(skipClickCount)/\(skipClicksNeeded))"
        }
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in self?.monitorTick() }
        }
    }

    private func monitorTick() {
        let idle = getUserIdleSeconds()
        if idle < 3 && remaining > 0 {
            warningLabel?.stringValue = "检测到操作，倒计时已暂停"
        } else {
            warningLabel?.stringValue = ""
            remaining -= 1
        }
        countdownLabel?.stringValue = formatTime(remaining)
    }

    private func formatTime(_ s: Int) -> String {
        let m = max(0, s) / 60
        let sec = max(0, s) % 60
        return String(format: "%02d:%02d", m, sec)
    }

    private func makeLabel(_ text: String, frame: NSRect, size: CGFloat) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.stringValue = text
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: size)
        return label
    }
}
