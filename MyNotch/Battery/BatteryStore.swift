import Combine
import IOKit.ps

struct BatteryReading: Equatable {
    let percent: Int
    let charging: Bool
    let pluggedIn: Bool

    static func current() -> Self? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                  let level = info[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = info[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
            return Self(percent: min(100, max(0, Int((100 * Double(level) / Double(maximum)).rounded()))),
                        charging: info[kIOPSIsChargingKey] as? Bool == true,
                        pluggedIn: info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue)
        }
        return nil
    }
}

final class BatteryStore: ObservableObject {
    @Published private(set) var reading: BatteryReading?
    var onCharge: ((Int) -> Void)?
    private var source: CFRunLoopSource?

    func start() {
        reading = .current()
        source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let store = Unmanaged<BatteryStore>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { store.refresh() }
        }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue()
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
    }

    private func refresh() {
        let next = BatteryReading.current()
        if let previous = reading, let next, !previous.charging && next.charging { onCharge?(next.percent) }
        if next != reading { reading = next }
    }

    func stop() {
        if let source { CFRunLoopSourceInvalidate(source) }
        source = nil
    }
}
