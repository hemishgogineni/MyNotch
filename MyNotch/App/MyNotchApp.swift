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
    private let lyrics = LyricsStore()
    private var mouseMonitor: Any?
    private var panels: [NotchPanel] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        lyrics.follow(media)
        media.start()
        hardware.start()
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            let point = NSEvent.mouseLocation
            self?.panels.forEach { $0.updateHover(at: point) }
        }
        refreshDisplays()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hardware.stop()
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        refreshDisplays()
    }

    private func refreshDisplays() {
        panels.forEach { $0.dismiss() }
        panels = NSScreen.screens.map { NotchPanel(display: $0, media: media, lyrics: lyrics, hardware: hardware) }
        panels.forEach { $0.orderFrontRegardless() }
    }
}
