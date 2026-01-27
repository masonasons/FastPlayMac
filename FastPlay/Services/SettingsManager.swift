//
//  SettingsManager.swift
//  FastPlay
//
//  Settings persistence using INI format (compatible with Windows)
//  Maps to Windows settings.cpp - ALL DEFAULTS MUST MATCH WINDOWS
//

import Foundation

class SettingsManager {

    // MARK: - Singleton

    static let shared = SettingsManager()

    // MARK: - File Paths

    private var configPath: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("FastPlay")
        return appDir.appendingPathComponent("FastPlay.ini")
    }

    var databasePath: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("FastPlay")
        return appDir.appendingPathComponent("FastPlay.db")
    }

    // MARK: - Volume & Playback (matching Windows defaults)

    var volume: Float = 1.0                    // 100% (Windows: g_volume = 1.0f)
    var muted: Bool = false                    // (Windows: g_muted = false)
    var legacyVolume: Bool = false             // (Windows: g_legacyVolume = false)
    var volumeStep: Float = 0.02               // 2% (Windows: g_volumeStep = 0.02f)

    // MARK: - Effects (matching Windows defaults)

    var tempo: Float = 0.0                     // (Windows: g_tempo = 0.0f)
    var pitch: Float = 0.0                     // (Windows: g_pitch = 0.0f)
    var rate: Float = 1.0                      // (Windows: g_rate = 1.0f)

    var effectEnabled: [Bool] = [true, false, false, false]  // Volume enabled by default
    var currentEffectIndex: Int = 0
    var rateStepMode: Int = 0                  // 0=0.01x, 1=Semitone

    // MARK: - Device & Buffer (matching Windows defaults)

    var selectedDevice: Int = -1               // Default device
    var selectedDeviceName: String = ""
    var bufferSize: Int = 500                  // (Windows: g_bufferSize = 500)
    var updatePeriod: Int = 100                // (Windows: g_updatePeriod = 100)

    // MARK: - SoundTouch Settings (matching Windows defaults)
    var stAntiAliasFilter: Bool = true         // (Windows: g_stAntiAliasFilter = true)
    var stAAFilterLength: Int = 32             // (Windows: g_stAAFilterLength = 32)
    var stQuickAlgorithm: Bool = false         // (Windows: g_stQuickAlgorithm = false)
    var stSequenceMs: Int = 82                 // (Windows: g_stSequenceMs = 82)
    var stSeekWindowMs: Int = 28               // (Windows: g_stSeekWindowMs = 28)
    var stOverlapMs: Int = 8                   // (Windows: g_stOverlapMs = 8)
    var stPreventClick: Bool = false           // (Windows: g_stPreventClick = false)
    var stAlgorithm: Int = 1                   // 0=Linear, 1=Cubic, 2=Shannon

    // MARK: - Effects Settings (matching Windows defaults)

    // DSP effect toggles: [Reverb, Echo, EQ, Compressor, StereoWidth, CenterCancel, Convolution]
    var dspEffectEnabled: [Bool] = [false, false, false, false, false, false, false]

    var reverbAlgorithm: Int = 0               // 0=Off (Windows: g_reverbAlgorithm = 0)
    var convolutionIRPath: String = ""

    var eqBassFreq: Float = 50.0               // (Windows: g_eqBassFreq = 50.0f)
    var eqMidFreq: Float = 1000.0              // (Windows: g_eqMidFreq = 1000.0f)
    var eqTrebleFreq: Float = 12000.0          // (Windows: g_eqTrebleFreq = 12000.0f)

    // DSP effect parameter values (matching Windows defaults)
    var reverbMix: Float = 30.0                // (Windows: g_reverbMix = 30)
    var reverbRoom: Float = 50.0               // (Windows: g_reverbRoom = 50)
    var reverbDamp: Float = 50.0               // (Windows: g_reverbDamp = 50)
    var echoDelay: Float = 300.0               // (Windows: g_echoDelay = 300)
    var echoFeedback: Float = 40.0             // (Windows: g_echoFeedback = 40)
    var echoMix: Float = 30.0                  // (Windows: g_echoMix = 30)
    var eqPreamp: Float = 0.0                  // (Windows: g_eqPreamp = 0)
    var eqBass: Float = 0.0                    // (Windows: g_eqBass = 0)
    var eqMid: Float = 0.0                     // (Windows: g_eqMid = 0)
    var eqTreble: Float = 0.0                  // (Windows: g_eqTreble = 0)
    var compThreshold: Float = -20.0           // (Windows: g_compThreshold = -20)
    var compRatio: Float = 4.0                 // (Windows: g_compRatio = 4)
    var compAttack: Float = 20.0               // (Windows: g_compAttack = 20)
    var compRelease: Float = 200.0             // (Windows: g_compRelease = 200)
    var compGain: Float = 0.0                  // (Windows: g_compGain = 0)
    var stereoWidth: Float = 100.0             // (Windows: g_stereoWidth = 100)
    var centerCancel: Float = 0.0              // (Windows: g_centerCancel = 0)
    var convolutionMix: Float = 50.0           // (Windows: g_convolutionMix = 50)
    var convolutionGain: Float = 0.0           // (Windows: g_convolutionGain = 0)

    // MARK: - MIDI Settings (matching Windows defaults)

    var midiSoundFont: String = ""             // (Windows: g_midiSoundFont empty)
    var midiMaxVoices: Int = 128               // (Windows: g_midiMaxVoices = 128)
    var midiSincInterp: Bool = false           // (Windows: g_midiSincInterp = false)

    // MARK: - YouTube Settings

    var ytdlpPath: String = ""
    var ytApiKey: String = ""

    // MARK: - Downloads Settings (matching Windows defaults)

    var downloadPath: String = ""
    var downloadOrganizeByFeed: Bool = false   // (Windows: g_downloadOrganizeByFeed = false)

    // MARK: - Recording Settings (matching Windows defaults)

    var recordPath: String = ""
    var recordTemplate: String = "%Y-%m-%d_%H-%M-%S"  // (Windows: g_recordTemplate)
    var recordFormat: Int = 0                  // 0=WAV (Windows: g_recordFormat = 0)
    var recordBitrate: Int = 192               // (Windows: g_recordBitrate = 192)

    // MARK: - Speech Settings (matching Windows defaults)

    var speechTrackChange: Bool = false        // (Windows: g_speechTrackChange = false)
    var speechVolume: Bool = true              // (Windows: g_speechVolume = true)
    var speechEffect: Bool = true              // (Windows: g_speechEffect = true)

    // MARK: - Behavior Settings (matching Windows defaults)

    var allowAmplify: Bool = false             // (Windows: g_allowAmplify = false)
    var rememberState: Bool = false            // (Windows: g_rememberState = false)
    var rememberPosMinutes: Int = 0            // (Windows: g_rememberPosMinutes = 0)
    var bringToFront: Bool = true              // (Windows: g_bringToFront = true)
    var minimizeToTray: Bool = true            // (Windows: g_minimizeToTray = true)
    var loadFolder: Bool = false               // (Windows: g_loadFolder = false)
    var showTitleInWindow: Bool = true         // (Windows: g_showTitleInWindow = true)

    // MARK: - Shuffle & Auto-advance (matching Windows defaults)

    var shuffle: Bool = false                  // (Windows: g_shuffle = false)
    var autoAdvance: Bool = true               // (Windows: g_autoAdvance = true)

    // MARK: - Chapters (matching Windows defaults)

    var chapterSeekEnabled: Bool = true        // (Windows: g_chapterSeekEnabled = true)

    // MARK: - Seek Settings (matching Windows defaults)

    /// Seek amount definition matching Windows g_seekAmounts
    struct SeekAmount {
        let value: Double
        let label: String
        let isTrack: Bool
    }

    /// Seek amounts matching Windows globals.cpp exactly
    static let defaultSeekAmounts: [SeekAmount] = [
        SeekAmount(value: 1.0, label: "1 second", isTrack: false),
        SeekAmount(value: 5.0, label: "5 seconds", isTrack: false),
        SeekAmount(value: 10.0, label: "10 seconds", isTrack: false),
        SeekAmount(value: 30.0, label: "30 seconds", isTrack: false),
        SeekAmount(value: 60.0, label: "1 minute", isTrack: false),
        SeekAmount(value: 300.0, label: "5 minutes", isTrack: false),
        SeekAmount(value: 600.0, label: "10 minutes", isTrack: false),
        SeekAmount(value: 1.0, label: "1 track", isTrack: true),
        SeekAmount(value: 5.0, label: "5 tracks", isTrack: true),
        SeekAmount(value: 10.0, label: "10 tracks", isTrack: true),
    ]

    var seekEnabled: [Bool] = [false, true, false, false, false, false, false, false, false, false]
    var currentSeekIndex: Int = 1              // 5 seconds (Windows: g_currentSeekIndex = 1)

    /// Current seek amount in seconds (only valid for non-chapter seek modes)
    var currentSeekAmount: Double {
        guard currentSeekIndex >= 0 && currentSeekIndex < SettingsManager.defaultSeekAmounts.count else { return 5 }
        return SettingsManager.defaultSeekAmounts[currentSeekIndex].value
    }

    /// Check if current seek mode is chapter seeking (index 10)
    var isChapterSeekMode: Bool {
        return currentSeekIndex == 10
    }

    /// Check if a seek amount is currently available
    /// - Parameter index: Seek index (0-9 for time/track amounts, 10 for chapter)
    /// - Returns: True if this seek mode is available
    func isSeekAmountAvailable(_ index: Int) -> Bool {
        // Index 10 is chapter seeking (virtual, not in defaultSeekAmounts array)
        if index == 10 {
            return chapterSeekEnabled && !AudioEngine.shared.chapters.isEmpty
        }
        if index < 0 || index >= SettingsManager.defaultSeekAmounts.count {
            return false
        }
        if !seekEnabled[index] {
            return false
        }
        // Track-based options only available with multiple tracks
        if SettingsManager.defaultSeekAmounts[index].isTrack {
            return PlaylistManager.shared.count > 1
        }
        return true
    }

    // MARK: - Hotkeys

    var hotkeysEnabled: Bool = true            // (Windows: g_hotkeysEnabled = true)
    var hotkeys: [[String: Any]] = []          // Stored hotkey configurations

    // MARK: - Saved State

    private var savedPath: String = ""
    private var savedPosition: Double = 0

    // MARK: - Initialization

    private init() {
        ensureAppSupportDirectory()
    }

    private func ensureAppSupportDirectory() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("FastPlay")

        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Load/Save

    func load() {
        guard FileManager.default.fileExists(atPath: configPath.path) else { return }

        guard let content = try? String(contentsOf: configPath, encoding: .utf8) else { return }

        var currentSection = ""
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix(";") || trimmed.hasPrefix("#") {
                continue
            }

            // Section header
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = String(trimmed.dropFirst().dropLast())
                continue
            }

            // Key=Value
            if let equalsIndex = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)

                parseValue(section: currentSection, key: key, value: value)
            }
        }
    }

    private func parseValue(section: String, key: String, value: String) {
        switch section {
        case "Playback":
            switch key {
            case "Volume": volume = Float(value) ?? 1.0
            case "Muted": muted = value == "1"
            case "LegacyVolume": legacyVolume = value == "1"
            case "VolumeStep": volumeStep = Float(value) ?? 0.02
            case "Tempo": tempo = Float(value) ?? 0.0
            case "Pitch": pitch = Float(value) ?? 0.0
            case "Rate": rate = Float(value) ?? 1.0
            case "Shuffle": shuffle = value == "1"
            case "AutoAdvance": autoAdvance = value == "1"
            default: break
            }

        case "Device":
            switch key {
            case "DeviceName": selectedDeviceName = value
            case "BufferSize": bufferSize = Int(value) ?? 500
            case "UpdatePeriod": updatePeriod = Int(value) ?? 100
            default: break
            }

        case "SoundTouch":
            switch key {
            case "AntiAliasFilter": stAntiAliasFilter = value == "1"
            case "AAFilterLength": stAAFilterLength = Int(value) ?? 32
            case "QuickAlgorithm": stQuickAlgorithm = value == "1"
            case "SequenceMs": stSequenceMs = Int(value) ?? 82
            case "SeekWindowMs": stSeekWindowMs = Int(value) ?? 28
            case "OverlapMs": stOverlapMs = Int(value) ?? 8
            case "PreventClick": stPreventClick = value == "1"
            case "Algorithm": stAlgorithm = Int(value) ?? 1
            default: break
            }

        case "Effects":
            switch key {
            case "Volume": effectEnabled[0] = value == "1"
            case "Pitch": effectEnabled[1] = value == "1"
            case "Tempo": effectEnabled[2] = value == "1"
            case "Rate": effectEnabled[3] = value == "1"
            case "CurrentEffect": currentEffectIndex = Int(value) ?? 0
            case "RateStepMode": rateStepMode = Int(value) ?? 0
            case "ReverbAlgorithm": reverbAlgorithm = Int(value) ?? 0
            case "ConvolutionIRPath": convolutionIRPath = value
            case "EQBassFreq": eqBassFreq = Float(value) ?? 50.0
            case "EQMidFreq": eqMidFreq = Float(value) ?? 1000.0
            case "EQTrebleFreq": eqTrebleFreq = Float(value) ?? 12000.0
            case "DSPReverb": dspEffectEnabled[0] = value == "1"
            case "DSPEcho": dspEffectEnabled[1] = value == "1"
            case "DSPEQ": dspEffectEnabled[2] = value == "1"
            case "DSPCompressor": dspEffectEnabled[3] = value == "1"
            case "DSPStereoWidth": dspEffectEnabled[4] = value == "1"
            case "DSPCenterCancel": dspEffectEnabled[5] = value == "1"
            case "DSPConvolution": dspEffectEnabled[6] = value == "1"
            // DSP parameter values
            case "ReverbMix": reverbMix = Float(value) ?? 30.0
            case "ReverbRoom": reverbRoom = Float(value) ?? 50.0
            case "ReverbDamp": reverbDamp = Float(value) ?? 50.0
            case "EchoDelay": echoDelay = Float(value) ?? 300.0
            case "EchoFeedback": echoFeedback = Float(value) ?? 40.0
            case "EchoMix": echoMix = Float(value) ?? 30.0
            case "EQPreamp": eqPreamp = Float(value) ?? 0.0
            case "EQBass": eqBass = Float(value) ?? 0.0
            case "EQMid": eqMid = Float(value) ?? 0.0
            case "EQTreble": eqTreble = Float(value) ?? 0.0
            case "CompThreshold": compThreshold = Float(value) ?? -20.0
            case "CompRatio": compRatio = Float(value) ?? 4.0
            case "CompAttack": compAttack = Float(value) ?? 20.0
            case "CompRelease": compRelease = Float(value) ?? 200.0
            case "CompGain": compGain = Float(value) ?? 0.0
            case "StereoWidth": stereoWidth = Float(value) ?? 100.0
            case "CenterCancel": centerCancel = Float(value) ?? 0.0
            case "ConvolutionMix": convolutionMix = Float(value) ?? 50.0
            case "ConvolutionGain": convolutionGain = Float(value) ?? 0.0
            default: break
            }

        case "MIDI":
            switch key {
            case "SoundFont": midiSoundFont = value
            case "MaxVoices": midiMaxVoices = Int(value) ?? 128
            case "SincInterp": midiSincInterp = value == "1"
            default: break
            }

        case "YouTube":
            switch key {
            case "YtdlpPath": ytdlpPath = value
            case "ApiKey": ytApiKey = value
            default: break
            }

        case "Downloads":
            switch key {
            case "DownloadPath": downloadPath = value
            case "OrganizeByFeed": downloadOrganizeByFeed = value == "1"
            default: break
            }

        case "Recording":
            switch key {
            case "RecordPath": recordPath = value
            case "RecordTemplate": recordTemplate = value
            case "RecordFormat": recordFormat = Int(value) ?? 0
            case "RecordBitrate": recordBitrate = Int(value) ?? 192
            default: break
            }

        case "Speech":
            switch key {
            case "TrackChange": speechTrackChange = value == "1"
            case "Volume": speechVolume = value == "1"
            case "Effect": speechEffect = value == "1"
            default: break
            }

        case "Options":
            switch key {
            case "AllowAmplify": allowAmplify = value == "1"
            case "RememberState": rememberState = value == "1"
            case "RememberPosMinutes": rememberPosMinutes = Int(value) ?? 0
            case "BringToFront": bringToFront = value == "1"
            case "MinimizeToTray": minimizeToTray = value == "1"
            case "LoadFolder": loadFolder = value == "1"
            case "ShowTitleInWindow": showTitleInWindow = value == "1"
            case "HotkeysEnabled": hotkeysEnabled = value == "1"
            case "ChapterSeekEnabled": chapterSeekEnabled = value == "1"
            default: break
            }

        case "Seek":
            if key == "CurrentIndex" {
                currentSeekIndex = Int(value) ?? 1
            } else if key.hasPrefix("Enabled") {
                if let idx = Int(key.dropFirst(7)), idx < seekEnabled.count {
                    seekEnabled[idx] = value == "1"
                }
            }

        case "SavedState":
            switch key {
            case "Path": savedPath = value
            case "Position": savedPosition = Double(value) ?? 0
            default: break
            }

        case "Hotkeys":
            if key == "Count" {
                // Clear existing hotkeys before loading new ones
                hotkeys.removeAll()
            } else if key.hasPrefix("Hotkey") {
                // Format: modifiers,keyCode,action,keyDisplay
                let parts = value.split(separator: ",", maxSplits: 3, omittingEmptySubsequences: false)
                if parts.count >= 4,
                   let modifiers = UInt(parts[0]),
                   let keyCode = UInt16(parts[1]) {
                    let action = String(parts[2])
                    let keyDisplay = String(parts[3])
                    let hotkeyData: [String: Any] = [
                        "modifiers": modifiers,
                        "keyCode": keyCode,
                        "action": action,
                        "key": keyDisplay
                    ]
                    hotkeys.append(hotkeyData)
                }
            }

        default:
            break
        }
    }

    func save() {
        var content = ""

        // Playback section
        content += "[Playback]\n"
        content += "Volume=\(volume)\n"
        content += "Muted=\(muted ? 1 : 0)\n"
        content += "LegacyVolume=\(legacyVolume ? 1 : 0)\n"
        content += "VolumeStep=\(volumeStep)\n"
        content += "Tempo=\(tempo)\n"
        content += "Pitch=\(pitch)\n"
        content += "Rate=\(rate)\n"
        content += "Shuffle=\(shuffle ? 1 : 0)\n"
        content += "AutoAdvance=\(autoAdvance ? 1 : 0)\n"
        content += "\n"

        // Device section
        content += "[Device]\n"
        content += "DeviceName=\(selectedDeviceName)\n"
        content += "BufferSize=\(bufferSize)\n"
        content += "UpdatePeriod=\(updatePeriod)\n"
        content += "\n"

        // SoundTouch section
        content += "[SoundTouch]\n"
        content += "AntiAliasFilter=\(stAntiAliasFilter ? 1 : 0)\n"
        content += "AAFilterLength=\(stAAFilterLength)\n"
        content += "QuickAlgorithm=\(stQuickAlgorithm ? 1 : 0)\n"
        content += "SequenceMs=\(stSequenceMs)\n"
        content += "SeekWindowMs=\(stSeekWindowMs)\n"
        content += "OverlapMs=\(stOverlapMs)\n"
        content += "PreventClick=\(stPreventClick ? 1 : 0)\n"
        content += "Algorithm=\(stAlgorithm)\n"
        content += "\n"

        // Effects section
        content += "[Effects]\n"
        content += "Volume=\(effectEnabled[0] ? 1 : 0)\n"
        content += "Pitch=\(effectEnabled[1] ? 1 : 0)\n"
        content += "Tempo=\(effectEnabled[2] ? 1 : 0)\n"
        content += "Rate=\(effectEnabled[3] ? 1 : 0)\n"
        content += "CurrentEffect=\(currentEffectIndex)\n"
        content += "RateStepMode=\(rateStepMode)\n"
        content += "ReverbAlgorithm=\(reverbAlgorithm)\n"
        content += "ConvolutionIRPath=\(convolutionIRPath)\n"
        content += "EQBassFreq=\(eqBassFreq)\n"
        content += "EQMidFreq=\(eqMidFreq)\n"
        content += "EQTrebleFreq=\(eqTrebleFreq)\n"
        content += "DSPReverb=\(dspEffectEnabled[0] ? 1 : 0)\n"
        content += "DSPEcho=\(dspEffectEnabled[1] ? 1 : 0)\n"
        content += "DSPEQ=\(dspEffectEnabled[2] ? 1 : 0)\n"
        content += "DSPCompressor=\(dspEffectEnabled[3] ? 1 : 0)\n"
        content += "DSPStereoWidth=\(dspEffectEnabled[4] ? 1 : 0)\n"
        content += "DSPCenterCancel=\(dspEffectEnabled[5] ? 1 : 0)\n"
        content += "DSPConvolution=\(dspEffectEnabled[6] ? 1 : 0)\n"
        // DSP parameter values
        content += "ReverbMix=\(reverbMix)\n"
        content += "ReverbRoom=\(reverbRoom)\n"
        content += "ReverbDamp=\(reverbDamp)\n"
        content += "EchoDelay=\(echoDelay)\n"
        content += "EchoFeedback=\(echoFeedback)\n"
        content += "EchoMix=\(echoMix)\n"
        content += "EQPreamp=\(eqPreamp)\n"
        content += "EQBass=\(eqBass)\n"
        content += "EQMid=\(eqMid)\n"
        content += "EQTreble=\(eqTreble)\n"
        content += "CompThreshold=\(compThreshold)\n"
        content += "CompRatio=\(compRatio)\n"
        content += "CompAttack=\(compAttack)\n"
        content += "CompRelease=\(compRelease)\n"
        content += "CompGain=\(compGain)\n"
        content += "StereoWidth=\(stereoWidth)\n"
        content += "CenterCancel=\(centerCancel)\n"
        content += "ConvolutionMix=\(convolutionMix)\n"
        content += "ConvolutionGain=\(convolutionGain)\n"
        content += "\n"

        // MIDI section
        content += "[MIDI]\n"
        content += "SoundFont=\(midiSoundFont)\n"
        content += "MaxVoices=\(midiMaxVoices)\n"
        content += "SincInterp=\(midiSincInterp ? 1 : 0)\n"
        content += "\n"

        // YouTube section
        content += "[YouTube]\n"
        content += "YtdlpPath=\(ytdlpPath)\n"
        content += "ApiKey=\(ytApiKey)\n"
        content += "\n"

        // Downloads section
        content += "[Downloads]\n"
        content += "DownloadPath=\(downloadPath)\n"
        content += "OrganizeByFeed=\(downloadOrganizeByFeed ? 1 : 0)\n"
        content += "\n"

        // Recording section
        content += "[Recording]\n"
        content += "RecordPath=\(recordPath)\n"
        content += "RecordTemplate=\(recordTemplate)\n"
        content += "RecordFormat=\(recordFormat)\n"
        content += "RecordBitrate=\(recordBitrate)\n"
        content += "\n"

        // Speech section
        content += "[Speech]\n"
        content += "TrackChange=\(speechTrackChange ? 1 : 0)\n"
        content += "Volume=\(speechVolume ? 1 : 0)\n"
        content += "Effect=\(speechEffect ? 1 : 0)\n"
        content += "\n"

        // Options section
        content += "[Options]\n"
        content += "AllowAmplify=\(allowAmplify ? 1 : 0)\n"
        content += "RememberState=\(rememberState ? 1 : 0)\n"
        content += "RememberPosMinutes=\(rememberPosMinutes)\n"
        content += "BringToFront=\(bringToFront ? 1 : 0)\n"
        content += "MinimizeToTray=\(minimizeToTray ? 1 : 0)\n"
        content += "LoadFolder=\(loadFolder ? 1 : 0)\n"
        content += "ShowTitleInWindow=\(showTitleInWindow ? 1 : 0)\n"
        content += "HotkeysEnabled=\(hotkeysEnabled ? 1 : 0)\n"
        content += "ChapterSeekEnabled=\(chapterSeekEnabled ? 1 : 0)\n"
        content += "\n"

        // Seek section
        content += "[Seek]\n"
        content += "CurrentIndex=\(currentSeekIndex)\n"
        for (i, enabled) in seekEnabled.enumerated() {
            content += "Enabled\(i)=\(enabled ? 1 : 0)\n"
        }
        content += "\n"

        // Saved state section
        content += "[SavedState]\n"
        content += "Path=\(savedPath)\n"
        content += "Position=\(savedPosition)\n"
        content += "\n"

        // Hotkeys section
        content += "[Hotkeys]\n"
        content += "Count=\(hotkeys.count)\n"
        for (i, hk) in hotkeys.enumerated() {
            let modifiers = hk["modifiers"] as? UInt ?? 0
            let keyCode = hk["keyCode"] as? UInt16 ?? 0
            let action = hk["action"] as? String ?? ""
            let keyDisplay = hk["key"] as? String ?? ""
            content += "Hotkey\(i)=\(modifiers),\(keyCode),\(action),\(keyDisplay)\n"
        }

        try? content.write(to: configPath, atomically: true, encoding: .utf8)
    }

    // MARK: - Playback State

    func savePlaybackState() {
        if let path = PlaylistManager.shared.currentTrackPath {
            savedPath = path
            savedPosition = AudioEngine.shared.currentPosition
            save()
        }
    }

    func restorePlaybackState() -> (path: String, position: Double)? {
        guard !savedPath.isEmpty, savedPosition > 0 else { return nil }
        return (savedPath, savedPosition)
    }
}
