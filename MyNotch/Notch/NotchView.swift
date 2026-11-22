import SwiftUI

final class NotchView: NSView {
    private let expanded: NSHostingView<MediaView>
    private let compact: NSHostingView<CompactMedia>
    private let hasNotch: Bool
    var hover: ((Bool) -> Void)?
    var progress: CGFloat = 0 { didSet { needsDisplay = true; needsLayout = true } }
    override var isFlipped: Bool { true }

    init(hasNotch: Bool, media: MediaStore, lyrics: LyricsStore) {
        self.hasNotch = hasNotch
        expanded = NSHostingView(rootView: MediaView(media: media, lyrics: lyrics))
        compact = NSHostingView(rootView: CompactMedia(media: media))
        super.init(frame: .zero)
        addSubview(expanded)
        addSubview(compact)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
                                       owner: self, userInfo: nil))
        setAccessibilityElement(false)
        setAccessibilityLabel("MyNotch")
    }

    required init?(coder: NSCoder) { nil }

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
        NSColor.black.setFill()
        body.fill()
    }

    override func layout() {
        super.layout()
        expanded.frame = NSRect(x: 21, y: bounds.height - 189, width: max(0, bounds.width - 42), height: 182)
        expanded.isHidden = progress < 0.92
        compact.isHidden = progress > 0.08
        let size = min(18, max(8, bounds.height - 4))
        compact.frame = NSRect(x: 5, y: (bounds.height - size) / 2, width: max(0, bounds.width - 10), height: size)
    }
}
