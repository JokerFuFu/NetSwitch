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

print("NetSwitch parser tests passed")
