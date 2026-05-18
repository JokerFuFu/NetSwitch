# NetSwitch

NetSwitch is a small native macOS menu bar app for switching between network services with one click.

The first version includes two menu choices:

- `Wi-Fi`, the built-in wireless network service
- `F50 Pro`, a wired network service

## Requirements

- macOS 13 or later
- Apple Swift command line tools
- The target network services must exist in macOS Network settings

## Build

Run the test suite:

```sh
swift run NetSwitchParserTests
```

Build a macOS app bundle:

```sh
./scripts/build-app.sh
```

The app bundle is created at:

```text
.build/NetSwitch.app
```

## Run

Open the built app:

```sh
open .build/NetSwitch.app
```

NetSwitch appears in the macOS menu bar. The status item shows the active target when one is detected. Click the item and choose `Wi-Fi` or `F50 Pro` to switch networks.

## How It Works

NetSwitch uses macOS' built-in `networksetup` command:

- Reads network services with `networksetup -listallnetworkservices`
- Reads each target service IP with `networksetup -getinfo`
- Enables the selected service with `networksetup -setnetworkserviceenabled <service> on`
- Disables the other managed services with `networksetup -setnetworkserviceenabled <service> off`
- Reads the Wi-Fi SSID with `networksetup -getairportnetwork` when Wi-Fi is active

For a Wi-Fi target, NetSwitch also turns Wi-Fi power on before switching. For the default `F50 Pro` wired target, NetSwitch enables the `F50 Pro` service and disables `Wi-Fi`.
