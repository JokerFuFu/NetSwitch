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
    private let statusLabel = NSTextField(labelWithString: "")

    init(switcher: NetworkSwitcher) {
        self.switcher = switcher
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 390), styleMask: [.titled, .closable], backing: .buffered, defer: false)
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
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22)
        ])

        stack.addArrangedSubview(header())
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
        let icon = symbol("switch.2", size: 34)
        let title = NSTextField(labelWithString: "Network Switching")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        let detail = NSTextField(wrappingLabelWithString: "Pick the services this Mac should use. NetSwitch will remember these choices locally.")
        detail.textColor = .secondaryLabelColor

        let text = NSStackView(views: [title, detail])
        text.orientation = .vertical
        text.spacing = 4

        let stack = NSStackView(views: [icon, text])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 14
        return stack
    }

    private func section(icon: String, title: String, detail: String, control: NSView) -> NSView {
        let image = symbol(icon, size: 22)

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let detailLabel = NSTextField(wrappingLabelWithString: detail)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.font = .systemFont(ofSize: 12)

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
        row.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        return row
    }

    private func symbol(_ name: String, size: CGFloat) -> NSImageView {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
        image.isTemplate = true
        let imageView = NSImageView(image: image)
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        imageView.contentTintColor = .controlAccentColor
        imageView.widthAnchor.constraint(equalToConstant: size + 4).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: size + 4).isActive = true
        return imageView
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
