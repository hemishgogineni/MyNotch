import AppKit
import Combine

enum Player: String, CaseIterable {
    case music = "com.apple.Music"
    case spotify = "com.spotify.client"

    var notification: String {
        self == .music ? "com.apple.Music.playerInfo" : "com.spotify.client.PlaybackStateChanged"
    }

    var running: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: rawValue).isEmpty
    }
}

struct Track {
    let player: Player
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let elapsed: Double
    let playing: Bool
    let observed = ProcessInfo.processInfo.systemUptime
    let artwork: NSImage?
    let icon: NSImage?

    var position: Double {
        min(duration, max(0, elapsed + (playing ? ProcessInfo.processInfo.systemUptime - observed : 0)))
    }
}

enum Transport {
    case previous, toggle, next, seek(Double)
    var script: String {
        switch self {
        case .previous: "previous track"
        case .toggle: "playpause"
        case .next: "next track"
        case .seek(let seconds): "set player position to " + String(seconds)
        }
    }
}

final class MediaStore: NSObject, ObservableObject {
    @Published private(set) var track: Track?
    @Published private(set) var message = "Nothing playing"
    private var pending: Task<Void, Never>?

    func start() {
        for player in Player.allCases {
            DistributedNotificationCenter.default().addObserver(self, selector: #selector(changed(_:)),
                name: Notification.Name(player.notification), object: nil)
        }
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(applicationChanged(_:)),
                                                              name: name, object: nil)
        }
        refresh()
    }

    @objc private func applicationChanged(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let id = app.bundleIdentifier, let player = Player(rawValue: id) else { return }
        refresh(preferred: player)
    }

    @objc private func changed(_ note: Notification) {
        refresh(preferred: Player.allCases.first { $0.notification == note.name.rawValue })
    }

    func refresh(preferred: Player? = nil) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            let first = preferred ?? track?.player ?? .music
            var paused: Track?
            var denied = false
            for player in [first] + Player.allCases.filter({ $0 != first }) where player.running {
                let artFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                defer { try? FileManager.default.removeItem(at: artFile) }
                let script = Self.snapshotScript(player: player)
                let result = await Self.run(script, arguments: [artFile.path])
                guard !Task.isCancelled else { return }
                denied = denied || result.contains("(-1743)")
                let fields = result.components(separatedBy: "\u{1e}")
                guard fields.count == 6, let duration = Double(fields[3]), let elapsed = Double(fields[4]) else { continue }
                let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: player.rawValue)
                    .map { NSWorkspace.shared.icon(forFile: $0.path) }
                let item = Track(player: player, title: fields[0], artist: fields[1], album: fields[2],
                                 duration: max(0, duration), elapsed: elapsed, playing: fields[5] == "playing",
                                 artwork: NSImage(contentsOf: artFile), icon: icon)
                if item.playing { track = item; return }
                if paused == nil { paused = item }
            }
            track = paused
            message = denied ? "Allow player access in Privacy & Security → Automation" : "Nothing playing"
        }
    }

    func send(_ command: Transport) {
        guard let player = track?.player, player.running else { return }
        Task {
            _ = await Self.run("tell application id \"\(player.rawValue)\" to \(command.script)")
            refresh(preferred: player)
        }
    }

    private static func snapshotScript(player: Player) -> String {
        let art = player == .music ? """
            try
                set bytes to raw data of artwork 1 of t
                set f to open for access (POSIX file artPath) with write permission
                try
                    write bytes to f
                end try
                close access f
            end try
            """ : ""
        return """
            on run args
                set artPath to item 1 of args
                tell application id "\(player.rawValue)"
                    if not running then return ""
                    if player state is stopped then return ""
                    set s to "paused"
                    if player state is playing then set s to "playing"
                    set t to current track
                    set d to duration of t
                    \(player == .spotify ? "set d to d / 1000" : "")
                    \(art)
                    set fields to {name of t, artist of t, album of t, d, player position, s}
                end tell
                set AppleScript's text item delimiters to ASCII character 30
                return fields as text
            end run
            """
    }

    nonisolated private static func run(_ script: String, arguments: [String] = []) async -> String {
        await Task.detached(priority: .utility) {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script] + arguments
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .newlines)
            } catch { return "" }
        }.value
    }
}
