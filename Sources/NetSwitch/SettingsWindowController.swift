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
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 260), styleMask: [.titled, .closable], backing: .buffered, defer: false)
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
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22)
        ])

        stack.addArrangedSubview(row(label: "Wi-Fi service", control: wiFiPopup))
        stack.addArrangedSubview(row(label: "Wired service", control: wiredPopup))
        stack.addArrangedSubview(autoModeButton)
        stack.addArrangedSubview(row(label: "Auto priority", control: priorityControl))
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

    private func row(label: String, control: NSView) -> NSStackView {
        let labelView = NSTextField(labelWithString: label)
        labelView.widthAnchor.constraint(equalToConstant: 120).isActive = true
        control.widthAnchor.constraint(equalToConstant: 330).isActive = true

        let stack = NSStackView(views: [labelView, control])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        return stack
    }

    func reload() {
        services = (try? switcher.discoverServices()) ?? []
        populate(wiFiPopup, with: services.filter { $0.kind == .wiFi }, selected: preferences.wiFiService)
        populate(wiredPopup, with: services.filter { $0.kind == .wired }, selected: preferences.wiredService)
        autoModeButton.state = preferences.autoMode ? .on : .off
        priorityControl.selectedSegment = preferences.autoPriority == .wired ? 0 : 1

        let wiredCount = services.filter { $0.kind == .wired }.count
        statusLabel.stringValue = wiredCount == 0 ? "No wired network service found. Wi-Fi remains available." : "Network services are detected from this Mac."
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
