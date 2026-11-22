import SwiftUI

struct LyricsView: View {
    @ObservedObject var lyrics: LyricsStore
    let track: Track

    var body: some View {
        Group {
            switch lyrics.state {
            case .loading: Text("Loading lyrics…")
            case .missing: Text("No lyrics found")
            case .unavailable: Button("Lyrics unavailable · Retry") { lyrics.retry() }
            case .plain(let text):
                ScrollView { Text(text).frame(maxWidth: .infinity, alignment: .leading) }
            case .synced(let lines):
                let position = track.position
                let now = Date()
                let dates = track.playing ? lines.filter { $0.time > position }.map {
                    now.addingTimeInterval($0.time - position)
                } : []
                TimelineView(.explicit([now] + dates)) { _ in
                    let index = lines.currentIndex(at: track.position)
                    VStack(alignment: .leading, spacing: 3) {
                        if let index, !lines[index].text.isEmpty {
                            Text(lines[index].text).fontWeight(.semibold).foregroundStyle(.white).lineLimit(2)
                        }
                        let next = (index ?? -1) + 1
                        if lines.indices.contains(next) {
                            Text(lines[next].text).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
        }
        .font(.callout)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lyrics")
    }
}
