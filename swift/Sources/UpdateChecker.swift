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

        let urlStr = "https://api.github.com/repos/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlStr) else {
            isChecking = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isChecking = false

                if let error {
                    if !silent { self.checkError = "网络错误: \(error.localizedDescription)" }
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String else {
                    if !silent { self.checkError = "当前已是最新版本 v\(appVersion)" }
                    return
                }

                let remote = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                self.latestVersion = remote

                // Find platform-specific .dmg asset
                let platformKey = isAppleSilicon ? "Apple-Silicon" : "Intel"
                if let assets = json["assets"] as? [[String: Any]] {
                    // First: match platform-specific DMG
                    for asset in assets {
                        if let name = asset["name"] as? String,
                           let url = asset["browser_download_url"] as? String,
                           name.hasSuffix(".dmg") && name.contains(platformKey) {
                            self.downloadURL = url
                            break
                        }
                    }
                    // Fallback: any DMG
                    if self.downloadURL == nil {
                        for asset in assets {
                            if let name = asset["name"] as? String,
                               let url = asset["browser_download_url"] as? String,
                               name.hasSuffix(".dmg") {
                                self.downloadURL = url
                                break
                            }
                        }
                    }
                }
                // Fallback to release page
                if self.downloadURL == nil, let htmlURL = json["html_url"] as? String {
                    self.downloadURL = htmlURL
                }

                if self.compareVersions(remote, isNewerThan: appVersion) {
                    self.hasUpdate = true
                    if !silent { self.showUpdateAlert(version: remote) }
                } else {
                    if !silent { self.checkError = "已是最新版本 v\(appVersion)" }
                }
            }
        }.resume()
    }

    func showUpdateAlertPublic() {
        guard let version = latestVersion else { return }
        showUpdateAlert(version: version)
    }

    private func showUpdateAlert(version: String) {
        let arch = isAppleSilicon ? "Apple Silicon" : "Intel"
        let alert = NSAlert()
        alert.messageText = "发现新版本"
        alert.informativeText = "HealthTick v\(version) 已发布（当前 v\(appVersion)）。\n将为你下载 \(arch) 版本到「下载」文件夹。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "立即下载")
        alert.addButton(withTitle: "稍后再说")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let resp = alert.runModal()
        NSApp.setActivationPolicy(.accessory)
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
                    self.checkError = "下载失败: \(error.localizedDescription)"
                    return
                }
                guard let tempURL else { return }

                // Move to Downloads folder
                let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
                let fileName = url.lastPathComponent
                let dest = downloads.appendingPathComponent(fileName)

                try? FileManager.default.removeItem(at: dest)
                do {
                    try FileManager.default.moveItem(at: tempURL, to: dest)
                    self.showDownloadComplete(file: dest)
                } catch {
                    self.checkError = "保存失败: \(error.localizedDescription)"
                }
            }
        }

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    private func showDownloadComplete(file: URL) {
        let alert = NSAlert()
        alert.messageText = "下载完成"
        alert.informativeText = "已保存到「下载」文件夹。\n请打开 DMG 文件并将 HealthTick 拖入 Applications 替换旧版本。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开 DMG")
        alert.addButton(withTitle: "稍后安装")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let resp = alert.runModal()
        NSApp.setActivationPolicy(.accessory)
        if resp == .alertFirstButtonReturn {
            NSWorkspace.shared.open(file)
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

// MARK: - Download Delegate

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let onProgress: (Double) -> Void
    let onComplete: (URL?, Error?) -> Void

    init(onProgress: @escaping (Double) -> Void, onComplete: @escaping (URL?, Error?) -> Void) {
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Copy to temp so it survives delegate callback
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
