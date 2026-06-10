import Foundation
import AppKit

/// Runs a background update check on launch and every 24 hours.
/// Posts a notification to NotificationCenter when an update is available so
/// any live UI (StatusBarController, SettingsView) can react without coupling.
final class UpdateChecker {
    static let shared = UpdateChecker()

    /// Posted on the main actor when a newer version is found.
    /// userInfo: ["version": String, "downloadURL": URL]
    static let updateAvailableNotification = Notification.Name("DropConvertUpdateAvailable")

    private let versionURL = URL(string: "https://dropconvert.app/version.json")!
    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private var timer: Timer?

    /// Latest available update info, persisted in memory for the session.
    private(set) var availableVersion: String?
    private(set) var availableDownloadURL: URL?

    private init() {}

    func startChecking() {
        // Check immediately on launch (after a short delay so the app is fully up)
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            await checkNow()
        }
        // Then every 24 hours
        timer = Timer.scheduledTimer(withTimeInterval: 86_400, repeats: true) { [weak self] _ in
            Task { await self?.checkNow() }
        }
    }

    func checkNow() async {
        guard let (data, _) = try? await URLSession.shared.data(from: versionURL),
              let info = try? JSONDecoder().decode(VersionInfo.self, from: data),
              isNewer(info.version, than: currentVersion),
              let url = URL(string: info.url)
        else { return }

        availableVersion = info.version
        availableDownloadURL = url

        NotificationCenter.default.post(
            name: UpdateChecker.updateAvailableNotification,
            object: nil,
            userInfo: ["version": info.version, "downloadURL": url]
        )
    }

    private func isNewer(_ remote: String, than local: String) -> Bool {
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
