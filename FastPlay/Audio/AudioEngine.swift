//
//  AudioEngine.swift
//  FastPlay
//
//  BASS Audio Library wrapper for playback, effects, and recording
//  Maps to Windows player.cpp
//

import AppKit
import Foundation
import UniformTypeIdentifiers

/// Main audio engine wrapping BASS library
class AudioEngine {

    // MARK: - Singleton

    static let shared = AudioEngine()

    // MARK: - Constants (matching Windows)

    static let maxVolumeNormal: Float = 1.0
    static let maxVolumeAmplify: Float = 4.0

    /// Supported audio file types
    static let supportedFileTypes: [UTType] = [
        .mp3, .wav, .aiff,
        UTType(filenameExtension: "ogg")!,
        UTType(filenameExtension: "oga")!,
        UTType(filenameExtension: "flac")!,
        UTType(filenameExtension: "m4a")!,
        UTType(filenameExtension: "m4b")!,
        UTType(filenameExtension: "aac")!,
        UTType(filenameExtension: "opus")!,
        UTType(filenameExtension: "wma")!,
        UTType(filenameExtension: "ape")!,
        UTType(filenameExtension: "wv")!,
        UTType(filenameExtension: "mid")!,
        UTType(filenameExtension: "midi")!,
    ]

    /// Supported playlist types
    static let supportedPlaylistTypes: [UTType] = [
        UTType(filenameExtension: "m3u")!,
        UTType(filenameExtension: "m3u8")!,
        UTType(filenameExtension: "pls")!,
    ]

    // MARK: - BASS Handles

    private var stream: HSTREAM = 0           // Source stream
    private var _fxStream: HSTREAM = 0         // Tempo stream (wraps stream for pitch/tempo)
    private var sourceStream: HSTREAM = 0     // Original decode stream (for bitrate queries)
    private var endSync: HSYNC = 0
    private var metaSync: HSYNC = 0
    private var soundFont: DWORD = 0          // SoundFont handle for MIDI playback

    /// Public accessor for DSP effects to attach to
    var fxStream: HSTREAM { return _fxStream }

    // MARK: - State

    private(set) var isInitialized = false
    private(set) var isPlaying = false
    private(set) var isPaused = false
    private(set) var isLiveStream = false
    private(set) var currentBitrate: Int = 0
    private(set) var isVBR = false

    private var volume: Float = 1.0
    private var isMuted = false
    private var legacyVolume = false

    // Effect state
    private var tempo: Float = 0.0            // -50 to +100 percent
    private var pitch: Float = 0.0            // -12 to +12 semitones
    private var rate: Float = 1.0             // 0.5 to 2.0
    private var originalFreq: Float = 44100.0

    // MARK: - Callbacks

    var onTrackEnd: (() -> Void)?
    var onMetadataChange: ((String) -> Void)?
    var onTrackLoad: (() -> Void)?

    // MARK: - Chapters

    private(set) var chapters: [Chapter] = []

    /// Chapter information
    struct Chapter {
        let position: Double    // Position in seconds
        let name: String        // Chapter name
    }

    // MARK: - Initialization

    private init() {}

    /// Initialize BASS with default device
    func initialize() -> Bool {
        guard !isInitialized else { return true }

        // Get device from settings (-1 = default)
        let device = SettingsManager.shared.selectedDevice

        // Set buffer settings before init (matching Windows defaults)
        BASS_SetConfig(DWORD(BASS_CONFIG_BUFFER), DWORD(SettingsManager.shared.bufferSize))
        BASS_SetConfig(DWORD(BASS_CONFIG_UPDATEPERIOD), DWORD(SettingsManager.shared.updatePeriod))

        // Initialize BASS
        guard BASS_Init(Int32(device), 44100, 0, nil, nil) != 0 else {
            print("BASS_Init failed: \(BASS_ErrorGetCode())")
            return false
        }

        // Load plugins
        loadPlugins()

        // Apply MIDI settings (SoundFont, max voices)
        applyMidiSettings()

        isInitialized = true

        // Restore state from settings
        volume = SettingsManager.shared.volume
        isMuted = SettingsManager.shared.muted
        legacyVolume = SettingsManager.shared.legacyVolume

        return true
    }

    /// Shutdown BASS and free resources
    func shutdown() {
        guard isInitialized else { return }

        freeStream()

        // Free SoundFont
        if soundFont != 0 {
            BASS_MIDI_FontFree(soundFont)
            soundFont = 0
        }

        BASS_Free()
        isInitialized = false
    }

    /// Change audio output device
    /// - Parameter deviceIndex: BASS device index (-1 for default, or specific device index)
    /// - Returns: true if device change succeeded
    func changeDevice(_ deviceIndex: Int) -> Bool {
        // Save current state BEFORE stopping - use isPlaying flag, not state property
        // (state queries BASS which can have timing issues)
        let wasPlaying = isPlaying
        let wasPaused = isPaused
        let wasLiveStream = isLiveStream  // Save before freeStream clears it
        let currentPath = PlaylistManager.shared.currentTrackPath
        let savedPosition = _fxStream != 0 ? currentPosition : 0.0

        // Free current stream (don't call stop() as it resets position)
        freeStream()

        // Free SoundFont before reinit
        if soundFont != 0 {
            BASS_MIDI_FontFree(soundFont)
            soundFont = 0
        }

        // Free BASS
        BASS_Free()
        isInitialized = false

        // Update settings
        SettingsManager.shared.selectedDevice = deviceIndex

        // Set buffer settings
        BASS_SetConfig(DWORD(BASS_CONFIG_BUFFER), DWORD(SettingsManager.shared.bufferSize))
        BASS_SetConfig(DWORD(BASS_CONFIG_UPDATEPERIOD), DWORD(SettingsManager.shared.updatePeriod))

        // Reinitialize BASS with new device
        guard BASS_Init(Int32(deviceIndex), 44100, 0, nil, nil) != 0 else {
            print("BASS_Init failed on device \(deviceIndex): \(BASS_ErrorGetCode())")
            // Try to recover with default device
            if deviceIndex != -1 {
                _ = BASS_Init(-1, 44100, 0, nil, nil)
                SettingsManager.shared.selectedDevice = -1
            }
            isInitialized = BASS_GetDevice() >= 0
            loadPlugins()
            applyMidiSettings()
            return false
        }

        loadPlugins()
        applyMidiSettings()
        isInitialized = true

        // Restore playback if we had a track
        if let path = currentPath {
            // Check if it's a URL (stream) or local file
            let isURL = path.hasPrefix("http://") || path.hasPrefix("https://")
            let loaded = isURL ? loadURL(path) : loadFile(path)

            if loaded {
                // Seek to saved position (not for live streams)
                if savedPosition > 0 && !wasLiveStream {
                    seek(to: savedPosition)
                }
                // Resume playback state
                if wasPlaying || wasLiveStream {
                    // Live streams should always play (can't be paused)
                    play()
                } else if wasPaused && !wasLiveStream {
                    // Load but stay paused - pause() only works if playing, so play then pause
                    play()
                    pause()
                }
            }
        }

        return true
    }

    /// Get list of available audio output devices
    /// Returns array of (index, name, isDefault, isEnabled) tuples
    func getAvailableDevices() -> [(index: Int, name: String, isDefault: Bool, isEnabled: Bool)] {
        var devices: [(index: Int, name: String, isDefault: Bool, isEnabled: Bool)] = []
        var info = BASS_DEVICEINFO()
        var deviceIndex: DWORD = 1  // Start at 1, 0 is "No Sound"

        while BASS_GetDeviceInfo(deviceIndex, &info) != 0 {
            let name = info.name != nil ? String(cString: info.name) : "Unknown Device"
            let isDefault = (info.flags & DWORD(BASS_DEVICE_DEFAULT)) != 0
            let isEnabled = (info.flags & DWORD(BASS_DEVICE_ENABLED)) != 0

            if isEnabled {
                devices.append((index: Int(deviceIndex), name: name, isDefault: isDefault, isEnabled: isEnabled))
            }
            deviceIndex += 1
        }

        return devices
    }

    /// Get currently selected device index
    var currentDeviceIndex: Int {
        return SettingsManager.shared.selectedDevice
    }

    /// Load BASS plugins for additional format support
    private func loadPlugins() {
        // Get bundle's Frameworks directory
        guard let frameworksPath = Bundle.main.privateFrameworksPath else { return }

        let plugins = [
            "libbassflac.dylib",
            "libbassopus.dylib",
            "libbassmidi.dylib",
            "libbass_aac.dylib",
            "libbass_ape.dylib",
            "libbasswv.dylib",
            "libbassenc.dylib",
            "libbassenc_mp3.dylib",
            "libbassenc_ogg.dylib",
            "libbassenc_flac.dylib",
        ]

        for plugin in plugins {
            let path = (frameworksPath as NSString).appendingPathComponent(plugin)
            if FileManager.default.fileExists(atPath: path) {
                _ = BASS_PluginLoad(path, 0)
            }
        }
    }

    /// Get list of loaded plugins
    func getLoadedPlugins() -> String {
        var result = ""

        // BASS_PluginGetInfo returns info for loaded plugins
        // This is a simplified version - in practice you'd iterate through handles
        result += "BASS \(BASS_GetVersion() >> 24).\(BASS_GetVersion() >> 16 & 0xFF)\n"
        result += "BASS_FX loaded\n"

        return result
    }

    // MARK: - Loading

    /// Load a local file
    func loadFile(_ path: String) -> Bool {
        freeStream()

        // Check if MIDI file
        let ext = (path as NSString).pathExtension.lowercased()
        if ext == "mid" || ext == "midi" {
            return loadMIDI(path)
        }

        // Create decode stream first
        // Include BASS_SAMPLE_FLOAT so DSP callbacks receive float samples
        let flags: DWORD = DWORD(BASS_STREAM_DECODE | BASS_STREAM_PRESCAN | BASS_SAMPLE_FLOAT)
        stream = BASS_StreamCreateFile(0, path, 0, 0, flags)

        guard stream != 0 else {
            print("Failed to load file: \(BASS_ErrorGetCode())")
            return false
        }

        sourceStream = stream
        return setupTempoStream()
    }

    /// Load a URL stream
    func loadURL(_ url: String) -> Bool {
        freeStream()

        // Include BASS_SAMPLE_FLOAT so DSP callbacks receive float samples
        let flags: DWORD = DWORD(BASS_STREAM_DECODE | BASS_STREAM_STATUS | BASS_SAMPLE_FLOAT)
        stream = BASS_StreamCreateURL(url, 0, flags, nil, nil)

        guard stream != 0 else {
            print("Failed to load URL: \(BASS_ErrorGetCode())")
            return false
        }

        sourceStream = stream

        // Check if live stream (non-seekable)
        let length = BASS_ChannelGetLength(stream, DWORD(BASS_POS_BYTE))
        isLiveStream = (length == UInt64(bitPattern: -1))

        // Set up metadata sync for Shoutcast/Icecast
        if let metaPtr = BASS_ChannelGetTags(stream, DWORD(BASS_TAG_META)) {
            let meta = String(cString: metaPtr)
            parseStreamMeta(meta)
        }

        // Register for metadata updates
        metaSync = BASS_ChannelSetSync(stream, DWORD(BASS_SYNC_META), 0, { _, _, _, user in
            guard let user = user else { return }
            let engine = Unmanaged<AudioEngine>.fromOpaque(user).takeUnretainedValue()
            if let metaPtr = BASS_ChannelGetTags(engine.sourceStream, DWORD(BASS_TAG_META)) {
                let meta = String(cString: metaPtr)
                engine.parseStreamMeta(meta)
            }
        }, Unmanaged.passUnretained(self).toOpaque())

        return setupTempoStream()
    }

    /// Load a MIDI file with SoundFont
    /// Note: Requires BASSMIDI plugin. Falls back to regular loading if unavailable.
    private func loadMIDI(_ path: String) -> Bool {
        // Build flags for MIDI stream
        var flags: DWORD = DWORD(BASS_STREAM_DECODE | BASS_SAMPLE_FLOAT)

        // Add sinc interpolation if enabled (higher quality)
        if SettingsManager.shared.midiSincInterp {
            flags |= DWORD(BASS_MIDI_SINCINTER)
        }

        // Try BASSMIDI first
        stream = BASS_MIDI_StreamCreateFile(0, path, 0, 0, flags, 0)

        if stream != 0 {
            // Apply SoundFont to this specific stream if loaded
            if soundFont != 0 {
                var font = BASS_MIDI_FONT(font: soundFont, preset: -1, bank: 0)
                BASS_MIDI_StreamSetFonts(stream, &font, 1)
            }
        } else {
            // Fallback to regular stream loading (will likely fail for MIDI)
            print("BASSMIDI not available, trying as regular file")
            let fallbackFlags: DWORD = DWORD(BASS_STREAM_DECODE | BASS_SAMPLE_FLOAT)
            stream = BASS_StreamCreateFile(0, path, 0, 0, fallbackFlags)
        }

        guard stream != 0 else {
            print("Failed to load MIDI file: \(BASS_ErrorGetCode())")
            return false
        }

        sourceStream = stream
        isLiveStream = false
        return setupTempoStream()
    }

    /// Apply MIDI settings (SoundFont, max voices)
    func applyMidiSettings() {
        // Free previous SoundFont if any
        if soundFont != 0 {
            BASS_MIDI_FontFree(soundFont)
            soundFont = 0
        }

        // Set max voices for MIDI playback
        BASS_SetConfig(DWORD(BASS_CONFIG_MIDI_VOICES), DWORD(SettingsManager.shared.midiMaxVoices))

        // Load SoundFont if configured
        let soundFontPath = SettingsManager.shared.midiSoundFont
        if !soundFontPath.isEmpty && FileManager.default.fileExists(atPath: soundFontPath) {
            soundFont = BASS_MIDI_FontInit(soundFontPath, 0)
            if soundFont != 0 {
                // Set as default SoundFont for all MIDI streams
                var font = BASS_MIDI_FONT(font: soundFont, preset: -1, bank: 0)
                BASS_MIDI_StreamSetFonts(0, &font, 1)  // 0 = set default
            }
        }
    }

    /// Set up tempo stream for pitch/tempo effects
    private func setupTempoStream() -> Bool {
        // Get original sample rate
        var info = BASS_CHANNELINFO()
        BASS_ChannelGetInfo(stream, &info)
        originalFreq = Float(info.freq)

        // Get bitrate
        updateBitrate()

        // Create tempo stream (takes ownership of source stream)
        // Use BASS_SAMPLE_FLOAT for DSP callbacks to receive float samples (matches Windows)
        let flags: DWORD = DWORD(BASS_FX_FREESOURCE) | DWORD(BASS_SAMPLE_FLOAT)
        _fxStream = BASS_FX_TempoCreate(stream, flags)

        guard _fxStream != 0 else {
            print("Failed to create tempo stream: \(BASS_ErrorGetCode())")
            BASS_StreamFree(stream)
            stream = 0
            sourceStream = 0
            return false
        }

        // Apply current tempo/pitch/rate settings
        applyTempoSettings()

        // Apply volume
        applyVolume()

        // Apply DSP effects (reverb, echo, EQ, compressor, etc.)
        DSPEffectsManager.shared.applyEffects()

        // Set up end sync
        endSync = BASS_ChannelSetSync(_fxStream, DWORD(BASS_SYNC_END), 0, { _, _, _, user in
            DispatchQueue.main.async {
                AudioEngine.shared.handleTrackEnd()
            }
        }, nil)

        // Parse chapters from file (if any)
        parseChapters()

        // Notify that a new track was loaded
        onTrackLoad?()

        return true
    }

    /// Parse chapters from the current stream (matches Windows ParseChapters)
    private func parseChapters() {
        chapters = []
        guard sourceStream != 0 else { return }

        // Try VorbisComment format (Ogg/FLAC/Opus)
        parseVorbisCommentChapters()

        // If no chapters found, try ID3v2 format (MP3, M4A)
        if chapters.isEmpty {
            parseID3v2Chapters()
        }

        // Sort chapters by position
        chapters.sort { $0.position < $1.position }
    }

    /// Parse VorbisComment chapters (CHAPTER001=00:00:00.000, CHAPTER001NAME=Name)
    private func parseVorbisCommentChapters() {
        guard let tagPtr = BASS_ChannelGetTags(sourceStream, DWORD(BASS_TAG_OGG)) else { return }

        var chapterMap: [Int: (position: Double?, name: String?)] = [:]

        var current = tagPtr
        while current.pointee != 0 {
            let tag = String(cString: current)

            // Check for CHAPTERnnn= format
            if tag.uppercased().hasPrefix("CHAPTER") {
                let afterChapter = tag.dropFirst(7)

                // Parse chapter number
                var numStr = ""
                var remainder = afterChapter

                for char in afterChapter {
                    if char.isNumber {
                        numStr.append(char)
                    } else {
                        remainder = afterChapter.dropFirst(numStr.count)
                        break
                    }
                }

                if let num = Int(numStr), num > 0 {
                    let restStr = String(remainder)

                    if restStr.uppercased().hasPrefix("NAME=") {
                        // Chapter name
                        let name = String(restStr.dropFirst(5))
                        if chapterMap[num] == nil {
                            chapterMap[num] = (nil, name)
                        } else {
                            chapterMap[num]?.name = name
                        }
                    } else if restStr.hasPrefix("=") {
                        // Chapter time (format: HH:MM:SS.mmm or MM:SS.mmm)
                        let timeStr = String(restStr.dropFirst(1))
                        if let time = parseChapterTime(timeStr) {
                            if chapterMap[num] == nil {
                                chapterMap[num] = (time, nil)
                            } else {
                                chapterMap[num]?.position = time
                            }
                        }
                    }
                }
            }

            current = current.advanced(by: tag.utf8.count + 1)
        }

        // Convert map to chapters array
        for (num, data) in chapterMap.sorted(by: { $0.key < $1.key }) {
            if let position = data.position, (position >= 0 || num == 1) {
                let name = data.name?.isEmpty == false ? data.name! : "Chapter \(num)"
                chapters.append(Chapter(position: position, name: name))
            }
        }
    }

    /// Parse chapter time string (HH:MM:SS.mmm or MM:SS.mmm) to seconds
    private func parseChapterTime(_ timeStr: String) -> Double? {
        let parts = timeStr.split(separator: ":")
        guard parts.count == 2 || parts.count == 3 else { return nil }

        var hours = 0.0
        var minutes = 0.0
        var seconds = 0.0

        if parts.count == 3 {
            // HH:MM:SS.mmm
            hours = Double(parts[0]) ?? 0
            minutes = Double(parts[1]) ?? 0
            seconds = Double(parts[2]) ?? 0
        } else {
            // MM:SS.mmm
            minutes = Double(parts[0]) ?? 0
            seconds = Double(parts[1]) ?? 0
        }

        return hours * 3600 + minutes * 60 + seconds
    }

    /// Parse ID3v2 CHAP frames (used by MP3, M4A)
    private func parseID3v2Chapters() {
        guard let tagPtr = BASS_ChannelGetTags(sourceStream, DWORD(BASS_TAG_ID3V2)) else { return }

        // First, read just the header to get actual tag size
        let headerData = Data(bytes: tagPtr, count: 10)
        guard headerData.count >= 10 else { return }

        // Check ID3v2 header
        guard headerData[0] == 0x49 && headerData[1] == 0x44 && headerData[2] == 0x33 else { return }  // "ID3"

        let version = headerData[3]
        guard version >= 3 else { return }  // Need ID3v2.3 or higher for CHAP

        // Parse size (synchsafe integer)
        let tagSize = Int((UInt32(headerData[6]) << 21) | (UInt32(headerData[7]) << 14) | (UInt32(headerData[8]) << 7) | UInt32(headerData[9]))

        // Sanity check: tag size should be reasonable (max 16MB)
        guard tagSize > 0 && tagSize < 16 * 1024 * 1024 else { return }

        // Now read the actual tag data (header + content)
        let totalSize = 10 + tagSize
        let data = Data(bytes: tagPtr, count: totalSize)
        guard data.count >= totalSize else { return }

        let endPos = totalSize

        var pos = 10
        while pos + 10 <= endPos {
            // Check for padding (zeros)
            if data[pos] == 0 { break }

            // Frame ID (4 bytes)
            guard pos + 4 <= endPos else { break }
            let frameId = String(data: data[pos..<pos+4], encoding: .ascii) ?? ""
            pos += 4

            // Frame size (4 bytes, synchsafe in v2.4, normal in v2.3)
            guard pos + 4 <= endPos else { break }
            let frameSize: Int
            if version >= 4 {
                frameSize = Int((UInt32(data[pos]) << 21) | (UInt32(data[pos+1]) << 14) | (UInt32(data[pos+2]) << 7) | UInt32(data[pos+3]))
            } else {
                frameSize = Int((UInt32(data[pos]) << 24) | (UInt32(data[pos+1]) << 16) | (UInt32(data[pos+2]) << 8) | UInt32(data[pos+3]))
            }
            pos += 4

            // Frame flags (2 bytes)
            guard pos + 2 <= endPos else { break }
            pos += 2

            // Sanity check frame size
            guard frameSize >= 0 && frameSize < 16 * 1024 * 1024 else { break }
            guard pos + frameSize <= endPos else { break }

            if frameId == "CHAP" && frameSize > 0 {
                // Parse CHAP frame
                let frameData = data[pos..<pos+frameSize]
                parseID3ChapFrame(frameData)
            }

            pos += frameSize
        }

        // Sort chapters by position
        chapters.sort { $0.position < $1.position }
    }

    /// Parse a single ID3v2 CHAP frame
    private func parseID3ChapFrame(_ frameData: Data) {
        guard frameData.count > 16 else { return }

        // Use array for safer access
        let bytes = Array(frameData)
        var pos = 0

        // Element ID (null-terminated string)
        var elemIdLen = 0
        while pos + elemIdLen < bytes.count && bytes[pos + elemIdLen] != 0 {
            elemIdLen += 1
        }
        pos += elemIdLen + 1  // Skip ID and null terminator

        guard pos + 16 <= bytes.count else { return }

        // Start time (4 bytes, milliseconds)
        let startMs = (UInt32(bytes[pos]) << 24) | (UInt32(bytes[pos+1]) << 16) | (UInt32(bytes[pos+2]) << 8) | UInt32(bytes[pos+3])
        pos += 4

        // End time (4 bytes, skip)
        pos += 4

        // Start byte offset (4 bytes, skip)
        pos += 4

        // End byte offset (4 bytes, skip)
        pos += 4

        let startSec = Double(startMs) / 1000.0
        var chapterName = ""

        // Look for TIT2 sub-frame (chapter title)
        while pos + 10 <= bytes.count {
            // Check for valid frame ID (should be ASCII letters/numbers)
            guard bytes[pos] >= 0x20 && bytes[pos] <= 0x7E else { break }

            guard pos + 4 <= bytes.count else { break }
            let subFrameId = String(bytes: bytes[pos..<pos+4], encoding: .ascii) ?? ""
            pos += 4

            guard pos + 4 <= bytes.count else { break }
            let subFrameSize = Int((UInt32(bytes[pos]) << 24) | (UInt32(bytes[pos+1]) << 16) | (UInt32(bytes[pos+2]) << 8) | UInt32(bytes[pos+3]))
            pos += 4

            // Skip flags
            guard pos + 2 <= bytes.count else { break }
            pos += 2

            // Sanity check frame size
            guard subFrameSize > 0 && subFrameSize < bytes.count else { break }
            guard pos + subFrameSize <= bytes.count else { break }

            if subFrameId == "TIT2" && subFrameSize > 1 {
                // Text frame - first byte is encoding
                let encoding = bytes[pos]
                let textBytes = Array(bytes[(pos+1)..<(pos+subFrameSize)])
                let textData = Data(textBytes)

                // Decode based on encoding
                if encoding == 0 {
                    // ISO-8859-1
                    chapterName = String(data: textData, encoding: .isoLatin1) ?? ""
                } else if encoding == 1 {
                    // UTF-16 with BOM
                    chapterName = String(data: textData, encoding: .utf16) ?? ""
                } else if encoding == 3 {
                    // UTF-8
                    chapterName = String(data: textData, encoding: .utf8) ?? ""
                }

                // Remove null terminators
                chapterName = chapterName.trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
                break
            }

            pos += subFrameSize
        }

        // Generate default name if none found
        if chapterName.isEmpty {
            chapterName = "Chapter \(chapters.count + 1)"
        }

        chapters.append(Chapter(position: startSec, name: chapterName))
    }

    /// Update cached bitrate info
    private func updateBitrate() {
        guard sourceStream != 0 else {
            currentBitrate = 0
            isVBR = false
            return
        }

        // Try BASS_ATTRIB_BITRATE
        var bitrate: Float = 0
        if BASS_ChannelGetAttribute(sourceStream, DWORD(BASS_ATTRIB_BITRATE), &bitrate) != 0 && bitrate > 0 {
            currentBitrate = Int(bitrate)
        }

        // Check VBR
        var vbr: Float = 0
        isVBR = BASS_ChannelGetAttribute(sourceStream, DWORD(BASS_ATTRIB_VBR), &vbr) != 0 && vbr > 0

        // Try ICY headers for streams
        if currentBitrate == 0 {
            if let icyPtr = BASS_ChannelGetTags(sourceStream, DWORD(BASS_TAG_ICY)) {
                let icy = String(cString: icyPtr)
                if let range = icy.range(of: "icy-br:") {
                    let brStr = icy[range.upperBound...].prefix(while: { $0.isNumber })
                    currentBitrate = Int(brStr) ?? 0
                }
            }
        }
    }

    /// Get current bitrate (live for VBR)
    func getCurrentBitrate() -> Int {
        // For VBR, query live bitrate
        if sourceStream != 0 {
            var bitrate: Float = 0
            if BASS_ChannelGetAttribute(sourceStream, DWORD(BASS_ATTRIB_BITRATE), &bitrate) != 0 && bitrate > 0 {
                return Int(bitrate)
            }
        }
        return currentBitrate
    }

    /// Get current stream tags (matches Windows GetMetadataTag fallback order)
    func getCurrentTags() -> [String: String] {
        var tags: [String: String] = [:]
        guard sourceStream != 0 else { return tags }

        // For live streams, check ICY and META tags first
        if isLiveStream {
            // Try Shoutcast META tag (StreamTitle='...')
            if let metaPtr = BASS_ChannelGetTags(sourceStream, DWORD(BASS_TAG_META)) {
                parseShoutcastMeta(metaPtr, into: &tags)
            }

            // Try ICY headers (icy-name, icy-description, etc.)
            if tags["title"] == nil, let icyPtr = BASS_ChannelGetTags(sourceStream, DWORD(BASS_TAG_ICY)) {
                parseICYTags(icyPtr, into: &tags)
            }

            // Also check HTTP headers for stream info
            if tags["title"] == nil, let httpPtr = BASS_ChannelGetTags(sourceStream, DWORD(BASS_TAG_HTTP)) {
                parseICYTags(httpPtr, into: &tags)
            }

            if !tags.isEmpty {
                return tags
            }
        }

        // Try OGG tags (also works for FLAC, Opus)
        if let tagPtr = BASS_ChannelGetTags(sourceStream, DWORD(BASS_TAG_OGG)) {
            parseNullTerminatedTags(tagPtr, into: &tags)
        }

        // Try APE tags
        if tags.isEmpty, let tagPtr = BASS_ChannelGetTags(sourceStream, DWORD(BASS_TAG_APE)) {
            parseNullTerminatedTags(tagPtr, into: &tags)
        }

        // Try MP4/iTunes tags
        if tags.isEmpty, let tagPtr = BASS_ChannelGetTags(sourceStream, DWORD(BASS_TAG_MP4)) {
            parseNullTerminatedTags(tagPtr, into: &tags)
        }

        // Try WMA tags
        if tags.isEmpty, let tagPtr = BASS_ChannelGetTags(sourceStream, DWORD(BASS_TAG_WMA)) {
            parseNullTerminatedTags(tagPtr, into: &tags)
        }

        // Try RIFF INFO tags (WAV files)
        if tags.isEmpty, let tagPtr = BASS_ChannelGetTags(sourceStream, DWORD(BASS_TAG_RIFF_INFO)) {
            parseNullTerminatedTags(tagPtr, into: &tags)
        }

        // Try Media Foundation tags
        if tags.isEmpty, let tagPtr = BASS_ChannelGetTags(sourceStream, DWORD(BASS_TAG_MF)) {
            parseNullTerminatedTags(tagPtr, into: &tags)
        }

        // Try ID3v2 tags (most MP3 files use this)
        if tags.isEmpty, let tagPtr = BASS_ChannelGetTags(sourceStream, DWORD(BASS_TAG_ID3V2)) {
            parseID3v2Tags(tagPtr, into: &tags)
        }

        // Try ID3v1 as last fallback
        if tags.isEmpty, let tagPtr = BASS_ChannelGetTags(sourceStream, DWORD(BASS_TAG_ID3)) {
            parseID3v1Tags(tagPtr, into: &tags)
        }

        return tags
    }

    /// Get formatted display title (matches Windows GetTagTitle behavior)
    /// Returns: "Artist - Title" if both available, just title if only title, or nil if no tags
    func getDisplayTitle() -> String? {
        let tags = getCurrentTags()

        // Try to get title
        let title = tags["title"]

        // Try to get artist
        let artist = tags["artist"]

        if let title = title, !title.isEmpty {
            if let artist = artist, !artist.isEmpty {
                return "\(artist) - \(title)"
            }
            return title
        }

        return nil
    }

    /// Get specific tag value by key (common keys: title, artist, album, year, genre, track, comment)
    func getTag(_ key: String) -> String? {
        let tags = getCurrentTags()
        return tags[key.lowercased()]
    }

    /// Get current track artwork as TIFF data (for AppleScript/Airfoil integration)
    func getArtworkData() -> Data? {
        guard sourceStream != 0 else { return nil }

        // Try FLAC picture (BASS_TAG_FLAC_PICTURE)
        if let artwork = extractFLACPicture() {
            return artwork
        }

        // Try MP4/M4A cover art (BASS_TAG_MP4_COVERART)
        if let artwork = extractMP4Artwork() {
            return artwork
        }

        // Try ID3v2 APIC frame (MP3 files)
        if let artwork = extractID3v2Artwork() {
            return artwork
        }

        return nil
    }

    private func extractFLACPicture() -> Data? {
        // BASS_TAG_FLAC_PICTURE + index (0 for first picture)
        let tagType = DWORD(0x12000)
        guard let tagPtr = BASS_ChannelGetTags(sourceStream, tagType) else { return nil }

        // TAG_FLAC_PICTURE structure: apic, mime, desc, width, height, depth, colors, length, data
        let picture = tagPtr.withMemoryRebound(to: TAG_FLAC_PICTURE.self, capacity: 1) { $0.pointee }
        guard picture.length > 0, let data = picture.data else { return nil }

        let imageData = Data(bytes: data, count: Int(picture.length))
        return convertToTIFF(imageData)
    }

    private func extractMP4Artwork() -> Data? {
        // BASS_TAG_MP4_COVERART + index (0 for first cover)
        let tagType = DWORD(0x1400)
        guard let tagPtr = BASS_ChannelGetTags(sourceStream, tagType) else { return nil }

        // TAG_BINARY structure: data pointer and length
        let binary = tagPtr.withMemoryRebound(to: TAG_BINARY.self, capacity: 1) { $0.pointee }
        guard binary.length > 0, let data = binary.data else { return nil }

        let imageData = Data(bytes: data, count: Int(binary.length))
        return convertToTIFF(imageData)
    }

    private func extractID3v2Artwork() -> Data? {
        guard let tagPtr = BASS_ChannelGetTags(sourceStream, DWORD(BASS_TAG_ID3V2)) else { return nil }

        // Get the ID3v2 tag size from header
        let header = Data(bytes: tagPtr, count: 10)
        guard header.count >= 10,
              header[0] == 0x49, header[1] == 0x44, header[2] == 0x33 else { return nil } // "ID3"

        let size = Int((UInt32(header[6] & 0x7F) << 21) |
                       (UInt32(header[7] & 0x7F) << 14) |
                       (UInt32(header[8] & 0x7F) << 7) |
                       UInt32(header[9] & 0x7F))
        let version = header[3]

        // Read the full tag data
        let tagData = Data(bytes: tagPtr, count: min(10 + size, 1024 * 1024)) // Cap at 1MB
        var pos = 10

        while pos + 10 < tagData.count {
            let frameId = String(data: tagData[pos..<pos+4], encoding: .ascii) ?? ""
            pos += 4

            if frameId.isEmpty || frameId.hasPrefix("\0") { break }

            let frameSize: Int
            if version >= 4 {
                // ID3v2.4 uses syncsafe integers for frame size
                frameSize = Int((UInt32(tagData[pos] & 0x7F) << 21) |
                               (UInt32(tagData[pos+1] & 0x7F) << 14) |
                               (UInt32(tagData[pos+2] & 0x7F) << 7) |
                               UInt32(tagData[pos+3] & 0x7F))
            } else {
                // ID3v2.3 uses regular integers
                frameSize = Int((UInt32(tagData[pos]) << 24) |
                               (UInt32(tagData[pos+1]) << 16) |
                               (UInt32(tagData[pos+2]) << 8) |
                               UInt32(tagData[pos+3]))
            }
            pos += 4 + 2 // Skip size and flags

            guard frameSize > 0, pos + frameSize <= tagData.count else { break }

            if frameId == "APIC" {
                // Parse APIC frame
                if let imageData = parseAPICFrame(Data(tagData[pos..<pos+frameSize])) {
                    return convertToTIFF(imageData)
                }
            }

            pos += frameSize
        }

        return nil
    }

    private func parseAPICFrame(_ frameData: Data) -> Data? {
        guard !frameData.isEmpty else { return nil }
        var pos = 0

        // Text encoding (1 byte)
        let encoding = frameData[pos]
        pos += 1

        // Skip MIME type (null-terminated)
        while pos < frameData.count && frameData[pos] != 0 {
            pos += 1
        }
        pos += 1 // Skip null terminator

        guard pos < frameData.count else { return nil }

        // Picture type (1 byte)
        pos += 1

        // Skip description (null-terminated, encoding-dependent)
        if encoding == 0 || encoding == 3 {
            // ISO-8859-1 or UTF-8: single null terminator
            while pos < frameData.count && frameData[pos] != 0 {
                pos += 1
            }
            pos += 1
        } else {
            // UTF-16: double null terminator
            while pos + 1 < frameData.count {
                if frameData[pos] == 0 && frameData[pos + 1] == 0 {
                    pos += 2
                    break
                }
                pos += 2
            }
        }

        guard pos < frameData.count else { return nil }

        // Remaining data is the image
        return Data(frameData[pos...])
    }

    private func convertToTIFF(_ imageData: Data) -> Data? {
        guard let image = NSImage(data: imageData) else { return nil }
        return image.tiffRepresentation
    }

    private func parseNullTerminatedTags(_ ptr: UnsafePointer<CChar>, into tags: inout [String: String]) {
        var current = ptr
        while current.pointee != 0 {
            let str = String(cString: current)
            if let equalIdx = str.firstIndex(of: "=") {
                let key = String(str[..<equalIdx]).lowercased()
                let value = String(str[str.index(after: equalIdx)...])
                tags[key] = value
            }
            current = current.advanced(by: str.utf8.count + 1)
        }
    }

    /// Parse ID3v2 tags (binary format with frame headers)
    private func parseID3v2Tags(_ ptr: UnsafePointer<CChar>, into tags: inout [String: String]) {
        let data = UnsafeRawPointer(ptr)

        // Check for "ID3" header
        let header = data.assumingMemoryBound(to: UInt8.self)
        guard header[0] == 0x49, header[1] == 0x44, header[2] == 0x33 else { return }  // "ID3"

        let version = header[3]  // ID3v2.3 or ID3v2.4
        let flags = header[5]

        // Calculate tag size (syncsafe integer: 4 bytes, 7 bits each)
        let size = (Int(header[6]) << 21) | (Int(header[7]) << 14) | (Int(header[8]) << 7) | Int(header[9])

        // Sanity check: tag size should be reasonable (max 256MB)
        guard size > 0 && size < 256 * 1024 * 1024 else { return }

        var offset = 10  // Skip header

        // Skip extended header if present
        if (flags & 0x40) != 0 {
            guard offset + 4 <= size + 10 else { return }
            let extSize = (Int(header[10]) << 21) | (Int(header[11]) << 14) | (Int(header[12]) << 7) | Int(header[13])
            offset += 4 + extSize
        }

        // Frame ID to tag name mapping
        let frameMap: [String: String] = [
            "TIT2": "title",
            "TPE1": "artist",
            "TALB": "album",
            "TYER": "year",
            "TDRC": "year",  // ID3v2.4 date
            "TRCK": "track",
            "TCON": "genre",
            "COMM": "comment"
        ]

        // Parse frames
        while offset + 10 <= size + 10 {
            // Read frame ID (4 bytes)
            let framePtr = data.advanced(by: offset).assumingMemoryBound(to: UInt8.self)

            // Check for padding (zeros)
            if framePtr[0] == 0 { break }

            let frameId = String(bytes: [framePtr[0], framePtr[1], framePtr[2], framePtr[3]], encoding: .ascii) ?? ""

            // Read frame size
            var frameSize: Int
            if version >= 4 {
                // ID3v2.4: syncsafe integer
                frameSize = (Int(framePtr[4]) << 21) | (Int(framePtr[5]) << 14) | (Int(framePtr[6]) << 7) | Int(framePtr[7])
            } else {
                // ID3v2.3: regular integer
                frameSize = (Int(framePtr[4]) << 24) | (Int(framePtr[5]) << 16) | (Int(framePtr[6]) << 8) | Int(framePtr[7])
            }

            let frameFlags = (Int(framePtr[8]) << 8) | Int(framePtr[9])
            _ = frameFlags  // Unused for now

            offset += 10  // Skip frame header

            // Sanity check frame size (prevent buffer overflow)
            guard frameSize >= 0 && frameSize < 16 * 1024 * 1024 else { break }
            guard offset + frameSize <= size + 10 else { break }

            // Only process text frames we care about
            if let tagName = frameMap[frameId], frameSize > 0 {
                let contentPtr = data.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
                if let value = parseID3v2TextFrame(contentPtr, size: frameSize) {
                    tags[tagName] = value
                }
            }

            offset += frameSize
        }
    }

    /// Parse ID3v2 text frame content (handles different encodings)
    private func parseID3v2TextFrame(_ ptr: UnsafePointer<UInt8>, size: Int) -> String? {
        guard size > 1 else { return nil }

        let encoding = ptr[0]
        let contentPtr = ptr.advanced(by: 1)
        let contentSize = size - 1

        switch encoding {
        case 0:
            // ISO-8859-1 (Latin-1)
            let data = Data(bytes: contentPtr, count: contentSize)
            return String(data: data, encoding: .isoLatin1)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0").union(.whitespaces))

        case 1:
            // UTF-16 with BOM
            let data = Data(bytes: contentPtr, count: contentSize)
            // Check BOM
            if contentSize >= 2 {
                if contentPtr[0] == 0xFF && contentPtr[1] == 0xFE {
                    // Little endian
                    return String(data: data.dropFirst(2), encoding: .utf16LittleEndian)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0").union(.whitespaces))
                } else if contentPtr[0] == 0xFE && contentPtr[1] == 0xFF {
                    // Big endian
                    return String(data: data.dropFirst(2), encoding: .utf16BigEndian)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0").union(.whitespaces))
                }
            }
            return String(data: data, encoding: .utf16)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0").union(.whitespaces))

        case 2:
            // UTF-16BE (no BOM)
            let data = Data(bytes: contentPtr, count: contentSize)
            return String(data: data, encoding: .utf16BigEndian)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0").union(.whitespaces))

        case 3:
            // UTF-8
            let data = Data(bytes: contentPtr, count: contentSize)
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0").union(.whitespaces))

        default:
            return nil
        }
    }

    private func parseID3v1Tags(_ ptr: UnsafePointer<CChar>, into tags: inout [String: String]) {
        // ID3v1 is a 128-byte fixed structure starting with "TAG"
        let raw = UnsafeRawPointer(ptr)

        func extractString(at offset: Int, length: Int) -> String? {
            let bytes = raw.advanced(by: offset).assumingMemoryBound(to: CChar.self)
            var buffer = [CChar](repeating: 0, count: length + 1)
            for i in 0..<length {
                buffer[i] = bytes[i]
            }
            let str = String(cString: buffer).trimmingCharacters(in: .whitespaces)
            return str.isEmpty ? nil : str
        }

        // TAG starts at offset 0 (3 bytes)
        // Title: offset 3, 30 bytes
        // Artist: offset 33, 30 bytes
        // Album: offset 63, 30 bytes
        // Year: offset 93, 4 bytes
        if let title = extractString(at: 3, length: 30) { tags["title"] = title }
        if let artist = extractString(at: 33, length: 30) { tags["artist"] = artist }
        if let album = extractString(at: 63, length: 30) { tags["album"] = album }
        if let year = extractString(at: 93, length: 4) { tags["year"] = year }
    }

    /// Parse ICY headers (format: "key:value\r\n" or "key:value\0")
    private func parseICYTags(_ ptr: UnsafePointer<CChar>, into tags: inout [String: String]) {
        var current = ptr
        while current.pointee != 0 {
            let line = String(cString: current)
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Parse "key:value" format
            if let colonIdx = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIdx]).lowercased().trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)

                // Map ICY keys to standard tag names
                switch key {
                case "icy-name":
                    if tags["title"] == nil { tags["title"] = value }
                case "icy-description":
                    if tags["album"] == nil { tags["album"] = value }
                case "icy-genre":
                    if tags["genre"] == nil { tags["genre"] = value }
                case "icy-url":
                    if tags["url"] == nil { tags["url"] = value }
                default:
                    break
                }
            }

            current = current.advanced(by: line.utf8.count + 1)
        }
    }

    /// Parse Shoutcast META tag (format: "StreamTitle='Artist - Title';StreamUrl='...';")
    private func parseShoutcastMeta(_ ptr: UnsafePointer<CChar>, into tags: inout [String: String]) {
        let meta = String(cString: ptr)

        // Parse StreamTitle='...'
        if let range = meta.range(of: "StreamTitle='") {
            var rawTitle = String(meta[range.upperBound...])
            if let endRange = rawTitle.range(of: "';") {
                rawTitle = String(rawTitle[..<endRange.lowerBound])
            }
            rawTitle = rawTitle.trimmingCharacters(in: .whitespaces)

            if !rawTitle.isEmpty {
                // Try iHeart Format 2: "Artist - text="Title" song_spot="M" ..."
                if let textRange = rawTitle.range(of: " - text=\"") {
                    let artist = String(rawTitle[..<textRange.lowerBound])
                    let afterText = rawTitle[textRange.upperBound...]
                    if let endQuote = afterText.firstIndex(of: "\"") {
                        let title = String(afterText[..<endQuote])
                        if !title.isEmpty { tags["title"] = title }
                        if !artist.isEmpty { tags["artist"] = artist }
                        // Done if we found something
                        if !tags.isEmpty {
                            parseShoutcastURL(meta, into: &tags)
                            return
                        }
                    }
                }

                // Try iHeart Format 1: title="...",artist="..."
                if rawTitle.contains("title=\"") {
                    if let titleRange = rawTitle.range(of: "title=\"") {
                        let afterTitle = rawTitle[titleRange.upperBound...]
                        if let endQuote = afterTitle.firstIndex(of: "\"") {
                            tags["title"] = String(afterTitle[..<endQuote])
                        }
                    }
                    if let artistRange = rawTitle.range(of: "artist=\"") {
                        let afterArtist = rawTitle[artistRange.upperBound...]
                        if let endQuote = afterArtist.firstIndex(of: "\"") {
                            tags["artist"] = String(afterArtist[..<endQuote])
                        }
                    }
                    // Done if we found something
                    if tags["title"] != nil || tags["artist"] != nil {
                        parseShoutcastURL(meta, into: &tags)
                        return
                    }
                }

                // Standard "Artist - Title" format
                if rawTitle.contains(" - ") {
                    let parts = rawTitle.components(separatedBy: " - ")
                    if parts.count >= 2 {
                        tags["artist"] = parts[0].trimmingCharacters(in: .whitespaces)
                        tags["title"] = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                    } else {
                        tags["title"] = rawTitle
                    }
                } else {
                    tags["title"] = rawTitle
                }
            }
        }

        parseShoutcastURL(meta, into: &tags)
    }

    /// Parse StreamUrl from Shoutcast META
    private func parseShoutcastURL(_ meta: String, into tags: inout [String: String]) {
        if let range = meta.range(of: "StreamUrl='") {
            var url = String(meta[range.upperBound...])
            if let endRange = url.range(of: "';") {
                url = String(url[..<endRange.lowerBound])
            }
            if !url.isEmpty {
                tags["url"] = url
            }
        }
    }

    /// Free current stream
    private func freeStream() {
        if endSync != 0 {
            BASS_ChannelRemoveSync(_fxStream, endSync)
            endSync = 0
        }
        if metaSync != 0 {
            BASS_ChannelRemoveSync(_fxStream, metaSync)
            metaSync = 0
        }

        // Only free _fxStream - it owns the source stream via BASS_FX_FREESOURCE
        if _fxStream != 0 {
            BASS_StreamFree(_fxStream)
            _fxStream = 0
        }

        stream = 0
        sourceStream = 0
        isPlaying = false
        isPaused = false
        isLiveStream = false
        currentBitrate = 0
        isVBR = false
        chapters = []
    }

    /// Handle track end
    private func handleTrackEnd() {
        isPlaying = false
        isPaused = false
        onTrackEnd?()
    }

    /// Parse Shoutcast/Icecast metadata
    private func parseStreamMeta(_ meta: String) {
        // Parse StreamTitle='...'
        if let range = meta.range(of: "StreamTitle='") {
            var rawTitle = String(meta[range.upperBound...])
            if let endRange = rawTitle.range(of: "';") {
                rawTitle = String(rawTitle[..<endRange.lowerBound])
            }
            rawTitle = rawTitle.trimmingCharacters(in: .whitespaces)

            // Parse the title into artist/title components
            let displayTitle = parseStreamTitle(rawTitle)

            DispatchQueue.main.async { [weak self] in
                self?.onMetadataChange?(displayTitle)
                // Record to song history (matches Windows AnnounceStreamMetadata)
                if !displayTitle.isEmpty {
                    DatabaseManager.shared.addSongHistoryEntry(title: displayTitle)
                }
            }
        }
    }

    /// Parse stream title into formatted "Artist - Title" (handles iHeart and standard formats)
    private func parseStreamTitle(_ rawTitle: String) -> String {
        var artist = ""
        var title = ""

        // Try iHeart Format 2: "Artist - text="Title" song_spot="M" ..."
        if let textRange = rawTitle.range(of: " - text=\"") {
            artist = String(rawTitle[..<textRange.lowerBound])
            let afterText = rawTitle[textRange.upperBound...]
            if let endQuote = afterText.firstIndex(of: "\"") {
                title = String(afterText[..<endQuote])
            }
            if !artist.isEmpty && !title.isEmpty {
                return "\(artist) - \(title)"
            } else if !title.isEmpty {
                return title
            }
        }

        // Try iHeart Format 1: title="...",artist="..."
        if rawTitle.contains("title=\"") {
            // Extract title
            if let titleRange = rawTitle.range(of: "title=\"") {
                let afterTitle = rawTitle[titleRange.upperBound...]
                if let endQuote = afterTitle.firstIndex(of: "\"") {
                    title = String(afterTitle[..<endQuote])
                }
            }
            // Extract artist
            if let artistRange = rawTitle.range(of: "artist=\"") {
                let afterArtist = rawTitle[artistRange.upperBound...]
                if let endQuote = afterArtist.firstIndex(of: "\"") {
                    artist = String(afterArtist[..<endQuote])
                }
            }
            if !artist.isEmpty && !title.isEmpty {
                return "\(artist) - \(title)"
            } else if !title.isEmpty {
                return title
            } else if !artist.isEmpty {
                return artist
            }
        }

        // Try standard "Artist - Title" format
        if rawTitle.contains(" - ") {
            let parts = rawTitle.components(separatedBy: " - ")
            if parts.count >= 2 {
                artist = parts[0].trimmingCharacters(in: .whitespaces)
                title = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                return "\(artist) - \(title)"
            }
        }

        // Return raw title if no format matched
        return rawTitle
    }

    // MARK: - Playback Control

    func play() {
        // If no stream loaded but we have a track in playlist, reload it
        // (This handles the case where a live stream was stopped/freed)
        if _fxStream == 0 {
            if let path = PlaylistManager.shared.currentTrackPath {
                // Check if it's a URL (stream) or local file
                let isURL = path.hasPrefix("http://") || path.hasPrefix("https://")
                let loaded = isURL ? loadURL(path) : loadFile(path)

                if loaded {
                    // loadFile/loadURL sets up the stream, call play for files
                    if !isPlaying {
                        _ = BASS_ChannelPlay(_fxStream, BOOL32(0))
                        isPlaying = true
                        isPaused = false
                    }
                }
            }
            return
        }

        if BASS_ChannelPlay(_fxStream, BOOL32(0)) != 0 {
            isPlaying = true
            isPaused = false
        }
    }

    func pause() {
        guard _fxStream != 0 else { return }

        // Don't allow pausing live streams
        if isLiveStream {
            AccessibilityManager.announce("Cannot pause live stream")
            return
        }

        if BASS_ChannelPause(_fxStream) != 0 {
            isPlaying = false
            isPaused = true
        }
    }

    func stop() {
        guard _fxStream != 0 else { return }

        // For live streams, free the stream entirely to disconnect
        // (otherwise BASS buffers it and stop/play acts like pause/resume)
        if isLiveStream {
            freeStream()
        } else {
            BASS_ChannelStop(_fxStream)
            BASS_ChannelSetPosition(_fxStream, 0, DWORD(BASS_POS_BYTE))
            isPlaying = false
            isPaused = false
        }
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    // MARK: - Position & Duration

    /// Current position in seconds
    var currentPosition: Double {
        guard _fxStream != 0 else { return 0 }
        let bytes = BASS_ChannelGetPosition(_fxStream, DWORD(BASS_POS_BYTE))
        return BASS_ChannelBytes2Seconds(_fxStream, bytes)
    }

    /// Total duration in seconds (-1 for live streams)
    var duration: Double {
        guard _fxStream != 0, !isLiveStream else { return -1 }
        let bytes = BASS_ChannelGetLength(_fxStream, DWORD(BASS_POS_BYTE))
        return BASS_ChannelBytes2Seconds(_fxStream, bytes)
    }

    /// Seek to absolute position
    func seek(to position: Double) {
        guard _fxStream != 0, !isLiveStream else { return }

        var pos = position
        let dur = duration
        if dur > 0 {
            pos = max(0, min(pos, dur))
        }

        let bytes = BASS_ChannelSeconds2Bytes(_fxStream, pos)
        BASS_ChannelSetPosition(_fxStream, bytes, DWORD(BASS_POS_BYTE))
    }

    /// Seek by relative amount
    func seek(by amount: Double) {
        seek(to: currentPosition + amount)
    }

    // MARK: - Volume

    /// Get current volume (0.0 - 4.0)
    var currentVolume: Float {
        return isMuted ? 0 : volume
    }

    /// Set volume (0.0 - 4.0)
    func setVolume(_ newVolume: Float) {
        let maxVol = SettingsManager.shared.allowAmplify ? AudioEngine.maxVolumeAmplify : AudioEngine.maxVolumeNormal
        volume = max(0, min(newVolume, maxVol))
        SettingsManager.shared.volume = volume
        applyVolume()

        // Announce if enabled
        if SettingsManager.shared.speechVolume {
            let percent = Int(volume * 100)
            AccessibilityManager.announce("\(percent) percent")
        }
    }

    /// Adjust volume by amount
    func adjustVolume(by amount: Float) {
        setVolume(volume + amount)
    }

    /// Toggle mute
    func toggleMute() {
        isMuted.toggle()
        SettingsManager.shared.muted = isMuted
        applyVolume()

        if SettingsManager.shared.speechVolume {
            AccessibilityManager.announce(isMuted ? "Muted" : "Unmuted")
        }
    }

    /// Current mute state
    var muted: Bool { isMuted }

    /// Set mute state without announcing — used by the scheduler.
    func setMuted(_ value: Bool) {
        guard isMuted != value else { return }
        isMuted = value
        SettingsManager.shared.muted = isMuted
        applyVolume()
    }

    private func applyVolume() {
        guard _fxStream != 0 else { return }

        let effectiveVolume = isMuted ? 0 : volume

        if legacyVolume {
            // Legacy: set channel volume directly
            BASS_ChannelSetAttribute(_fxStream, DWORD(BASS_ATTRIB_VOL), effectiveVolume)
        } else {
            // Modern: use volume attribute (doesn't affect recording)
            BASS_ChannelSlideAttribute(_fxStream, DWORD(BASS_ATTRIB_VOL), effectiveVolume, 50)
        }
    }

    // MARK: - Tempo/Pitch/Rate

    /// Get/set tempo adjustment (-50 to +100 percent)
    var tempoValue: Float {
        get { tempo }
        set {
            tempo = max(-50, min(newValue, 100))
            applyTempoSettings()
        }
    }

    /// Get/set pitch adjustment (-12 to +12 semitones)
    var pitchValue: Float {
        get { pitch }
        set {
            pitch = max(-12, min(newValue, 12))
            applyTempoSettings()
        }
    }

    /// Get/set rate (0.5 to 2.0)
    var rateValue: Float {
        get { rate }
        set {
            rate = max(0.5, min(newValue, 2.0))
            applyTempoSettings()
        }
    }

    /// Apply stream effects (called when toggling effects)
    func applyStreamEffects() {
        applyTempoSettings()
        applyVolume()
    }

    private func applyTempoSettings() {
        guard _fxStream != 0 else { return }

        // Apply SoundTouch options from settings
        let settings = SettingsManager.shared
        BASS_ChannelSetAttribute(_fxStream, DWORD(BASS_ATTRIB_TEMPO_OPTION_USE_AA_FILTER), settings.stAntiAliasFilter ? 1 : 0)
        BASS_ChannelSetAttribute(_fxStream, DWORD(BASS_ATTRIB_TEMPO_OPTION_AA_FILTER_LENGTH), Float(settings.stAAFilterLength))
        BASS_ChannelSetAttribute(_fxStream, DWORD(BASS_ATTRIB_TEMPO_OPTION_USE_QUICKALGO), settings.stQuickAlgorithm ? 1 : 0)
        BASS_ChannelSetAttribute(_fxStream, DWORD(BASS_ATTRIB_TEMPO_OPTION_SEQUENCE_MS), Float(settings.stSequenceMs))
        BASS_ChannelSetAttribute(_fxStream, DWORD(BASS_ATTRIB_TEMPO_OPTION_SEEKWINDOW_MS), Float(settings.stSeekWindowMs))
        BASS_ChannelSetAttribute(_fxStream, DWORD(BASS_ATTRIB_TEMPO_OPTION_OVERLAP_MS), Float(settings.stOverlapMs))
        BASS_ChannelSetAttribute(_fxStream, DWORD(BASS_ATTRIB_TEMPO_OPTION_PREVENT_CLICK), settings.stPreventClick ? 1 : 0)

        // Pitch always works, even on live streams
        BASS_ChannelSetAttribute(_fxStream, DWORD(BASS_ATTRIB_TEMPO_PITCH), pitch)

        // For live streams, tempo and rate changes are not supported (requires seeking)
        if isLiveStream {
            return
        }

        // Apply tempo (only for seekable streams)
        BASS_ChannelSetAttribute(_fxStream, DWORD(BASS_ATTRIB_TEMPO), tempo)

        // Apply rate via frequency (only for seekable streams)
        let newFreq = originalFreq * rate
        BASS_ChannelSetAttribute(_fxStream, DWORD(BASS_ATTRIB_TEMPO_FREQ), newFreq)
    }

    /// Reset tempo/pitch/rate to defaults
    func resetEffects() {
        tempo = 0
        pitch = 0
        rate = 1.0
        applyTempoSettings()
    }

    /// Update EQ frequencies (called when settings change)
    func updateEQFrequencies() {
        // Re-apply DSP effects to pick up new EQ frequencies
        DSPEffectsManager.shared.applyEffects()
    }

    // MARK: - State Queries

    /// Get current playback state
    var state: PlaybackState {
        guard _fxStream != 0 else { return .stopped }

        let bassState = BASS_ChannelIsActive(_fxStream)
        switch Int32(bassState) {
        case BASS_ACTIVE_PLAYING:
            return .playing
        case BASS_ACTIVE_PAUSED:
            return .paused
        case BASS_ACTIVE_STALLED:
            return .stalled
        default:
            return .stopped
        }
    }

    /// Check if a stream is loaded
    var hasStream: Bool {
        return _fxStream != 0
    }

    // MARK: - Chapter Seeking

    /// Get index of current chapter based on playback position (-1 if no chapters)
    func getCurrentChapterIndex() -> Int {
        guard !chapters.isEmpty else { return -1 }

        let pos = currentPosition
        var currentChapter = -1

        // Find the last chapter whose position is <= current position
        for (i, chapter) in chapters.enumerated() {
            if chapter.position <= pos {
                currentChapter = i
            } else {
                break  // Chapters are sorted
            }
        }
        return currentChapter
    }

    /// Seek to next chapter (returns true if successful)
    @discardableResult
    func seekToNextChapter() -> Bool {
        guard !chapters.isEmpty, _fxStream != 0 else { return false }

        let pos = currentPosition

        // Find the first chapter after current position (with small tolerance for current chapter)
        for (i, chapter) in chapters.enumerated() {
            if chapter.position > pos + 0.5 {  // 0.5s tolerance
                seek(to: chapter.position)

                // Announce chapter name
                if SettingsManager.shared.speechEffect {
                    AccessibilityManager.announce("Chapter \(i + 1): \(chapter.name)")
                }
                return true
            }
        }
        return false  // Already at or past last chapter
    }

    /// Seek to previous chapter (returns true if successful)
    @discardableResult
    func seekToPrevChapter() -> Bool {
        guard !chapters.isEmpty, _fxStream != 0 else { return false }

        let pos = currentPosition

        // Find the chapter before current position
        // If we're more than 3 seconds into a chapter, go to its start
        // Otherwise go to the previous chapter
        let currentChapter = getCurrentChapterIndex()

        if currentChapter < 0 {
            // Before first chapter, go to start
            seek(to: 0)
            return true
        }

        let chapterStart = chapters[currentChapter].position

        if pos - chapterStart > 3.0 && currentChapter >= 0 {
            // More than 3 seconds into current chapter - restart it
            seek(to: chapterStart)
            if SettingsManager.shared.speechEffect {
                AccessibilityManager.announce("Chapter \(currentChapter + 1): \(chapters[currentChapter].name)")
            }
            return true
        } else if currentChapter > 0 {
            // Go to previous chapter
            let prevChapter = currentChapter - 1
            seek(to: chapters[prevChapter].position)
            if SettingsManager.shared.speechEffect {
                AccessibilityManager.announce("Chapter \(prevChapter + 1): \(chapters[prevChapter].name)")
            }
            return true
        } else {
            // At first chapter, go to start
            seek(to: 0)
            if SettingsManager.shared.speechEffect {
                AccessibilityManager.announce("Beginning")
            }
            return true
        }
    }
}

// MARK: - Playback State Enum

enum PlaybackState {
    case stopped
    case playing
    case paused
    case stalled
}
