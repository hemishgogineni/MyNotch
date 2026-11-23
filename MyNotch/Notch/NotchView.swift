import SwiftUI

final class NotchView: NSView {
    static let expandedDepth: CGFloat = 136
    private let material = NSHostingView(rootView: NotchMaterial())
    private let expanded: ClipboardHostingView
    private let banner: NSHostingView<ActivityLabel>
    private let clipboard: ClipboardStore
    private let hardware: HardwareStatus
    private let compact: NSHostingView<CompactMedia>
    private let hasNotch: Bool
    var dragState: ((Bool) -> Void)?
    var openOnClick: (() -> Void)?
    var hover: ((Bool) -> Void)?
    var progress: CGFloat = 0 { didSet { needsDisplay = true; needsLayout = true } }
    override var isFlipped: Bool { true }

    init(hasNotch: Bool, media: MediaStore, clipboard: ClipboardStore, hardware: HardwareStatus) {
        self.clipboard = clipboard
        self.hardware = hardware
        banner = NSHostingView(rootView: ActivityLabel(hardware: hardware))
        self.hasNotch = hasNotch
        expanded = ClipboardHostingView(rootView: MediaView(media: media, clipboard: clipboard))
        compact = NSHostingView(rootView: CompactMedia(media: media))
        super.init(frame: .zero)
        material.sizingOptions = []
        expanded.owner = self
        expanded.registerForDraggedTypes([.fileURL] + NSImage.imageTypes.map { NSPasteboard.PasteboardType($0) })
        addSubview(material)
        addSubview(expanded)
        addSubview(compact)
        addSubview(banner)
        registerForDraggedTypes([.fileURL] + NSImage.imageTypes.map { NSPasteboard.PasteboardType($0) })
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
                                       owner: self, userInfo: nil))
        setAccessibilityElement(false)
        setAccessibilityLabel("MyNotch")
    }

    required init?(coder: NSCoder) { nil }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if progress < 0.1 && bounds.contains(point) { return self }
        return super.hitTest(point)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { openOnClick?() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard sender.draggingPasteboard.types?.contains(where: { $0 == .fileURL || ClipboardStore.isImage($0) }) == true else { return [] }
        clipboard.receivingDrop = true
        dragState?(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func draggingExited(_ sender: NSDraggingInfo?) { clipboard.receivingDrop = false; dragState?(false) }
    override func draggingEnded(_ sender: NSDraggingInfo) { clipboard.receivingDrop = false; dragState?(false) }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        defer { clipboard.receivingDrop = false; dragState?(false) }
        return clipboard.acceptDrop(from: sender.draggingPasteboard)
    }

    override func mouseEntered(with event: NSEvent) { hover?(true) }
    override func mouseExited(with event: NSEvent) { hover?(false) }

    override func draw(_ dirtyRect: NSRect) {
        let w = bounds.width
        let h = bounds.height
        let p = min(1, progress)
        let body = NSBezierPath()
        if !hasNotch && p == 0 {
            body.appendRoundedRect(bounds, xRadius: h / 2, yRadius: h / 2)
        } else {
            let lip = 9 * p
            let radius = min(h / 2, 7 + 12 * p)
            body.move(to: .zero)
            body.curve(to: NSPoint(x: lip, y: lip), controlPoint1: NSPoint(x: lip * 0.55, y: 0),
                       controlPoint2: NSPoint(x: lip, y: lip * 0.45))
            body.line(to: NSPoint(x: lip, y: h - radius))
            body.appendArc(from: NSPoint(x: lip, y: h), to: NSPoint(x: w / 2, y: h), radius: radius)
            body.line(to: NSPoint(x: w - lip - radius, y: h))
            body.appendArc(from: NSPoint(x: w - lip, y: h), to: NSPoint(x: w - lip, y: 0), radius: radius)
            body.line(to: NSPoint(x: w - lip, y: lip))
            body.curve(to: NSPoint(x: w, y: 0), controlPoint1: NSPoint(x: w - lip, y: lip * 0.45),
                       controlPoint2: NSPoint(x: w - lip * 0.55, y: 0))
            body.close()
        }
        NSColor.black.withAlphaComponent(1 - reveal).setFill()
        body.fill()
    }

    private var reveal: CGFloat {
        if progress >= 1 { return 1 }
        return max(0, (progress - 0.55) / 0.45)
    }

    override func layout() {
        super.layout()
        material.frame = bounds
        material.isHidden = reveal == 0
        material.alphaValue = reveal
        expanded.frame = NSRect(x: 21, y: bounds.height - Self.expandedDepth + 8, width: max(0, bounds.width - 42), height: Self.expandedDepth - 16)
        expanded.isHidden = reveal == 0
        expanded.alphaValue = reveal
        banner.frame = NSRect(x: 12, y: bounds.height - 30, width: max(0, bounds.width - 24), height: 26)
        banner.isHidden = hardware.activity == nil || progress > 0.08
        compact.isHidden = progress > 0.08 || hardware.activity != nil
        let size = min(18, max(8, bounds.height - 4))
        compact.frame = NSRect(x: 5, y: (bounds.height - size) / 2, width: max(0, bounds.width - 10), height: size)
    }
}


// Route drops over SwiftUI controls to the same destination as the collapsed notch.
final class ClipboardHostingView: NSHostingView<MediaView> {
    weak var owner: NotchView?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        owner?.draggingEntered(sender) ?? []
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func draggingExited(_ sender: NSDraggingInfo?) { owner?.draggingExited(sender) }
    override func draggingEnded(_ sender: NSDraggingInfo) { owner?.draggingEnded(sender) }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        owner?.performDragOperation(sender) ?? false
    }
}
