import SwiftUI

struct MediaView: View {
    @ObservedObject var media: MediaStore
    @ObservedObject var lyrics: LyricsStore
    @State private var scrub: Double?
    var body: some View {
        Group {
            if let track = media.track {
                VStack(spacing: 8) {
                    HStack(spacing: 10) {
                        Cover(track: track).frame(width: 42, height: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.title).font(.headline)
                            Text(track.artist).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .lineLimit(1)
                        Spacer(minLength: 4)
                        if let icon = track.icon {
                            Image(nsImage: icon).resizable().frame(width: 20, height: 20)
                        }
                    }
                    TimelineView(.periodic(from: .now, by: track.playing ? 1 : 86400)) { _ in
                        Slider(value: Binding(get: { scrub ?? track.position }, set: { scrub = $0 }),
                               in: 0...max(1, track.duration)) { Text("Playback position") }
                            onEditingChanged: { editing in
                                if !editing, let value = scrub { media.send(.seek(value)); scrub = nil }
                            }
                            .labelsHidden().disabled(track.duration <= 0)
                    }
                    transport(for: track)
                    LyricsView(lyrics: lyrics, track: track).frame(height: 54)
                }
            } else {
                Text(media.message).font(.subheadline).foregroundStyle(.secondary)
            }
        }.environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func transport(for track: Track) -> some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 6) {
                buttons(for: track).buttonStyle(.glass)
            }
        } else {
            buttons(for: track).buttonStyle(.bordered)
        }
    }

    private func buttons(for track: Track) -> some View {
        HStack(spacing: 12) {
            control("Previous track", "backward.fill", .previous)
            control(track.playing ? "Pause" : "Play", track.playing ? "pause.fill" : "play.fill", .toggle)
            control("Next track", "forward.fill", .next)
        }
        .controlSize(.small)
    }

    private func control(_ label: String, _ symbol: String, _ action: Transport) -> some View {
        Button { media.send(action) } label: {
            Image(systemName: symbol).frame(width: 28, height: 23)
        }.accessibilityLabel(label).help(label)
    }
}

struct Cover: View {
    let track: Track
    var body: some View {
        Group {
            if let image = track.artwork ?? track.icon {
                Image(nsImage: image).resizable().scaledToFill()
            } else { Image(systemName: "music.note") }
        }.clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct CompactMedia: View {
    @ObservedObject var media: MediaStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var body: some View {
        if let track = media.track, track.playing {
            HStack {
                Cover(track: track).aspectRatio(1, contentMode: .fit)
                Spacer()
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
                    .foregroundStyle(.white)
            }
        }
    }
}
