import Foundation
import AppKit

let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
let githubRepo = "lifedever/health-tick-release"

private var isAppleSilicon: Bool {
    var sysinfo = utsname()
    uname(&sysinfo)
    let machine = withUnsafePointer(to: &sysinfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
    }
    return machine.hasPrefix("arm64")
}

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var latestVersion: String?
    @Published var downloadURL: String?
    @Published var isChecking = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var hasUpdate = false
    @Published var checkError: String?

    private var downloadTask: URLSessionDownloadTask?

    func check(silent: Bool = false) {
        guard !isChecking else { return }
        isChecking = true
        checkError = nil

        let urlStr = "https://github.com/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlStr) else {
            isChecking = false
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        // Use a session that doesn't follow redirects to extract version from redirect URL
        let delegate = RedirectBlocker()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        session.dataTask(with: request) { [weak self] _, response, error in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isChecking = false

                if let error {
                    if !silent { self.checkError = L.networkError(error.localizedDescription) }
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      let location = httpResponse.value(forHTTPHeaderField: "Location"),
                      let tagRange = location.range(of: "/tag/") else {
                    if !silent { self.showNoUpdateAlert() }
                    return
                }

                let tag = String(location[tagRange.upperBound...])
                let remote = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                self.latestVersion = remote

                let platformKey = isAppleSilicon ? "Apple-Silicon" : "Intel"
                self.downloadURL = "https://github.com/\(githubRepo)/releases/download/\(tag)/HealthTick-\(tag)-\(platformKey).dmg"

                if self.compareVersions(remote, isNewerThan: appVersion) {
                    self.hasUpdate = true
                    if !silent { self.showUpdateAlert(version: remote) }
                } else {
                    if !silent { self.showNoUpdateAlert() }
                }
            }
        }.resume()
    }

    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = L.noUpdateTitle
        alert.informativeText = L.noUpdateMsg(appVersion)
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showUpdateAlertPublic() {
        // Re-check to ensure we have the latest version before showing alert
        check(silent: false)
    }

    private func showUpdateAlert(version: String) {
        let arch = isAppleSilicon ? "Apple Silicon" : "Intel"
        let alert = NSAlert()
        alert.messageText = L.newVersionFound
        alert.informativeText = L.updateInfo(version: version, currentVersion: appVersion, arch: arch)
        alert.alertStyle = .informational
        alert.addButton(withTitle: L.downloadNow)
        alert.addButton(withTitle: L.laterAction)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            startDownload()
        }
    }

    private func startDownload() {
        guard let urlStr = downloadURL, let url = URL(string: urlStr) else { return }
        isDownloading = true
        downloadProgress = 0

        let delegate = DownloadDelegate { [weak self] progress in
            Task { @MainActor [weak self] in
                self?.downloadProgress = progress
            }
        } onComplete: { [weak self] tempURL, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isDownloading = false
                if let error {
                    self.checkError = L.downloadFailed(error.localizedDescription)
                    return
                }
                guard let tempURL else { return }

                let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                let fileName = url.lastPathComponent
                let dest = downloads.appendingPathComponent(fileName)

                try? FileManager.default.removeItem(at: dest)
                do {
                    try FileManager.default.moveItem(at: tempURL, to: dest)
                    self.showDownloadComplete(file: dest)
                } catch {
                    self.checkError = L.saveFailed(error.localizedDescription)
                }
            }
        }

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    private func showDownloadComplete(file: URL) {
        let alert = NSAlert()
        alert.messageText = L.downloadComplete
        alert.informativeText = L.downloadCompleteMsg
        alert.alertStyle = .informational
        alert.addButton(withTitle: L.installAndQuit)
        alert.addButton(withTitle: L.installLater)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let resp = alert.runModal()
        if resp == .alertFirstButtonReturn {
            NSWorkspace.shared.open(file)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NSApp.terminate(nil)
            }
        }
    }

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
        // Block redirect so we can read the Location header
        completionHandler(nil)
    }
}

// MARK: - Download Delegate

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: (Double) -> Void
    let onComplete: (URL?, Error?) -> Void

    init(onProgress: @escaping (Double) -> Void, onComplete: @escaping (URL?, Error?) -> Void) {
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".dmg")
        try? FileManager.default.copyItem(at: location, to: tmp)
        onComplete(tmp, nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { onComplete(nil, error) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }
}
