import Foundation
import AppKit

let appVersion = "1.0.0"
let githubRepo = "lifedever/health-tick-release"

@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published var latestVersion: String?
    @Published var downloadURL: String?
    @Published var isChecking = false
    @Published var hasUpdate = false
    @Published var checkError: String?

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

                // Find .dmg or .zip asset
                if let assets = json["assets"] as? [[String: Any]] {
                    for asset in assets {
                        if let name = asset["name"] as? String,
                           let url = asset["browser_download_url"] as? String,
                           name.hasSuffix(".dmg") || name.hasSuffix(".zip") {
                            self.downloadURL = url
                            break
                        }
                    }
                }
                // Fallback to html_url
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

    private func showUpdateAlert(version: String) {
        let alert = NSAlert()
        alert.messageText = "发现新版本"
        alert.informativeText = "HealthTick v\(version) 已发布，当前版本 v\(appVersion)。是否前往下载？"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "前往下载")
        alert.addButton(withTitle: "稍后再说")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let resp = alert.runModal()
        NSApp.setActivationPolicy(.accessory)
        if resp == .alertFirstButtonReturn, let urlStr = downloadURL, let url = URL(string: urlStr) {
            NSWorkspace.shared.open(url)
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
