import Foundation

public struct CommandResult: Equatable, Sendable {
    let status: Int32
    let output: String
    let error: String

    var combinedOutput: String {
        [output, error].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

public enum NetworkSwitchError: LocalizedError {
    case wiFiDeviceNotFound
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .wiFiDeviceNotFound:
            return "Could not find a Wi-Fi network device."
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

    public func switchToNetwork(named ssid: String) throws {
        let device = try wiFiDevice()

        let powerResult = try runner.run(networksetup, ["-setairportpower", device, "on"])
        guard powerResult.status == 0 else {
            throw NetworkSwitchError.commandFailed(powerResult.combinedOutput)
        }

        let switchResult = try runner.run(networksetup, ["-setairportnetwork", device, ssid])
        guard switchResult.status == 0 else {
            let message = switchResult.combinedOutput.isEmpty ? "Failed to switch to \(ssid)." : switchResult.combinedOutput
            throw NetworkSwitchError.commandFailed(message)
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
}
