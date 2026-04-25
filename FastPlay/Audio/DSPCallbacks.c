//
//  DSPCallbacks.c
//  FastPlay
//
//  C implementations of DSP callbacks for BASS
//  Includes FFT-based center cancel processor (ported from Windows)
//

#include "DSPCallbacks.h"
#include "../Supporting/BASS/bass.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Global parameter values (set from Swift)
float g_dsp_stereoWidth = 100.0f;
float g_dsp_centerCancel = 0.0f;

// Convolution reverb callback function pointer (set from Swift)
static DSP_ConvolutionCallback g_convolutionCallback = NULL;

void DSP_SetConvolutionCallback(DSP_ConvolutionCallback callback) {
    g_convolutionCallback = callback;
}

// Spatial audio callback function pointer (set from Swift)
static DSP_SpatialCallback g_spatialCallback = NULL;

void DSP_SetSpatialCallback(DSP_SpatialCallback callback) {
    g_spatialCallback = callback;
}

// Setter functions (called from Swift)
void DSP_SetStereoWidth(float value) {
    g_dsp_stereoWidth = value;
}

void DSP_SetCenterCancel(float value) {
    g_dsp_centerCancel = value;
}

// ============================================================================
// FFT-based Center Cancel Processor (matching Windows implementation)
// ============================================================================

#define CC_FFT_SIZE 4096
#define CC_HOP_SIZE 1024  // 75% overlap
#define CC_OUTPUT_BUF_SIZE (CC_FFT_SIZE * 2)

typedef struct {
    float real;
    float imag;
} Complex;

typedef struct {
    int initialized;
    int sampleRate;

    // Buffers
    float *inputBufferL;
    float *inputBufferR;
    float *outputBufferL;
    float *outputBufferR;
    float *window;

    // FFT work buffers
    Complex *fftL;
    Complex *fftR;

    int inputPos;
    int outputPos;
    int outputAvail;
} CenterCancelProcessor;

static CenterCancelProcessor *g_ccProcessor = NULL;

// Complex number helpers
static inline Complex complex_make(float r, float i) {
    Complex c = {r, i};
    return c;
}

static inline Complex complex_add(Complex a, Complex b) {
    return complex_make(a.real + b.real, a.imag + b.imag);
}

static inline Complex complex_sub(Complex a, Complex b) {
    return complex_make(a.real - b.real, a.imag - b.imag);
}

static inline Complex complex_mul(Complex a, Complex b) {
    return complex_make(a.real * b.real - a.imag * b.imag,
                       a.real * b.imag + a.imag * b.real);
}

static inline Complex complex_scale(Complex a, float s) {
    return complex_make(a.real * s, a.imag * s);
}

static inline Complex complex_conj(Complex a) {
    return complex_make(a.real, -a.imag);
}

static inline float complex_abs(Complex a) {
    return sqrtf(a.real * a.real + a.imag * a.imag);
}

static inline float complex_arg(Complex a) {
    return atan2f(a.imag, a.real);
}

// Cooley-Tukey radix-2 FFT
static void FFT(Complex *data, int n, int inverse) {
    // Bit-reversal permutation
    int j = 0;
    for (int i = 0; i < n - 1; i++) {
        if (i < j) {
            Complex temp = data[i];
            data[i] = data[j];
            data[j] = temp;
        }
        int k = n / 2;
        while (k <= j) {
            j -= k;
            k /= 2;
        }
        j += k;
    }

    // Cooley-Tukey iterative FFT
    for (int len = 2; len <= n; len *= 2) {
        float angle = (inverse ? 2.0f : -2.0f) * (float)M_PI / len;
        Complex wn = complex_make(cosf(angle), sinf(angle));

        for (int i = 0; i < n; i += len) {
            Complex w = complex_make(1.0f, 0.0f);
            for (int jj = 0; jj < len / 2; jj++) {
                Complex u = data[i + jj];
                Complex t = complex_mul(w, data[i + jj + len / 2]);
                data[i + jj] = complex_add(u, t);
                data[i + jj + len / 2] = complex_sub(u, t);
                w = complex_mul(w, wn);
            }
        }
    }

    // Scale for inverse FFT
    if (inverse) {
        for (int i = 0; i < n; i++) {
            data[i] = complex_scale(data[i], 1.0f / n);
        }
    }
}

// Process one FFT frame
static void ProcessFrame(CenterCancelProcessor *proc, float amount) {
    // Copy input to FFT buffers and apply window
    for (int i = 0; i < CC_FFT_SIZE; i++) {
        proc->fftL[i] = complex_make(proc->inputBufferL[i] * proc->window[i], 0.0f);
        proc->fftR[i] = complex_make(proc->inputBufferR[i] * proc->window[i], 0.0f);
    }

    // Forward FFT
    FFT(proc->fftL, CC_FFT_SIZE, 0);
    FFT(proc->fftR, CC_FFT_SIZE, 0);

    // Process each frequency bin using Mid/Side in frequency domain
    int cancel = amount > 0.0f;
    float strength = fabsf(amount);

    for (int i = 0; i <= CC_FFT_SIZE / 2; i++) {
        Complex L = proc->fftL[i];
        Complex R = proc->fftR[i];

        // Convert to Mid/Side in frequency domain
        Complex Mid = complex_scale(complex_add(L, R), 0.5f);
        Complex Side = complex_scale(complex_sub(L, R), 0.5f);

        float magMid = complex_abs(Mid);
        float magSide = complex_abs(Side);
        float magTotal = magMid + magSide;

        if (magTotal < 1e-10f) continue;  // Skip silent bins

        // Calculate "centerness" based on Mid/Side ratio
        float centerness = magMid / (magMid + magSide + 1e-10f);

        // Also factor in phase correlation for better detection
        float phaseL = complex_arg(L);
        float phaseR = complex_arg(R);
        float phaseDiff = phaseL - phaseR;
        while (phaseDiff > M_PI) phaseDiff -= 2.0f * (float)M_PI;
        while (phaseDiff < -M_PI) phaseDiff += 2.0f * (float)M_PI;
        float phaseCorrelation = cosf(phaseDiff) * 0.5f + 0.5f;

        // Blend centerness with phase correlation
        centerness = centerness * 0.7f + phaseCorrelation * 0.3f;

        Complex newL, newR;

        if (cancel) {
            // Cancel center: reduce Mid, keep Side
            float midGain = 1.0f - (centerness * strength);
            if (midGain < 0.0f) midGain = 0.0f;

            Complex newMid = complex_scale(Mid, midGain);
            newL = complex_add(newMid, Side);
            newR = complex_sub(newMid, Side);
        } else {
            // Extract center: keep Mid, reduce Side
            float sideGain = 1.0f - strength;
            if (sideGain < 0.0f) sideGain = 0.0f;

            Complex newSide = complex_scale(Side, sideGain);
            newL = complex_add(Mid, newSide);
            newR = complex_sub(Mid, newSide);
        }

        proc->fftL[i] = newL;
        proc->fftR[i] = newR;

        // Mirror for negative frequencies (except DC and Nyquist)
        if (i > 0 && i < CC_FFT_SIZE / 2) {
            proc->fftL[CC_FFT_SIZE - i] = complex_conj(proc->fftL[i]);
            proc->fftR[CC_FFT_SIZE - i] = complex_conj(proc->fftR[i]);
        }
    }

    // Inverse FFT
    FFT(proc->fftL, CC_FFT_SIZE, 1);
    FFT(proc->fftR, CC_FFT_SIZE, 1);

    // Overlap-add to output buffer
    float scale = 1.0f / (CC_FFT_SIZE / CC_HOP_SIZE * 0.5f);

    for (int i = 0; i < CC_FFT_SIZE; i++) {
        int outIdx = (proc->outputPos + i) % CC_OUTPUT_BUF_SIZE;
        proc->outputBufferL[outIdx] += proc->fftL[i].real * proc->window[i] * scale;
        proc->outputBufferR[outIdx] += proc->fftR[i].real * proc->window[i] * scale;
    }

    proc->outputAvail += CC_HOP_SIZE;
}

void DSP_InitCenterCancelProcessor(int sampleRate) {
    if (!g_ccProcessor) {
        g_ccProcessor = (CenterCancelProcessor *)calloc(1, sizeof(CenterCancelProcessor));
    }

    CenterCancelProcessor *proc = g_ccProcessor;

    // Free existing buffers if reinitializing
    if (proc->initialized) {
        free(proc->inputBufferL);
        free(proc->inputBufferR);
        free(proc->outputBufferL);
        free(proc->outputBufferR);
        free(proc->window);
        free(proc->fftL);
        free(proc->fftR);
    }

    proc->sampleRate = sampleRate;

    // Allocate buffers
    proc->inputBufferL = (float *)calloc(CC_FFT_SIZE, sizeof(float));
    proc->inputBufferR = (float *)calloc(CC_FFT_SIZE, sizeof(float));
    proc->outputBufferL = (float *)calloc(CC_OUTPUT_BUF_SIZE, sizeof(float));
    proc->outputBufferR = (float *)calloc(CC_OUTPUT_BUF_SIZE, sizeof(float));
    proc->window = (float *)malloc(CC_FFT_SIZE * sizeof(float));
    proc->fftL = (Complex *)malloc(CC_FFT_SIZE * sizeof(Complex));
    proc->fftR = (Complex *)malloc(CC_FFT_SIZE * sizeof(Complex));

    // Create Hann window
    for (int i = 0; i < CC_FFT_SIZE; i++) {
        proc->window[i] = 0.5f * (1.0f - cosf(2.0f * (float)M_PI * i / (CC_FFT_SIZE - 1)));
    }

    proc->inputPos = 0;
    proc->outputPos = 0;
    proc->outputAvail = 0;
    proc->initialized = 1;
}

void DSP_FreeCenterCancelProcessor(void) {
    if (g_ccProcessor) {
        if (g_ccProcessor->initialized) {
            free(g_ccProcessor->inputBufferL);
            free(g_ccProcessor->inputBufferR);
            free(g_ccProcessor->outputBufferL);
            free(g_ccProcessor->outputBufferR);
            free(g_ccProcessor->window);
            free(g_ccProcessor->fftL);
            free(g_ccProcessor->fftR);
        }
        free(g_ccProcessor);
        g_ccProcessor = NULL;
    }
}

// Stereo Width DSP callback
void CALLBACK DSP_StereoWidthProc(HDSP handle, DWORD channel, void *buffer, DWORD length, void *user) {
    if (!buffer) return;

    // Get channel info
    BASS_CHANNELINFO info;
    if (!BASS_ChannelGetInfo(channel, &info)) return;
    if (info.chans != 2) return;

    float width = g_dsp_stereoWidth / 100.0f;

    // Skip if at default (100%)
    if (width > 0.99f && width < 1.01f) return;

    // Handle float format (we use BASS_SAMPLE_FLOAT)
    if (info.flags & BASS_SAMPLE_FLOAT) {
        float *samples = (float *)buffer;
        DWORD frameCount = length / (sizeof(float) * 2);

        for (DWORD i = 0; i < frameCount; i++) {
            float left = samples[i * 2];
            float right = samples[i * 2 + 1];

            // Mid/Side processing
            float mid = (left + right) * 0.5f;
            float side = (left - right) * 0.5f;

            // Apply width
            side *= width;

            // Convert back
            samples[i * 2] = mid + side;
            samples[i * 2 + 1] = mid - side;
        }
    }
}

// Center Cancel DSP callback - FFT-based spectral processing
void CALLBACK DSP_CenterCancelProc(HDSP handle, DWORD channel, void *buffer, DWORD length, void *user) {
    if (!buffer) return;

    // Get channel info
    BASS_CHANNELINFO info;
    if (!BASS_ChannelGetInfo(channel, &info)) return;
    if (info.chans != 2) return;
    if (!(info.flags & BASS_SAMPLE_FLOAT)) return;  // Only handle float format

    float amount = g_dsp_centerCancel / 100.0f;

    // Skip if at neutral (0%)
    if (amount > -0.01f && amount < 0.01f) return;

    // Initialize processor if needed
    if (!g_ccProcessor || !g_ccProcessor->initialized) {
        DSP_InitCenterCancelProcessor((int)info.freq);
    }

    CenterCancelProcessor *proc = g_ccProcessor;
    if (!proc) return;

    float *samples = (float *)buffer;
    DWORD frameCount = length / (sizeof(float) * 2);

    // For extraction mode (negative amount), use simple time-domain processing
    // This is more reliable and produces cleaner mono extraction
    if (amount < 0.0f) {
        float strength = -amount;
        for (DWORD i = 0; i < frameCount; i++) {
            float left = samples[i * 2];
            float right = samples[i * 2 + 1];

            float center = (left + right) * 0.5f;
            float sideL = left - center;
            float sideR = right - center;

            float sideGain = 1.0f - strength;
            samples[i * 2] = center + sideL * sideGain;
            samples[i * 2 + 1] = center + sideR * sideGain;
        }
        return;
    }

    // FFT-based processing for cancellation (positive amount)
    DWORD outIdx = 0;

    for (DWORD i = 0; i < frameCount; i++) {
        // Add input to buffer
        proc->inputBufferL[proc->inputPos] = samples[i * 2];
        proc->inputBufferR[proc->inputPos] = samples[i * 2 + 1];
        proc->inputPos++;

        // When we have a full FFT frame, process it
        if (proc->inputPos >= CC_FFT_SIZE) {
            ProcessFrame(proc, amount);

            // Shift input buffer by hop size
            memmove(proc->inputBufferL, proc->inputBufferL + CC_HOP_SIZE,
                   (CC_FFT_SIZE - CC_HOP_SIZE) * sizeof(float));
            memmove(proc->inputBufferR, proc->inputBufferR + CC_HOP_SIZE,
                   (CC_FFT_SIZE - CC_HOP_SIZE) * sizeof(float));
            proc->inputPos = CC_FFT_SIZE - CC_HOP_SIZE;
        }

        // Output available samples
        if (proc->outputAvail > 0) {
            int readIdx = proc->outputPos % CC_OUTPUT_BUF_SIZE;
            samples[outIdx * 2] = proc->outputBufferL[readIdx];
            samples[outIdx * 2 + 1] = proc->outputBufferR[readIdx];

            // Clear the output buffer position we just read
            proc->outputBufferL[readIdx] = 0.0f;
            proc->outputBufferR[readIdx] = 0.0f;

            proc->outputPos++;
            proc->outputAvail--;
        } else {
            // No output available yet (startup latency), output silence
            samples[outIdx * 2] = 0.0f;
            samples[outIdx * 2 + 1] = 0.0f;
        }
        outIdx++;
    }
}

// Convolution Reverb DSP callback
void CALLBACK DSP_ConvolutionProc(HDSP handle, DWORD channel, void *buffer, DWORD length, void *user) {
    if (!buffer || !g_convolutionCallback) return;

    // Get channel info
    BASS_CHANNELINFO info;
    if (!BASS_ChannelGetInfo(channel, &info)) return;
    if (info.chans != 2) return;

    // Only process float format (convolution requires float)
    if (!(info.flags & BASS_SAMPLE_FLOAT)) return;

    float *samples = (float *)buffer;
    DWORD frameCount = length / (sizeof(float) * 2);

    // Call the Swift convolution processor
    g_convolutionCallback(samples, frameCount);
}

// Spatial Audio DSP callback (defers to Swift SpatialAudio.process)
void CALLBACK DSP_SpatialProc(HDSP handle, DWORD channel, void *buffer, DWORD length, void *user) {
    if (!buffer || !g_spatialCallback) return;

    BASS_CHANNELINFO info;
    if (!BASS_ChannelGetInfo(channel, &info)) return;
    if (info.chans != 2) return;
    if (!(info.flags & BASS_SAMPLE_FLOAT)) return;

    float *samples = (float *)buffer;
    DWORD frameCount = length / (sizeof(float) * 2);
    g_spatialCallback(samples, frameCount);
}
