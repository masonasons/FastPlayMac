//
//  RecordingManager.swift
//  FastPlay
//
//  Recording Manager - capture playback to file
//  Maps to Windows player.cpp recording functions
//

import Foundation
import AppKit

/// Recording Manager
class RecordingManager {

    // MARK: - Singleton

    static let shared = RecordingManager()

    // MARK: - State

    private var encoder: DWORD = 0  // Encoder handle
    private(set) var isRecording = false
    private(set) var currentRecordingPath: String?

    // MARK: - Initialization

    private init() {}

    // MARK: - Recording Control

    /// Start recording to file
    func startRecording() -> Bool {
        guard !isRecording else {
            AccessibilityManager.announce("Already recording")
            return false
        }

        guard AudioEngine.shared.fxStream != 0 else {
            AccessibilityManager.announce("Nothing to record")
            return false
        }

        // Determine output path
        let outputPath = getRecordingDirectory()
        let filename = generateRecordingFilename()
        let format = RecordingFormat(rawValue: SettingsManager.shared.recordFormat) ?? .wav
        var fullPath = (outputPath as NSString).appendingPathComponent(filename + "." + format.fileExtension)

        // Create directory if needed
        do {
            try FileManager.default.createDirectory(atPath: outputPath, withIntermediateDirectories: true)
        } catch {
            AccessibilityManager.announce("Failed to create recording directory")
            return false
        }

        // Start encoder based on format
        let stream = AudioEngine.shared.fxStream

        // BASS_ENCODE_FP_16BIT converts floating-point audio to 16-bit integer
        // which is required for WAV and FLAC encoders
        let wavFlags = DWORD(BASS_ENCODE_AUTOFREE | BASS_ENCODE_FP_16BIT)

        switch format {
        case .wav:
            // WAV - use BASS_Encode_StartPCMFile for direct WAV output
            encoder = BASS_Encode_StartPCMFile(stream, wavFlags, fullPath)

        case .mp3:
            // MP3 - use bassenc_mp3
            let bitrate = SettingsManager.shared.recordBitrate
            let options = "--preset cbr \(bitrate)"
            encoder = BASS_Encode_MP3_StartFile(stream, options, DWORD(BASS_ENCODE_AUTOFREE), fullPath)
            if encoder == 0 {
                // Fall back to WAV if MP3 encoding fails
                fullPath = (outputPath as NSString).appendingPathComponent(filename + ".wav")
                encoder = BASS_Encode_StartPCMFile(stream, wavFlags, fullPath)
                if encoder != 0 {
                    AccessibilityManager.announce("MP3 encoding not available, using WAV")
                }
            }

        case .ogg:
            // OGG - use bassenc_ogg
            let bitrate = SettingsManager.shared.recordBitrate
            let options = "--bitrate \(bitrate)"
            encoder = BASS_Encode_OGG_StartFile(stream, options, DWORD(BASS_ENCODE_AUTOFREE), fullPath)
            if encoder == 0 {
                // Fall back to WAV if OGG encoding fails
                fullPath = (outputPath as NSString).appendingPathComponent(filename + ".wav")
                encoder = BASS_Encode_StartPCMFile(stream, wavFlags, fullPath)
                if encoder != 0 {
                    AccessibilityManager.announce("OGG encoding not available, using WAV")
                }
            }

        case .flac:
            // FLAC - use bassenc_flac (also needs FP conversion)
            encoder = BASS_Encode_FLAC_StartFile(stream, nil, wavFlags, fullPath)
            if encoder == 0 {
                // Fall back to WAV if FLAC encoding fails
                fullPath = (outputPath as NSString).appendingPathComponent(filename + ".wav")
                encoder = BASS_Encode_StartPCMFile(stream, wavFlags, fullPath)
                if encoder != 0 {
                    AccessibilityManager.announce("FLAC encoding not available, using WAV")
                }
            }
        }

        if encoder == 0 {
            let error = BASS_ErrorGetCode()
            AccessibilityManager.announce("Failed to start recording, error \(error)")
            return false
        }

        isRecording = true
        currentRecordingPath = fullPath
        AccessibilityManager.announce("Recording started")
        return true
    }

    /// Stop recording
    func stopRecording() {
        guard isRecording else { return }

        if encoder != 0 {
            BASS_Encode_Stop(encoder)
            encoder = 0
        }

        isRecording = false

        // Announce with path info
        if let path = currentRecordingPath {
            let filename = (path as NSString).lastPathComponent
            AccessibilityManager.announce("Recording saved: \(filename)")
        } else {
            AccessibilityManager.announce("Recording stopped")
        }

        currentRecordingPath = nil
    }

    /// Toggle recording on/off
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            _ = startRecording()
        }
    }

    /// Check if encoder is still active
    func checkEncoderStatus() -> Bool {
        guard encoder != 0 else { return false }
        return BASS_Encode_IsActive(encoder) != 0
    }

    // MARK: - Helpers

    private func getRecordingDirectory() -> String {
        if !SettingsManager.shared.recordPath.isEmpty {
            return SettingsManager.shared.recordPath
        }

        // Default to Music folder
        let musicURL = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first
        let recordingsURL = musicURL?.appendingPathComponent("FastPlay Recordings")
        return recordingsURL?.path ?? NSTemporaryDirectory()
    }

    private func generateRecordingFilename() -> String {
        // Use template from settings, defaulting to timestamp format
        var template = SettingsManager.shared.recordTemplate
        if template.isEmpty {
            template = "yyyy-MM-dd_HH-mm-ss"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = template
        return dateFormatter.string(from: Date())
    }

    /// Get the recordings directory for display
    func getRecordingsFolder() -> URL? {
        let path = getRecordingDirectory()
        return URL(fileURLWithPath: path)
    }

    /// Open recordings folder in Finder
    func openRecordingsFolder() {
        if let url = getRecordingsFolder() {
            // Create directory if it doesn't exist
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            NSWorkspace.shared.open(url)
        }
    }
}
