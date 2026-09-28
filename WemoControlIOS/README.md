# WemoControl (iOS)

SwiftUI iPhone app for discovering and controlling Belkin Wemo smart
switches over your home Wi-Fi. No Wemo cloud account needed. Companion to
the macOS menu bar app in `../WemoControl`.

## Why discovery works differently here than on the Mac

The Mac app finds devices via SSDP (UDP multicast). On a **real iPhone**,
iOS blocks raw IP multicast unless the app carries Apple's **Multicast
Networking entitlement** (`com.apple.developer.networking.multicast`) —
which requires a paid Apple Developer Program membership and a separate,
non-guaranteed approval request to Apple. Attempting multicast without it
fails silently at the socket level (`sendto` returns `EHOSTUNREACH`).
Simulator does *not* enforce this restriction, which can make code look
fine there and then fail on-device.

The workaround, in `SubnetDiscovery.swift`: instead of multicast, probe
every host on the local `/24` subnet with a plain unicast HTTP request to
the Wemo `setup.xml` endpoint. This only needs the ordinary **Local
Network** permission (`NSLocalNetworkUsageDescription` in `Info.plist`),
which any free/personal Apple ID can sign. Tradeoff: a scan takes a few
seconds (up to 254 probes) instead of an instant multicast reply.

## Build & run

Requires full Xcode (not just Command Line Tools) and
[XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
cd WemoControlIOS
# Edit project.yml: set DEVELOPMENT_TEAM to your own Apple Developer Team ID
xcodegen generate
open WemoControlIOS.xcodeproj
```

Then in Xcode: select your iPhone as the run destination, confirm signing
under **Signing & Capabilities**, and Run. On first launch, allow the
"find devices on your local network" permission prompt — without it,
discovery silently returns nothing.

### Building/installing from the command line instead

```bash
xcodebuild -project WemoControlIOS.xcodeproj -scheme WemoControlIOS \
  -sdk iphoneos -destination 'id=<your-device-udid>' \
  -configuration Debug -allowProvisioningUpdates build

xcrun devicectl device install app --device <your-device-udid> \
  "$(xcodebuild -showBuildSettings -sdk iphoneos | awk -F'= ' '/BUILT_PRODUCTS_DIR/{print $2; exit}')/WemoControlIOS.app"
```

Find your device UDID with `xcrun devicectl list devices`.

## Free Apple ID signing limitation

Without a paid Apple Developer Program membership, apps signed with a
personal Apple ID expire after **7 days** and need reinstalling from Xcode.
This is an Apple platform restriction, not something fixable in the project
itself. Sharing with other people's devices (beyond a 7-day cable install)
needs either their device connected to a Mac with Xcode, or upgrading to
a paid account for TestFlight/Ad Hoc distribution.

## Project layout

```
project.yml                 XcodeGen project spec (source of truth — the
                             .xcodeproj itself is generated, not committed)
Sources/
  WemoControlIOSApp.swift   @main entry point
  ContentView.swift         Device list UI, empty/searching states
  WemoStore.swift           Discovery + toggle state, auto-refresh timer
  SubnetDiscovery.swift     Unicast subnet scan (see above)
  WemoDevice.swift          UPnP SOAP control (get/set on-off state)
  Assets.xcassets/          App icon
```
