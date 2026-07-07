import Foundation

/// Dev-build-only probe log for window-lifecycle forensics (menu panel
/// flash/disappear investigations). No-op in release builds; writes a
/// timestamped line per event to /tmp so a repro session can be correlated
/// against CGWindowList sampling afterwards.
@MainActor
enum Probe {
    private static let enabled = Bundle.main.bundleIdentifier?.hasSuffix(".dev") == true
    private static let path = "/tmp/healthtick-dev-probe.log"
    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func log(_ msg: @autoclosure () -> String) {
        guard enabled else { return }
        let line = "[\(fmt.string(from: Date()))] \(msg())\n"
        guard let data = line.data(using: .utf8) else { return }
        if let h = FileHandle(forWritingAtPath: path) {
            defer { try? h.close() }
            _ = try? h.seekToEnd()
            try? h.write(contentsOf: data)
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
