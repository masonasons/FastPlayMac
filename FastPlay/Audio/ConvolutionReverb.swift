//
//  ConvolutionReverb.swift
//  FastPlay
//
//  Partitioned convolution reverb using Apple Accelerate framework
//  Port of Windows convolution.cpp
//

import Foundation
import Accelerate

/// Partitioned convolution reverb for applying impulse response files
class ConvolutionReverb {

    // MARK: - Singleton

    static let shared = ConvolutionReverb()

    // MARK: - State

    private(set) var isInitialized = false
    private(set) var isIRLoaded = false
    private(set) var irPath: String = ""

    // IR info
    private(set) var irSampleRate: Int = 44100
    private(set) var irChannels: Int = 2
    private(set) var irSamples: Int = 0

    // FFT parameters
    private var fftSize: Int = 2048
    private var blockSize: Int = 1024
    private var numPartitions: Int = 0
    private var sampleRate: Int = 44100

    // FFT setup (Accelerate)
    private var fftSetup: FFTSetup?
    private var log2n: vDSP_Length = 11  // log2(2048)

    // IR in frequency domain (partitioned)
    private var irSpectrumL: [[DSPSplitComplex]] = []
    private var irSpectrumR: [[DSPSplitComplex]] = []

    // Storage for IR spectrums (real and imaginary parts)
    private var irSpectrumLReal: [[Float]] = []
    private var irSpectrumLImag: [[Float]] = []
    private var irSpectrumRReal: [[Float]] = []
    private var irSpectrumRImag: [[Float]] = []

    // Input buffers
    private var inputBufferL: [Float] = []
    private var inputBufferR: [Float] = []
    private var inputPos: Int = 0

    // Frequency delay line (circular buffer of FFT'd input blocks)
    private var fdlLReal: [[Float]] = []
    private var fdlLImag: [[Float]] = []
    private var fdlRReal: [[Float]] = []
    private var fdlRImag: [[Float]] = []
    private var fdlPos: Int = 0

    // Output accumulator
    private var outputL: [Float] = []
    private var outputR: [Float] = []

    // Temporary FFT buffers
    private var fftBufferReal: [Float] = []
    private var fftBufferImag: [Float] = []
    private var accumLReal: [Float] = []
    private var accumLImag: [Float] = []
    private var accumRReal: [Float] = []
    private var accumRImag: [Float] = []

    // Parameters
    var mix: Float = 50.0  // 0-100%
    var gain: Float = 0.0  // dB

    // MARK: - Initialization

    private init() {}

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    /// Load impulse response from audio file (WAV, FLAC, MP3, etc.)
    func loadIR(_ path: String) -> Bool {
        // Use BASS to decode the file
        let flags: DWORD = DWORD(BASS_STREAM_DECODE | BASS_SAMPLE_FLOAT)
        let stream = BASS_StreamCreateFile(0, path, 0, 0, flags)

        guard stream != 0 else {
            print("ConvolutionReverb: Failed to open IR file")
            return false
        }

        defer { BASS_StreamFree(stream) }

        // Get stream info
        var info = BASS_CHANNELINFO()
        guard BASS_ChannelGetInfo(stream, &info) != 0 else {
            print("ConvolutionReverb: Failed to get IR info")
            return false
        }

        let channels = Int(info.chans)
        let sampleRate = Int(info.freq)

        // Get total length
        let length = BASS_ChannelGetLength(stream, DWORD(BASS_POS_BYTE))
        guard length != QWORD(bitPattern: -1) else {
            print("ConvolutionReverb: Failed to get IR length")
            return false
        }

        let numSamples = Int(length) / (MemoryLayout<Float>.size * channels)

        // Read all audio data
        var interleavedData = [Float](repeating: 0, count: numSamples * channels)
        let bytesRead = BASS_ChannelGetData(stream, &interleavedData, DWORD(length))

        guard bytesRead != DWORD(bitPattern: -1) else {
            print("ConvolutionReverb: Failed to read IR data")
            return false
        }

        // Deinterleave to L/R channels
        var irDataL = [Float](repeating: 0, count: numSamples)
        var irDataR = [Float](repeating: 0, count: numSamples)

        for i in 0..<numSamples {
            irDataL[i] = interleavedData[i * channels]
            if channels >= 2 {
                irDataR[i] = interleavedData[i * channels + 1]
            } else {
                irDataR[i] = irDataL[i]  // Mono: duplicate
            }
        }

        // Store IR info
        irPath = path
        irSampleRate = sampleRate
        irChannels = channels
        irSamples = numSamples

        // Compute FFT parameters
        blockSize = 1024
        fftSize = blockSize * 2
        log2n = vDSP_Length(log2(Double(fftSize)))
        numPartitions = (numSamples + blockSize - 1) / blockSize

        // Create FFT setup
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        guard fftSetup != nil else {
            print("ConvolutionReverb: Failed to create FFT setup")
            return false
        }

        // Pad IR to multiple of block size
        let paddedSize = numPartitions * blockSize
        irDataL.append(contentsOf: [Float](repeating: 0, count: paddedSize - numSamples))
        irDataR.append(contentsOf: [Float](repeating: 0, count: paddedSize - numSamples))

        // Pre-compute FFT of each IR partition
        irSpectrumLReal = []
        irSpectrumLImag = []
        irSpectrumRReal = []
        irSpectrumRImag = []

        var tempReal = [Float](repeating: 0, count: fftSize)
        var tempImag = [Float](repeating: 0, count: fftSize)

        for p in 0..<numPartitions {
            // Left channel
            var partitionLReal = [Float](repeating: 0, count: fftSize / 2)
            var partitionLImag = [Float](repeating: 0, count: fftSize / 2)

            // Copy block and zero-pad
            for i in 0..<fftSize {
                tempReal[i] = i < blockSize ? irDataL[p * blockSize + i] : 0
                tempImag[i] = 0
            }

            // FFT
            tempReal.withUnsafeMutableBufferPointer { realPtr in
                tempImag.withUnsafeMutableBufferPointer { imagPtr in
                    var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                    vDSP_ctoz(UnsafePointer<DSPComplex>(OpaquePointer(realPtr.baseAddress!)), 2, &split, 1, vDSP_Length(fftSize / 2))
                    vDSP_fft_zip(fftSetup!, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
                    partitionLReal = Array(realPtr.prefix(fftSize / 2))
                    partitionLImag = Array(imagPtr.prefix(fftSize / 2))
                }
            }

            irSpectrumLReal.append(partitionLReal)
            irSpectrumLImag.append(partitionLImag)

            // Right channel
            var partitionRReal = [Float](repeating: 0, count: fftSize / 2)
            var partitionRImag = [Float](repeating: 0, count: fftSize / 2)

            for i in 0..<fftSize {
                tempReal[i] = i < blockSize ? irDataR[p * blockSize + i] : 0
                tempImag[i] = 0
            }

            tempReal.withUnsafeMutableBufferPointer { realPtr in
                tempImag.withUnsafeMutableBufferPointer { imagPtr in
                    var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                    vDSP_ctoz(UnsafePointer<DSPComplex>(OpaquePointer(realPtr.baseAddress!)), 2, &split, 1, vDSP_Length(fftSize / 2))
                    vDSP_fft_zip(fftSetup!, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
                    partitionRReal = Array(realPtr.prefix(fftSize / 2))
                    partitionRImag = Array(imagPtr.prefix(fftSize / 2))
                }
            }

            irSpectrumRReal.append(partitionRReal)
            irSpectrumRImag.append(partitionRImag)
        }

        isIRLoaded = true
        isInitialized = false  // Force re-initialization
        return true
    }

    /// Initialize processing buffers
    func initialize(sampleRate: Int) -> Bool {
        self.sampleRate = sampleRate

        // Allocate buffers
        inputBufferL = [Float](repeating: 0, count: fftSize)
        inputBufferR = [Float](repeating: 0, count: fftSize)
        inputPos = 0

        fftBufferReal = [Float](repeating: 0, count: fftSize)
        fftBufferImag = [Float](repeating: 0, count: fftSize)

        // Frequency delay line
        fdlLReal = []
        fdlLImag = []
        fdlRReal = []
        fdlRImag = []

        for _ in 0..<numPartitions {
            fdlLReal.append([Float](repeating: 0, count: fftSize / 2))
            fdlLImag.append([Float](repeating: 0, count: fftSize / 2))
            fdlRReal.append([Float](repeating: 0, count: fftSize / 2))
            fdlRImag.append([Float](repeating: 0, count: fftSize / 2))
        }
        fdlPos = 0

        // Accumulator buffers
        accumLReal = [Float](repeating: 0, count: fftSize / 2)
        accumLImag = [Float](repeating: 0, count: fftSize / 2)
        accumRReal = [Float](repeating: 0, count: fftSize / 2)
        accumRImag = [Float](repeating: 0, count: fftSize / 2)

        // Output accumulator
        outputL = [Float](repeating: 0, count: fftSize)
        outputR = [Float](repeating: 0, count: fftSize)

        isInitialized = true
        return true
    }

    /// Reset internal buffers
    func reset() {
        guard isInitialized else { return }

        inputBufferL = [Float](repeating: 0, count: fftSize)
        inputBufferR = [Float](repeating: 0, count: fftSize)
        inputPos = 0

        for i in 0..<numPartitions {
            fdlLReal[i] = [Float](repeating: 0, count: fftSize / 2)
            fdlLImag[i] = [Float](repeating: 0, count: fftSize / 2)
            fdlRReal[i] = [Float](repeating: 0, count: fftSize / 2)
            fdlRImag[i] = [Float](repeating: 0, count: fftSize / 2)
        }
        fdlPos = 0

        outputL = [Float](repeating: 0, count: fftSize)
        outputR = [Float](repeating: 0, count: fftSize)
    }

    /// Get IR length in milliseconds
    var irLengthMs: Float {
        guard isIRLoaded, irSampleRate > 0 else { return 0 }
        return Float(irSamples) / Float(irSampleRate) * 1000.0
    }

    /// Process stereo interleaved audio buffer
    func process(_ buffer: UnsafeMutablePointer<Float>, frames: Int) {
        guard isInitialized, isIRLoaded, numPartitions > 0 else { return }

        let wetGain = mix / 100.0
        let dryGain = 1.0 - wetGain
        let gainLinear = powf(10.0, gain / 20.0)

        for i in 0..<frames {
            let inL = buffer[i * 2]
            let inR = buffer[i * 2 + 1]

            // Store input
            inputBufferL[inputPos] = inL
            inputBufferR[inputPos] = inR

            // Get wet output from previously processed blocks
            let wetL = outputL[inputPos] * gainLinear
            let wetR = outputR[inputPos] * gainLinear

            // Mix dry and wet
            buffer[i * 2] = inL * dryGain + wetL * wetGain
            buffer[i * 2 + 1] = inR * dryGain + wetR * wetGain

            inputPos += 1

            // Process when we have a full block
            if inputPos >= blockSize {
                processBlock()
                inputPos = 0
            }
        }
    }

    /// Process one block of audio using partitioned convolution
    private func processBlock() {
        guard let setup = fftSetup else { return }

        // Left channel: zero-pad and FFT
        for i in 0..<fftSize {
            fftBufferReal[i] = i < blockSize ? inputBufferL[i] : 0
            fftBufferImag[i] = 0
        }

        fftBufferReal.withUnsafeMutableBufferPointer { realPtr in
            fftBufferImag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_ctoz(UnsafePointer<DSPComplex>(OpaquePointer(realPtr.baseAddress!)), 2, &split, 1, vDSP_Length(fftSize / 2))
                vDSP_fft_zip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }

        // Store in FDL
        for i in 0..<(fftSize / 2) {
            fdlLReal[fdlPos][i] = fftBufferReal[i]
            fdlLImag[fdlPos][i] = fftBufferImag[i]
        }

        // Right channel: zero-pad and FFT
        for i in 0..<fftSize {
            fftBufferReal[i] = i < blockSize ? inputBufferR[i] : 0
            fftBufferImag[i] = 0
        }

        fftBufferReal.withUnsafeMutableBufferPointer { realPtr in
            fftBufferImag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_ctoz(UnsafePointer<DSPComplex>(OpaquePointer(realPtr.baseAddress!)), 2, &split, 1, vDSP_Length(fftSize / 2))
                vDSP_fft_zip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }

        // Store in FDL
        for i in 0..<(fftSize / 2) {
            fdlRReal[fdlPos][i] = fftBufferReal[i]
            fdlRImag[fdlPos][i] = fftBufferImag[i]
        }

        // Partitioned convolution: accumulate products
        accumLReal = [Float](repeating: 0, count: fftSize / 2)
        accumLImag = [Float](repeating: 0, count: fftSize / 2)
        accumRReal = [Float](repeating: 0, count: fftSize / 2)
        accumRImag = [Float](repeating: 0, count: fftSize / 2)

        for p in 0..<numPartitions {
            let fdlIdx = (fdlPos - p + numPartitions) % numPartitions

            // Complex multiply and accumulate: (a+bi)(c+di) = (ac-bd) + (ad+bc)i
            for k in 0..<(fftSize / 2) {
                // Left
                let aL = fdlLReal[fdlIdx][k]
                let bL = fdlLImag[fdlIdx][k]
                let cL = irSpectrumLReal[p][k]
                let dL = irSpectrumLImag[p][k]
                accumLReal[k] += aL * cL - bL * dL
                accumLImag[k] += aL * dL + bL * cL

                // Right
                let aR = fdlRReal[fdlIdx][k]
                let bR = fdlRImag[fdlIdx][k]
                let cR = irSpectrumRReal[p][k]
                let dR = irSpectrumRImag[p][k]
                accumRReal[k] += aR * cR - bR * dR
                accumRImag[k] += aR * dR + bR * cR
            }
        }

        // IFFT left
        accumLReal.withUnsafeMutableBufferPointer { realPtr in
            accumLImag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_fft_zip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Inverse))

                // Scale
                var scale = Float(1.0 / Float(fftSize))
                vDSP_vsmul(realPtr.baseAddress!, 1, &scale, realPtr.baseAddress!, 1, vDSP_Length(fftSize / 2))
            }
        }

        // IFFT right
        accumRReal.withUnsafeMutableBufferPointer { realPtr in
            accumRImag.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_fft_zip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Inverse))

                var scale = Float(1.0 / Float(fftSize))
                vDSP_vsmul(realPtr.baseAddress!, 1, &scale, realPtr.baseAddress!, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Overlap-add
        for j in 0..<blockSize {
            outputL[j] = outputL[j + blockSize] + accumLReal[j]
            outputR[j] = outputR[j + blockSize] + accumRReal[j]
        }
        for j in 0..<blockSize {
            outputL[j + blockSize] = j < accumLReal.count - blockSize ? accumLReal[j + blockSize] : 0
            outputR[j + blockSize] = j < accumRReal.count - blockSize ? accumRReal[j + blockSize] : 0
        }

        // Advance FDL position
        fdlPos = (fdlPos + 1) % numPartitions
    }
}
