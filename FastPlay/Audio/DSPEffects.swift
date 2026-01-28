//
//  DSPEffects.swift
//  FastPlay
//
//  DSP Effects Manager - Reverb, Echo, EQ, Compressor, Stereo Width, Center Cancel
//  Maps to Windows effects.cpp
//

import Foundation

/// DSP Effect types matching Windows DSPEffectType enum
enum DSPEffectType: Int, CaseIterable {
    case reverb = 0
    case echo = 1
    case eq = 2
    case compressor = 3
    case stereoWidth = 4
    case centerCancel = 5
    case convolution = 6
}

/// Parameter IDs for effects
enum DSPParamId: Int, CaseIterable {
    // Reverb (Freeverb)
    case reverbMix = 0
    case reverbRoom = 1
    case reverbDamp = 2
    // Echo
    case echoDelay = 3
    case echoFeedback = 4
    case echoMix = 5
    // EQ
    case eqPreamp = 6
    case eqBass = 7
    case eqMid = 8
    case eqTreble = 9
    // Compressor
    case compThreshold = 10
    case compRatio = 11
    case compAttack = 12
    case compRelease = 13
    case compGain = 14
    // Stereo Width
    case stereoWidth = 15
    // Center Cancel
    case centerCancel = 16
    // Convolution
    case convolutionMix = 17
    case convolutionGain = 18
}

/// Parameter definition
struct DSPParamDef {
    let id: DSPParamId
    let name: String
    let unit: String
    let minValue: Float
    let maxValue: Float
    let step: Float
    let defaultValue: Float
    let effectType: DSPEffectType
}

/// DSP Effects Manager
class DSPEffectsManager {

    // MARK: - Singleton

    static let shared = DSPEffectsManager()

    // MARK: - Parameter Definitions

    /// All DSP parameter definitions - accessible for effects cycler
    static let paramDefs: [DSPParamDef] = [
        // Reverb (Freeverb)
        DSPParamDef(id: .reverbMix, name: "Reverb Mix", unit: "%", minValue: 0, maxValue: 100, step: 5, defaultValue: 30, effectType: .reverb),
        DSPParamDef(id: .reverbRoom, name: "Reverb Room", unit: "%", minValue: 0, maxValue: 100, step: 5, defaultValue: 50, effectType: .reverb),
        DSPParamDef(id: .reverbDamp, name: "Reverb Damp", unit: "%", minValue: 0, maxValue: 100, step: 5, defaultValue: 50, effectType: .reverb),
        // Echo
        DSPParamDef(id: .echoDelay, name: "Echo Delay", unit: "ms", minValue: 10, maxValue: 2000, step: 50, defaultValue: 300, effectType: .echo),
        DSPParamDef(id: .echoFeedback, name: "Echo Feedback", unit: "%", minValue: 0, maxValue: 90, step: 5, defaultValue: 40, effectType: .echo),
        DSPParamDef(id: .echoMix, name: "Echo Mix", unit: "%", minValue: 0, maxValue: 100, step: 5, defaultValue: 30, effectType: .echo),
        // EQ
        DSPParamDef(id: .eqPreamp, name: "EQ Preamp", unit: "dB", minValue: -15, maxValue: 0, step: 1, defaultValue: 0, effectType: .eq),
        DSPParamDef(id: .eqBass, name: "EQ Bass", unit: "dB", minValue: -15, maxValue: 15, step: 1, defaultValue: 0, effectType: .eq),
        DSPParamDef(id: .eqMid, name: "EQ Mid", unit: "dB", minValue: -15, maxValue: 15, step: 1, defaultValue: 0, effectType: .eq),
        DSPParamDef(id: .eqTreble, name: "EQ Treble", unit: "dB", minValue: -15, maxValue: 15, step: 1, defaultValue: 0, effectType: .eq),
        // Compressor
        DSPParamDef(id: .compThreshold, name: "Comp Threshold", unit: "dB", minValue: -60, maxValue: 0, step: 3, defaultValue: -20, effectType: .compressor),
        DSPParamDef(id: .compRatio, name: "Comp Ratio", unit: ":1", minValue: 1, maxValue: 20, step: 1, defaultValue: 4, effectType: .compressor),
        DSPParamDef(id: .compAttack, name: "Comp Attack", unit: "ms", minValue: 0.01, maxValue: 500, step: 10, defaultValue: 20, effectType: .compressor),
        DSPParamDef(id: .compRelease, name: "Comp Release", unit: "ms", minValue: 10, maxValue: 2000, step: 50, defaultValue: 200, effectType: .compressor),
        DSPParamDef(id: .compGain, name: "Comp Gain", unit: "dB", minValue: -20, maxValue: 20, step: 1, defaultValue: 0, effectType: .compressor),
        // Stereo Width
        DSPParamDef(id: .stereoWidth, name: "Stereo Width", unit: "%", minValue: 0, maxValue: 200, step: 10, defaultValue: 100, effectType: .stereoWidth),
        // Center Cancel
        DSPParamDef(id: .centerCancel, name: "Center Cancel", unit: "%", minValue: -100, maxValue: 100, step: 10, defaultValue: 0, effectType: .centerCancel),
        // Convolution
        DSPParamDef(id: .convolutionMix, name: "Conv Mix", unit: "%", minValue: 0, maxValue: 100, step: 5, defaultValue: 50, effectType: .convolution),
        DSPParamDef(id: .convolutionGain, name: "Conv Gain", unit: "dB", minValue: -20, maxValue: 20, step: 1, defaultValue: 0, effectType: .convolution),
    ]

    // MARK: - State

    private var effectEnabled: [Bool] = Array(repeating: false, count: DSPEffectType.allCases.count)
    private var paramValues: [Float] = []

    // Effect handles (BASS HFX/HDSP)
    private var hfxReverb: HFX = 0
    private var hfxEcho: HFX = 0
    private var hfxEQPreamp: HFX = 0
    private var hfxEQBass: HFX = 0
    private var hfxEQMid: HFX = 0
    private var hfxEQTreble: HFX = 0
    private var hfxCompressor: HFX = 0
    private var hdspStereoWidth: HDSP = 0
    private var hdspCenterCancel: HDSP = 0
    private var hdspConvolution: HDSP = 0

    // Current reverb algorithm (0=Off, 1=Freeverb)
    var reverbAlgorithm: Int = 0 {
        didSet {
            if reverbAlgorithm != oldValue {
                applyEffects()
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Initialize parameter values from settings (or defaults if not set)
        paramValues = Array(repeating: 0, count: DSPParamId.allCases.count)
        loadParamsFromSettings()
    }

    /// Load parameter values from SettingsManager
    func loadParamsFromSettings() {
        let settings = SettingsManager.shared
        paramValues[DSPParamId.reverbMix.rawValue] = settings.reverbMix
        paramValues[DSPParamId.reverbRoom.rawValue] = settings.reverbRoom
        paramValues[DSPParamId.reverbDamp.rawValue] = settings.reverbDamp
        paramValues[DSPParamId.echoDelay.rawValue] = settings.echoDelay
        paramValues[DSPParamId.echoFeedback.rawValue] = settings.echoFeedback
        paramValues[DSPParamId.echoMix.rawValue] = settings.echoMix
        paramValues[DSPParamId.eqPreamp.rawValue] = settings.eqPreamp
        paramValues[DSPParamId.eqBass.rawValue] = settings.eqBass
        paramValues[DSPParamId.eqMid.rawValue] = settings.eqMid
        paramValues[DSPParamId.eqTreble.rawValue] = settings.eqTreble
        paramValues[DSPParamId.compThreshold.rawValue] = settings.compThreshold
        paramValues[DSPParamId.compRatio.rawValue] = settings.compRatio
        paramValues[DSPParamId.compAttack.rawValue] = settings.compAttack
        paramValues[DSPParamId.compRelease.rawValue] = settings.compRelease
        paramValues[DSPParamId.compGain.rawValue] = settings.compGain
        paramValues[DSPParamId.stereoWidth.rawValue] = settings.stereoWidth
        paramValues[DSPParamId.centerCancel.rawValue] = settings.centerCancel
        paramValues[DSPParamId.convolutionMix.rawValue] = settings.convolutionMix
        paramValues[DSPParamId.convolutionGain.rawValue] = settings.convolutionGain
    }

    /// Save a single parameter value to SettingsManager
    private func saveParamToSettings(_ param: DSPParamId) {
        let settings = SettingsManager.shared
        let value = paramValues[param.rawValue]
        switch param {
        case .reverbMix: settings.reverbMix = value
        case .reverbRoom: settings.reverbRoom = value
        case .reverbDamp: settings.reverbDamp = value
        case .echoDelay: settings.echoDelay = value
        case .echoFeedback: settings.echoFeedback = value
        case .echoMix: settings.echoMix = value
        case .eqPreamp: settings.eqPreamp = value
        case .eqBass: settings.eqBass = value
        case .eqMid: settings.eqMid = value
        case .eqTreble: settings.eqTreble = value
        case .compThreshold: settings.compThreshold = value
        case .compRatio: settings.compRatio = value
        case .compAttack: settings.compAttack = value
        case .compRelease: settings.compRelease = value
        case .compGain: settings.compGain = value
        case .stereoWidth: settings.stereoWidth = value
        case .centerCancel: settings.centerCancel = value
        case .convolutionMix: settings.convolutionMix = value
        case .convolutionGain: settings.convolutionGain = value
        }
    }

    // MARK: - Effect Control

    func isEffectEnabled(_ type: DSPEffectType) -> Bool {
        return effectEnabled[type.rawValue]
    }

    func setEffectEnabled(_ type: DSPEffectType, enabled: Bool) {
        effectEnabled[type.rawValue] = enabled
        applyEffects()
    }

    func toggleEffect(_ type: DSPEffectType) {
        let newState = !effectEnabled[type.rawValue]
        effectEnabled[type.rawValue] = newState

        let names = ["Reverb", "Echo", "EQ", "Compressor", "Stereo Width", "Center Cancel", "Convolution"]
        let message = "\(names[type.rawValue]) \(newState ? "enabled" : "disabled")"
        AccessibilityManager.announce(message)

        applyEffects()
    }

    /// Sync effect enabled state from SettingsManager and reapply
    func updateEffects() {
        for i in 0..<min(effectEnabled.count, SettingsManager.shared.dspEffectEnabled.count) {
            effectEnabled[i] = SettingsManager.shared.dspEffectEnabled[i]
        }
        applyEffects()
    }

    // MARK: - Parameter Control

    func getParamValue(_ param: DSPParamId) -> Float {
        return paramValues[param.rawValue]
    }

    func setParamValue(_ param: DSPParamId, value: Float) {
        guard let def = DSPEffectsManager.paramDefs.first(where: { $0.id == param }) else { return }
        paramValues[param.rawValue] = max(def.minValue, min(def.maxValue, value))

        // Save to settings for persistence
        saveParamToSettings(param)

        // Update global variables for custom DSP callbacks
        if param == .stereoWidth || param == .centerCancel {
            updateDSPGlobals()
        }

        // Update convolution parameters in real-time
        if param == .convolutionMix {
            ConvolutionReverb.shared.mix = paramValues[param.rawValue]
        } else if param == .convolutionGain {
            ConvolutionReverb.shared.gain = paramValues[param.rawValue]
        }

        updateEffectParam(param)
    }

    func adjustParam(_ param: DSPParamId, increase: Bool) {
        guard let def = DSPEffectsManager.paramDefs.first(where: { $0.id == param }) else { return }
        let step = increase ? def.step : -def.step
        let newValue = paramValues[param.rawValue] + step
        setParamValue(param, value: newValue)

        // Announce
        let value = paramValues[param.rawValue]
        AccessibilityManager.announce("\(def.name) \(formatValue(value, unit: def.unit))")
    }

    func resetParam(_ param: DSPParamId) {
        guard let def = DSPEffectsManager.paramDefs.first(where: { $0.id == param }) else { return }
        setParamValue(param, value: def.defaultValue)
        AccessibilityManager.announce("\(def.name) reset")
    }

    func setParamToExtreme(_ param: DSPParamId, minimum: Bool) {
        guard let def = DSPEffectsManager.paramDefs.first(where: { $0.id == param }) else { return }
        let value = minimum ? def.minValue : def.maxValue
        setParamValue(param, value: value)
        AccessibilityManager.announce("\(def.name) \(formatValue(value, unit: def.unit))")
    }

    private func formatValue(_ value: Float, unit: String) -> String {
        if unit == "%" || unit == "dB" || unit == "ms" {
            return String(format: "%.0f%@", value, unit)
        } else if unit == ":1" {
            return String(format: "%.0f%@", value, unit)
        } else {
            return String(format: "%.2f%@", value, unit)
        }
    }

    // MARK: - Convolution IR Loading

    /// Load an impulse response file for convolution reverb
    func loadConvolutionIR(_ path: String) -> Bool {
        let success = ConvolutionReverb.shared.loadIR(path)
        if success {
            // Store IR path in settings
            SettingsManager.shared.convolutionIRPath = path
            AccessibilityManager.announce("Impulse response loaded")
            // Reapply effects to activate convolution
            if isDSPEnabled(.convolution) {
                applyEffects()
            }
        } else {
            AccessibilityManager.announce("Failed to load impulse response")
        }
        return success
    }

    /// Get info about the loaded IR
    var convolutionIRInfo: String {
        let conv = ConvolutionReverb.shared
        if conv.isIRLoaded {
            let filename = (conv.irPath as NSString).lastPathComponent
            let lengthMs = conv.irLengthMs
            return "\(filename) (\(Int(lengthMs))ms)"
        }
        return "No IR loaded"
    }

    // MARK: - Apply Effects

    /// Check if a DSP effect is enabled (reads from SettingsManager)
    private func isDSPEnabled(_ type: DSPEffectType) -> Bool {
        let index = type.rawValue
        return index < SettingsManager.shared.dspEffectEnabled.count &&
               SettingsManager.shared.dspEffectEnabled[index]
    }

    func applyEffects() {
        let stream = AudioEngine.shared.fxStream
        guard stream != 0 else { return }

        // Remove existing effects first
        removeEffects()

        // Apply Reverb (Freeverb algorithm using BASS_FX)
        // Use SettingsManager.reverbAlgorithm directly
        let reverbAlgo = SettingsManager.shared.reverbAlgorithm
        if reverbAlgo > 0 {
            // Use BASS_FX reverb
            hfxReverb = BASS_ChannelSetFX(stream, DWORD(BASS_FX_BFX_FREEVERB), 0)
            if hfxReverb != 0 {
                updateReverbParams()
            }
        }

        // Apply Echo
        if isDSPEnabled(.echo) {
            hfxEcho = BASS_ChannelSetFX(stream, DWORD(BASS_FX_BFX_ECHO4), 0)
            if hfxEcho != 0 {
                updateEchoParams()
                print("DSP: Echo effect created (handle \(hfxEcho))")
            } else {
                print("DSP: Failed to create Echo effect, error: \(BASS_ErrorGetCode())")
            }
        }

        // Apply EQ (3-band using peaking EQ)
        if isDSPEnabled(.eq) {
            // Preamp (volume adjustment)
            hfxEQPreamp = BASS_ChannelSetFX(stream, DWORD(BASS_FX_BFX_VOLUME), 0)

            // Bass band
            hfxEQBass = BASS_ChannelSetFX(stream, DWORD(BASS_FX_BFX_PEAKEQ), 0)

            // Mid band
            hfxEQMid = BASS_ChannelSetFX(stream, DWORD(BASS_FX_BFX_PEAKEQ), 0)

            // Treble band
            hfxEQTreble = BASS_ChannelSetFX(stream, DWORD(BASS_FX_BFX_PEAKEQ), 0)

            updateEQParams()
        }

        // Apply Compressor
        if isDSPEnabled(.compressor) {
            hfxCompressor = BASS_ChannelSetFX(stream, DWORD(BASS_FX_BFX_COMPRESSOR2), 0)
            if hfxCompressor != 0 {
                updateCompressorParams()
            }
        }

        // Update C global variables for custom DSP callbacks
        updateDSPGlobals()

        // Apply Stereo Width (custom DSP using C callback)
        if isDSPEnabled(.stereoWidth) {
            hdspStereoWidth = BASS_ChannelSetDSP(stream, DSP_StereoWidthProc, nil, 0)
        }

        // Apply Center Cancel (custom DSP using C callback)
        if isDSPEnabled(.centerCancel) {
            hdspCenterCancel = BASS_ChannelSetDSP(stream, DSP_CenterCancelProc, nil, 0)
        }

        // Apply Convolution Reverb (custom DSP with Swift callback)
        if isDSPEnabled(.convolution) && ConvolutionReverb.shared.isIRLoaded {
            // Initialize convolution if needed
            if !ConvolutionReverb.shared.isInitialized {
                var info = BASS_CHANNELINFO()
                if BASS_ChannelGetInfo(stream, &info) != 0 {
                    _ = ConvolutionReverb.shared.initialize(sampleRate: Int(info.freq))
                }
            }

            // Update convolution parameters from DSP settings
            ConvolutionReverb.shared.mix = getParamValue(.convolutionMix)
            ConvolutionReverb.shared.gain = getParamValue(.convolutionGain)

            // Register the Swift callback with the C DSP system
            DSP_SetConvolutionCallback { buffer, frames in
                ConvolutionReverb.shared.process(buffer!, frames: Int(frames))
            }

            hdspConvolution = BASS_ChannelSetDSP(stream, DSP_ConvolutionProc, nil, 0)
        }
    }

    func removeEffects() {
        let stream = AudioEngine.shared.fxStream
        guard stream != 0 else { return }

        if hfxReverb != 0 { BASS_ChannelRemoveFX(stream, hfxReverb); hfxReverb = 0 }
        if hfxEcho != 0 { BASS_ChannelRemoveFX(stream, hfxEcho); hfxEcho = 0 }
        if hfxEQPreamp != 0 { BASS_ChannelRemoveFX(stream, hfxEQPreamp); hfxEQPreamp = 0 }
        if hfxEQBass != 0 { BASS_ChannelRemoveFX(stream, hfxEQBass); hfxEQBass = 0 }
        if hfxEQMid != 0 { BASS_ChannelRemoveFX(stream, hfxEQMid); hfxEQMid = 0 }
        if hfxEQTreble != 0 { BASS_ChannelRemoveFX(stream, hfxEQTreble); hfxEQTreble = 0 }
        if hfxCompressor != 0 { BASS_ChannelRemoveFX(stream, hfxCompressor); hfxCompressor = 0 }
        if hdspStereoWidth != 0 { BASS_ChannelRemoveDSP(stream, hdspStereoWidth); hdspStereoWidth = 0 }
        if hdspCenterCancel != 0 { BASS_ChannelRemoveDSP(stream, hdspCenterCancel); hdspCenterCancel = 0 }
        if hdspConvolution != 0 {
            BASS_ChannelRemoveDSP(stream, hdspConvolution)
            hdspConvolution = 0
            DSP_SetConvolutionCallback(nil)  // Clear the callback
        }
    }

    // MARK: - Update Individual Effects

    private func updateEffectParam(_ param: DSPParamId) {
        guard let def = DSPEffectsManager.paramDefs.first(where: { $0.id == param }) else { return }

        switch def.effectType {
        case .reverb:
            updateReverbParams()
        case .echo:
            updateEchoParams()
        case .eq:
            updateEQParams()
        case .compressor:
            updateCompressorParams()
        case .stereoWidth, .centerCancel, .convolution:
            // Custom DSPs read values directly from paramValues
            break
        }
    }

    private func updateReverbParams() {
        guard hfxReverb != 0 else { return }

        var params = BASS_BFX_FREEVERB()
        params.fDryMix = 1.0 - (paramValues[DSPParamId.reverbMix.rawValue] / 100.0)
        params.fWetMix = paramValues[DSPParamId.reverbMix.rawValue] / 100.0
        params.fRoomSize = paramValues[DSPParamId.reverbRoom.rawValue] / 100.0
        params.fDamp = paramValues[DSPParamId.reverbDamp.rawValue] / 100.0
        params.fWidth = 1.0
        params.lMode = 0
        params.lChannel = BASS_BFX_CHANALL

        BASS_FXSetParameters(hfxReverb, &params)
    }

    private func updateEchoParams() {
        guard hfxEcho != 0 else { return }

        var params = BASS_BFX_ECHO4()
        params.fDryMix = 1.0 - (paramValues[DSPParamId.echoMix.rawValue] / 100.0)
        params.fWetMix = paramValues[DSPParamId.echoMix.rawValue] / 100.0
        params.fFeedback = paramValues[DSPParamId.echoFeedback.rawValue] / 100.0
        params.fDelay = paramValues[DSPParamId.echoDelay.rawValue] / 1000.0  // Convert ms to seconds
        params.bStereo = true
        params.lChannel = BASS_BFX_CHANALL

        BASS_FXSetParameters(hfxEcho, &params)
    }

    private func updateEQParams() {
        // Update preamp
        if hfxEQPreamp != 0 {
            var volParams = BASS_BFX_VOLUME()
            volParams.lChannel = BASS_BFX_CHANALL
            let preampDb = paramValues[DSPParamId.eqPreamp.rawValue]
            volParams.fVolume = powf(10.0, preampDb / 20.0)  // dB to linear
            BASS_FXSetParameters(hfxEQPreamp, &volParams)
        }

        // Update bass band
        if hfxEQBass != 0 {
            var eqParams = BASS_BFX_PEAKEQ()
            eqParams.lBand = 0
            eqParams.fBandwidth = 2.5
            eqParams.fQ = 0
            eqParams.fCenter = SettingsManager.shared.eqBassFreq
            eqParams.fGain = paramValues[DSPParamId.eqBass.rawValue]
            eqParams.lChannel = BASS_BFX_CHANALL
            BASS_FXSetParameters(hfxEQBass, &eqParams)
        }

        // Update mid band
        if hfxEQMid != 0 {
            var eqParams = BASS_BFX_PEAKEQ()
            eqParams.lBand = 0
            eqParams.fBandwidth = 2.5
            eqParams.fQ = 0
            eqParams.fCenter = SettingsManager.shared.eqMidFreq
            eqParams.fGain = paramValues[DSPParamId.eqMid.rawValue]
            eqParams.lChannel = BASS_BFX_CHANALL
            BASS_FXSetParameters(hfxEQMid, &eqParams)
        }

        // Update treble band
        if hfxEQTreble != 0 {
            var eqParams = BASS_BFX_PEAKEQ()
            eqParams.lBand = 0
            eqParams.fBandwidth = 2.5
            eqParams.fQ = 0
            eqParams.fCenter = SettingsManager.shared.eqTrebleFreq
            eqParams.fGain = paramValues[DSPParamId.eqTreble.rawValue]
            eqParams.lChannel = BASS_BFX_CHANALL
            BASS_FXSetParameters(hfxEQTreble, &eqParams)
        }
    }

    private func updateCompressorParams() {
        guard hfxCompressor != 0 else { return }

        var params = BASS_BFX_COMPRESSOR2()
        params.fGain = paramValues[DSPParamId.compGain.rawValue]
        params.fThreshold = paramValues[DSPParamId.compThreshold.rawValue]
        params.fRatio = paramValues[DSPParamId.compRatio.rawValue]
        params.fAttack = paramValues[DSPParamId.compAttack.rawValue]
        params.fRelease = paramValues[DSPParamId.compRelease.rawValue]
        params.lChannel = BASS_BFX_CHANALL

        BASS_FXSetParameters(hfxCompressor, &params)
    }

    // MARK: - Get Available Parameters

    func getAvailableParams() -> [DSPParamId] {
        var params: [DSPParamId] = []

        for def in DSPEffectsManager.paramDefs {
            if effectEnabled[def.effectType.rawValue] {
                params.append(def.id)
            }
        }

        return params
    }
}

// MARK: - DSP Parameter Updates

/// Update the C DSP parameters (call this when params change)
func updateDSPGlobals() {
    let stereoWidth = DSPEffectsManager.shared.getParamValue(.stereoWidth)
    let centerCancel = DSPEffectsManager.shared.getParamValue(.centerCancel)

    // Update C globals via setter functions (defined in DSPCallbacks.c)
    DSP_SetStereoWidth(stereoWidth)
    DSP_SetCenterCancel(centerCancel)
}

