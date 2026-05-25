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

For development, open the built app:

```sh
open .build/NetSwitch.app
```

NetSwitch appears in the macOS menu bar. The status item shows the active target when one is detected. Click the item and choose `Wi-Fi` or `F50 Pro` to switch networks.

## Install

Install NetSwitch into `~/Applications` and launch it automatically when you log in:

```sh
./scripts/install-app.sh
```

After installing, you can also open it manually from Finder or Terminal:

```sh
open ~/Applications/NetSwitch.app
```

Remove the installed app and login item:

```sh
./scripts/uninstall-app.sh
```

## How It Works

NetSwitch uses macOS' built-in `networksetup` command:

- Reads network services with `networksetup -listallnetworkservices`
- Reads each target service IP with `networksetup -getinfo`
- Enables the selected service with `networksetup -setnetworkserviceenabled <service> on`
- When switching to `Wi-Fi`, disables the managed wired service
- When switching to `F50 Pro`, keeps Wi-Fi service and Wi-Fi power on, then disconnects the current Wi-Fi association through CoreWLAN
- Reads the Wi-Fi SSID with `networksetup -getairportnetwork` when Wi-Fi is active

After a switch, NetSwitch refreshes the menu automatically for a few seconds so DHCP-assigned IP addresses appear without clicking the menu again.
