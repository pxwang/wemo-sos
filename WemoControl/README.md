# WemoControl

A tiny macOS menu bar app for discovering and controlling Belkin Wemo smart
switches on your local network — no Wemo cloud account required.

Built after Belkin shut down the Wemo cloud service in 2026, leaving
previously cloud-connected switches strandable. Wemo switches never actually
needed the cloud for local control: they speak plain UPnP over your LAN.

## How it works

- **Discovery**: sends an SSDP (`M-SEARCH`) multicast query on your LAN and
  collects the `LOCATION` URLs that Wemo devices reply with.
- **Control**: reads/sets on-off state via UPnP SOAP actions
  (`GetBinaryState` / `SetBinaryState`) posted to each device's
  `basicevent` control endpoint over plain HTTP.

Everything happens directly between this Mac and the switches over your
home network. Nothing is sent anywhere else.

## Requirements

- macOS 12 or later
- Swift toolchain (Xcode Command Line Tools are enough — `xcode-select -p`
  should print a path)

## Build

```bash
swift build -c release
```

## Run without installing

```bash
.build/release/WemoControl
```

## Package as a proper .app and install

```bash
APP=WemoControl.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/WemoControl "$APP/Contents/MacOS/WemoControl"
cp Info.plist "$APP/Contents/Info.plist"   # see below if missing
cp -R "$APP" /Applications/
```

If `Info.plist` isn't present, recreate it with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>WemoControl</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.wemocontrol</string>
    <key>CFBundleName</key>
    <string>WemoControl</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>WemoControl discovers and controls Wemo switches on your local network.</string>
</dict>
</plist>
```

## Usage

WemoControl is a menu bar app — it has no Dock icon or window
(`LSUIElement` is set). Look for the 🔌 icon in your menu bar:

- Click a device to toggle it on/off
- **Discover Devices** re-runs SSDP discovery (results can be intermittent —
  UDP multicast replies occasionally get dropped; just discover again)
- **Quit** to exit

To launch at login, drag `WemoControl.app` into
**System Settings → General → Login Items**.

## Project layout

```
Package.swift               Swift package manifest
Sources/WemoControl/
  App.swift                 @main entry point
  AppDelegate.swift         NSStatusItem / menu bar UI
  SSDPDiscovery.swift       SSDP multicast discovery
  WemoDevice.swift          UPnP SOAP control (get/set on-off state)
```

## Scheduling

Since Wemo switches can no longer be scheduled through the (defunct) cloud
app, see `../scripts/wemo_ctl.py` and `../launchd/` in the parent directory
for a `launchd`-based scheduling setup that reuses the same discovery/control
approach from the command line.
