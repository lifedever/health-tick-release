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

        Window("设置", id: "settings") {
            SettingsView()
                .environmentObject(state)
        }
        .defaultSize(width: 440, height: 480)
        .commands {
            // Replace default "New Window" etc
            CommandGroup(replacing: .newItem) {}

            // HealthTick menu
            CommandGroup(after: .appInfo) {
                Button("检查更新...") {
                    UpdateChecker.shared.check(silent: false)
                }
            }

            // File menu - settings
            CommandGroup(replacing: .sidebar) {
                Button("设置") {
                    openWindow(id: "settings")
                    bringToFront()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            // Window menu items
            CommandGroup(before: .windowArrangement) {
                Button("成就") {
                    openWindow(id: "stats")
                    bringToFront()
                }
                .keyboardShortcut("1", modifiers: .command)

                Divider()
            }

            // Help menu
            CommandGroup(replacing: .help) {
                Button("HealthTick 帮助") {
                    openWindow(id: "helpguide")
                    bringToFront()
                }
                .keyboardShortcut("?", modifiers: .command)

                Divider()

                Button("赞助支持") {
                    if let url = URL(string: "https://github.com/lifedever/health-tick-release#-赞助支持") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        Window("帮助", id: "helpguide") {
            HelpView()
        }
        .defaultSize(width: 600, height: 650)

        Window("成就", id: "stats") {
            StatsWindowView()
                .environmentObject(state)
        }
        .defaultSize(width: 780, height: 620)
    }

    private var phaseSystemImage: String {
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
        // Set app icon from bundle resources
        let iconPath = Bundle.main.bundlePath + "/Contents/Resources/AppIcon.icns"
        if let icon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = icon
        }
        // Check for updates silently on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            UpdateChecker.shared.check(silent: true)
        }

        // Monitor window close to hide Dock icon when no windows are open
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
