//
//  PlaylistManager.swift
//  FastPlay
//
//  Playlist management for tracks and folders
//

import Foundation

class PlaylistManager {

    // MARK: - Singleton

    static let shared = PlaylistManager()

    // MARK: - Properties

    private(set) var tracks: [String] = []     // File paths or URLs
    private(set) var currentIndex: Int = -1

    /// Current track path/URL (nil if no track loaded)
    var currentTrackPath: String? {
        guard currentIndex >= 0 && currentIndex < tracks.count else { return nil }
        return tracks[currentIndex]
    }

    /// Current track name (filename without extension)
    var currentTrackName: String? {
        guard let path = currentTrackPath else { return nil }

        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            // For URLs, use the URL or stream title
            return AudioEngine.shared.onMetadataChange != nil ? path : URL(string: path)?.lastPathComponent ?? path
        } else {
            // For files, use filename without extension
            return (path as NSString).deletingPathExtension.components(separatedBy: "/").last
        }
    }

    /// Number of tracks in playlist
    var count: Int { tracks.count }

    /// Whether shuffle is enabled (delegates to settings)
    var shuffleEnabled: Bool {
        get { SettingsManager.shared.shuffle }
        set { SettingsManager.shared.shuffle = newValue }
    }

    // MARK: - Shuffle State

    private var shuffleOrder: [Int] = []
    private var shuffleIndex: Int = -1

    // MARK: - Initialization

    private init() {
        // Register for track end callback
        AudioEngine.shared.onTrackEnd = { [weak self] in
            self?.handleTrackEnd()
        }
    }

    // MARK: - Playlist Management

    /// Clear the playlist
    func clear() {
        tracks.removeAll()
        currentIndex = -1
        shuffleOrder.removeAll()
        shuffleIndex = -1
    }

    /// Add a single file to the playlist
    func addFile(_ path: String) {
        tracks.append(path)
        updateShuffleOrder()
    }

    /// Add a URL to the playlist
    func addURL(_ url: String) {
        tracks.append(url)
        updateShuffleOrder()
    }

    /// Add all audio files from a folder
    func addFolder(_ folderPath: String) {
        let fileManager = FileManager.default
        let supportedExtensions = ["mp3", "wav", "ogg", "flac", "m4a", "aac", "opus", "wma", "aiff", "ape", "wv", "mid", "midi"]

        guard let enumerator = fileManager.enumerator(atPath: folderPath) else { return }

        var files: [String] = []

        while let file = enumerator.nextObject() as? String {
            let ext = (file as NSString).pathExtension.lowercased()
            if supportedExtensions.contains(ext) {
                let fullPath = (folderPath as NSString).appendingPathComponent(file)
                files.append(fullPath)
            }
        }

        // Sort alphabetically
        files.sort { $0.localizedStandardCompare($1) == .orderedAscending }

        tracks.append(contentsOf: files)
        updateShuffleOrder()
    }

    /// Add files from an M3U playlist
    func addM3U(_ path: String) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }

        let basePath = (path as NSString).deletingLastPathComponent
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Handle relative vs absolute paths
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                tracks.append(trimmed)
            } else if trimmed.hasPrefix("/") {
                tracks.append(trimmed)
            } else {
                let fullPath = (basePath as NSString).appendingPathComponent(trimmed)
                tracks.append(fullPath)
            }
        }

        updateShuffleOrder()
    }

    /// Add files from a PLS playlist
    func addPLS(_ path: String) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }

        let basePath = (path as NSString).deletingLastPathComponent
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Look for File1=, File2=, etc.
            if trimmed.lowercased().hasPrefix("file") {
                if let equalsIndex = trimmed.firstIndex(of: "=") {
                    let value = String(trimmed[trimmed.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)

                    if value.hasPrefix("http://") || value.hasPrefix("https://") {
                        tracks.append(value)
                    } else if value.hasPrefix("/") {
                        tracks.append(value)
                    } else {
                        let fullPath = (basePath as NSString).appendingPathComponent(value)
                        tracks.append(fullPath)
                    }
                }
            }
        }

        updateShuffleOrder()
    }

    /// Remove track at index
    func removeTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }

        tracks.remove(at: index)

        // Adjust current index if needed
        if index < currentIndex {
            currentIndex -= 1
        } else if index == currentIndex {
            currentIndex = -1
        }

        updateShuffleOrder()
    }

    /// Move track from one position to another
    @discardableResult
    func moveTrack(from: Int, to: Int) -> Bool {
        guard from >= 0 && from < tracks.count && to >= 0 && to < tracks.count else { return false }

        let track = tracks.remove(at: from)
        tracks.insert(track, at: to)

        // Update current index
        if currentIndex == from {
            currentIndex = to
        } else if from < currentIndex && to >= currentIndex {
            currentIndex -= 1
        } else if from > currentIndex && to <= currentIndex {
            currentIndex += 1
        }

        updateShuffleOrder()
        return true
    }

    /// Get track name at index
    func trackName(at index: Int) -> String? {
        guard index >= 0 && index < tracks.count else { return nil }
        let path = tracks[index]

        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)?.lastPathComponent ?? path
        } else {
            return (path as NSString).lastPathComponent
        }
    }

    // MARK: - Playback

    /// Play track at index
    func playTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }

        currentIndex = index
        let path = tracks[index]

        var success = false
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            success = AudioEngine.shared.loadURL(path)
        } else {
            success = AudioEngine.shared.loadFile(path)
        }

        if success {
            AudioEngine.shared.play()

            // Announce track if enabled
            if let name = currentTrackName {
                AccessibilityManager.announceTrack(name)
            }
        }
    }

    /// Play next track
    func next() {
        guard !tracks.isEmpty else { return }

        if shuffleEnabled && !shuffleOrder.isEmpty {
            // Shuffle mode
            shuffleIndex += 1
            if shuffleIndex >= shuffleOrder.count {
                // Reshuffle at end
                generateShuffleOrder()
                shuffleIndex = 0
            }
            playTrack(at: shuffleOrder[shuffleIndex])
        } else {
            // Normal mode
            let nextIndex = currentIndex + 1
            if nextIndex < tracks.count {
                playTrack(at: nextIndex)
            } else if SettingsManager.shared.autoAdvance {
                // Wrap to beginning
                playTrack(at: 0)
            }
        }
    }

    /// Play previous track
    func previous() {
        guard !tracks.isEmpty else { return }

        if shuffleEnabled && !shuffleOrder.isEmpty {
            // Shuffle mode
            shuffleIndex -= 1
            if shuffleIndex < 0 {
                shuffleIndex = shuffleOrder.count - 1
            }
            playTrack(at: shuffleOrder[shuffleIndex])
        } else {
            // Normal mode
            let prevIndex = currentIndex - 1
            if prevIndex >= 0 {
                playTrack(at: prevIndex)
            } else {
                // Wrap to end
                playTrack(at: tracks.count - 1)
            }
        }
    }

    /// Handle track end
    private func handleTrackEnd() {
        if SettingsManager.shared.autoAdvance {
            next()
        }
    }

    // MARK: - Shuffle

    private func updateShuffleOrder() {
        if shuffleEnabled {
            generateShuffleOrder()
        }
    }

    private func generateShuffleOrder() {
        shuffleOrder = Array(0..<tracks.count)
        shuffleOrder.shuffle()

        // If we have a current track, make sure it's first in shuffle order
        if currentIndex >= 0 {
            if let pos = shuffleOrder.firstIndex(of: currentIndex) {
                shuffleOrder.remove(at: pos)
                shuffleOrder.insert(currentIndex, at: 0)
            }
            shuffleIndex = 0
        } else {
            shuffleIndex = -1
        }
    }

    // MARK: - Export

    /// Export playlist to M3U file
    func exportM3U(to path: String) -> Bool {
        var content = "#EXTM3U\n"

        for track in tracks {
            // Try to get duration (0 if unknown)
            let duration = -1  // TODO: Get actual duration

            // Get display name
            let name: String
            if track.hasPrefix("http://") || track.hasPrefix("https://") {
                name = URL(string: track)?.lastPathComponent ?? track
            } else {
                name = (track as NSString).lastPathComponent
            }

            content += "#EXTINF:\(duration),\(name)\n"
            content += "\(track)\n"
        }

        do {
            // Write with UTF-8 BOM for compatibility
            let bom = "\u{FEFF}"
            try (bom + content).write(toFile: path, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
}
