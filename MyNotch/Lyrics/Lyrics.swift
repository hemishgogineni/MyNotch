import Foundation

nonisolated struct LyricLine: Equatable {
    let time: Double
    let text: String
}

nonisolated struct LyricsRecord: Codable {
    var syncedLyrics: String?
    var plainLyrics: String?

    var lines: [LyricLine] {
        var result: [LyricLine] = []
        var offset = 0.0
        for row in (syncedLyrics ?? "").components(separatedBy: .newlines) {
            var tail = row.trimmingCharacters(in: .whitespaces)[...]
            var times: [Double] = []
            while tail.first == "[", let end = tail.firstIndex(of: "]") {
                let tag = tail[tail.index(after: tail.startIndex)..<end]
                if tag.hasPrefix("offset:"), let milliseconds = Double(tag.dropFirst(7)), milliseconds.isFinite {
                    offset = milliseconds / 1000
                } else {
                    let parts = tag.split(separator: ":")
                    guard parts.count == 2, let minutes = Int(parts[0]), minutes >= 0,
                          let seconds = Double(parts[1]), (0..<60).contains(seconds) else { break }
                    times.append(Double(minutes) * 60 + seconds)
                }
                tail = tail[tail.index(after: end)...]
            }
            let text = tail.trimmingCharacters(in: .whitespaces)
            result += times.map { LyricLine(time: $0, text: text) }
        }
        guard result.contains(where: { !$0.text.isEmpty }) else { return [] }
        return result.sorted { $0.time < $1.time }.map { LyricLine(time: max(0, $0.time - offset), text: $0.text) }
    }
}

extension Array where Element == LyricLine {
    func currentIndex(at position: Double) -> Int? {
        guard let index = lastIndex(where: { $0.time <= position }) else { return nil }
        return index
    }
}
