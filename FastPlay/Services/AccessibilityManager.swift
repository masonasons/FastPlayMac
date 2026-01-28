//
//  AccessibilityManager.swift
//  FastPlay
//
//  Accessibility announcements using NSAccessibility
//  Replaces Windows Universal Speech
//

import AppKit
import Accessibility
import AVFoundation

/// Manages accessibility announcements for screen reader users
class AccessibilityManager {

    // MARK: - Singleton

    static let shared = AccessibilityManager()

    // MARK: - AVSpeechSynthesizer

    private let speechSynthesizer = AVSpeechSynthesizer()

    private init() {}

    // MARK: - Announcements

    /// Announce a message to VoiceOver
    /// - Parameter message: The message to announce
    static func announce(_ message: String) {
        shared.announce(message)
    }

    /// Announce a message to VoiceOver or AVSpeechSynthesizer
    /// - Parameter message: The message to announce
    func announce(_ message: String) {
        guard !message.isEmpty else { return }

        DispatchQueue.main.async { [self] in
            // Use AVSpeechSynthesizer when app is not active and setting is enabled
            if !NSApp.isActive && SettingsManager.shared.speechUseAVSpeech {
                speakWithAVSpeech(message, interruptsPrevious: true)
                return
            }

            // Use macOS 14+ Accessibility framework API
            if #available(macOS 14.0, *) {
                let announcement = AccessibilityNotification.Announcement(message)
                announcement.post()
                return
            }

            // Legacy approach for older macOS
            guard let window = NSApp.mainWindow ?? NSApp.keyWindow ?? NSApp.windows.first else {
                // Fallback to AVSpeech if no window available
                if SettingsManager.shared.speechUseAVSpeech {
                    speakWithAVSpeech(message, interruptsPrevious: true)
                }
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

        DispatchQueue.main.async { [self] in
            // Use AVSpeechSynthesizer when app is not active and setting is enabled
            if !NSApp.isActive && SettingsManager.shared.speechUseAVSpeech {
                speakWithAVSpeech(message, interruptsPrevious: false)
                return
            }

            // Use macOS 14+ Accessibility framework API
            if #available(macOS 14.0, *) {
                let announcement = AccessibilityNotification.Announcement(message)
                announcement.post()
                return
            }

            // Legacy approach for older macOS
            guard let window = NSApp.mainWindow ?? NSApp.keyWindow ?? NSApp.windows.first else {
                // Fallback to AVSpeech if no window available
                if SettingsManager.shared.speechUseAVSpeech {
                    speakWithAVSpeech(message, interruptsPrevious: false)
                }
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

    // MARK: - AVSpeechSynthesizer

    /// Speak using AVSpeechSynthesizer with configured voice settings
    /// - Parameters:
    ///   - message: Text to speak
    ///   - interruptsPrevious: Whether to stop any current speech
    private func speakWithAVSpeech(_ message: String, interruptsPrevious: Bool) {
        if interruptsPrevious && speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: message)

        // Apply configured voice
        let voiceId = SettingsManager.shared.speechVoiceIdentifier
        if !voiceId.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else {
            // Use default voice for current locale (compatible with macOS 12+)
            let languageCode = Locale.current.languageCode ?? "en"
            utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        }

        // Apply configured settings
        utterance.rate = SettingsManager.shared.speechRate
        utterance.pitchMultiplier = SettingsManager.shared.speechPitch
        utterance.volume = SettingsManager.shared.speechSynthVolume

        speechSynthesizer.speak(utterance)
    }

    /// Stop any current AVSpeechSynthesizer speech
    func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - Voice Utilities

    /// Get list of available speech synthesis voices
    /// - Returns: Array of tuples (identifier, displayName) for available voices
    static func getAvailableVoices() -> [(identifier: String, name: String)] {
        let voices = AVSpeechSynthesisVoice.speechVoices()

        return voices
            .sorted { $0.name < $1.name }
            .map { (identifier: $0.identifier, name: "\($0.name) (\($0.language))") }
    }

    /// Get the name of a voice by its identifier
    /// - Parameter identifier: Voice identifier string
    /// - Returns: Voice display name or "System Default" if not found
    static func getVoiceName(for identifier: String) -> String {
        if identifier.isEmpty {
            return "System Default"
        }
        if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return "\(voice.name) (\(voice.language))"
        }
        return "Unknown Voice"
    }
}
