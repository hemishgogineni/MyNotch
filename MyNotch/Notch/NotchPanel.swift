import AppKit
import Combine

final class NotchPanel: NSPanel {
    private let idleFrame: NSRect
    private var subscription: AnyCancellable?
    private var closedFrame: NSRect
    private let openFrame: NSRect
    private let surface: NotchView
    private var delay: Task<Void, Never>?
    private var motion: Task<Void, Never>?
    private var expanded = false
    private var pointerInside: Bool?

    init(display: NSScreen, media: MediaStore, lyrics: LyricsStore, hardware: HardwareStatus) {
        let screen = display.frame
        let inset = display.safeAreaInsets.top
        let left = display.auxiliaryTopLeftArea ?? .zero
        let right = display.auxiliaryTopRightArea ?? .zero
        let hasNotch = inset > 0 && right.minX > left.maxX && !left.isEmpty && !right.isEmpty
        let width = hasNotch ? right.minX - left.maxX : 60
        let height = hasNotch ? inset : 14
        let center = hasNotch ? (left.maxX + right.minX) / 2 : screen.midX
        let top = screen.maxY - (hasNotch ? 0 : 3)
        closedFrame = NSRect(x: center - width / 2, y: top - height, width: width, height: height)
        idleFrame = closedFrame
        let openWidth = min(screen.width, max(width + 80, 560))
        openFrame = NSRect(x: center - openWidth / 2, y: screen.maxY - height - NotchView.expandedDepth,
                           width: openWidth, height: height + NotchView.expandedDepth)
        surface = NotchView(hasNotch: hasNotch, media: media, lyrics: lyrics, hardware: hardware)
        super.init(contentRect: closedFrame, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        isReleasedWhenClosed = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView = surface
        surface.hover = { [weak self] _ in self?.updateHover(at: NSEvent.mouseLocation) }
        surface.openOnClick = { [weak self] in
            guard let self, !self.expanded else { return }
            self.delay?.cancel()
            self.pointerInside = true
            self.transition(to: true)
        }
        setFrame(closedFrame, display: true)
        subscription = media.$track.map { $0?.playing == true }.removeDuplicates().combineLatest(hardware.$activity).sink { [weak self] playing, activity in
            guard let self else { return }
            self.closedFrame = self.idleFrame.insetBy(dx: playing && hasNotch ? -28 : 0, dy: 0)
            if activity != nil {
                let width = min(screen.width, max(260, self.idleFrame.width))
                self.closedFrame = NSRect(x: center - width / 2, y: top - height - 32, width: width, height: height + 32)
            }
            self.apply(self.surface.progress)
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    func dismiss() {
        delay?.cancel()
        motion?.cancel()
        surface.hover = nil
        close()
    }

    func updateHover(at point: NSPoint) {
        // Include the small gap above the pill so the screen edge is a stable target.
        let target = frame.union(NSRect(x: frame.minX, y: frame.maxY, width: frame.width, height: 3))
        schedule(point.x >= target.minX && point.x < target.maxX &&
                 point.y >= target.minY && point.y <= target.maxY)
    }

    private func schedule(_ inside: Bool) {
        guard inside != pointerInside else { return }
        pointerInside = inside
        delay?.cancel()
        guard expanded != inside else { return }
        let openDelay = UserDefaults.standard.object(forKey: "hoverDelay") as? Double ?? 0.16
        delay = Task { [weak self] in
            try? await Task.sleep(for: .seconds(inside ? openDelay : 0.24))
            guard !Task.isCancelled else { return }
            self?.transition(to: inside)
        }
    }

    private func transition(to open: Bool) {
        expanded = open
        motion?.cancel()
        let start = surface.progress
        let end: CGFloat = open ? 1 : 0
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            apply(end)
            return
        }
        motion = Task { [weak self] in
            let began = ProcessInfo.processInfo.systemUptime
            while !Task.isCancelled {
                let t = ProcessInfo.processInfo.systemUptime - began
                guard let self else { return }
                if t >= 0.42 {
                    self.apply(end)
                    return
                }
                let spring = 1 - exp(-16 * t) * (cos(12 * t) + (16.0 / 12) * sin(12 * t))
                self.apply(max(0, start + (end - start) * spring))
                try? await Task.sleep(for: .milliseconds(8))
            }
        }
    }

    private func apply(_ progress: CGFloat) {
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * progress }
        surface.progress = progress
        setFrame(NSRect(x: mix(closedFrame.minX, openFrame.minX),
                        y: mix(closedFrame.minY, openFrame.minY),
                        width: mix(closedFrame.width, openFrame.width),
                        height: mix(closedFrame.height, openFrame.height)), display: true)
    }
}
