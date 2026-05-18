import AppKit
import NetSwitchCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let switcher = NetworkSwitcher()
    private let networks = ["Wi-Fi", "F50 Pro"]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        rebuildMenu()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        if let image = NSImage(systemSymbolName: "wifi", accessibilityDescription: "NetSwitch") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "NetSwitch"
        }
        button.toolTip = "NetSwitch"
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let currentSSID = try? switcher.currentSSID()
        let currentItem = NSMenuItem(title: currentSSID.map { "Current: \($0)" } ?? "Current: Unknown", action: nil, keyEquivalent: "")
        currentItem.isEnabled = false
        menu.addItem(currentItem)
        menu.addItem(.separator())

        for ssid in networks {
            let item = NSMenuItem(title: ssid, action: #selector(selectNetwork(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = ssid
            item.state = currentSSID == ssid ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshMenu), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let quitItem = NSMenuItem(title: "Quit NetSwitch", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func selectNetwork(_ sender: NSMenuItem) {
        guard let ssid = sender.representedObject as? String else { return }
        setMenuEnabled(false)
        let switcher = switcher

        Task.detached(priority: .userInitiated) {
            do {
                try switcher.switchToNetwork(named: ssid)
                await MainActor.run {
                    self.rebuildMenu()
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run {
                    self.rebuildMenu()
                    self.showError(message, ssid: ssid)
                }
            }
        }
    }

    @objc private func refreshMenu() {
        rebuildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func setMenuEnabled(_ enabled: Bool) {
        statusItem.menu?.items.forEach { item in
            if item.action == #selector(selectNetwork(_:)) {
                item.isEnabled = enabled
            }
        }
    }

    private func showError(_ message: String, ssid: String) {
        let alert = NSAlert()
        alert.messageText = "Could not switch to \(ssid)"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
