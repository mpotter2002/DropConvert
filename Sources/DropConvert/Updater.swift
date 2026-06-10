import Foundation
import AppKit

/// Handles the in-app update flow:
/// 1. Download DMG to temp dir (with progress)
/// 2. Mount it via hdiutil
/// 3. Replace the running app bundle in /Applications
/// 4. Relaunch the new version
@MainActor
final class Updater: ObservableObject {
    enum Phase: Equatable {
        case idle
        case downloading(progress: Double)
        case installing
        case relaunching
        case failed(String)
    }

    @Published var phase: Phase = .idle

    func installUpdate(from url: URL) {
        phase = .downloading(progress: 0)
        Task {
            do {
                let dmgURL = try await download(from: url)
                phase = .installing
                let mountPoint = try mount(dmg: dmgURL)
                defer { _ = try? unmount(mountPoint: mountPoint) }
                try replaceApp(from: mountPoint)
                phase = .relaunching
                try relaunchApp()
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Download

    private func download(from url: URL) async throws -> URL {
        let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UpdateError.downloadFailed("HTTP error")
        }
        let total = response.expectedContentLength
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DropConvert-update-\(UUID().uuidString).dmg")
        FileManager.default.createFile(atPath: tmpURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tmpURL)
        defer { try? handle.close() }

        var received: Int64 = 0
        var buffer = Data()
        buffer.reserveCapacity(64 * 1024)
        var lastReport: Double = 0

        for try await byte in asyncBytes {
            buffer.append(byte)
            if buffer.count >= 64 * 1024 {
                try handle.write(contentsOf: buffer)
                received += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                if total > 0 {
                    let p = Double(received) / Double(total)
                    if p - lastReport > 0.01 {
                        lastReport = p
                        await MainActor.run { self.phase = .downloading(progress: p) }
                    }
                }
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
        }
        try handle.close()
        await MainActor.run { self.phase = .downloading(progress: 1.0) }
        return tmpURL
    }

    // MARK: - Mount / Unmount

    private func mount(dmg: URL) throws -> URL {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        task.arguments = ["attach", "-nobrowse", "-quiet", "-mountrandom", "/tmp", dmg.path]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            throw UpdateError.mountFailed
        }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        // hdiutil prints lines like: /dev/disk4s1  Apple_HFS  /tmp/dmg.XXXXXX/DropConvert
        // Pick the last whitespace-separated path that starts with "/tmp/" or "/Volumes/"
        for line in output.split(separator: "\n").reversed() {
            let parts = line.split(separator: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
            if let last = parts.last, last.hasPrefix("/") {
                return URL(fileURLWithPath: last)
            }
        }
        throw UpdateError.mountFailed
    }

    private func unmount(mountPoint: URL) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        task.arguments = ["detach", "-quiet", "-force", mountPoint.path]
        try task.run()
        task.waitUntilExit()
    }

    // MARK: - Replace app

    private func replaceApp(from mountPoint: URL) throws {
        let newApp = mountPoint.appendingPathComponent("DropConvert.app")
        guard FileManager.default.fileExists(atPath: newApp.path) else {
            throw UpdateError.installFailed("DropConvert.app not found in DMG")
        }

        let currentApp = URL(fileURLWithPath: Bundle.main.bundlePath)
        let targetApp = currentApp

        let fm = FileManager.default
        let backupApp = targetApp.deletingLastPathComponent()
            .appendingPathComponent("DropConvert.app.old-\(UUID().uuidString)")

        // Move running app aside (allowed even while it's running, since the
        // process keeps its open file handles via inode references)
        if fm.fileExists(atPath: targetApp.path) {
            try fm.moveItem(at: targetApp, to: backupApp)
        }

        do {
            try fm.copyItem(at: newApp, to: targetApp)
        } catch {
            // Roll back
            try? fm.moveItem(at: backupApp, to: targetApp)
            throw UpdateError.installFailed(error.localizedDescription)
        }

        // Strip the quarantine attribute so Gatekeeper doesn't prompt on relaunch
        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-dr", "com.apple.quarantine", targetApp.path]
        try? xattr.run()
        xattr.waitUntilExit()

        // Best-effort cleanup of the old bundle
        try? fm.removeItem(at: backupApp)
    }

    // MARK: - Relaunch

    private func relaunchApp() throws {
        let appURL = URL(fileURLWithPath: Bundle.main.bundlePath)
        let pid = ProcessInfo.processInfo.processIdentifier

        // Spawn a detached shell that waits for us to exit, then launches the new app
        let script = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        /usr/bin/open "\(appURL.path)"
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script]
        try task.run()

        // Give the shell a moment to start, then quit
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }
}

enum UpdateError: LocalizedError {
    case downloadFailed(String)
    case mountFailed
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let msg): return "Download failed: \(msg)"
        case .mountFailed:             return "Could not mount the update."
        case .installFailed(let msg):  return "Install failed: \(msg)"
        }
    }
}
