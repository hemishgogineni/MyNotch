import SwiftUI

@main
struct MyNotchApp: App {
    @NSApplicationDelegateAdaptor(DisplayCoordinator.self) private var coordinator
    @AppStorage("hoverDelay") private var hoverDelay = 0.16

    var body: some Scene {
        MenuBarExtra("MyNotch", systemImage: "rectangle.topthird.inset.filled") {
            SettingsLink { Text("Settings…") }
            Divider()
            Button("Quit MyNotch") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        Settings {
            Form {
                Slider(value: $hoverDelay, in: 0.05...0.5, step: 0.01) {
                    Text("Hover delay")
                }
                Text("\(Int((hoverDelay * 1000).rounded())) milliseconds")
                    .monospacedDigit()
            }
            .padding(24)
            .frame(width: 320)
        }
    }
}

final class DisplayCoordinator: NSObject, NSApplicationDelegate {
    private let media = MediaStore()
    private let hardware = HardwareStatus()
    private let clipboard = ClipboardStore()
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?
    private struct DisplayGeometry: Equatable {
        let id: NSNumber?
        let frame: NSRect
        let topInset: CGFloat
        let left: NSRect?
        let right: NSRect?
    }
    private var displays: [DisplayGeometry] = []
    private var panels: [NotchPanel] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        clipboard.start()
        media.start()
        hardware.start()
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown]) { [weak self] event in
            let point = NSEvent.mouseLocation
            if event.type == .leftMouseDown { self?.panels.forEach { $0.pointerClicked(at: point) } }
            self?.panels.forEach { $0.updateHover(at: point) }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseUp, .leftMouseDown]) { [weak self] event in
            if event.type == .leftMouseDown {
                let point = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
                self?.panels.forEach { $0.pointerClicked(at: point) }
            }
            self?.panels.forEach { $0.updateHover(at: NSEvent.mouseLocation) }
            return event
        }
        refreshDisplays()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboard.stop()
        hardware.stop()
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        refreshDisplays()
    }

    private func refreshDisplays() {
        let screens = NSScreen.screens
        let geometry = screens.map {
            DisplayGeometry(id: $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
                            frame: $0.frame, topInset: $0.safeAreaInsets.top,
                            left: $0.auxiliaryTopLeftArea, right: $0.auxiliaryTopRightArea)
        }
        guard geometry != displays else { return }
        displays = geometry
        panels.forEach { $0.dismiss() }
        panels = screens.map { NotchPanel(display: $0, media: media, clipboard: clipboard, hardware: hardware) }
        panels.forEach { $0.orderFrontRegardless() }
    }
}
