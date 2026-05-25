# NetSwitch

NetSwitch is a small native macOS menu bar app for switching between Wi-Fi and wired network services with one click.

NetSwitch automatically detects this Mac's network services:

- The built-in Wi-Fi service
- A real wired Ethernet, USB LAN, or Thunderbolt Ethernet service

VPN, proxy, bridge, and virtual services are excluded from wired recommendations.

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

NetSwitch appears in the macOS menu bar. The status item shows `Wi-Fi`, `Wired`, `Offline`, or `Mixed`. Click the item to switch targets, refresh status, or open Settings.

## Visual Guide

NetSwitch includes a `How to Use` guide from the menu bar item. It shows a simple Wi-Fi → NetSwitch → Wired flow and explains the main actions with icons:

- `Wi-Fi`: switch back to the selected wireless service
- `Wired`: switch to the selected Ethernet/USB/Thunderbolt service
- `Settings`: choose services and automatic priority for this Mac
- `Refresh`: update IP, SSID, and connection status

The first launch also opens the visual guide once, so new users can understand the Wi-Fi and wired switching model before changing network state.

## Settings

Open `Settings...` from the menu bar item to:

- Choose the Wi-Fi service and wired service for this Mac
- Enable or disable automatic mode
- Choose automatic priority: wired first or Wi-Fi first

Selections are saved in macOS `UserDefaults`, so every Mac keeps its own local configuration.

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

## Distribution

Build a universal Apple Silicon + Intel app, zip archive, and installer package:

```sh
./scripts/package-app.sh
```

Artifacts are written to `dist/`:

- `NetSwitch.app`
- `NetSwitch-<version>-universal.zip`
- `NetSwitch-<version>-universal.pkg`

The `.pkg` installs NetSwitch into `/Applications` and adds a LaunchAgent at `/Library/LaunchAgents/com.joker2.netswitch.plist` so it starts automatically for users at login.

The app bundle is ad-hoc signed for local installation and internal sharing. The `.pkg` is not Developer ID signed. Public distribution outside trusted Macs still requires an Apple Developer ID Installer certificate and notarization.

## How It Works

NetSwitch uses macOS' built-in `networksetup` command:

- Reads network services with `networksetup -listallnetworkservices`
- Reads hardware ports with `networksetup -listallhardwareports`
- Reads each target service IP with `networksetup -getinfo`
- Automatically recommends Wi-Fi and a wired service from this Mac's current services
- Enables the selected service with `networksetup -setnetworkserviceenabled <service> on`
- When switching to `Wi-Fi`, disables the managed wired service
- When switching to wired, keeps Wi-Fi service and Wi-Fi power on, then disconnects the current Wi-Fi association through CoreWLAN
- Reads the Wi-Fi SSID with `networksetup -getairportnetwork` when Wi-Fi is active

After a switch, NetSwitch refreshes the menu automatically for a few seconds so DHCP-assigned IP addresses appear without clicking the menu again.
