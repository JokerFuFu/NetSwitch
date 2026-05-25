import AppKit
import Darwin

let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.joker2.netswitch"
let existingApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    .filter { $0.processIdentifier != getpid() && !$0.isTerminated }

if let existingApp = existingApps.first {
    existingApp.activate(options: [])
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()

app.delegate = delegate
app.run()
