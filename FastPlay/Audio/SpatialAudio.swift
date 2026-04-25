//
//  SpatialAudio.swift
//  FastPlay
//
//  Spatial audio (binaural + 5.1 virtual surround via HRTF).
//  Direct port of Windows src/spatial_audio.cpp using Valve's Steam Audio (Phonon).
//  Structure mirrors the C++ version so upstream changes are easy to diff.
//

import Foundation

/// Spatial processing mode, matches Windows SpatialMode enum class.
enum SpatialMode: Int {
    case binaural = 0     // Stereo HRTF for headphones (2 virtual speakers)
    case surround51 = 1   // 5.1 virtual surround rendered binaurally
}

final class SpatialAudio {

    // MARK: - Singleton

    static let shared = SpatialAudio()

    // MARK: - Constants

    private static let FRAME_SIZE = 128
    private static let MAX_QUEUE = 16384
    private static let DEG2RAD: Float = .pi / 180.0

    // Virtual speaker angles (degrees)
    private static let ANGLE_FL: Float = -30
    private static let ANGLE_FR: Float =  30
    private static let ANGLE_C:  Float =   0
    private static let ANGLE_SL: Float = -135
    private static let ANGLE_SR: Float =  135
    private static let ANGLE_RC: Float =  180

    // MARK: - Public parameters (read on the audio thread)

    var mode: SpatialMode = .binaural {
        didSet { if oldValue != mode { rebuildEffectsForModeChange() } }
    }
    var rearCenter: Bool = true
    var width: Float = 45.0          // front speaker angle, 15..90
    var rotation: Float = 0.0        // -180..180
    var listenerX: Float = 0.0
    var listenerY: Float = 0.0
    var listenerZ: Float = 0.0

    // MARK: - State

    private(set) var isInitialized = false
    private(set) var lastError: String = ""
    private var sampleRate: Int32 = 0

    // Steam Audio handles
    private var context: IPLContext?
    private var hrtf: IPLHRTF?
    private var effectL: IPLBinauralEffect?
    private var effectR: IPLBinauralEffect?
    private var effectFL: IPLBinauralEffect?
    private var effectFR: IPLBinauralEffect?
    private var effectC:  IPLBinauralEffect?
    private var effectSL: IPLBinauralEffect?
    private var effectSR: IPLBinauralEffect?
    private var effectRC: IPLBinauralEffect?

    // Working buffers
    private var mono:    [Float] = Array(repeating: 0, count: SpatialAudio.FRAME_SIZE)
    private var tmpL:    [Float] = Array(repeating: 0, count: SpatialAudio.FRAME_SIZE)
    private var tmpR:    [Float] = Array(repeating: 0, count: SpatialAudio.FRAME_SIZE)
    private var savL:    [Float] = Array(repeating: 0, count: SpatialAudio.FRAME_SIZE)
    private var savR:    [Float] = Array(repeating: 0, count: SpatialAudio.FRAME_SIZE)
    private var upmix:   [Float] = Array(repeating: 0, count: 6 * SpatialAudio.FRAME_SIZE)
    private var outAccL: [Float] = Array(repeating: 0, count: SpatialAudio.FRAME_SIZE)
    private var outAccR: [Float] = Array(repeating: 0, count: SpatialAudio.FRAME_SIZE)

    // Input carry (samples left over from previous BASS callback)
    private var carryL: [Float] = Array(repeating: 0, count: SpatialAudio.FRAME_SIZE * 2)
    private var carryR: [Float] = Array(repeating: 0, count: SpatialAudio.FRAME_SIZE * 2)
    private var carryCount = 0

    // Output queue (processed frames waiting to be written back)
    private var queueL: [Float] = Array(repeating: 0, count: SpatialAudio.MAX_QUEUE)
    private var queueR: [Float] = Array(repeating: 0, count: SpatialAudio.MAX_QUEUE)
    private var queueCount = 0

    // BASS DSP callback runs off-thread; protect state with a lock.
    private let lock = NSRecursiveLock()

    private init() {}
    deinit { shutdown() }

    // MARK: - Public API

    /// Initialize the engine for the given sample rate. Returns false on failure
    /// (lastError carries the reason). Safe to call repeatedly — a rate change
    /// will tear down and rebuild.
    @discardableResult
    func initialize(sampleRate: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }

        if isInitialized && self.sampleRate == Int32(sampleRate) {
            return true
        }
        if isInitialized {
            shutdownLocked()
        }

        self.sampleRate = Int32(sampleRate)
        lastError = ""

        // Context
        var cs = IPLContextSettings()
        // STEAMAUDIO_VERSION is a compound macro that doesn't cross the Swift bridge;
        // reconstruct from the MAJOR/MINOR/PATCH constants (which do).
        cs.version = (UInt32(STEAMAUDIO_VERSION_MAJOR) << 16) |
                     (UInt32(STEAMAUDIO_VERSION_MINOR) << 8) |
                      UInt32(STEAMAUDIO_VERSION_PATCH)
        cs.simdLevel = IPL_SIMDLEVEL_AVX2
        var ctx: IPLContext?
        var err = iplContextCreate(&cs, &ctx)
        guard err == IPL_STATUS_SUCCESS, ctx != nil else {
            lastError = "Steam Audio context creation failed (error \(err.rawValue))."
            return false
        }
        self.context = ctx

        // HRTF
        var audio = IPLAudioSettings()
        audio.samplingRate = Int32(sampleRate)
        audio.frameSize = Int32(SpatialAudio.FRAME_SIZE)

        var hs = IPLHRTFSettings()
        hs.type = IPL_HRTFTYPE_DEFAULT
        hs.volume = 1.0
        var hrtfHandle: IPLHRTF?
        err = iplHRTFCreate(ctx, &audio, &hs, &hrtfHandle)
        guard err == IPL_STATUS_SUCCESS, hrtfHandle != nil else {
            lastError = "HRTF creation failed (error \(err.rawValue), sample rate \(sampleRate) Hz)."
            shutdownLocked()
            return false
        }
        self.hrtf = hrtfHandle

        // Effects
        if !createEffectsLocked(audio: audio) {
            shutdownLocked()
            return false
        }

        carryCount = 0
        // Pre-fill output queue with FRAME_SIZE silence to absorb initial deficit
        for i in 0..<SpatialAudio.FRAME_SIZE { queueL[i] = 0; queueR[i] = 0 }
        queueCount = SpatialAudio.FRAME_SIZE

        isInitialized = true
        return true
    }

    func shutdown() {
        lock.lock(); defer { lock.unlock() }
        shutdownLocked()
    }

    /// Process a stereo interleaved float buffer in place. `blend` is 0..1 dry/wet.
    func process(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int, blend: Float) {
        guard isInitialized, frameCount > 0 else { return }
        guard lock.try() else { return }  // audio thread: drop rather than block
        defer { lock.unlock() }
        guard isInitialized else { return }

        var newPos = 0

        while true {
            let available = carryCount + (frameCount - newPos)
            if available < SpatialAudio.FRAME_SIZE { break }
            if queueCount + SpatialAudio.FRAME_SIZE > SpatialAudio.MAX_QUEUE { break }

            var fL = [Float](repeating: 0, count: SpatialAudio.FRAME_SIZE)
            var fR = [Float](repeating: 0, count: SpatialAudio.FRAME_SIZE)

            // Drain carry first
            let fromCarry = min(carryCount, SpatialAudio.FRAME_SIZE)
            for i in 0..<fromCarry {
                fL[i] = carryL[i]
                fR[i] = carryR[i]
            }
            carryCount -= fromCarry
            if carryCount > 0 {
                for i in 0..<carryCount {
                    carryL[i] = carryL[i + fromCarry]
                    carryR[i] = carryR[i + fromCarry]
                }
            }

            // Fill remainder from input
            let fromInput = SpatialAudio.FRAME_SIZE - fromCarry
            for i in 0..<fromInput {
                fL[fromCarry + i] = buffer[(newPos + i) * 2]
                fR[fromCarry + i] = buffer[(newPos + i) * 2 + 1]
            }
            newPos += fromInput

            if mode == .surround51 {
                fL.withUnsafeMutableBufferPointer { lPtr in
                    fR.withUnsafeMutableBufferPointer { rPtr in
                        processSurroundFrame(lPtr.baseAddress!, rPtr.baseAddress!)
                    }
                }
            } else {
                fL.withUnsafeMutableBufferPointer { lPtr in
                    fR.withUnsafeMutableBufferPointer { rPtr in
                        processBinauralFrame(lPtr.baseAddress!, rPtr.baseAddress!)
                    }
                }
            }

            for i in 0..<SpatialAudio.FRAME_SIZE {
                queueL[queueCount + i] = fL[i]
                queueR[queueCount + i] = fR[i]
            }
            queueCount += SpatialAudio.FRAME_SIZE
        }

        // Save remaining new input as carry
        let remaining = min(frameCount - newPos, SpatialAudio.FRAME_SIZE)
        if remaining > 0 {
            for i in 0..<remaining {
                carryL[carryCount + i] = buffer[(newPos + i) * 2]
                carryR[carryCount + i] = buffer[(newPos + i) * 2 + 1]
            }
            carryCount += remaining
        }

        // Write from output queue
        let doBlend = blend < 1.0
        let wet = blend
        let dry = 1.0 - blend
        let toWrite = min(frameCount, queueCount)

        for i in 0..<toWrite {
            if doBlend {
                buffer[i * 2]     = buffer[i * 2]     * dry + queueL[i] * wet
                buffer[i * 2 + 1] = buffer[i * 2 + 1] * dry + queueR[i] * wet
            } else {
                buffer[i * 2]     = queueL[i]
                buffer[i * 2 + 1] = queueR[i]
            }
        }

        if toWrite > 0 && toWrite < queueCount {
            for i in 0..<(queueCount - toWrite) {
                queueL[i] = queueL[i + toWrite]
                queueR[i] = queueR[i + toWrite]
            }
        }
        queueCount -= toWrite
    }

    // MARK: - Private helpers

    private static func direction(angleDeg: Float,
                                  lx: Float, ly: Float, lz: Float) -> IPLVector3 {
        let rad = angleDeg * DEG2RAD
        var dx = sinf(rad) - lx
        var dy: Float = -ly
        var dz = -cosf(rad) - lz
        let len = sqrtf(dx * dx + dy * dy + dz * dz)
        if len < 0.0001 {
            return IPLVector3(x: 0, y: 0, z: -1)
        }
        dx /= len; dy /= len; dz /= len
        return IPLVector3(x: dx, y: dy, z: dz)
    }

    private func createEffectsLocked(audio: IPLAudioSettings) -> Bool {
        var audio = audio
        var bs = IPLBinauralEffectSettings()
        bs.hrtf = hrtf

        func create(into out: inout IPLBinauralEffect?) -> Bool {
            let err = iplBinauralEffectCreate(context, &audio, &bs, &out)
            return err == IPL_STATUS_SUCCESS && out != nil
        }

        if mode == .binaural {
            if !create(into: &effectL) { lastError = "Binaural effect (L) creation failed."; return false }
            if !create(into: &effectR) { lastError = "Binaural effect (R) creation failed."; return false }
        } else {
            if !create(into: &effectFL) { lastError = "Surround effect (FL) creation failed."; return false }
            if !create(into: &effectFR) { lastError = "Surround effect (FR) creation failed."; return false }
            if !create(into: &effectC)  { lastError = "Surround effect (C) creation failed.";  return false }
            if !create(into: &effectSL) { lastError = "Surround effect (SL) creation failed."; return false }
            if !create(into: &effectSR) { lastError = "Surround effect (SR) creation failed."; return false }
            if !create(into: &effectRC) { lastError = "Surround effect (RC) creation failed."; return false }
        }
        return true
    }

    private func releaseEffectsLocked() {
        if effectL  != nil { iplBinauralEffectRelease(&effectL);  effectL  = nil }
        if effectR  != nil { iplBinauralEffectRelease(&effectR);  effectR  = nil }
        if effectFL != nil { iplBinauralEffectRelease(&effectFL); effectFL = nil }
        if effectFR != nil { iplBinauralEffectRelease(&effectFR); effectFR = nil }
        if effectC  != nil { iplBinauralEffectRelease(&effectC);  effectC  = nil }
        if effectSL != nil { iplBinauralEffectRelease(&effectSL); effectSL = nil }
        if effectSR != nil { iplBinauralEffectRelease(&effectSR); effectSR = nil }
        if effectRC != nil { iplBinauralEffectRelease(&effectRC); effectRC = nil }
    }

    private func shutdownLocked() {
        isInitialized = false
        releaseEffectsLocked()
        if hrtf    != nil { iplHRTFRelease(&hrtf);       hrtf    = nil }
        if context != nil { iplContextRelease(&context); context = nil }
        carryCount = 0
        queueCount = 0
    }

    private func rebuildEffectsForModeChange() {
        lock.lock(); defer { lock.unlock() }
        guard isInitialized, hrtf != nil else { return }
        let wasInit = isInitialized
        isInitialized = false
        releaseEffectsLocked()
        var audio = IPLAudioSettings()
        audio.samplingRate = sampleRate
        audio.frameSize = Int32(SpatialAudio.FRAME_SIZE)
        let ok = createEffectsLocked(audio: audio)
        if ok {
            carryCount = 0
            for i in 0..<SpatialAudio.FRAME_SIZE { queueL[i] = 0; queueR[i] = 0 }
            queueCount = SpatialAudio.FRAME_SIZE
            isInitialized = wasInit
        }
    }

    // MARK: - Frame processors

    private func processBinauralFrame(_ frameL: UnsafeMutablePointer<Float>,
                                      _ frameR: UnsafeMutablePointer<Float>) {
        let dirL = Self.direction(angleDeg: -width - rotation,
                                  lx: listenerX, ly: listenerY, lz: listenerZ)
        let dirR = Self.direction(angleDeg:  width - rotation,
                                  lx: listenerX, ly: listenerY, lz: listenerZ)

        mono.withUnsafeMutableBufferPointer { monoBuf in
        tmpL.withUnsafeMutableBufferPointer { tmpLBuf in
        tmpR.withUnsafeMutableBufferPointer { tmpRBuf in
            var monoPtr: UnsafeMutablePointer<Float>? = monoBuf.baseAddress
            var outPtrs: [UnsafeMutablePointer<Float>?] = [tmpLBuf.baseAddress, tmpRBuf.baseAddress]

            outPtrs.withUnsafeMutableBufferPointer { outArr in
            withUnsafeMutablePointer(to: &monoPtr) { monoArr in
                var inBuf = IPLAudioBuffer(numChannels: 1,
                                            numSamples: Int32(SpatialAudio.FRAME_SIZE),
                                            data: monoArr)
                var outBuf = IPLAudioBuffer(numChannels: 2,
                                             numSamples: Int32(SpatialAudio.FRAME_SIZE),
                                             data: outArr.baseAddress)

                var pL = IPLBinauralEffectParams()
                pL.direction = dirL
                pL.interpolation = IPL_HRTFINTERPOLATION_NEAREST
                pL.spatialBlend = 1.0
                pL.hrtf = hrtf

                var pR = IPLBinauralEffectParams()
                pR.direction = dirR
                pR.interpolation = IPL_HRTFINTERPOLATION_NEAREST
                pR.spatialBlend = 1.0
                pR.hrtf = hrtf

                // HRTF left channel
                memcpy(monoBuf.baseAddress, frameL, SpatialAudio.FRAME_SIZE * MemoryLayout<Float>.size)
                _ = iplBinauralEffectApply(effectL, &pL, &inBuf, &outBuf)
                _ = savL.withUnsafeMutableBufferPointer { sL in
                    memcpy(sL.baseAddress, tmpLBuf.baseAddress, SpatialAudio.FRAME_SIZE * MemoryLayout<Float>.size)
                }
                _ = savR.withUnsafeMutableBufferPointer { sR in
                    memcpy(sR.baseAddress, tmpRBuf.baseAddress, SpatialAudio.FRAME_SIZE * MemoryLayout<Float>.size)
                }

                // HRTF right channel
                memcpy(monoBuf.baseAddress, frameR, SpatialAudio.FRAME_SIZE * MemoryLayout<Float>.size)
                _ = iplBinauralEffectApply(effectR, &pR, &inBuf, &outBuf)
            }
            }
        }
        }
        }

        // Sum both virtual speakers into output
        for i in 0..<SpatialAudio.FRAME_SIZE {
            frameL[i] = (savL[i] + tmpL[i]) * 0.707
            frameR[i] = (savR[i] + tmpR[i]) * 0.707
        }
    }

    private func processSurroundFrame(_ frameL: UnsafeMutablePointer<Float>,
                                      _ frameR: UnsafeMutablePointer<Float>) {
        let frontAngle = width
        let surroundAngle: Float
        if rearCenter {
            // With RC: surrounds go far back (135..172°) since RC fills dead center
            surroundAngle = 180.0 - (width * 0.5)
        } else {
            // Without RC: surrounds stay to the sides (~90..120°), standard 5.1 layout
            surroundAngle = 90.0 + (width * 0.33)
        }

        // Upmix stereo to 6 channels into `upmix`: FL, FR, C, SL, SR, RC (stride FRAME_SIZE)
        let stride = SpatialAudio.FRAME_SIZE
        upmix.withUnsafeMutableBufferPointer { u in
            let fl = u.baseAddress!
            let fr = fl + stride
            let cc = fl + 2 * stride
            let sl = fl + 3 * stride
            let sr = fl + 4 * stride
            let rc = fl + 5 * stride
            for i in 0..<SpatialAudio.FRAME_SIZE {
                let l = frameL[i]
                let r = frameR[i]
                let mid = (l + r) * 0.5
                let side = (l - r) * 0.5
                fl[i] = l
                fr[i] = r
                cc[i] = mid * 0.6
                sl[i] = l * 0.5 + side * 1.0
                sr[i] = r * 0.5 - side * 1.0
                rc[i] = mid * 0.9
            }
        }

        for i in 0..<SpatialAudio.FRAME_SIZE { outAccL[i] = 0; outAccR[i] = 0 }

        let speakers: [(signal: Int, angle: Float, gain: Float, effect: IPLBinauralEffect?)] = [
            (0, -frontAngle    + rotation, 0.9, effectFL),
            (1,  frontAngle    + rotation, 0.9, effectFR),
            (2,  0.0           + rotation, 0.7, effectC),
            (3, -surroundAngle + rotation, 1.0, effectSL),
            (4,  surroundAngle + rotation, 1.0, effectSR),
            (5,  180.0         + rotation, 1.0, effectRC),
        ]
        let speakerCount = rearCenter ? 6 : 5

        mono.withUnsafeMutableBufferPointer { monoBuf in
        tmpL.withUnsafeMutableBufferPointer { tmpLBuf in
        tmpR.withUnsafeMutableBufferPointer { tmpRBuf in
        upmix.withUnsafeMutableBufferPointer { upmixBuf in
            var monoPtr: UnsafeMutablePointer<Float>? = monoBuf.baseAddress
            var outPtrs: [UnsafeMutablePointer<Float>?] = [tmpLBuf.baseAddress, tmpRBuf.baseAddress]

            outPtrs.withUnsafeMutableBufferPointer { outArr in
            withUnsafeMutablePointer(to: &monoPtr) { monoArr in
                var inBuf = IPLAudioBuffer(numChannels: 1,
                                            numSamples: Int32(SpatialAudio.FRAME_SIZE),
                                            data: monoArr)
                var outBuf = IPLAudioBuffer(numChannels: 2,
                                             numSamples: Int32(SpatialAudio.FRAME_SIZE),
                                             data: outArr.baseAddress)

                for s in 0..<speakerCount {
                    let spk = speakers[s]
                    var params = IPLBinauralEffectParams()
                    params.direction = Self.direction(angleDeg: spk.angle,
                                                      lx: listenerX, ly: listenerY, lz: listenerZ)
                    params.interpolation = IPL_HRTFINTERPOLATION_NEAREST
                    params.spatialBlend = 1.0
                    params.hrtf = hrtf

                    // Copy this speaker's signal into mono
                    let src = upmixBuf.baseAddress! + spk.signal * SpatialAudio.FRAME_SIZE
                    memcpy(monoBuf.baseAddress, src, SpatialAudio.FRAME_SIZE * MemoryLayout<Float>.size)
                    _ = iplBinauralEffectApply(spk.effect, &params, &inBuf, &outBuf)

                    for i in 0..<SpatialAudio.FRAME_SIZE {
                        outAccL[i] += tmpLBuf[i] * spk.gain
                        outAccR[i] += tmpRBuf[i] * spk.gain
                    }
                }
            }
            }
        }
        }
        }
        }

        let norm: Float = rearCenter ? 0.33 : 0.38
        for i in 0..<SpatialAudio.FRAME_SIZE {
            frameL[i] = outAccL[i] * norm
            frameR[i] = outAccR[i] * norm
        }
    }
}
