import Foundation

@MainActor
final class WemoStore: ObservableObject {
    @Published var devices: [WemoDevice] = []
    @Published var isSearching = false

    private var autoRefreshTask: Task<Void, Never>?

    func refresh() {
        Task { await performScan() }
    }

    func startAutoRefresh(interval: TimeInterval = 30) {
        guard autoRefreshTask == nil else { return }
        autoRefreshTask = Task {
            while !Task.isCancelled {
                await performScan()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    private func performScan() async {
        isSearching = true
        let found = await SubnetDiscovery.scan()
        self.devices = found.sorted { $0.friendlyName < $1.friendlyName }
        isSearching = false
    }

    func toggle(_ device: WemoDevice) {
        Task {
            let newState = await WemoClient.setBinaryState(location: device.location, on: !device.isOn)
            if let idx = self.devices.firstIndex(where: { $0.location == device.location }) {
                self.devices[idx].isOn = newState
            }
        }
    }
}
