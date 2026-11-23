import Combine
import SwiftUI

final class HardwareStatus: ObservableObject {
    let pods = AirPodsStore()
    @Published private(set) var activity: String?
    private var dismissal: Task<Void, Never>?

    func start() {
        pods.onConnect = { [weak self] in self?.show("\($0) connected") }
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
        pods.stop()
    }
}

struct ActivityLabel: View {
    @ObservedObject var hardware: HardwareStatus
    var body: some View {
        Text(hardware.activity ?? "").lineLimit(1).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
    }
}
