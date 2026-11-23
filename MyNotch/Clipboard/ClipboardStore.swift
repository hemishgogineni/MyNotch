import AppKit
import Combine

struct Clip: Identifiable {
    let id = UUID()
    let items: [[NSPasteboard.PasteboardType: Data]]
    let title: String
    let symbol: String
}

final class ClipboardStore: NSObject, ObservableObject {
    @Published private(set) var entries: [Clip] = []
    private let board: NSPasteboard
    private var generation = 0
    private var timer: Timer?

    init(board: NSPasteboard = .general) { self.board = board }

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(suspend), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(resume), name: NSWorkspace.didWakeNotification, object: nil)
        resume()
    }

    @objc func resume() {
        timer?.invalidate()
        generation = board.changeCount
        let tick = Timer(timeInterval: 0.45, target: self, selector: #selector(capture), userInfo: nil, repeats: true)
        tick.tolerance = 0.1
        RunLoop.main.add(tick, forMode: .common)
        timer = tick
    }

    @objc func suspend() {
        timer?.invalidate()
        timer = nil
        entries.removeAll()
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        suspend()
    }

    @objc func capture() {
        let count = board.changeCount
        guard timer != nil, count != generation else { return }
        generation = count
        guard let copied = board.pasteboardItems, !copied.isEmpty else { return }
        let excluded = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]
        let formats: [NSPasteboard.PasteboardType] = [.fileURL, .URL, .string, .rtf, .html, .png, .tiff, .pdf]
        var items: [[NSPasteboard.PasteboardType: Data]] = []
        for item in copied {
            guard !item.types.contains(where: { excluded.contains($0.rawValue) }) else { return }
            var representations: [NSPasteboard.PasteboardType: Data] = [:]
            for type in formats where item.types.contains(type) {
                representations[type] = item.data(forType: type)
            }
            guard !representations.isEmpty else { return }
            items.append(representations)
        }
        guard board.changeCount == count, let first = copied.first else { return }
        let title: String
        let symbol: String
        if let path = first.string(forType: .fileURL), let url = URL(string: path) {
            title = items.count > 1 ? "\(items.count) files" : url.lastPathComponent
            symbol = "doc"
        } else if let text = first.string(forType: .string) ?? first.string(forType: .URL) {
            title = String(text.prefix(160)).components(separatedBy: .newlines).joined(separator: " ")
            symbol = "text.alignleft"
        } else if first.types.contains(.png) || first.types.contains(.tiff) {
            title = "Image"
            symbol = "photo"
        } else {
            title = first.types.contains(.pdf) ? "PDF" : "Formatted text"
            symbol = "doc"
        }
        guard board.changeCount == count else { return }
        entries.removeAll { $0.items == items }
        entries.insert(Clip(items: items, title: title, symbol: symbol), at: 0)
    }

    func restore(_ clip: Clip) {
        let objects = clip.items.map { representations in
            let item = NSPasteboardItem()
            for (type, data) in representations { item.setData(data, forType: type) }
            return item
        }
        board.clearContents()
        board.writeObjects(objects)
        generation = board.changeCount
    }
}
