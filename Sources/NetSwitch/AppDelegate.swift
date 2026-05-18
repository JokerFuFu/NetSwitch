import AppKit
import NetSwitchCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let switcher = NetworkSwitcher()
    private let targets = [
        NetworkTarget(id: "wifi", displayName: "Wi-Fi", serviceName: "Wi-Fi", kind: .wiFi),
        NetworkTarget(id: "f50-pro", displayName: "F50 Pro", serviceName: "F50 Pro", kind: .wired)
    ]
    private var isSwitching = false

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

        let snapshot = try? switcher.snapshot(for: targets)
        let activeTargets = snapshot?.activeTargets(from: targets) ?? []
        updateStatusButton(activeTargets: activeTargets)

        let currentItem = NSMenuItem(title: statusTitle(for: activeTargets, snapshot: snapshot), action: nil, keyEquivalent: "")
        currentItem.isEnabled = false
        menu.addItem(currentItem)

        if let ssid = snapshot?.currentSSID, activeTargets.contains(where: { $0.kind == .wiFi }) {
            let ssidItem = NSMenuItem(title: "Wi-Fi SSID: \(ssid)", action: nil, keyEquivalent: "")
            ssidItem.isEnabled = false
            menu.addItem(ssidItem)
        }

        menu.addItem(.separator())

        for target in targets {
            let item = NSMenuItem(title: menuTitle(for: target, snapshot: snapshot), action: #selector(selectTarget(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = target.id
            item.state = activeTargets.contains(target) ? .on : .off
            item.isEnabled = !isSwitching
            menu.addItem(item)
        }

        if isSwitching {
            menu.addItem(.separator())
            let switchingItem = NSMenuItem(title: "Switching...", action: nil, keyEquivalent: "")
            switchingItem.isEnabled = false
            menu.addItem(switchingItem)
        }

        menu.addItem(.separator())
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshMenu), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.isEnabled = !isSwitching
        menu.addItem(refreshItem)

        let quitItem = NSMenuItem(title: "Quit NetSwitch", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateStatusButton(activeTargets: [NetworkTarget]) {
        guard let button = statusItem.button else { return }

        if activeTargets.count == 1 {
            let target = activeTargets[0]
            button.title = " \(target.displayName)"
            button.image = NSImage(systemSymbolName: target.kind == .wiFi ? "wifi" : "cable.connector", accessibilityDescription: target.displayName)
        } else if activeTargets.isEmpty {
            button.title = " Offline"
            button.image = NSImage(systemSymbolName: "network.slash", accessibilityDescription: "No active network")
        } else {
            button.title = " Mixed"
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Multiple active networks")
        }
        button.image?.isTemplate = true
        button.toolTip = "NetSwitch"
    }

    private func statusTitle(for activeTargets: [NetworkTarget], snapshot: NetworkSnapshot?) -> String {
        if activeTargets.count == 1 {
            return "Active: \(activeTargets[0].displayName)"
        }
        if activeTargets.isEmpty {
            return snapshot == nil ? "Active: Unable to read network state" : "Active: None"
        }
        return "Active: \(activeTargets.map(\.displayName).joined(separator: " + "))"
    }

    private func menuTitle(for target: NetworkTarget, snapshot: NetworkSnapshot?) -> String {
        let state = snapshot?.state(for: target.serviceName)
        let detail: String

        if state?.isActive == true, let ipAddress = state?.ipAddress {
            detail = ipAddress
        } else if state?.isEnabled == false {
            detail = "Off"
        } else {
            detail = "Ready"
        }

        return "\(target.displayName)  \(detail)"
    }

    @objc private func selectTarget(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let target = targets.first(where: { $0.id == id }) else { return }
        isSwitching = true
        rebuildMenu()
        let switcher = switcher
        let targets = targets

        Task.detached(priority: .userInitiated) {
            do {
                try switcher.switchToTarget(target, among: targets)
                await MainActor.run {
                    self.isSwitching = false
                    self.rebuildMenu()
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run {
                    self.isSwitching = false
                    self.rebuildMenu()
                    self.showError(message, target: target)
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

    private func showError(_ message: String, target: NetworkTarget) {
        let alert = NSAlert()
        alert.messageText = "Could not switch to \(target.displayName)"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
