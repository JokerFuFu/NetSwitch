import CoreWLAN
import Foundation

public struct CommandResult: Equatable, Sendable {
    public let status: Int32
    public let output: String
    public let error: String

    public init(status: Int32, output: String = "", error: String = "") {
        self.status = status
        self.output = output
        self.error = error
    }

    public var combinedOutput: String {
        [output, error].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

public enum NetworkSwitchError: LocalizedError {
    case wiFiDeviceNotFound
    case targetNotFound(String)
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .wiFiDeviceNotFound:
            return "Could not find a Wi-Fi network device."
        case .targetNotFound(let name):
            return "Could not find network service \"\(name)\"."
        case .commandFailed(let message):
            return message
        }
    }
}

public protocol CommandRunning: Sendable {
    func run(_ executable: String, _ arguments: [String]) throws -> CommandResult
}

public protocol WiFiManaging: Sendable {
    func disconnectCurrentNetwork(device: String) throws
}

public struct ProcessCommandRunner: CommandRunning, Sendable {
    public init() {}

    public func run(_ executable: String, _ arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return CommandResult(status: process.terminationStatus, output: output.trimmingCharacters(in: .whitespacesAndNewlines), error: error.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

public struct CoreWLANWiFiManager: WiFiManaging, Sendable {
    public init() {}

    public func disconnectCurrentNetwork(device: String) throws {
        let client = CWWiFiClient.shared()
        let wiFiInterface = client.interface(withName: device) ?? client.interface()
        wiFiInterface?.disassociate()
    }
}

public enum NetworkTargetKind: String, Sendable {
    case wiFi
    case wired
}

public enum NetworkPriority: String, Sendable {
    case wired
    case wiFi
}

public struct HardwarePort: Equatable, Sendable {
    public let name: String
    public let device: String

    public init(name: String, device: String) {
        self.name = name
        self.device = device
    }
}

public struct NetworkServiceDescriptor: Equatable, Sendable {
    public let serviceName: String
    public let displayName: String
    public let device: String?
    public let kind: NetworkTargetKind?
    public let isEnabled: Bool
    public let ipAddress: String?

    public var detailLabel: String {
        [displayName, device, ipAddress]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
    }

    public var isActive: Bool {
        isEnabled && ipAddress != nil
    }

    public var target: NetworkTarget? {
        guard let kind else { return nil }
        return NetworkTarget(id: serviceName, displayName: displayName, serviceName: serviceName, kind: kind)
    }
}

public struct NetworkTarget: Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let serviceName: String
    public let kind: NetworkTargetKind
    public let ssid: String?

    public init(id: String, displayName: String, serviceName: String, kind: NetworkTargetKind, ssid: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.serviceName = serviceName
        self.kind = kind
        self.ssid = ssid
    }
}

public struct NetworkServiceState: Equatable, Sendable {
    public let serviceName: String
    public let isEnabled: Bool
    public let ipAddress: String?

    public var isActive: Bool {
        isEnabled && ipAddress != nil
    }
}

public struct NetworkSnapshot: Equatable, Sendable {
    public let services: [NetworkServiceState]
    public let currentSSID: String?

    public func state(for serviceName: String) -> NetworkServiceState? {
        services.first { $0.serviceName == serviceName }
    }

    public func activeTargets(from targets: [NetworkTarget]) -> [NetworkTarget] {
        targets.filter { target in
            guard let state = state(for: target.serviceName) else {
                return false
            }

            switch target.kind {
            case .wiFi:
                return state.isEnabled && currentSSID != nil
            case .wired:
                return state.isActive
            }
        }
    }
}

public struct NetworkSwitcher: Sendable {
    private let runner: CommandRunning
    private let wiFiManager: WiFiManaging
    private let networksetup = "/usr/sbin/networksetup"

    public init(runner: CommandRunning = ProcessCommandRunner(), wiFiManager: WiFiManaging = CoreWLANWiFiManager()) {
        self.runner = runner
        self.wiFiManager = wiFiManager
    }

    public func wiFiDevice() throws -> String {
        let result = try runner.run(networksetup, ["-listallhardwareports"])
        guard result.status == 0 else {
            throw NetworkSwitchError.commandFailed(result.combinedOutput)
        }
        guard let device = Self.parseWiFiDevice(from: result.output) else {
            throw NetworkSwitchError.wiFiDeviceNotFound
        }
        return device
    }

    public func currentSSID() throws -> String? {
        let device = try wiFiDevice()
        let result = try runner.run(networksetup, ["-getairportnetwork", device])
        guard result.status == 0 else {
            return nil
        }
        return Self.parseCurrentSSID(from: result.output)
    }

    public func snapshot(for targets: [NetworkTarget]) throws -> NetworkSnapshot {
        let services = try networkServiceEnabledStates()
        let serviceStates = try targets.map { target in
            let isEnabled = services[target.serviceName]
            guard let isEnabled else {
                throw NetworkSwitchError.targetNotFound(target.serviceName)
            }

            let info = try runner.run(networksetup, ["-getinfo", target.serviceName])
            let ipAddress = info.status == 0 ? Self.parseIPAddress(from: info.output) : nil
            return NetworkServiceState(serviceName: target.serviceName, isEnabled: isEnabled, ipAddress: ipAddress)
        }

        return NetworkSnapshot(services: serviceStates, currentSSID: try? currentSSID())
    }

    public func discoverServices() throws -> [NetworkServiceDescriptor] {
        let serviceStates = try networkServiceEnabledList()
        let hardwarePorts = try hardwarePorts()
        let hardwareByName = Dictionary(uniqueKeysWithValues: hardwarePorts.map { ($0.name, $0) })

        return try serviceStates.map { serviceName, isEnabled in
            let info = try runner.run(networksetup, ["-getinfo", serviceName])
            let ipAddress = info.status == 0 ? Self.parseIPAddress(from: info.output) : nil
            let hardware = hardwareByName[serviceName]
            let kind = Self.classifyService(name: serviceName, device: hardware?.device)

            return NetworkServiceDescriptor(
                serviceName: serviceName,
                displayName: serviceName,
                device: hardware?.device,
                kind: kind,
                isEnabled: isEnabled,
                ipAddress: ipAddress
            )
        }
    }

    public func recommendedTargets(from services: [NetworkServiceDescriptor]) -> [NetworkTarget] {
        var targets: [NetworkTarget] = []

        if let wiFi = services.first(where: { $0.kind == .wiFi })?.target {
            targets.append(wiFi)
        }

        let wiredCandidates = services.filter { $0.kind == .wired }
        let activeWired = wiredCandidates.first { $0.isActive }
        if let wired = (activeWired ?? wiredCandidates.first)?.target {
            targets.append(wired)
        }

        return targets
    }

    public func switchToTarget(_ target: NetworkTarget, among targets: [NetworkTarget]) throws {
        try setNetworkService(target.serviceName, enabled: true)

        if target.kind == .wiFi {
            let device = try wiFiDevice()
            try runRequired(["-setairportpower", device, "on"])

            if let ssid = target.ssid {
                try runRequired(["-setairportnetwork", device, ssid])
            }
        }

        for otherTarget in targets where otherTarget.id != target.id {
            switch (target.kind, otherTarget.kind) {
            case (.wired, .wiFi):
                let device = try wiFiDevice()
                try runRequired(["-setairportpower", device, "on"])
                try setNetworkService(otherTarget.serviceName, enabled: true)
                try wiFiManager.disconnectCurrentNetwork(device: device)
            default:
                try setNetworkService(otherTarget.serviceName, enabled: false)
            }
        }
    }

    public func disconnectWiFiKeepingPower(serviceName: String) throws {
        let device = try wiFiDevice()
        try runRequired(["-setairportpower", device, "on"])
        try setNetworkService(serviceName, enabled: true)
        try wiFiManager.disconnectCurrentNetwork(device: device)
    }

    private func networkServiceEnabledStates() throws -> [String: Bool] {
        let result = try runner.run(networksetup, ["-listallnetworkservices"])
        guard result.status == 0 else {
            throw NetworkSwitchError.commandFailed(result.combinedOutput)
        }
        return Self.parseNetworkServices(from: result.output)
    }

    private func networkServiceEnabledList() throws -> [(String, Bool)] {
        let result = try runner.run(networksetup, ["-listallnetworkservices"])
        guard result.status == 0 else {
            throw NetworkSwitchError.commandFailed(result.combinedOutput)
        }
        return Self.parseNetworkServiceList(from: result.output)
    }

    public func hardwarePorts() throws -> [HardwarePort] {
        let result = try runner.run(networksetup, ["-listallhardwareports"])
        guard result.status == 0 else {
            throw NetworkSwitchError.commandFailed(result.combinedOutput)
        }
        return Self.parseHardwarePorts(from: result.output)
    }

    private func setNetworkService(_ serviceName: String, enabled: Bool) throws {
        try runRequired(["-setnetworkserviceenabled", serviceName, enabled ? "on" : "off"])
    }

    private func runRequired(_ arguments: [String]) throws {
        let result = try runner.run(networksetup, arguments)
        guard result.status == 0 else {
            throw NetworkSwitchError.commandFailed(result.combinedOutput.isEmpty ? "networksetup \(arguments.joined(separator: " ")) failed." : result.combinedOutput)
        }
    }

    public static func parseWiFiDevice(from output: String) -> String? {
        let lines = output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        for index in lines.indices where lines[index].caseInsensitiveCompare("Hardware Port: Wi-Fi") == .orderedSame || lines[index].caseInsensitiveCompare("Hardware Port: AirPort") == .orderedSame {
            let nextLines = lines.dropFirst(index + 1).prefix(3)
            for line in nextLines where line.hasPrefix("Device:") {
                return String(line.dropFirst("Device:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return nil
    }

    public static func parseHardwarePorts(from output: String) -> [HardwarePort] {
        let lines = output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        var ports: [HardwarePort] = []
        var name: String?

        for line in lines {
            if line.hasPrefix("Hardware Port:") {
                name = String(line.dropFirst("Hardware Port:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if line.hasPrefix("Device:"), let portName = name {
                let device = String(line.dropFirst("Device:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                ports.append(HardwarePort(name: portName, device: device))
                name = nil
            }
        }

        return ports
    }

    public static func parseCurrentSSID(from output: String) -> String? {
        guard let separator = output.firstIndex(of: ":") else {
            return nil
        }
        let ssid = output[output.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
        return ssid.isEmpty ? nil : ssid
    }

    public static func parseNetworkServices(from output: String) -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: parseNetworkServiceList(from: output))
    }

    public static func parseNetworkServiceList(from output: String) -> [(String, Bool)] {
        var orderedServices: [(String, Bool)] = []

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("An asterisk") else {
                continue
            }

            if line.hasPrefix("*") {
                let name = String(line.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                orderedServices.append((name, false))
            } else {
                orderedServices.append((line, true))
            }
        }

        return orderedServices
    }

    public static func parseIPAddress(from output: String) -> String? {
        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("IP address:") else {
                continue
            }

            let address = String(line.dropFirst("IP address:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !address.isEmpty, address.lowercased() != "none" {
                return address
            }
        }

        return nil
    }

    public static func classifyService(name: String, device: String?) -> NetworkTargetKind? {
        let lowerName = name.lowercased()
        let lowerDevice = device?.lowercased()

        if lowerName == "wi-fi" || lowerName == "wifi" || lowerName == "airport" {
            return .wiFi
        }

        if lowerName.contains("tailscale")
            || lowerName.contains("shadowrocket")
            || lowerName.contains("vpn")
            || lowerName.contains("bridge")
            || lowerName.contains("thunderbolt bridge")
            || lowerDevice?.hasPrefix("utun") == true
            || lowerDevice?.hasPrefix("bridge") == true {
            return nil
        }

        if lowerName.contains("ethernet")
            || lowerName.contains("lan")
            || lowerName.contains("usb")
            || lowerName.contains("thunderbolt")
            || lowerName.contains("adapter")
            || lowerDevice?.hasPrefix("en") == true {
            return .wired
        }

        return nil
    }
}
