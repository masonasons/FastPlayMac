//
//  ScriptingBridge.swift
//  FastPlay
//
//  AppleScript scripting support for Airfoil and macOS automation
//

import AppKit

// MARK: - Application Scripting Extension

extension NSApplication {

    // MARK: - Track Metadata Properties

    /// The title of the currently playing track
    @objc var scriptingTrackTitle: String {
        let tags = AudioEngine.shared.getCurrentTags()
        if let title = tags["title"], !title.isEmpty {
            return title
        }
        return PlaylistManager.shared.currentTrackName ?? ""
    }

    /// The artist of the currently playing track
    @objc var scriptingArtist: String {
        let tags = AudioEngine.shared.getCurrentTags()
        return tags["artist"] ?? ""
    }

    /// The album of the currently playing track
    @objc var scriptingAlbum: String {
        let tags = AudioEngine.shared.getCurrentTags()
        return tags["album"] ?? ""
    }

    /// The duration of the current track in seconds
    @objc var scriptingDuration: Int {
        let duration = AudioEngine.shared.duration
        return duration > 0 ? Int(duration) : 0
    }

    /// The artwork of the currently playing track as TIFF data
    @objc var scriptingArtwork: Data? {
        return AudioEngine.shared.getArtworkData()
    }

    /// The current playback state
    @objc var scriptingPlayerState: String {
        switch AudioEngine.shared.state {
        case .playing:
            return "playing"
        case .paused:
            return "paused"
        case .stopped, .stalled:
            return "stopped"
        }
    }

    /// The current playback position in seconds (read/write)
    @objc var scriptingPlayerPosition: Double {
        get {
            return AudioEngine.shared.currentPosition
        }
        set {
            AudioEngine.shared.seek(to: newValue)
        }
    }
}

// MARK: - Script Commands

/// PlayPause command
@objc(PlayPauseCommand)
class PlayPauseCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        AudioEngine.shared.togglePlayPause()
        return nil
    }
}

/// Next track command
@objc(NextTrackCommand)
class NextTrackCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        PlaylistManager.shared.next()
        return nil
    }
}

/// Previous track command
@objc(PreviousTrackCommand)
class PreviousTrackCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        PlaylistManager.shared.previous()
        return nil
    }
}
