import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        promptMoveToApplicationsIfNeeded()
        statusBarController = StatusBarController()
    }

    private func promptMoveToApplicationsIfNeeded() {
        let bundlePath = Bundle.main.bundlePath
        guard bundlePath.hasSuffix(".app"),
              !bundlePath.hasPrefix("/Applications"),
              !bundlePath.hasPrefix(NSHomeDirectory() + "/Applications")
        else { return }

        let alert = NSAlert()
        alert.messageText = "Move DropConvert to Applications?"
        alert.informativeText = "DropConvert works best when run from your Applications folder. Move it there now?"
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Keep in Current Location")
        alert.alertStyle = .informational

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let dest = "/Applications/DropConvert.app"
        let fm = FileManager.default

        // Remove existing copy if present
        try? fm.removeItem(atPath: dest)

        do {
            try fm.moveItem(atPath: bundlePath, toPath: dest)
            // Relaunch from new location
            let task = Process()
            task.launchPath = "/usr/bin/open"
            task.arguments = [dest]
            try? task.run()
            NSApplication.shared.terminate(nil)
        } catch {
            let err = NSAlert()
            err.messageText = "Could not move DropConvert"
            err.informativeText = error.localizedDescription
            err.runModal()
        }
    }
}
