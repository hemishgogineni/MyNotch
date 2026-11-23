import Combine
import SwiftUI

final class HardwareStatus: ObservableObject {
    let battery = BatteryStore()
    let pods = AirPodsStore()
    @Published private(set) var activity: String?
    private var dismissal: Task<Void, Never>?

    func start() {
        battery.onCharge = { [weak self] in self?.show("Charging · \($0)%") }
        pods.onConnect = { [weak self] in self?.show("\($0) connected") }
        battery.start()
        pods.start()
    }

    func show(_ message: String) {
        dismissal?.cancel()
        activity = message
        dismissal = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled { activity = nil }
        }
    }

    func stop() {
        dismissal?.cancel()
        battery.stop()
        pods.stop()
    }
}

struct HardwareRows: View {
    @ObservedObject var battery: BatteryStore
    @ObservedObject var pods: AirPodsStore
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let reading = battery.reading {
                Label {
                    Text("\(reading.charging ? "Charging" : reading.pluggedIn ? "Power connected" : "Battery") · \(reading.percent)%")
                } icon: {
                    Image(systemName: reading.charging ? "battery.100percent.bolt" : "battery.\(25 * (reading.percent / 25))percent")
                }
            }
            ForEach(pods.devices.keys.sorted(), id: \.self) { id in
                if let item = pods.devices[id] {
                    Label(item.name + (item.levels.isEmpty ? " · Connected" : " · " + item.levels.joined(separator: "  ")),
                          systemImage: "airpodspro").lineLimit(1)
                }
            }
        }.font(.caption).frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ActivityLabel: View {
    @ObservedObject var hardware: HardwareStatus
    var body: some View {
        Text(hardware.activity ?? "").lineLimit(1).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
    }
}
