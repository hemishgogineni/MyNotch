import SwiftUI

struct ClipboardView: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label("Clipboard", systemImage: "clipboard").font(.headline)
                Spacer()
                Button("Clear", action: store.clearHistory)
                    .buttonStyle(.plain).font(.caption)
                    .disabled(store.entries.isEmpty)
                    .help("Clear MyNotch clipboard history")
            }
            if store.entries.isEmpty {
                Text("Copy an item or drop files here.").font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(store.entries) { clip in
                            if !clip.files.isEmpty {
                                FileClipRow(clip: clip) { store.restore(clip) }
                                    .frame(height: 23)
                            } else {
                                Button {
                                    store.restore(clip)
                                } label: {
                                    Label {
                                            Text(clip.title)
                                        } icon: {
                                            if let thumbnail = clip.thumbnail {
                                                Image(nsImage: thumbnail).resizable().scaledToFit().frame(width: 28, height: 20)
                                            } else {
                                                Image(systemName: clip.symbol)
                                            }
                                        }
                                        .font(.callout).lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 3).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Copies this item back to the clipboard")
                                .help("Copy this item again")
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
