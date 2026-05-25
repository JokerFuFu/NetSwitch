import AppKit

@MainActor
enum DesignSystem {
    static let accent = NSColor(calibratedRed: 0.11, green: 0.52, blue: 0.49, alpha: 1)
    static let wired = NSColor(calibratedRed: 0.45, green: 0.36, blue: 0.72, alpha: 1)
    static let warning = NSColor(calibratedRed: 0.86, green: 0.47, blue: 0.18, alpha: 1)

    static func cardBackground() -> CGColor {
        NSColor.controlBackgroundColor.cgColor
    }

    static func iconBubble(symbol: String, tint: NSColor = accent, size: CGFloat = 24) -> NSView {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage()
        image.isTemplate = true

        let imageView = NSImageView(image: image)
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: size, weight: .medium)
        imageView.contentTintColor = tint
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.layer?.backgroundColor = tint.withAlphaComponent(0.12).cgColor
        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 42),
            container.heightAnchor.constraint(equalToConstant: 42),
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: size + 4),
            imageView.heightAnchor.constraint(equalToConstant: size + 4)
        ])

        return container
    }

    static func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        return label
    }

    static func wrappedLabel(_ text: String, size: CGFloat = 12, color: NSColor = .secondaryLabelColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: size)
        label.textColor = color
        return label
    }
}
