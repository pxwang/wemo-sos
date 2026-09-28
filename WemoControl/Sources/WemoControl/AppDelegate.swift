import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var devices: [WemoDevice] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "🔌"

        rebuildMenu(discovering: true)
        refresh()
    }

    @objc private func refresh() {
        rebuildMenu(discovering: true)
        Task { @MainActor in
            let locations = SSDPDiscovery.discover(timeout: 6)
            var found: [WemoDevice] = []
            for loc in locations {
                let (name, model) = await WemoClient.fetchDescription(location: loc)
                let isOn = await WemoClient.getBinaryState(location: loc)
                found.append(WemoDevice(location: loc, friendlyName: name, modelName: model, isOn: isOn))
            }
            self.devices = found.sorted { $0.friendlyName < $1.friendlyName }
            self.rebuildMenu(discovering: false)
        }
    }

    @objc private func toggle(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? WemoDevice else { return }
        Task { @MainActor in
            let newState = await WemoClient.setBinaryState(location: device.location, on: !device.isOn)
            if let idx = self.devices.firstIndex(where: { $0.location == device.location }) {
                self.devices[idx].isOn = newState
            }
            self.rebuildMenu(discovering: false)
        }
    }

    private func rebuildMenu(discovering: Bool) {
        let menu = NSMenu()

        if discovering {
            menu.addItem(withTitle: "Searching for devices…", action: nil, keyEquivalent: "")
        } else if devices.isEmpty {
            menu.addItem(withTitle: "No devices found", action: nil, keyEquivalent: "")
        } else {
            for device in devices {
                let mark = device.isOn ? "●" : "○"
                let item = NSMenuItem(title: "\(mark) \(device.friendlyName)", action: #selector(toggle(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = device
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let refreshItem = NSMenuItem(title: "Discover Devices", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }
}
