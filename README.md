# NetSwitch

NetSwitch is a small native macOS menu bar app for switching between saved Wi-Fi networks with one click.

The first version includes two menu choices:

- `Wi-Fi`
- `F50 Pro`

## Requirements

- macOS 13 or later
- Apple Swift command line tools
- The target Wi-Fi networks must already be saved in macOS

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

NetSwitch appears as a Wi-Fi icon in the macOS menu bar. Click the icon and choose `Wi-Fi` or `F50 Pro` to switch networks.

## How It Works

NetSwitch uses macOS' built-in `networksetup` command:

- Finds the Wi-Fi device with `networksetup -listallhardwareports`
- Reads the current SSID with `networksetup -getairportnetwork`
- Switches networks with `networksetup -setairportnetwork`

If macOS does not already know the password for a selected network, the switch can fail. Join the network once from System Settings first, then use NetSwitch.
