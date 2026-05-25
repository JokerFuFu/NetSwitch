import AppKit
import NetSwitchCore

@MainActor
final class SettingsWindowController: NSWindowController {
    private let preferences = NetworkPreferences()
    private let switcher: NetworkSwitcher
    private var services: [NetworkServiceDescriptor] = []

    private let wiFiPopup = NSPopUpButton()
    private let wiredPopup = NSPopUpButton()
    private let autoModeButton = NSButton(checkboxWithTitle: "Automatic mode", target: nil, action: nil)
    private let priorityControl = NSSegmentedControl(labels: ["Wired first", "Wi-Fi first"], trackingMode: .selectOne, target: nil, action: nil)
    private let statusLabel = DesignSystem.wrappedLabel("")

    init(switcher: NetworkSwitcher) {
        self.switcher = switcher
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 460), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "NetSwitch Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
        reload()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22)
        ])

        stack.addArrangedSubview(header())
        stack.addArrangedSubview(overview())
        stack.addArrangedSubview(section(icon: "wifi", title: "Wi-Fi Target", detail: "Used when switching back to wireless.", control: wiFiPopup))
        stack.addArrangedSubview(section(icon: "cable.connector", title: "Wired Target", detail: "Real Ethernet, USB LAN, or Thunderbolt Ethernet services are recommended.", control: wiredPopup))
        stack.addArrangedSubview(section(icon: "arrow.triangle.2.circlepath", title: "Automatic Mode", detail: "Let NetSwitch choose a target using your preferred priority.", control: autoModeButton))
        stack.addArrangedSubview(section(icon: "list.bullet.indent", title: "Auto Priority", detail: "Choose which connection should win when both are available.", control: priorityControl))
        stack.addArrangedSubview(statusLabel)

        wiFiPopup.target = self
        wiFiPopup.action = #selector(save)
        wiredPopup.target = self
        wiredPopup.action = #selector(save)
        autoModeButton.target = self
        autoModeButton.action = #selector(save)
        priorityControl.target = self
        priorityControl.action = #selector(save)
    }

    private func header() -> NSView {
        let icon = DesignSystem.iconBubble(symbol: "switch.2", tint: DesignSystem.accent, size: 28)
        let title = DesignSystem.label("Network Switching", size: 22, weight: .semibold)
        let detail = DesignSystem.wrappedLabel("Pick the services this Mac should use. NetSwitch remembers these choices locally.")

        let text = NSStackView(views: [title, detail])
        text.orientation = .vertical
        text.spacing = 4

        let stack = NSStackView(views: [icon, text])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 14
        return stack
    }

    private func overview() -> NSView {
        let cards = NSStackView(views: [
            miniCard(icon: "wifi", title: "Wi-Fi", detail: selectedServiceName(from: wiFiPopup) ?? "Auto detected", tint: DesignSystem.accent),
            miniCard(icon: "cable.connector", title: "Wired", detail: selectedServiceName(from: wiredPopup) ?? "Auto detected", tint: DesignSystem.wired),
            miniCard(icon: "arrow.triangle.2.circlepath", title: "Auto", detail: preferences.autoMode ? "Enabled" : "Manual", tint: preferences.autoMode ? DesignSystem.accent : .secondaryLabelColor)
        ])
        cards.orientation = .horizontal
        cards.spacing = 10
        cards.distribution = .fillEqually
        return cards
    }

    private func miniCard(icon: String, title: String, detail: String, tint: NSColor) -> NSView {
        let image = DesignSystem.iconBubble(symbol: icon, tint: tint, size: 18)
        let titleLabel = DesignSystem.label(title, size: 12, weight: .semibold)
        let detailLabel = DesignSystem.wrappedLabel(detail, size: 11)
        detailLabel.lineBreakMode = .byTruncatingTail

        let text = NSStackView(views: [titleLabel, detailLabel])
        text.orientation = .vertical
        text.spacing = 2

        let row = NSStackView(views: [image, text])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        row.wantsLayer = true
        row.layer?.cornerRadius = 8
        row.layer?.backgroundColor = DesignSystem.cardBackground()
        return row
    }

    private func section(icon: String, title: String, detail: String, control: NSView) -> NSView {
        let tint = icon == "cable.connector" ? DesignSystem.wired : DesignSystem.accent
        let image = DesignSystem.iconBubble(symbol: icon, tint: tint, size: 19)

        let titleLabel = DesignSystem.label(title, size: 13, weight: .semibold)
        let detailLabel = DesignSystem.wrappedLabel(detail, size: 12)

        let text = NSStackView(views: [titleLabel, detailLabel])
        text.orientation = .vertical
        text.spacing = 3
        text.widthAnchor.constraint(equalToConstant: 245).isActive = true

        control.widthAnchor.constraint(equalToConstant: 250).isActive = true

        let row = NSStackView(views: [image, text, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.edgeInsets = NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        row.wantsLayer = true
        row.layer?.cornerRadius = 8
        row.layer?.backgroundColor = DesignSystem.cardBackground()
        return row
    }

    func reload() {
        services = (try? switcher.discoverServices()) ?? []
        populate(wiFiPopup, with: services.filter { $0.kind == .wiFi }, selected: preferences.wiFiService)
        populate(wiredPopup, with: services.filter { $0.kind == .wired }, selected: preferences.wiredService)
        autoModeButton.state = preferences.autoMode ? .on : .off
        priorityControl.selectedSegment = preferences.autoPriority == .wired ? 0 : 1

        let wiredCount = services.filter { $0.kind == .wired }.count
        statusLabel.stringValue = wiredCount == 0 ? "No wired network service found. Wi-Fi remains available." : "Network services are detected from this Mac."
        statusLabel.textColor = wiredCount == 0 ? .systemOrange : .secondaryLabelColor
    }

    private func selectedServiceName(from popup: NSPopUpButton) -> String? {
        popup.selectedItem?.representedObject as? String
    }

    private func populate(_ popup: NSPopUpButton, with descriptors: [NetworkServiceDescriptor], selected: String?) {
        popup.removeAllItems()
        for descriptor in descriptors {
            popup.addItem(withTitle: descriptor.detailLabel)
            popup.lastItem?.representedObject = descriptor.serviceName
        }

        if let selected, let item = popup.itemArray.first(where: { $0.representedObject as? String == selected }) {
            popup.select(item)
        } else {
            popup.selectItem(at: 0)
        }
    }

    @objc private func save() {
        preferences.wiFiService = wiFiPopup.selectedItem?.representedObject as? String
        preferences.wiredService = wiredPopup.selectedItem?.representedObject as? String
        preferences.autoMode = autoModeButton.state == .on
        preferences.autoPriority = priorityControl.selectedSegment == 1 ? .wiFi : .wired
        NotificationCenter.default.post(name: .netSwitchSettingsChanged, object: nil)
    }
}

extension Notification.Name {
    static let netSwitchSettingsChanged = Notification.Name("netSwitchSettingsChanged")
}
