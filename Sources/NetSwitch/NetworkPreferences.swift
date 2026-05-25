import Foundation
import NetSwitchCore

enum AutoPriority: String {
    case wired
    case wiFi
}

final class NetworkPreferences {
    private enum Key {
        static let wiFiService = "wiFiService"
        static let wiredService = "wiredService"
        static let autoMode = "autoMode"
        static let autoPriority = "autoPriority"
        static let hasShownGuide = "hasShownGuide"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var wiFiService: String? {
        get { defaults.string(forKey: Key.wiFiService) }
        set { defaults.set(newValue, forKey: Key.wiFiService) }
    }

    var wiredService: String? {
        get { defaults.string(forKey: Key.wiredService) }
        set { defaults.set(newValue, forKey: Key.wiredService) }
    }

    var autoMode: Bool {
        get { defaults.bool(forKey: Key.autoMode) }
        set { defaults.set(newValue, forKey: Key.autoMode) }
    }

    var autoPriority: AutoPriority {
        get { AutoPriority(rawValue: defaults.string(forKey: Key.autoPriority) ?? "") ?? .wired }
        set { defaults.set(newValue.rawValue, forKey: Key.autoPriority) }
    }

    var hasShownGuide: Bool {
        get { defaults.bool(forKey: Key.hasShownGuide) }
        set { defaults.set(newValue, forKey: Key.hasShownGuide) }
    }

    func targetServices(from discovered: [NetworkServiceDescriptor], switcher: NetworkSwitcher) -> [NetworkTarget] {
        let recommended = switcher.recommendedTargets(from: discovered)
        let selectedWiFi = wiFiService.flatMap { service in discovered.first { $0.serviceName == service && $0.kind == .wiFi }?.target }
        let selectedWired = wiredService.flatMap { service in discovered.first { $0.serviceName == service && $0.kind == .wired }?.target }
        let recommendedWiFi = recommended.first { $0.kind == .wiFi }
        let recommendedWired = recommended.first { $0.kind == .wired }

        return [selectedWiFi ?? recommendedWiFi, selectedWired ?? recommendedWired].compactMap { $0 }
    }
}
