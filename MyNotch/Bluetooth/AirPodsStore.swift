import Combine
import Foundation
import IOBluetooth

struct PodStatus {
    let name: String
    var levels: [String] = []
}

final class AirPodsStore: NSObject, ObservableObject {
    @Published private(set) var devices: [String: PodStatus] = [:]
    var onConnect: ((String) -> Void)?
    private var connections: IOBluetoothUserNotification?
    private var disconnects: [String: IOBluetoothUserNotification] = [:]
    private var reads: [String: Task<Void, Never>] = [:]

    func start() {
        connections = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
        for device in IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? [] where device.isConnected() {
            observe(device, announce: false)
        }
    }

    @objc private func connected(_ token: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        observe(device, announce: true)
    }

    private func observe(_ device: IOBluetoothDevice, announce: Bool) {
        guard let address = device.addressString, disconnects[address] == nil,
              let name = device.name else { return }
        let namedPods = name.localizedCaseInsensitiveContains("airpods")
        // Also check audio devices whose owner has renamed them.
        guard namedPods || device.deviceClassMajor == 4 else { return }
        disconnects[address] = device.register(forDisconnectNotification: self, selector: #selector(disconnected(_:device:)))
        if namedPods {
            devices[address] = PodStatus(name: name)
            if announce { onConnect?(name) }
        }
        reads[address] = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            let status = await Self.profile(address: address, name: name, knownPods: namedPods)
            guard !Task.isCancelled, let status else { return }
            devices[address] = status
            if !namedPods && announce { onConnect?(name) }
        }
    }

    @objc private func disconnected(_ token: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard let address = device.addressString else { return }
        reads.removeValue(forKey: address)?.cancel()
        disconnects.removeValue(forKey: address)?.unregister()
        devices.removeValue(forKey: address)
    }

    nonisolated private static func profile(address: String, name: String, knownPods: Bool) async -> PodStatus? {
        await Task.detached(priority: .utility) {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            process.arguments = ["SPBluetoothDataType", "-json", "-timeout", "8"]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do { try process.run() } catch { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return Self.parse(data, address: address, name: name, knownPods: knownPods)
        }.value
    }

    nonisolated static func parse(_ data: Data, address: String, name: String, knownPods: Bool) -> PodStatus? {
        func normalized(_ value: String) -> String { value.lowercased().filter(\.isHexDigit) }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let controllers = root["SPBluetoothDataType"] as? [[String: Any]] else { return nil }
        for controller in controllers {
            for entry in controller["device_connected"] as? [[String: [String: Any]]] ?? [] {
                for info in entry.values {
                    guard let id = info["device_address"] as? String, normalized(id) == normalized(address) else { continue }
                    let identified = (info["device_minorType"] as? String ?? "").localizedCaseInsensitiveContains("airpods")
                    guard knownPods || identified else { continue }
                    var levels: [String] = []
                    for (key, label) in [("Left", "L"), ("Right", "R"), ("Case", "Case")] {
                        guard let raw = info["device_batteryLevel" + key] else { continue }
                        let value = String(describing: raw).trimmingCharacters(in: CharacterSet(charactersIn: " %"))
                        if let percent = Int(value), (0...100).contains(percent) { levels.append("\(label) \(percent)%") }
                    }
                    return PodStatus(name: name, levels: levels)
                }
            }
        }
        return nil
    }

    func stop() {
        connections?.unregister()
        reads.values.forEach { $0.cancel() }
        disconnects.values.forEach { $0.unregister() }
        disconnects.removeAll()
    }
}
