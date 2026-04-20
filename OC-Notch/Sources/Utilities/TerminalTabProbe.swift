import Foundation
import os

private let logger = Logger(subsystem: "com.oc-notch.app", category: "TerminalTabProbe")

enum TerminalTabProbe {
    private static let fieldSeparator = "\u{1f}"
    private static let recordSeparator = "\u{1e}"

    static func snapshot() async -> [TerminalTab] {
        await withTaskGroup(of: [TerminalTab].self) { group in
            group.addTask { snapshotiTerm() }
            group.addTask { snapshotGhostty() }
            group.addTask { snapshotAppleTerminal() }

            var results: [TerminalTab] = []
            for await tabs in group {
                results.append(contentsOf: tabs)
            }
            return results
        }
    }

    // MARK: - iTerm2

    private static func snapshotiTerm() -> [TerminalTab] {
        let sep = fieldSeparator
        let rec = recordSeparator
        let script = """
            tell application "System Events"
                if not (exists process "iTerm2") then return ""
            end tell
            tell application "iTerm"
                set output to ""
                repeat with w in windows
                    repeat with t in tabs of w
                        repeat with s in sessions of t
                            set sid to (id of s as text)
                            set stty to (tty of s as text)
                            set sname to (name of s as text)
                            set output to output & sid & "\(sep)" & stty & "\(sep)" & sname & "\(rec)"
                        end repeat
                    end repeat
                end repeat
                return output
            end tell
            """

        guard let output = runAppleScript(script), output.isEmpty == false else { return [] }

        var tabs: [TerminalTab] = []
        for record in output.split(separator: Character(rec)) {
            let fields = record.split(separator: Character(sep), omittingEmptySubsequences: false)
            guard fields.count >= 3 else { continue }

            let sessionID = String(fields[0])
            let tty = String(fields[1])
            let title = String(fields[2])

            guard tty.isEmpty == false else { continue }

            tabs.append(TerminalTab(
                bundleID: "com.googlecode.iterm2",
                sessionID: sessionID.isEmpty ? nil : sessionID,
                tty: tty.hasPrefix("/dev/") ? tty : "/dev/\(tty)",
                title: title.isEmpty ? nil : title
            ))
        }

        logger.notice("iTerm probe: found \(tabs.count) sessions")
        return tabs
    }

    // MARK: - Ghostty

    private static func snapshotGhostty() -> [TerminalTab] {
        let sep = fieldSeparator
        let rec = recordSeparator
        let script = """
            tell application "System Events"
                if not (exists process "Ghostty") then return ""
            end tell
            tell application "Ghostty"
                set output to ""
                repeat with w in windows
                    set wName to name of w
                    set output to output & wName & "\(rec)"
                end repeat
                return output
            end tell
            """

        guard let output = runAppleScript(script), output.isEmpty == false else { return [] }

        var tabs: [TerminalTab] = []
        for record in output.split(separator: Character(rec)) {
            let name = String(record)
            guard name.isEmpty == false else { continue }

            // Ghostty window names often contain the TTY (e.g. "user@host: /path — ttys003")
            let tty = extractTTY(from: name)
            guard let tty else { continue }

            tabs.append(TerminalTab(
                bundleID: "com.mitchellh.ghostty",
                sessionID: nil,
                tty: tty,
                title: name
            ))
        }

        logger.notice("Ghostty probe: found \(tabs.count) windows")
        return tabs
    }

    // MARK: - Apple Terminal

    private static func snapshotAppleTerminal() -> [TerminalTab] {
        let sep = fieldSeparator
        let rec = recordSeparator
        let script = """
            tell application "System Events"
                if not (exists process "Terminal") then return ""
            end tell
            tell application "Terminal"
                set output to ""
                repeat with w in windows
                    repeat with t in tabs of w
                        set tabTTY to (tty of t as text)
                        set tabTitle to (custom title of t as text)
                        set output to output & tabTTY & "\(sep)" & tabTitle & "\(rec)"
                    end repeat
                end repeat
                return output
            end tell
            """

        guard let output = runAppleScript(script), output.isEmpty == false else { return [] }

        var tabs: [TerminalTab] = []
        for record in output.split(separator: Character(rec)) {
            let fields = record.split(separator: Character(sep), omittingEmptySubsequences: false)
            guard fields.count >= 2 else { continue }

            let tty = String(fields[0])
            let title = String(fields[1])
            guard tty.isEmpty == false else { continue }

            tabs.append(TerminalTab(
                bundleID: "com.apple.Terminal",
                sessionID: nil,
                tty: tty.hasPrefix("/dev/") ? tty : "/dev/\(tty)",
                title: title.isEmpty ? nil : title
            ))
        }

        logger.notice("Terminal probe: found \(tabs.count) tabs")
        return tabs
    }

    // MARK: - Helpers

    private static func extractTTY(from windowName: String) -> String? {
        let pattern = #"ttys\d+"#
        guard let range = windowName.range(of: pattern, options: .regularExpression) else { return nil }
        return "/dev/\(windowName[range])"
    }

    private static func runAppleScript(_ source: String) -> String? {
        let task = Process()
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", source]
        task.standardOutput = outPipe
        task.standardError = errPipe

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus != 0 {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr = String(data: errData, encoding: .utf8) ?? ""
                logger.debug("AppleScript probe failed: \(errStr)")
                return nil
            }

            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            logger.debug("Failed to run probe osascript: \(error)")
            return nil
        }
    }
}
