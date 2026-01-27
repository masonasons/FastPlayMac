//
//  AccessibilityManager.swift
//  FastPlay
//
//  Accessibility announcements using NSAccessibility
//  Replaces Windows Universal Speech
//

import AppKit
import Accessibility

/// Manages accessibility announcements for screen reader users
class AccessibilityManager {

    // MARK: - Singleton

    static let shared = AccessibilityManager()

    private init() {}

    // MARK: - Announcements

    /// Announce a message to VoiceOver
    /// - Parameter message: The message to announce
    static func announce(_ message: String) {
        shared.announce(message)
    }

    /// Announce a message to VoiceOver
    /// - Parameter message: The message to announce
    func announce(_ message: String) {
        guard !message.isEmpty else { return }

        DispatchQueue.main.async {
            // Use macOS 14+ Accessibility framework API
            if #available(macOS 14.0, *) {
                let announcement = AccessibilityNotification.Announcement(message)
                announcement.post()
                return
            }

            // Legacy approach for older macOS
            guard let window = NSApp.mainWindow ?? NSApp.keyWindow ?? NSApp.windows.first else {
                return
            }

            let userInfo: [NSAccessibility.NotificationUserInfoKey: Any] = [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.high
            ]

            NSAccessibility.post(
                element: window,
                notification: .announcementRequested,
                userInfo: userInfo
            )
        }
    }

    /// Announce a message with low priority (won't interrupt current speech)
    /// - Parameter message: The message to announce
    func announceLowPriority(_ message: String) {
        guard !message.isEmpty else { return }

        DispatchQueue.main.async {
            // Use macOS 14+ Accessibility framework API
            if #available(macOS 14.0, *) {
                let announcement = AccessibilityNotification.Announcement(message)
                announcement.post()
                return
            }

            // Legacy approach for older macOS
            guard let window = NSApp.mainWindow ?? NSApp.keyWindow ?? NSApp.windows.first else {
                return
            }

            let userInfo: [NSAccessibility.NotificationUserInfoKey: Any] = [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.low
            ]

            NSAccessibility.post(
                element: window,
                notification: .announcementRequested,
                userInfo: userInfo
            )
        }
    }

    // MARK: - Formatted Announcements

    /// Announce time in human-readable format
    /// - Parameter seconds: Time in seconds
    static func announceTime(_ seconds: Double) {
        let formatted = formatTime(seconds)
        announce(formatted)
    }

    /// Announce volume level
    /// - Parameter volume: Volume as 0.0-4.0
    static func announceVolume(_ volume: Float) {
        let percent = Int(volume * 100)
        announce("\(percent) percent")
    }

    /// Announce pitch in semitones
    /// - Parameter semitones: Pitch shift in semitones
    static func announcePitch(_ semitones: Float) {
        if semitones == 0 {
            announce("Pitch normal")
        } else if semitones > 0 {
            announce("Pitch plus \(String(format: "%.1f", semitones)) semitones")
        } else {
            announce("Pitch minus \(String(format: "%.1f", abs(semitones))) semitones")
        }
    }

    /// Announce tempo percentage
    /// - Parameter percent: Tempo change as percentage (-50 to +100)
    static func announceTempo(_ percent: Float) {
        if percent == 0 {
            announce("Tempo normal")
        } else if percent > 0 {
            announce("Tempo plus \(Int(percent)) percent")
        } else {
            announce("Tempo minus \(Int(abs(percent))) percent")
        }
    }

    /// Announce rate multiplier
    /// - Parameter rate: Rate as multiplier (0.5-2.0)
    static func announceRate(_ rate: Float) {
        if rate == 1.0 {
            announce("Rate normal")
        } else {
            announce("Rate \(String(format: "%.2f", rate))x")
        }
    }

    /// Announce track name
    /// - Parameter name: Track name
    static func announceTrack(_ name: String) {
        guard SettingsManager.shared.speechTrackChange else { return }
        announce("Now playing: \(name)")
    }

    // MARK: - Utility

    /// Format time in seconds to human-readable string
    /// - Parameter seconds: Time in seconds
    /// - Returns: Formatted string like "3 minutes 45 seconds"
    private static func formatTime(_ seconds: Double) -> String {
        guard seconds >= 0 else { return "unknown" }

        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        var parts: [String] = []

        if hours > 0 {
            parts.append("\(hours) hour\(hours == 1 ? "" : "s")")
        }
        if minutes > 0 {
            parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")")
        }
        if secs > 0 || parts.isEmpty {
            parts.append("\(secs) second\(secs == 1 ? "" : "s")")
        }

        return parts.joined(separator: " ")
    }

    /// Format time for display (MM:SS or HH:MM:SS)
    /// - Parameter seconds: Time in seconds
    /// - Returns: Formatted string like "3:45" or "1:03:45"
    static func formatTimeDisplay(_ seconds: Double) -> String {
        guard seconds >= 0 else { return "--:--" }

        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
