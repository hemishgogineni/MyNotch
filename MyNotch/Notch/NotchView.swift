import AppKit

final class NotchView: NSView {
    private let hasNotch: Bool
    var hover: ((Bool) -> Void)?
    var progress: CGFloat = 0 { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }

    init(hasNotch: Bool) {
        self.hasNotch = hasNotch
        super.init(frame: .zero)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
                                       owner: self, userInfo: nil))
        setAccessibilityElement(true)
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
        guard p > 0.55 else { return }
        let title = NSAttributedString(string: "MyNotch", attributes: [
            .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent((p - 0.55) / 0.45)
        ])
        title.draw(at: NSPoint(x: (w - title.size().width) / 2, y: h - 31 - title.size().height / 2))
    }
}
