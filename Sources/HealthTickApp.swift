import SwiftUI

@main
struct HealthTickApp: App {
    @StateObject private var state = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(state)
        } label: {
            Image(systemName: phaseSystemImage)
        }
        .menuBarExtraStyle(.window)

        Window(L.settingsWindow, id: "preferences") {
            SettingsView()
                .environmentObject(state)
        }
        .defaultSize(width: 440, height: 460)
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandGroup(after: .appInfo) {
                Button(L.checkForUpdates) {
                    UpdateChecker.shared.check(silent: false)
                }
            }

            CommandGroup(replacing: .sidebar) {
                Button(L.settings) {
                    openWindow(id: "preferences")
                    bringToFront()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(before: .windowArrangement) {
                Button(L.achievements) {
                    openWindow(id: "stats")
                    bringToFront()
                }
                .keyboardShortcut("1", modifiers: .command)

                Divider()
            }

            CommandGroup(replacing: .help) {
                Button(L.helpMenu) {
                    openWindow(id: "helpguide")
                    bringToFront()
                }
                .keyboardShortcut("?", modifiers: .command)

                Divider()

                Button(L.sponsorSupport) {
                    if let url = URL(string: "https://github.com/lifedever/health-tick-release#-赞助支持") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        Window(L.helpWindow, id: "helpguide") {
            HelpView()
        }
        .defaultSize(width: 600, height: 650)

        Window(L.statsWindow, id: "stats") {
            StatsWindowView()
                .environmentObject(state)
        }
        .defaultSize(width: 780, height: 620)
    }

    private static let isDev = Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true

    private var phaseSystemImage: String {
        if Self.isDev {
            switch state.phase {
            case .working: return "figure.walk.diamond"
            case .alerting, .breaking: return "cup.and.saucer"
            case .waiting: return "hand.raised"
            case .paused: return "pause.circle.fill"
            }
        }
        switch state.phase {
        case .working: return "figure.walk"
        case .alerting, .breaking: return "cup.and.saucer.fill"
        case .waiting: return "hand.raised.fill"
        case .paused: return "pause.circle"
        }
    }

    private func bringToFront() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var observer: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let iconPath = Bundle.main.bundlePath + "/Contents/Resources/AppIcon.icns"
        if let icon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = icon
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            UpdateChecker.shared.check(silent: true)
        }
        Timer.scheduledTimer(withTimeInterval: 4 * 3600, repeats: true) { _ in
            Task { @MainActor in
                UpdateChecker.shared.check(silent: true)
            }
        }

        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let hasVisibleWindow = NSApp.windows.contains { w in
                    w.isVisible && !(w is NSPanel) && !w.title.isEmpty
                        && w.styleMask.contains(.titled)
                }
                if !hasVisibleWindow {
                    NSApp.setActivationPolicy(.accessory)
                }
            }
        }
    }
}
