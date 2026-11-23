import SwiftUI

struct FileClipRow: NSViewRepresentable {
    let clip: Clip
    let copy: () -> Void

    func makeNSView(context: Context) -> FileButton {
        let button = FileButton()
        button.isBordered = false
        button.alignment = .left
        button.imagePosition = .imageLeading
        button.lineBreakMode = .byTruncatingMiddle
        button.target = button
        button.action = #selector(FileButton.copyEntry)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return button
    }

    func updateNSView(_ button: FileButton, context: Context) {
        button.files = clip.files
        button.copyEntryAction = copy
        button.title = clip.title
        button.toolTip = clip.files.map(\.lastPathComponent).joined(separator: "\n")
        button.image = NSImage(systemSymbolName: clip.files.count > 1 ? "doc.on.doc" : "doc", accessibilityDescription: nil)
    }
}

final class FileButton: NSButton, NSDraggingSource {
    var files: [URL] = []
    var copyEntryAction: (() -> Void)?
    private var down: NSEvent?

    @objc func copyEntry() { copyEntryAction?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { down = event }
    override func mouseUp(with event: NSEvent) {
        defer { down = nil }
        if down != nil, bounds.contains(convert(event.locationInWindow, from: nil)) { copyEntry() }
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start = down, !files.isEmpty else { return }
        let a = start.locationInWindow
        let b = event.locationInWindow
        guard hypot(a.x - b.x, a.y - b.y) >= 3 else { return }
        down = nil
        let origin = convert(a, from: nil)
        let items = files.map { url in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            item.setDraggingFrame(NSRect(origin: origin, size: NSSize(width: 32, height: 32)), contents: icon)
            return item
        }
        beginDraggingSession(with: items, event: start, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}
