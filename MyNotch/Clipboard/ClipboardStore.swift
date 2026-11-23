import AppKit
import Combine
import UniformTypeIdentifiers
import ImageIO

struct Clip: Identifiable {
    let id = UUID()
    let items: [[NSPasteboard.PasteboardType: Data]]
    let title: String
    let symbol: String
    let thumbnail: NSImage?
    var files: [URL] {
        items.compactMap { item in
            guard let data = item[.fileURL], let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.isFileURL else { return nil }
            return url
        }
    }
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
        _ = collect(from: board, expectedCount: count)
    }

    func clearHistory() {
        entries.removeAll()
        generation = board.changeCount
    }

    static func isImage(_ type: NSPasteboard.PasteboardType) -> Bool {
        UTType(type.rawValue)?.conforms(to: .image) == true
    }

    private func collect(from source: NSPasteboard, expectedCount: Int) -> Bool {
        guard let copied = source.pasteboardItems, !copied.isEmpty else { return false }
        let excluded = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]
        let formats: [NSPasteboard.PasteboardType] = [.fileURL, .URL, .string, .rtf, .html, .png, .tiff, .pdf]
        var items: [[NSPasteboard.PasteboardType: Data]] = []
        for item in copied {
            guard !item.types.contains(where: { excluded.contains($0.rawValue) }) else { return false }
            var representations: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types where formats.contains(type) || Self.isImage(type) {
                representations[type] = item.data(forType: type)
            }
            guard !representations.isEmpty else { return false }
            items.append(representations)
        }
        guard source.changeCount == expectedCount, let first = copied.first else { return false }
        let title: String
        let symbol: String
        if let path = first.string(forType: .fileURL), let url = URL(string: path) {
            title = items.count > 1 ? "\(items.count) files" : url.lastPathComponent
            symbol = "doc"
        } else if first.types.contains(where: { Self.isImage($0) }) {
            title = "Image"
            symbol = "photo"
        } else if let text = first.string(forType: .string) ?? first.string(forType: .URL) {
            title = String(text.prefix(160)).components(separatedBy: .newlines).joined(separator: " ")
            symbol = "text.alignleft"
        } else {
            title = first.types.contains(.pdf) ? "PDF" : "Formatted text"
            symbol = "doc"
        }
        guard source.changeCount == expectedCount else { return false }
        insert(items: items, title: title, symbol: symbol)
        return true
    }

    func acceptDrop(from source: NSPasteboard) -> Bool {
        guard timer != nil else { return false }
        if source.availableType(from: [.fileURL]) != nil { return holdFiles(from: source) }
        return collect(from: source, expectedCount: source.changeCount)
    }

    func holdFiles(from pasteboard: NSPasteboard) -> Bool {
        guard timer != nil, let urls = pasteboard.readObjects(forClasses: [NSURL.self],
              options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty else { return false }
        let items = urls.map { [NSPasteboard.PasteboardType.fileURL: $0.dataRepresentation] }
        insert(items: items, title: urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) files", symbol: "doc")
        return true
    }

    private func insert(items: [[NSPasteboard.PasteboardType: Data]], title: String, symbol: String) {
        entries.removeAll { $0.items == items }
        var thumbnail: NSImage?
        if symbol == "photo", let image = items.first?.first(where: { Self.isImage($0.key) }),
           let source = CGImageSourceCreateWithData(image.value as CFData, nil),
           let preview = CGImageSourceCreateThumbnailAtIndex(source, 0, [
               kCGImageSourceCreateThumbnailFromImageAlways: true,
               kCGImageSourceThumbnailMaxPixelSize: 56,
               kCGImageSourceCreateThumbnailWithTransform: true
           ] as CFDictionary) {
            thumbnail = NSImage(cgImage: preview, size: .zero)
        }
        entries.insert(Clip(items: items, title: title, symbol: symbol, thumbnail: thumbnail), at: 0)
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
