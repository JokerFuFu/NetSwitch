import AppKit

@MainActor
final class GuideWindowController: NSWindowController {
    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 440), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "NetSwitch 使用引导"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 18
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 26)
        ])

        root.addArrangedSubview(header())
        root.addArrangedSubview(flow())
        root.addArrangedSubview(step(icon: "menubar.rectangle", title: "从菜单栏使用", detail: "NetSwitch 常驻菜单栏，状态会显示「无线」「有线」「离线」或「混合」。"))
        root.addArrangedSubview(step(icon: "wifi", title: "切换到无线", detail: "选择无线后，会启用选中的 Wi-Fi 服务，并停用托管的有线服务。"))
        root.addArrangedSubview(step(icon: "cable.connector", title: "切换到有线", detail: "选择有线后，会启用选中的有线服务，同时保持 Wi-Fi 开关打开但断开当前连接。"))
        root.addArrangedSubview(step(icon: "gearshape", title: "按这台 Mac 调整", detail: "在设置里选择无线服务、有线服务、自动模式和登录自启。"))
    }

    private func header() -> NSView {
        let icon = symbol("switch.2", size: 40)
        let title = NSTextField(labelWithString: "NetSwitch")
        title.font = .systemFont(ofSize: 24, weight: .semibold)

        let subtitle = NSTextField(wrappingLabelWithString: "一个在菜单栏里快速切换无线和有线网络的小工具。")
        subtitle.textColor = .secondaryLabelColor

        let text = NSStackView(views: [title, subtitle])
        text.orientation = .vertical
        text.spacing = 4

        let stack = NSStackView(views: [icon, text])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 14
        return stack
    }

    private func flow() -> NSView {
        let wifi = flowNode(icon: "wifi", title: "无线")
        let app = flowNode(icon: "switch.2", title: "NetSwitch")
        let wired = flowNode(icon: "cable.connector", title: "有线")
        let arrow1 = symbol("arrow.right", size: 20)
        let arrow2 = symbol("arrow.right", size: 20)

        let stack = NSStackView(views: [wifi, arrow1, app, arrow2, wired])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 14
        return stack
    }

    private func flowNode(icon: String, title: String) -> NSView {
        let image = symbol(icon, size: 28)
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .medium)

        let stack = NSStackView(views: [image, label])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 8
        stack.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 18, bottom: 12, right: 18)
        return stack
    }

    private func step(icon: String, title: String, detail: String) -> NSView {
        let image = symbol(icon, size: 24)
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)

        let detailLabel = NSTextField(wrappingLabelWithString: detail)
        detailLabel.textColor = .secondaryLabelColor

        let text = NSStackView(views: [titleLabel, detailLabel])
        text.orientation = .vertical
        text.spacing = 3

        let stack = NSStackView(views: [image, text])
        stack.orientation = .horizontal
        stack.alignment = .top
        stack.spacing = 12
        return stack
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
}
