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

public enum NetworkTargetKind: String, Sendable {
    case wiFi
    case wired
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
            state(for: target.serviceName)?.isActive == true
        }
    }
}

public struct NetworkSwitcher: Sendable {
    private let runner: CommandRunning
    private let networksetup = "/usr/sbin/networksetup"

    public init(runner: CommandRunning = ProcessCommandRunner()) {
        self.runner = runner
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

    public func switchToTarget(_ target: NetworkTarget, among targets: [NetworkTarget]) throws {
        try setNetworkService(target.serviceName, enabled: true)

        if target.kind == .wiFi {
            let device = try wiFiDevice()
            try runRequired(["-setairportpower", device, "on"])

            if let ssid = target.ssid {
                try runRequired(["-setairportnetwork", device, ssid])
            }
        }

        let servicesToDisable = Set(targets.map(\.serviceName)).subtracting([target.serviceName])
        for serviceName in servicesToDisable.sorted() {
            try setNetworkService(serviceName, enabled: false)
        }
    }

    private func networkServiceEnabledStates() throws -> [String: Bool] {
        let result = try runner.run(networksetup, ["-listallnetworkservices"])
        guard result.status == 0 else {
            throw NetworkSwitchError.commandFailed(result.combinedOutput)
        }
        return Self.parseNetworkServices(from: result.output)
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

    public static func parseCurrentSSID(from output: String) -> String? {
        guard let separator = output.firstIndex(of: ":") else {
            return nil
        }
        let ssid = output[output.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)
        return ssid.isEmpty ? nil : ssid
    }

    public static func parseNetworkServices(from output: String) -> [String: Bool] {
        var services: [String: Bool] = [:]

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("An asterisk") else {
                continue
            }

            if line.hasPrefix("*") {
                let name = String(line.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                services[name] = false
            } else {
                services[line] = true
            }
        }

        return services
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
}
