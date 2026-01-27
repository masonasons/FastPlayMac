//
//  HotkeyManager.swift
//  FastPlay
//
//  Global hotkey registration using Carbon APIs
//  Replaces Windows RegisterHotKey
//

import AppKit
import Carbon

class HotkeyManager {

    // MARK: - Singleton

    static let shared = HotkeyManager()

    // MARK: - Properties

    private var hotkeys: [Int: EventHotKeyRef] = [:]
    private var nextId: Int = 1

    /// Hotkey actions matching Windows (IDM_ constants)
    enum HotkeyAction: Int, CaseIterable {
        // Playback
        case playPause = 1001
        case play = 1002
        case pause = 1003
        case stop = 1004
        case prevTrack = 1005
        case nextTrack = 1006

        // Seeking
        case seekBack = 1010
        case seekForward = 1011
        case prevSeekUnit = 1012
        case nextSeekUnit = 1013
        case speakSeekUnit = 1014

        // Volume
        case volumeUp = 1020
        case volumeDown = 1021

        // Speech feedback
        case speakElapsed = 1030
        case speakRemaining = 1031
        case speakTotal = 1032
        case speakNowPlaying = 1033

        // Effects navigation
        case prevEffect = 1040
        case nextEffect = 1041
        case effectUp = 1042
        case effectDown = 1043

        // Effect toggles
        case toggleVolume = 1050
        case togglePitch = 1051
        case toggleTempo = 1052
        case toggleRate = 1053
        case toggleReverb = 1054
        case toggleEcho = 1055
        case toggleEQ = 1056
        case toggleCompressor = 1057
        case toggleStereoWidth = 1058
        case toggleCenterCancel = 1059

        // Window/UI
        case toggleWindow = 1070
        case youtubeSearch = 1071

        // Recording
        case toggleRecording = 1080

        // Shuffle
        case toggleShuffle = 1090

        /// Display name for UI
        var displayName: String {
            switch self {
            case .playPause: return "Play/Pause"
            case .play: return "Play"
            case .pause: return "Pause"
            case .stop: return "Stop"
            case .prevTrack: return "Previous Track"
            case .nextTrack: return "Next Track"
            case .seekBack: return "Seek Backward"
            case .seekForward: return "Seek Forward"
            case .prevSeekUnit: return "Previous Seek Unit"
            case .nextSeekUnit: return "Next Seek Unit"
            case .speakSeekUnit: return "Speak Seek Unit"
            case .volumeUp: return "Volume Up"
            case .volumeDown: return "Volume Down"
            case .speakElapsed: return "Speak Elapsed Time"
            case .speakRemaining: return "Speak Remaining Time"
            case .speakTotal: return "Speak Total Time"
            case .speakNowPlaying: return "Speak Now Playing"
            case .prevEffect: return "Previous Effect"
            case .nextEffect: return "Next Effect"
            case .effectUp: return "Increase Effect"
            case .effectDown: return "Decrease Effect"
            case .toggleVolume: return "Toggle Volume"
            case .togglePitch: return "Toggle Pitch"
            case .toggleTempo: return "Toggle Tempo"
            case .toggleRate: return "Toggle Rate"
            case .toggleReverb: return "Toggle Reverb"
            case .toggleEcho: return "Toggle Echo"
            case .toggleEQ: return "Toggle EQ"
            case .toggleCompressor: return "Toggle Compressor"
            case .toggleStereoWidth: return "Toggle Stereo Width"
            case .toggleCenterCancel: return "Toggle Center Cancel"
            case .toggleWindow: return "Toggle Window"
            case .youtubeSearch: return "YouTube Search"
            case .toggleRecording: return "Toggle Recording"
            case .toggleShuffle: return "Toggle Shuffle"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        installEventHandler()
    }

    // MARK: - Event Handler

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

                HotkeyManager.shared.handleHotkey(id: Int(hotKeyID.id))
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }

    // MARK: - Registration

    /// Enable or disable global hotkeys
    func setEnabled(_ enabled: Bool) {
        if enabled {
            reloadHotkeys()
        } else {
            unregisterAll()
        }
    }

    /// Reload hotkeys from settings
    func reloadHotkeys() {
        unregisterAll()

        guard SettingsManager.shared.hotkeysEnabled else { return }

        let hotkeyConfigs = SettingsManager.shared.hotkeys
        for config in hotkeyConfigs {
            guard let actionName = config["action"] as? String,
                  let keyString = config["key"] as? String,
                  !keyString.isEmpty else { continue }

            // Parse key string to get key code and modifiers
            let (keyCode, modifiers) = parseKeyString(keyString)
            guard keyCode != 0 else { continue }

            // Find matching action by display name
            if let action = HotkeyAction.allCases.first(where: { $0.displayName == actionName }) {
                register(keyCode: keyCode, modifiers: modifiers, action: action)
            }
        }
    }

    /// Parse a key string like "⌘⇧P" into key code and modifiers
    private func parseKeyString(_ keyString: String) -> (UInt32, UInt32) {
        var modifiers: UInt32 = 0
        var key: Character?

        for char in keyString {
            switch char {
            case "⌘":
                modifiers |= UInt32(cmdKey)
            case "⌥":
                modifiers |= UInt32(optionKey)
            case "⌃":
                modifiers |= UInt32(controlKey)
            case "⇧":
                modifiers |= UInt32(shiftKey)
            default:
                key = char
            }
        }

        guard let k = key, let keyCode = HotkeyManager.keyCode(for: Character(k.lowercased())) else {
            return (0, 0)
        }

        return (keyCode, modifiers)
    }

    /// Register all hotkeys from settings
    func registerHotkeys() {
        // Load and register hotkeys from settings
        reloadHotkeys()
    }

    /// Register a global hotkey
    /// - Parameters:
    ///   - keyCode: The key code
    ///   - modifiers: Modifier flags (cmdKey, shiftKey, optionKey, controlKey)
    ///   - action: The action to perform
    /// - Returns: The hotkey ID, or -1 on failure
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, action: HotkeyAction) -> Int {
        let id = nextId
        nextId += 1

        let hotKeyID = EventHotKeyID(signature: OSType(0x4650_4C59), id: UInt32(id))  // "FPLY"
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        guard status == noErr, let ref = hotKeyRef else {
            print("Failed to register hotkey: \(status)")
            return -1
        }

        hotkeys[id] = ref

        // Store action mapping
        actionMap[id] = action

        return id
    }

    /// Unregister a hotkey by ID
    func unregister(id: Int) {
        guard let ref = hotkeys[id] else { return }
        UnregisterEventHotKey(ref)
        hotkeys.removeValue(forKey: id)
        actionMap.removeValue(forKey: id)
    }

    /// Unregister all hotkeys
    func unregisterAll() {
        for (_, ref) in hotkeys {
            UnregisterEventHotKey(ref)
        }
        hotkeys.removeAll()
        actionMap.removeAll()
    }

    // MARK: - Action Handling

    private var actionMap: [Int: HotkeyAction] = [:]

    private func handleHotkey(id: Int) {
        guard SettingsManager.shared.hotkeysEnabled else { return }
        guard let action = actionMap[id] else { return }

        DispatchQueue.main.async {
            self.performAction(action)
        }
    }

    private func performAction(_ action: HotkeyAction) {
        switch action {
        // Playback
        case .playPause:
            AudioEngine.shared.togglePlayPause()
        case .play:
            AudioEngine.shared.play()
        case .pause:
            AudioEngine.shared.pause()
        case .stop:
            AudioEngine.shared.stop()
        case .prevTrack:
            PlaylistManager.shared.previous()
        case .nextTrack:
            PlaylistManager.shared.next()

        // Seeking
        case .seekBack:
            if SettingsManager.shared.isChapterSeekMode {
                // Chapter seeking mode
                if !AudioEngine.shared.chapters.isEmpty {
                    AudioEngine.shared.seekToPrevChapter()
                }
            } else if SettingsManager.shared.currentSeekIndex < SettingsManager.defaultSeekAmounts.count &&
                      SettingsManager.defaultSeekAmounts[SettingsManager.shared.currentSeekIndex].isTrack {
                // Track seeking mode
                if PlaylistManager.shared.count > 1 {
                    PlaylistManager.shared.previous()
                }
            } else {
                // Time-based seeking
                let amount = SettingsManager.shared.currentSeekAmount
                AudioEngine.shared.seek(by: -amount)
            }
        case .seekForward:
            if SettingsManager.shared.isChapterSeekMode {
                // Chapter seeking mode
                if !AudioEngine.shared.chapters.isEmpty {
                    AudioEngine.shared.seekToNextChapter()
                }
            } else if SettingsManager.shared.currentSeekIndex < SettingsManager.defaultSeekAmounts.count &&
                      SettingsManager.defaultSeekAmounts[SettingsManager.shared.currentSeekIndex].isTrack {
                // Track seeking mode
                if PlaylistManager.shared.count > 1 {
                    PlaylistManager.shared.next()
                }
            } else {
                // Time-based seeking
                let amount = SettingsManager.shared.currentSeekAmount
                AudioEngine.shared.seek(by: amount)
            }
        case .prevSeekUnit:
            cycleSeekUnit(forward: false)
        case .nextSeekUnit:
            cycleSeekUnit(forward: true)
        case .speakSeekUnit:
            let index = SettingsManager.shared.currentSeekIndex
            if index == 10 {
                AccessibilityManager.announce("1 chapter")
            } else if index < SettingsManager.defaultSeekAmounts.count {
                AccessibilityManager.announce(SettingsManager.defaultSeekAmounts[index].label)
            }

        // Volume
        case .volumeUp:
            AudioEngine.shared.adjustVolume(by: SettingsManager.shared.volumeStep)
        case .volumeDown:
            AudioEngine.shared.adjustVolume(by: -SettingsManager.shared.volumeStep)

        // Speech feedback
        case .speakElapsed:
            let elapsed = AudioEngine.shared.currentPosition
            AccessibilityManager.announceTime(elapsed)
        case .speakRemaining:
            let duration = AudioEngine.shared.duration
            let elapsed = AudioEngine.shared.currentPosition
            if duration > 0 {
                AccessibilityManager.announceTime(duration - elapsed)
            }
        case .speakTotal:
            let duration = AudioEngine.shared.duration
            if duration > 0 {
                AccessibilityManager.announceTime(duration)
            }
        case .speakNowPlaying:
            if let name = PlaylistManager.shared.currentTrackName {
                AccessibilityManager.announce(name)
            }

        // Effects navigation
        case .prevEffect:
            cycleEffect(forward: false)
        case .nextEffect:
            cycleEffect(forward: true)
        case .effectUp:
            adjustCurrentEffect(increase: true)
        case .effectDown:
            adjustCurrentEffect(increase: false)

        // Effect toggles (stream effects)
        case .toggleVolume:
            toggleStreamEffect(0)
        case .togglePitch:
            toggleStreamEffect(1)
        case .toggleTempo:
            toggleStreamEffect(2)
        case .toggleRate:
            toggleStreamEffect(3)

        // DSP effect toggles
        case .toggleReverb:
            // Reverb uses algorithm cycling: Off -> Freeverb -> DX8 -> I3DL2 -> Off
            toggleReverbAlgorithm()
        case .toggleEcho:
            DSPEffectsManager.shared.toggleEffect(.echo)
        case .toggleEQ:
            DSPEffectsManager.shared.toggleEffect(.eq)
        case .toggleCompressor:
            DSPEffectsManager.shared.toggleEffect(.compressor)
        case .toggleStereoWidth:
            DSPEffectsManager.shared.toggleEffect(.stereoWidth)
        case .toggleCenterCancel:
            DSPEffectsManager.shared.toggleEffect(.centerCancel)

        // Window/UI
        case .toggleWindow:
            if let window = NSApp.mainWindow {
                if window.isVisible {
                    window.orderOut(nil)
                } else {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        case .youtubeSearch:
            // Open YouTube window (calls AppDelegate which shows "not yet implemented" message)
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.showYouTube(nil)
            }

        // Recording
        case .toggleRecording:
            RecordingManager.shared.toggleRecording()

        // Shuffle
        case .toggleShuffle:
            SettingsManager.shared.shuffle.toggle()
            let state = SettingsManager.shared.shuffle ? "Shuffle on" : "Shuffle off"
            AccessibilityManager.announce(state)
        }
    }

    // MARK: - Helper Functions

    /// Cycle seek unit (matching Windows CycleSeekAmount)
    private func cycleSeekUnit(forward: Bool) {
        let settings = SettingsManager.shared
        let seekAmountTotal = 11  // 10 regular amounts + chapter (index 10)

        // Count available amounts (track options need multiple tracks, chapter needs chapters)
        var availableCount = 0
        for i in 0..<seekAmountTotal {
            if settings.isSeekAmountAvailable(i) {
                availableCount += 1
            }
        }

        if availableCount == 0 {
            // No seek amounts available, default to 5s
            settings.currentSeekIndex = 1
            AccessibilityManager.announce("5 seconds")
            return
        }

        // If current selection is not available, find a valid one
        if !settings.isSeekAmountAvailable(settings.currentSeekIndex) {
            for i in 0..<seekAmountTotal {
                if settings.isSeekAmountAvailable(i) {
                    settings.currentSeekIndex = i
                    break
                }
            }
        }

        if availableCount == 1 {
            // Only one available, just announce it
            if settings.currentSeekIndex == 10 {
                AccessibilityManager.announce("1 chapter")
            } else {
                AccessibilityManager.announce(SettingsManager.defaultSeekAmounts[settings.currentSeekIndex].label)
            }
            return
        }

        // Cycle through available amounts
        let direction = forward ? 1 : -1
        var newIndex = settings.currentSeekIndex
        for _ in 0..<seekAmountTotal {
            newIndex += direction
            if newIndex >= seekAmountTotal {
                newIndex = 0
            } else if newIndex < 0 {
                newIndex = seekAmountTotal - 1
            }

            if settings.isSeekAmountAvailable(newIndex) {
                settings.currentSeekIndex = newIndex
                break
            }
        }

        // Announce the new seek amount
        if settings.currentSeekIndex == 10 {
            AccessibilityManager.announce("1 chapter")
        } else {
            AccessibilityManager.announce(SettingsManager.defaultSeekAmounts[settings.currentSeekIndex].label)
        }
    }

    /// Cycle through available effects (matching Windows CycleParam)
    private func cycleEffect(forward: Bool) {
        let available = getAvailableParams()

        if available.isEmpty {
            AccessibilityManager.announce("No parameters available")
            return
        }

        // Find current param in available list
        let currentRaw = SettingsManager.shared.currentEffectIndex
        var currentIdx = available.firstIndex(where: { $0.rawIndex == currentRaw }) ?? 0

        if forward {
            currentIdx += 1
            // Clamp to bounds (no wrapping, like Windows)
            if currentIdx >= available.count { currentIdx = available.count - 1 }
        } else {
            currentIdx -= 1
            if currentIdx < 0 { currentIdx = 0 }
        }

        SettingsManager.shared.currentEffectIndex = available[currentIdx].rawIndex
        announceCurrentEffect()
    }

    /// Adjust current effect value (matching Windows AdjustCurrentParam)
    private func adjustCurrentEffect(increase: Bool) {
        let available = getAvailableParams()
        if available.isEmpty { return }

        // Find current param or default to first
        let currentRaw = SettingsManager.shared.currentEffectIndex
        let currentParam: ParamType
        if let found = available.first(where: { $0.rawIndex == currentRaw }) {
            currentParam = found
        } else {
            currentParam = available[0]
            SettingsManager.shared.currentEffectIndex = currentParam.rawIndex
        }

        switch currentParam {
        case .streamEffect(let idx):
            adjustStreamEffect(idx, increase: increase)

        case .dspParam(let paramId):
            DSPEffectsManager.shared.adjustParam(paramId, increase: increase)
            // Announcement is handled by DSPEffectsManager.adjustParam
        }
    }

    /// Adjust stream effect value (Volume, Pitch, Tempo, Rate)
    private func adjustStreamEffect(_ index: Int, increase: Bool) {
        switch EffectType(rawValue: index) {
        case .volume:
            let step = SettingsManager.shared.volumeStep
            AudioEngine.shared.adjustVolume(by: increase ? step : -step)
            // Volume announcement is handled by AudioEngine.adjustVolume

        case .pitch:
            // Windows step: 1.0 semitone
            let step: Float = 1.0
            AudioEngine.shared.pitchValue += increase ? step : -step
            // Clamp to -12..+12
            AudioEngine.shared.pitchValue = max(-12, min(12, AudioEngine.shared.pitchValue))
            announceCurrentEffect()

        case .tempo:
            // Block for live streams
            if AudioEngine.shared.isLiveStream {
                AccessibilityManager.announce("Not available for live streams")
                return
            }
            // Windows step: 5%
            let step: Float = 5.0
            AudioEngine.shared.tempoValue += increase ? step : -step
            // Clamp to -50..+100
            AudioEngine.shared.tempoValue = max(-50, min(100, AudioEngine.shared.tempoValue))
            announceCurrentEffect()

        case .rate:
            // Block for live streams
            if AudioEngine.shared.isLiveStream {
                AccessibilityManager.announce("Not available for live streams")
                return
            }
            // Windows: 0.01x steps or semitone (multiply/divide by 1.0594630943592953)
            if SettingsManager.shared.rateStepMode == 1 {
                // Semitone stepping (multiplicative)
                let semitoneRatio: Float = 1.0594630943592953
                if increase {
                    AudioEngine.shared.rateValue *= semitoneRatio
                } else {
                    AudioEngine.shared.rateValue /= semitoneRatio
                }
            } else {
                // Linear 0.01x steps
                let step: Float = 0.01
                AudioEngine.shared.rateValue += increase ? step : -step
            }
            // Clamp to 0.5..2.0
            AudioEngine.shared.rateValue = max(0.5, min(2.0, AudioEngine.shared.rateValue))
            announceCurrentEffect()

        case .none:
            break
        }
    }

    /// Toggle stream effect (matching Windows ToggleStreamEffect)
    private func toggleStreamEffect(_ index: Int) {
        guard index >= 0 && index < SettingsManager.shared.effectEnabled.count else { return }

        let newState = !SettingsManager.shared.effectEnabled[index]
        SettingsManager.shared.effectEnabled[index] = newState

        let names = ["Volume", "Pitch", "Tempo", "Rate"]
        let message = "\(names[index]) \(newState ? "enabled" : "disabled")"
        AccessibilityManager.announce(message)

        // Apply effects
        AudioEngine.shared.applyStreamEffects()
    }

    /// Toggle reverb algorithm (matching Windows ToggleDSPEffect for Reverb)
    /// Cycles through: Off (0) -> Freeverb (1) -> DX8 (2) -> I3DL2 (3) -> Off
    private func toggleReverbAlgorithm() {
        let newAlgo = (SettingsManager.shared.reverbAlgorithm + 1) % 4
        SettingsManager.shared.reverbAlgorithm = newAlgo

        let algoNames = ["Off", "Freeverb", "DX8 Reverb", "I3DL2 Reverb"]
        let message = "Reverb: \(algoNames[newAlgo])"
        AccessibilityManager.announce(message)

        // Apply the new reverb algorithm
        DSPEffectsManager.shared.updateEffects()
    }

    /// Announce current effect value (matching Windows AnnounceCurrentParam)
    private func announceCurrentEffect() {
        guard SettingsManager.shared.speechEffect else { return }

        let currentRaw = SettingsManager.shared.currentEffectIndex
        guard let currentParam = ParamType.from(rawIndex: currentRaw) else { return }

        var message: String

        switch currentParam {
        case .streamEffect(let idx):
            switch EffectType(rawValue: idx) {
            case .volume:
                let percent = Int(AudioEngine.shared.currentVolume * 100 + 0.5)
                message = "Volume \(percent)%"

            case .pitch:
                let val = AudioEngine.shared.pitchValue
                if val == 0 {
                    message = "Pitch 0 semitones"
                } else {
                    message = String(format: "Pitch %+.0f semitones", val)
                }

            case .tempo:
                let val = AudioEngine.shared.tempoValue
                if val == 0 {
                    message = "Tempo 0%"
                } else {
                    message = String(format: "Tempo %+.0f%%", val)
                }

            case .rate:
                let val = AudioEngine.shared.rateValue
                message = String(format: "Rate %.2fx", val)

            case .none:
                return
            }

        case .dspParam(let paramId):
            guard let def = DSPEffectsManager.paramDefs.first(where: { $0.id == paramId }) else { return }
            let val = DSPEffectsManager.shared.getParamValue(paramId)
            message = formatDSPParamValue(name: def.name, value: val, unit: def.unit)
        }

        AccessibilityManager.announce(message)
    }

    /// Format DSP parameter value for speech
    private func formatDSPParamValue(name: String, value: Float, unit: String) -> String {
        if unit == "%" || unit == "ms" {
            return String(format: "%@ %.0f%@", name, value, unit)
        } else if unit == "dB" {
            // Show + sign for positive values
            if value > 0 {
                return String(format: "%@ +%.0f%@", name, value, unit)
            } else {
                return String(format: "%@ %.0f%@", name, value, unit)
            }
        } else if unit == ":1" {
            return String(format: "%@ %.0f%@", name, value, unit)
        } else {
            return String(format: "%@ %.2f%@", name, value, unit)
        }
    }

    /// Get list of available parameters (matching Windows GetAvailableParams)
    private func getAvailableParams() -> [ParamType] {
        var params: [ParamType] = []

        // Stream effects (Volume, Pitch, Tempo, Rate)
        for i in 0..<4 {
            if SettingsManager.shared.effectEnabled[i] {
                params.append(.streamEffect(i))
            }
        }

        // DSP effect parameters - check if each DSP effect is enabled
        let reverbAlgorithm = SettingsManager.shared.reverbAlgorithm

        for def in DSPEffectsManager.paramDefs {
            let effectIndex = def.effectType.rawValue
            let isEnabled: Bool

            switch def.effectType {
            case .reverb:
                // Reverb uses algorithm selection (0=Off, 1=Freeverb, etc.)
                isEnabled = reverbAlgorithm > 0
            default:
                // Other DSP effects use the enabled array
                isEnabled = effectIndex < SettingsManager.shared.dspEffectEnabled.count &&
                           SettingsManager.shared.dspEffectEnabled[effectIndex]
            }

            if isEnabled {
                params.append(.dspParam(def.id))
            }
        }

        return params
    }

    /// Parameter type enum (stream effects vs DSP parameters)
    private enum ParamType {
        case streamEffect(Int)  // 0-3: Volume, Pitch, Tempo, Rate
        case dspParam(DSPParamId)

        var rawIndex: Int {
            switch self {
            case .streamEffect(let idx): return idx
            case .dspParam(let param): return 100 + param.rawValue
            }
        }

        static func from(rawIndex: Int) -> ParamType? {
            if rawIndex >= 0 && rawIndex < 4 {
                return .streamEffect(rawIndex)
            } else if rawIndex >= 100 && rawIndex < 100 + DSPParamId.allCases.count {
                return .dspParam(DSPParamId(rawValue: rawIndex - 100)!)
            }
            return nil
        }
    }

    // MARK: - Key Code Helpers

    /// Convert character to Carbon key code
    static func keyCode(for character: Character) -> UInt32? {
        let keyCodeMap: [Character: UInt32] = [
            "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05, "z": 0x06,
            "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C, "w": 0x0D, "e": 0x0E,
            "r": 0x0F, "y": 0x10, "t": 0x11, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15,
            "6": 0x16, "5": 0x17, "=": 0x18, "9": 0x19, "7": 0x1A, "-": 0x1B, "8": 0x1C,
            "0": 0x1D, "]": 0x1E, "o": 0x1F, "u": 0x20, "[": 0x21, "i": 0x22, "p": 0x23,
            "l": 0x25, "j": 0x26, "'": 0x27, "k": 0x28, ";": 0x29, "\\": 0x2A, ",": 0x2B,
            "/": 0x2C, "n": 0x2D, "m": 0x2E, ".": 0x2F, "`": 0x32, " ": 0x31,
        ]
        return keyCodeMap[character]
    }
}
