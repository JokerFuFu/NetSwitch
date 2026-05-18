import Foundation
import NetSwitchCore

func expectEqual<T: Equatable>(_ actual: T?, _ expected: T?, _ message: String) {
    guard actual == expected else {
        fputs("FAILED: \(message). Expected \(String(describing: expected)), got \(String(describing: actual))\n", stderr)
        exit(1)
    }
}

let hardwarePorts = """
Hardware Port: Ethernet
Device: en7
Ethernet Address: 00:00:00:00:00:00

Hardware Port: Wi-Fi
Device: en0
Ethernet Address: 11:11:11:11:11:11
"""

let airportPorts = """
Hardware Port: AirPort
Device: en1
Ethernet Address: 11:11:11:11:11:11
"""

expectEqual(NetworkSwitcher.parseWiFiDevice(from: hardwarePorts), "en0", "parses Wi-Fi device")
expectEqual(NetworkSwitcher.parseWiFiDevice(from: airportPorts), "en1", "parses AirPort alias")
expectEqual(NetworkSwitcher.parseCurrentSSID(from: "Current Wi-Fi Network: F50 Pro"), "F50 Pro", "parses current SSID")
expectEqual(NetworkSwitcher.parseCurrentSSID(from: "Current Wi-Fi Network: "), nil, "empty SSID returns nil")
expectEqual(NetworkSwitcher.parseNetworkServices(from: "An asterisk (*) denotes that a network service is disabled.\n*Wi-Fi\nF50 Pro"), ["Wi-Fi": false, "F50 Pro": true], "parses disabled network services")
expectEqual(NetworkSwitcher.parseIPAddress(from: "DHCP Configuration\nIP address: 192.168.0.89\nRouter: 192.168.0.1"), "192.168.0.89", "parses IP address")
expectEqual(NetworkSwitcher.parseIPAddress(from: "DHCP Configuration\nIP address: none"), nil, "ignores missing IP address")

final class FakeRunner: CommandRunning, @unchecked Sendable {
    var calls: [[String]] = []

    func run(_ executable: String, _ arguments: [String]) throws -> CommandResult {
        calls.append(arguments)

        if arguments == ["-listallhardwareports"] {
            return CommandResult(status: 0, output: hardwarePorts)
        }

        return CommandResult(status: 0)
    }
}

let fakeRunner = FakeRunner()
let switcher = NetworkSwitcher(runner: fakeRunner)
let wifi = NetworkTarget(id: "wifi", displayName: "Wi-Fi", serviceName: "Wi-Fi", kind: .wiFi)
let f50 = NetworkTarget(id: "f50-pro", displayName: "F50 Pro", serviceName: "F50 Pro", kind: .wired)
try switcher.switchToTarget(f50, among: [wifi, f50])
expectEqual(fakeRunner.calls, [
    ["-setnetworkserviceenabled", "F50 Pro", "on"],
    ["-setnetworkserviceenabled", "Wi-Fi", "off"]
], "wired target enables F50 Pro and disables Wi-Fi")

print("NetSwitch parser tests passed")
