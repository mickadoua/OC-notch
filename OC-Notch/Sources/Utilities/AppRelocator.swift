import AppKit
import os

private let logger = Logger(subsystem: "com.oc-notch.app", category: "AppRelocator")

enum AppRelocator {

    @MainActor
    static func moveToApplicationsIfNeeded() {
        let bundlePath = Bundle.main.bundlePath

        if bundlePath.hasPrefix("/Applications/")
            || bundlePath.hasPrefix(NSHomeDirectory() + "/Applications/")
        {
            return
        }

        if bundlePath.contains("/DerivedData/") || bundlePath.contains("/Build/Products/") {
            logger.info("Skipping relocation: Xcode build directory")
            return
        }

        logger.info("App running from non-standard location: \(bundlePath)")

        let alert = NSAlert()
        alert.messageText = "Move to Applications folder?"
        alert.informativeText = "OC-Notch should be in your Applications folder for automatic updates to work correctly."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")

        guard alert.runModal() == .alertFirstButtonReturn else {
            logger.info("User declined app relocation")
            return
        }

        let appName = Bundle.main.bundleURL.lastPathComponent
        let destination = "/Applications/\(appName)"
        let fm = FileManager.default

        do {
            if fm.fileExists(atPath: destination) {
                try fm.removeItem(atPath: destination)
            }

            // copyItem (not move) — source may be on a read-only DMG volume
            try fm.copyItem(atPath: bundlePath, toPath: destination)
            logger.info("App installed to \(destination)")

            // Silently fails on read-only DMG — expected
            try? fm.trashItem(at: Bundle.main.bundleURL, resultingItemURL: nil)

            relaunch(from: destination)
        } catch {
            logger.error("Failed to move app: \(error)")

            let errAlert = NSAlert()
            errAlert.messageText = "Could Not Move App"
            errAlert.informativeText =
                "Please drag OC-Notch to your Applications folder manually.\n\n\(error.localizedDescription)"
            errAlert.alertStyle = .warning
            errAlert.addButton(withTitle: "OK")
            errAlert.runModal()
        }
    }

    @MainActor
    private static func relaunch(from path: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.5; open \"\(path)\""]
        try? task.run()
        NSApp.terminate(nil)
    }
}
