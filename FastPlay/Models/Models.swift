//
//  Models.swift
//  FastPlay
//
//  Data models for database entities
//

import Foundation

// MARK: - Bookmark

struct Bookmark {
    var id: Int64?
    var name: String
    var filepath: String
    var position: Double
    var createdAt: String
}

// MARK: - Radio Station

struct RadioStation {
    var id: Int64?
    var name: String
    var url: String
    var genre: String?
    var country: String?
    var bitrate: Int?
}

// MARK: - Podcast Subscription

struct PodcastSubscription {
    var id: Int64?
    var title: String
    var feedURL: String
    var description: String
    var author: String
    var imageURL: String?
}

// MARK: - Podcast Episode

struct PodcastEpisode {
    var id: Int64?
    var subscriptionId: Int64?
    var title: String
    var description: String
    var audioURL: String
    var duration: Int
    var publishDate: Date?
    var guid: String
    var played: Bool
    var localPath: String?
}

// MARK: - Scheduled Event

enum ScheduleAction: Int {
    case playback = 0
    case recording = 1
    case both = 2

    var displayName: String {
        switch self {
        case .playback: return "Play"
        case .recording: return "Record"
        case .both: return "Play+Record"
        }
    }
}

enum ScheduleSource: Int {
    case file = 0
    case radio = 1
}

enum ScheduleRepeat: Int {
    case none = 0
    case daily = 1
    case weekly = 2
    case weekdays = 3
    case weekends = 4
    case monthly = 5

    var displayName: String {
        switch self {
        case .none: return "Once"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .weekdays: return "Weekdays"
        case .weekends: return "Weekends"
        case .monthly: return "Monthly"
        }
    }
}

enum ScheduleStopAction: Int {
    case stopBoth = 0
    case stopPlayback = 1
    case stopRecording = 2
}

struct ScheduledEvent {
    var id: Int64?
    var name: String
    var action: ScheduleAction
    var sourceType: ScheduleSource
    var sourcePath: String          // File path or radio station URL
    var radioStationId: Int64       // Radio station ID (0 if file)
    var scheduledTime: Int64        // Unix timestamp of next scheduled run
    var repeatType: ScheduleRepeat
    var enabled: Bool
    var lastRun: Int64              // Unix timestamp of last run
    var duration: Int               // Duration in minutes (0 = no limit)
    var stopAction: ScheduleStopAction

    /// Display string used in the scheduler list
    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let timeStr = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(scheduledTime)))
        let prefix = enabled ? "[On] " : "[Off] "
        var result = "\(prefix)\(name) - \(action.displayName) @ \(timeStr) (\(repeatType.displayName))"
        if duration > 0 {
            result += " [\(duration)m]"
        }
        return result
    }
}

// MARK: - Song History Entry

struct SongHistoryEntry {
    let id: Int64
    let title: String
    let date: Date
}

// MARK: - Chapter

struct Chapter {
    let position: Double   // Position in seconds
    let name: String       // Chapter name
}

// MARK: - Track Info

struct TrackInfo {
    let title: String?
    let artist: String?
    let album: String?
    let year: String?
    let genre: String?
    let comment: String?
    let duration: Double
    let bitrate: Int
    let sampleRate: Int
    let channels: Int

    var displayTitle: String {
        if let title = title, !title.isEmpty {
            if let artist = artist, !artist.isEmpty {
                return "\(artist) - \(title)"
            }
            return title
        }
        return "Unknown"
    }
}

// MARK: - Seek Amount (matching Windows)

struct SeekAmount {
    let amount: Double     // Amount in seconds or tracks
    let label: String      // Display label
    let isTrack: Bool      // True if amount is in tracks, false if seconds
}

/// Default seek amounts (matching Windows g_seekAmounts)
let defaultSeekAmounts: [SeekAmount] = [
    SeekAmount(amount: 1.0, label: "1 second", isTrack: false),
    SeekAmount(amount: 5.0, label: "5 seconds", isTrack: false),
    SeekAmount(amount: 10.0, label: "10 seconds", isTrack: false),
    SeekAmount(amount: 30.0, label: "30 seconds", isTrack: false),
    SeekAmount(amount: 60.0, label: "1 minute", isTrack: false),
    SeekAmount(amount: 300.0, label: "5 minutes", isTrack: false),
    SeekAmount(amount: 600.0, label: "10 minutes", isTrack: false),
    SeekAmount(amount: 1800.0, label: "30 minutes", isTrack: false),
    SeekAmount(amount: 3600.0, label: "1 hour", isTrack: false),
    SeekAmount(amount: 1.0, label: "1 track", isTrack: true),
    SeekAmount(amount: 5.0, label: "5 tracks", isTrack: true),
    SeekAmount(amount: 10.0, label: "10 tracks", isTrack: true),
]

// MARK: - Global Hotkey

struct GlobalHotkey {
    let id: Int
    let actionId: Int      // Menu action ID
    let keyCode: UInt32
    let modifiers: UInt32
}

// MARK: - Effect Type

enum EffectType: Int, CaseIterable {
    case volume = 0
    case pitch = 1
    case tempo = 2
    case rate = 3

    var name: String {
        switch self {
        case .volume: return "Volume"
        case .pitch: return "Pitch"
        case .tempo: return "Tempo"
        case .rate: return "Rate"
        }
    }
}

// MARK: - Recording Format

enum RecordingFormat: Int, CaseIterable {
    case wav = 0
    case mp3 = 1
    case ogg = 2
    case flac = 3

    var name: String {
        switch self {
        case .wav: return "WAV"
        case .mp3: return "MP3"
        case .ogg: return "OGG"
        case .flac: return "FLAC"
        }
    }

    var displayName: String {
        switch self {
        case .wav: return "WAV (Lossless)"
        case .mp3: return "MP3"
        case .ogg: return "OGG Vorbis"
        case .flac: return "FLAC (Lossless)"
        }
    }

    var fileExtension: String {
        switch self {
        case .wav: return "wav"
        case .mp3: return "mp3"
        case .ogg: return "ogg"
        case .flac: return "flac"
        }
    }
}

// MARK: - Reverb Algorithm

enum ReverbAlgorithm: Int {
    case off = 0
    case freeverb = 1
    case dx8 = 2
    case i3dl2 = 3

    var name: String {
        switch self {
        case .off: return "Off"
        case .freeverb: return "Freeverb"
        case .dx8: return "DX8"
        case .i3dl2: return "I3DL2"
        }
    }
}
