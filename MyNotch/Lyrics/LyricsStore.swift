import Foundation
import CryptoKit
import Combine

struct LyricsQuery: Hashable {
    let artist: String
    let title: String
    let album: String
    let duration: Int

    init?(_ track: Track) {
        guard !track.title.isEmpty, !track.artist.isEmpty, track.duration.isFinite,
              (1...3600).contains(track.duration.rounded()) else { return nil }
        artist = track.artist
        title = track.title
        album = track.album
        duration = Int(track.duration.rounded())
    }

    var url: URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "lrclib.net"
        components.path = "/api/get"
        components.queryItems = [
            URLQueryItem(name: "artist_name", value: artist), URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "album_name", value: album), URLQueryItem(name: "duration", value: String(duration))
        ]
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url!
    }
}

final class LyricsStore: ObservableObject {
    enum State {
        case loading, missing, unavailable, synced([LyricLine]), plain(String)
    }
    @Published private(set) var state = State.missing
    private var query: LyricsQuery?
    private var task: Task<Void, Never>?
    private var subscription: AnyCancellable?

    func follow(_ media: MediaStore) {
        subscription = media.$track.map { track in track.flatMap { LyricsQuery($0) } }.removeDuplicates().sink { [weak self] in
            self?.load($0)
        }
    }

    func retry() { load(query) }

    private func load(_ next: LyricsQuery?) {
        task?.cancel()
        query = next
        guard let next else { state = .missing; return }
        state = .loading
        task = Task {
            do {
                let record = try await Self.fetch(next.url)
                try Task.checkCancellation()
                let lines = record.lines
                if !lines.isEmpty { state = .synced(lines) }
                else if let plain = record.plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines), !plain.isEmpty {
                    state = .plain(plain)
                } else { state = .missing }
            } catch {
                if !Task.isCancelled { state = .unavailable }
            }
        }
    }

    nonisolated static func fetch(_ url: URL, session: URLSession = .shared,
                                  folder: URL = URL.cachesDirectory.appending(path: "MyNotch/Lyrics")) async throws -> LyricsRecord {
        let key = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        let file = folder.appending(path: key)
        if let data = try? Data(contentsOf: file), let record = try? JSONDecoder().decode(LyricsRecord.self, from: data) {
            return record
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.setValue("MyNotch/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request, delegate: LyricsRedirectPolicy())
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 404 { return LyricsRecord() }
        guard http.statusCode == 200 else { throw URLError(.badServerResponse) }
        let record = try JSONDecoder().decode(LyricsRecord.self, from: data)
        try Task.checkCancellation()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
        return record
    }
}


private final class LyricsRedirectPolicy: NSObject, URLSessionTaskDelegate {
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask,
                                willPerformHTTPRedirection response: HTTPURLResponse,
                                newRequest request: URLRequest,
                                completionHandler: @escaping (URLRequest?) -> Void) {
        let allowed = request.url?.scheme == "https" && request.url?.host == "lrclib.net"
        completionHandler(allowed ? request : nil)
    }
}
