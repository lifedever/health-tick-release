import Foundation
import AppKit

let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
let githubRepo = "lifedever/health-tick-release"
let giteeRepo = "lifedever/health-tick-release"

private var isAppleSilicon: Bool {
    var sysinfo = utsname()
    uname(&sysinfo)
    let machine = withUnsafePointer(to: &sysinfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
    }
    return machine.hasPrefix("arm64")
}

private let platformKey = isAppleSilicon ? "Apple-Silicon" : "Intel"

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var latestVersion: String?
    @Published var releaseNotes: String?
    @Published var downloadURL: String?
    @Published var fallbackDownloadURL: String?
    @Published var isChecking = false
    @Published var hasUpdate = false
    @Published var checkError: String?

    // Download state
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var downloadComplete = false
    @Published var downloadedFileURL: URL?

    // UI state
    @Published var showUpdateDialog = false

    private var downloadTask: URLSessionDownloadTask?
    private var downloadDelegate: UpdateDownloadDelegate?

    func check(silent: Bool = false) {
        guard !isChecking else { return }
        isChecking = true
        checkError = nil
        checkFromGitee(silent: silent)
    }

    func skipVersion() {
        if let ver = latestVersion {
            UserDefaults.standard.set(ver, forKey: "skippedVersion")
        }
        hasUpdate = false
        showUpdateDialog = false
    }

    func showUpdateAlertPublic() {
        if hasUpdate {
            showUpdateDialog = true
        } else {
            check(silent: false)
        }
    }

    // MARK: - Gitee (Primary)

    private func checkFromGitee(silent: Bool) {
        let urlStr = "https://gitee.com/api/v5/repos/\(giteeRepo)/releases/latest"
        guard let url = URL(string: urlStr) else {
            checkFromGitHub(silent: silent)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }

                guard error == nil,
                      let data,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    self.checkFromGitHub(silent: silent)
                    return
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    self.checkFromGitHub(silent: silent)
                    return
                }

                let remote = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                self.latestVersion = remote
                self.releaseNotes = json["body"] as? String

                let dmgName = "HealthTick-\(tagName)-\(platformKey).dmg"
                var giteeDownloadURL: String?
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String, name == dmgName,
                           let browserURL = asset["browser_download_url"] as? String {
                            giteeDownloadURL = browserURL
                            if let size = asset["size"] as? Int {
                                self.totalBytes = Int64(size)
                            }
                            break
                        }
                    }
                }

                if giteeDownloadURL == nil {
                    giteeDownloadURL = "https://gitee.com/\(giteeRepo)/releases/download/\(tagName)/\(dmgName)"
                }

                // Use GitHub as primary download (more reliable for binary files)
                self.downloadURL = "https://github.com/\(githubRepo)/releases/download/\(tagName)/\(dmgName)"
                self.fallbackDownloadURL = giteeDownloadURL

                self.handleCheckResult(remote: remote, silent: silent)
            }
        }.resume()
    }

    // MARK: - GitHub (Fallback)

    private func checkFromGitHub(silent: Bool) {
        let urlStr = "https://api.github.com/repos/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlStr) else {
            isChecking = false
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }

                guard error == nil,
                      let data,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    self.isChecking = false
                    if !silent, let error { self.checkError = L.networkError(error.localizedDescription) }
                    return
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    self.isChecking = false
                    return
                }

                let remote = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                self.latestVersion = remote
                self.releaseNotes = json["body"] as? String

                let dmgName = "HealthTick-\(tagName)-\(platformKey).dmg"
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String, name == dmgName,
                           let browserURL = asset["browser_download_url"] as? String {
                            self.downloadURL = browserURL
                            if let size = asset["size"] as? Int {
                                self.totalBytes = Int64(size)
                            }
                            break
                        }
                    }
                }
                if self.downloadURL == nil {
                    self.downloadURL = "https://github.com/\(githubRepo)/releases/download/\(tagName)/\(dmgName)"
                }
                self.fallbackDownloadURL = nil

                self.handleCheckResult(remote: remote, silent: silent)
            }
        }.resume()
    }

    private func handleCheckResult(remote: String, silent: Bool) {
        isChecking = false

        let skippedVersion = UserDefaults.standard.string(forKey: "skippedVersion")
        if !silent && remote == skippedVersion {
            // User-initiated check: ignore skip
        } else if silent && remote == skippedVersion {
            hasUpdate = false
            return
        }

        if compareVersions(remote, isNewerThan: appVersion) {
            hasUpdate = true
            showUpdateDialog = true
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        } else if !silent {
            showNoUpdateAlert()
        }
    }

    // MARK: - Download

    func downloadUpdate() {
        guard let urlStr = downloadURL, let url = URL(string: urlStr) else { return }
        isDownloading = true
        downloadProgress = 0
        downloadedBytes = 0
        downloadComplete = false
        downloadedFileURL = nil
        startDownloadFrom(url: url, isFallback: false)
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadSession?.invalidateAndCancel()
        downloadSession = nil
        isDownloading = false
        downloadProgress = 0
        downloadComplete = false
    }

    private var downloadSession: URLSession?

    private func startDownloadFrom(url: URL, isFallback: Bool) {
        // Invalidate previous session to prevent URLSession + delegate leak
        downloadSession?.invalidateAndCancel()
        downloadSession = nil

        let delegate = UpdateDownloadDelegate(
            onProgress: { [weak self] progress, received, total in
                Task { @MainActor in
                    self?.downloadProgress = progress
                    self?.downloadedBytes = received
                    self?.totalBytes = total
                }
            },
            onComplete: { [weak self] fileURL in
                Task { @MainActor in
                    self?.downloadSession?.finishTasksAndInvalidate()
                    self?.downloadSession = nil
                    self?.downloadComplete = true
                    self?.downloadedFileURL = fileURL
                    self?.isDownloading = false
                }
            },
            onError: { [weak self] error in
                Task { @MainActor in
                    guard let self else { return }
                    self.downloadSession?.invalidateAndCancel()
                    self.downloadSession = nil
                    // Try fallback
                    if !isFallback, let fallback = self.fallbackDownloadURL, let fallbackURL = URL(string: fallback) {
                        self.downloadProgress = 0
                        self.startDownloadFrom(url: fallbackURL, isFallback: true)
                        return
                    }
                    self.isDownloading = false
                    self.checkError = L.downloadFailed(error.localizedDescription)
                }
            }
        )
        self.downloadDelegate = delegate

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        downloadSession = session
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    // MARK: - Install

    func installAndRestart() {
        guard let fileURL = downloadedFileURL else { return }

        let destApp = Bundle.main.bundlePath
        let dmgPath = fileURL.path

        let script = """
        #!/bin/bash
        DMG_PATH="\(dmgPath)"
        DEST_APP="\(destApp)"
        APP_NAME="HealthTick"

        MOUNT_POINT=$(hdiutil attach "$DMG_PATH" -nobrowse -noverify 2>/dev/null | grep -o '/Volumes/[^\t]*' | head -1)

        if [ -z "$MOUNT_POINT" ]; then
            open "$DMG_PATH"
            exit 1
        fi

        SOURCE_APP="$MOUNT_POINT/$APP_NAME.app"

        if [ ! -d "$SOURCE_APP" ]; then
            hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null
            open "$DMG_PATH"
            exit 1
        fi

        sleep 2

        rm -rf "$DEST_APP"
        cp -R "$SOURCE_APP" "$DEST_APP"
        hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null
        open "$DEST_APP"
        rm -f "$0"
        """

        do {
            let scriptPath = NSTemporaryDirectory() + "healthtick_update.sh"
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptPath]
            try process.run()

            NSApp.terminate(nil)
        } catch {
            // Fallback: open the DMG manually
            NSWorkspace.shared.open(fileURL)
        }
    }

    // MARK: - UI

    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = L.noUpdateTitle
        alert.informativeText = L.noUpdateMsg(appVersion)
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Helpers

    private func compareVersions(_ remote: String, isNewerThan local: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let l = local.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, l.count) {
            let rv = i < r.count ? r[i] : 0
            let lv = i < l.count ? l[i] : 0
            if rv > lv { return true }
            if rv < lv { return false }
        }
        return false
    }
}

// MARK: - Redirect Blocker

private class RedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

// MARK: - Download Delegate

private final class UpdateDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: (Double, Int64, Int64) -> Void
    let onComplete: (URL) -> Void
    let onError: (Error) -> Void

    init(
        onProgress: @escaping (Double, Int64, Int64) -> Void,
        onComplete: @escaping (URL) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onProgress = onProgress
        self.onComplete = onComplete
        self.onError = onError
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("HealthTick-update.dmg")
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.moveItem(at: location, to: dest)
        onComplete(dest)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { onError(error) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let total = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : 1
        let progress = Double(totalBytesWritten) / Double(total)
        onProgress(progress, totalBytesWritten, totalBytesExpectedToWrite)
    }
}
