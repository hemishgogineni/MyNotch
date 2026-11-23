import SwiftUI

struct ClipboardView: View {
    @ObservedObject var store: ClipboardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label("Clipboard", systemImage: "clipboard").font(.headline)
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
                                    Label(clip.title, systemImage: clip.symbol)
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
