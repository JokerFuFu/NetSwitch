import Foundation

struct LaunchAtLoginManager {
    private let fileManager = FileManager.default
    private let label = "com.joker2.netswitch"

    var plistURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    func enable(appPath: String = Bundle.main.bundlePath) throws {
        let directory = plistURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try plist(appPath: appPath).write(to: plistURL, atomically: true, encoding: .utf8)
        runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])
        runLaunchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
        runLaunchctl(["kickstart", "-k", "gui/\(getuid())/\(label)"])
    }

    func disable() {
        runLaunchctl(["bootout", "gui/\(getuid())", plistURL.path])
        try? fileManager.removeItem(at: plistURL)
    }

    func isUserAgentInstalled() -> Bool {
        fileManager.fileExists(atPath: plistURL.path)
    }

    private func plist(appPath: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
        \t<key>Label</key>
        \t<string>\(label)</string>
        \t<key>ProgramArguments</key>
        \t<array>
        \t\t<string>/usr/bin/open</string>
        \t\t<string>-a</string>
        \t\t<string>\(escape(appPath))</string>
        \t</array>
        \t<key>RunAtLoad</key>
        \t<true/>
        \t<key>LimitLoadToSessionType</key>
        \t<string>Aqua</string>
        </dict>
        </plist>
        """
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func runLaunchctl(_ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
