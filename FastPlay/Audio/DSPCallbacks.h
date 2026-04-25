//
//  DSPCallbacks.h
//  FastPlay
//
//  C implementations of DSP callbacks for BASS
//

#ifndef DSPCallbacks_h
#define DSPCallbacks_h

#include "../Supporting/BASS/bass.h"

// Define CALLBACK if not defined (macOS doesn't need calling convention)
#ifndef CALLBACK
#define CALLBACK
#endif

// Define BASS_SAMPLE_FLOAT if not defined
#ifndef BASS_SAMPLE_FLOAT
#define BASS_SAMPLE_FLOAT 0x100
#endif

// Setter functions (call from Swift to update parameters)
void DSP_SetStereoWidth(float value);
void DSP_SetCenterCancel(float value);

// Center cancel processor lifecycle (call from Swift)
void DSP_InitCenterCancelProcessor(int sampleRate);
void DSP_FreeCenterCancelProcessor(void);

// Convolution reverb callback type (Swift provides the actual processing function)
typedef void (*DSP_ConvolutionCallback)(float *buffer, unsigned int frames);
void DSP_SetConvolutionCallback(DSP_ConvolutionCallback callback);

// Spatial audio callback type (Swift provides the Steam Audio processor)
typedef void (*DSP_SpatialCallback)(float *buffer, unsigned int frames);
void DSP_SetSpatialCallback(DSP_SpatialCallback callback);

// DSP callback functions (pass to BASS_ChannelSetDSP)
void CALLBACK DSP_StereoWidthProc(HDSP handle, DWORD channel, void *buffer, DWORD length, void *user);
void CALLBACK DSP_CenterCancelProc(HDSP handle, DWORD channel, void *buffer, DWORD length, void *user);
void CALLBACK DSP_ConvolutionProc(HDSP handle, DWORD channel, void *buffer, DWORD length, void *user);
void CALLBACK DSP_SpatialProc(HDSP handle, DWORD channel, void *buffer, DWORD length, void *user);

#endif /* DSPCallbacks_h */
