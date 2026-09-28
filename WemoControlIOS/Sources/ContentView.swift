import SwiftUI

struct ContentView: View {
    @StateObject private var store = WemoStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationView {
            List {
                if store.devices.isEmpty {
                    if store.isSearching {
                        HStack {
                            ProgressView()
                            Text("Searching for devices…")
                        }
                        .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No devices found")
                                .font(.headline)
                            Text("Pull down to refresh, or check that your iPhone is on the same Wi-Fi network as your Wemo switches.")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                ForEach(store.devices, id: \.location) { device in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.friendlyName)
                                .font(.headline)
                            Text(device.modelName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { device.isOn },
                            set: { _ in store.toggle(device) }
                        ))
                        .labelsHidden()
                    }
                }
            }
            .navigationTitle("WemoControl")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if store.isSearching {
                        ProgressView()
                    } else {
                        Button("Discover") { store.refresh() }
                    }
                }
            }
            .refreshable { store.refresh() }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    store.startAutoRefresh()
                } else {
                    store.stopAutoRefresh()
                }
            }
        }
    }
}
