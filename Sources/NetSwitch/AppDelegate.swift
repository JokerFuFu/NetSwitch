import AppKit
import NetSwitchCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let switcher = NetworkSwitcher()
    private let preferences = NetworkPreferences()
    private var isSwitching = false
    private var refreshTask: Task<Void, Never>?
    private var autoTask: Task<Void, Never>?
    private var settingsWindowController: SettingsWindowController?
    private var guideWindowController: GuideWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        rebuildMenu()
        startAutoMonitor()
        NotificationCenter.default.addObserver(forName: .netSwitchSettingsChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildMenu()
                self?.startAutoMonitor()
            }
        }
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

        let services = (try? switcher.discoverServices()) ?? []
        let targets = preferences.targetServices(from: services, switcher: switcher)
        let snapshot = try? switcher.snapshot(for: targets)
        let activeTargets = snapshot?.activeTargets(from: targets) ?? []
        updateStatusButton(activeTargets: activeTargets)

        let currentItem = NSMenuItem(title: statusTitle(for: activeTargets, snapshot: snapshot), action: nil, keyEquivalent: "")
        currentItem.image = menuIcon("dot.radiowaves.left.and.right")
        currentItem.isEnabled = false
        menu.addItem(currentItem)

        if let ssid = snapshot?.currentSSID, activeTargets.contains(where: { $0.kind == .wiFi }) {
            let ssidItem = NSMenuItem(title: "Wi-Fi SSID: \(ssid)", action: nil, keyEquivalent: "")
            ssidItem.image = menuIcon("wifi")
            ssidItem.isEnabled = false
            menu.addItem(ssidItem)
        }

        menu.addItem(.separator())

        if targets.isEmpty {
            let setupItem = NSMenuItem(title: "No network targets found", action: nil, keyEquivalent: "")
            setupItem.image = menuIcon("exclamationmark.triangle")
            setupItem.isEnabled = false
            menu.addItem(setupItem)
        }

        for target in targets {
            let item = NSMenuItem(title: menuTitle(for: target, snapshot: snapshot), action: #selector(selectTarget(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = target.id
            item.state = activeTargets.contains(target) ? .on : .off
            item.image = menuIcon(target.kind == .wiFi ? "wifi" : "cable.connector")
            item.isEnabled = !isSwitching
            menu.addItem(item)
        }

        if targets.contains(where: { $0.kind == .wired }) == false {
            let wiredItem = NSMenuItem(title: "No wired service found", action: nil, keyEquivalent: "")
            wiredItem.image = menuIcon("cable.connector.slash")
            wiredItem.isEnabled = false
            menu.addItem(wiredItem)
        }

        if isSwitching {
            menu.addItem(.separator())
            let switchingItem = NSMenuItem(title: "Switching...", action: nil, keyEquivalent: "")
            switchingItem.image = menuIcon("arrow.triangle.2.circlepath")
            switchingItem.isEnabled = false
            menu.addItem(switchingItem)
        }

        menu.addItem(.separator())
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshMenu), keyEquivalent: "r")
        refreshItem.target = self
        refreshItem.image = menuIcon("arrow.clockwise")
        refreshItem.isEnabled = !isSwitching
        menu.addItem(refreshItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = menuIcon("gearshape")
        menu.addItem(settingsItem)

        let guideItem = NSMenuItem(title: "How to Use", action: #selector(openGuide), keyEquivalent: "?")
        guideItem.target = self
        guideItem.image = menuIcon("questionmark.circle")
        menu.addItem(guideItem)

        let quitItem = NSMenuItem(title: "Quit NetSwitch", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        quitItem.image = menuIcon("power")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func updateStatusButton(activeTargets: [NetworkTarget]) {
        guard let button = statusItem.button else { return }

        if activeTargets.count == 1 {
            let target = activeTargets[0]
            button.title = target.kind == .wiFi ? " Wi-Fi" : " Wired"
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
            let activeTarget = activeTargets[0]
            return "Active: \(activeTarget.kind == .wiFi ? "Wi-Fi" : "Wired")"
        }
        if activeTargets.isEmpty {
            return snapshot == nil ? "Active: Unable to read network state" : "Active: None"
        }
        return "Active: \(activeTargets.map(\.displayName).joined(separator: " + "))"
    }

    private func menuTitle(for target: NetworkTarget, snapshot: NetworkSnapshot?) -> String {
        let state = snapshot?.state(for: target.serviceName)
        let detail: String

        if state?.isEnabled == false {
            detail = "Off"
        } else if let ipAddress = state?.ipAddress {
            if target.kind == .wiFi, snapshot?.currentSSID == nil {
                detail = "On, not connected"
            } else {
                detail = ipAddress
            }
        } else if target.kind == .wiFi, snapshot?.currentSSID != nil {
            detail = "Connected, waiting for IP"
        } else if target.kind == .wiFi {
            detail = "On, not connected"
        } else {
            detail = "Connecting"
        }

        return "\(target.displayName)  \(detail)"
    }

    private func menuIcon(_ name: String) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        image?.isTemplate = true
        image?.size = NSSize(width: 16, height: 16)
        return image
    }

    @objc private func selectTarget(_ sender: NSMenuItem) {
        let services = (try? switcher.discoverServices()) ?? []
        let targets = preferences.targetServices(from: services, switcher: switcher)
        guard let id = sender.representedObject as? String, let target = targets.first(where: { $0.id == id }) else { return }
        switchTarget(target, among: targets)
    }

    private func switchTarget(_ target: NetworkTarget, among targets: [NetworkTarget]) {
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
                    self.refreshUntilSettled(preferredTarget: target, among: targets)
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

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(switcher: switcher)
        }
        settingsWindowController?.reload()
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openGuide() {
        if guideWindowController == nil {
            guideWindowController = GuideWindowController()
        }
        guideWindowController?.showWindow(nil)
        guideWindowController?.window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        refreshTask?.cancel()
        autoTask?.cancel()
        NSApp.terminate(nil)
    }

    private func refreshUntilSettled(preferredTarget: NetworkTarget, among targets: [NetworkTarget]) {
        refreshTask?.cancel()
        let switcher = switcher

        refreshTask = Task { [weak self] in
            for _ in 0..<12 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }

                let snapshot = try? switcher.snapshot(for: targets)
                await MainActor.run {
                    self?.rebuildMenu()
                }

                if preferredTarget.kind == .wired, let wiFiTarget = targets.first(where: { $0.kind == .wiFi }) {
                    try? switcher.disconnectWiFiKeepingPower(serviceName: wiFiTarget.serviceName)
                }

                if let snapshot, self?.hasIPAddress(for: preferredTarget, in: snapshot) == true {
                    return
                }
            }
        }
    }

    private nonisolated func hasIPAddress(for target: NetworkTarget, in snapshot: NetworkSnapshot) -> Bool {
        snapshot.state(for: target.serviceName)?.ipAddress != nil
    }

    private func startAutoMonitor() {
        autoTask?.cancel()
        guard preferences.autoMode else { return }
        let switcher = switcher

        autoTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await MainActor.run {
                    self?.evaluateAutoMode(switcher: switcher)
                }
            }
        }
    }

    private func evaluateAutoMode(switcher: NetworkSwitcher) {
        guard !isSwitching else { return }

        let services = (try? switcher.discoverServices()) ?? []
        let targets = preferences.targetServices(from: services, switcher: switcher)
        guard targets.count > 1, let snapshot = try? switcher.snapshot(for: targets) else {
            return
        }

        let activeTargets = snapshot.activeTargets(from: targets)
        let wiFiTarget = targets.first { $0.kind == .wiFi }
        let wiredTarget = targets.first { $0.kind == .wired }
        let desired: NetworkTarget?

        switch preferences.autoPriority {
        case .wired:
            if let wiredTarget, snapshot.state(for: wiredTarget.serviceName)?.ipAddress != nil {
                desired = wiredTarget
            } else {
                desired = wiFiTarget
            }
        case .wiFi:
            if snapshot.currentSSID != nil {
                desired = wiFiTarget
            } else if let wiredTarget, snapshot.state(for: wiredTarget.serviceName)?.ipAddress != nil {
                desired = wiredTarget
            } else {
                desired = wiFiTarget
            }
        }

        guard let desired, activeTargets.contains(desired) == false else {
            return
        }
        switchTarget(desired, among: targets)
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
