//
//  FastPlay-Bridging-Header.h
//  FastPlay
//
//  BASS Audio Library bridging header for Swift
//

#ifndef FastPlay_Bridging_Header_h
#define FastPlay_Bridging_Header_h

// Carbon for global hotkeys
#include <Carbon/Carbon.h>

// BASS Audio Library headers (downloaded by download-deps.sh)
// These are in FastPlay/Supporting/BASS/
#include "BASS/bass.h"

// Define CALLBACK if not already defined (BASS uses this for calling convention on Windows)
#ifndef CALLBACK
#define CALLBACK
#endif

// Define BASS_SAMPLE_FLOAT if not already defined (needed for DSP format checking)
#ifndef BASS_SAMPLE_FLOAT
#define BASS_SAMPLE_FLOAT 0x100
#endif

// BASS_FX for tempo/pitch
#if __has_include("BASS/bass_fx.h")
#include "BASS/bass_fx.h"
#else
// Fallback BASS_FX declarations if header not found

// Effect types
#define BASS_FX_BFX_ROTATE      0x10000
#define BASS_FX_BFX_VOLUME      0x10003
#define BASS_FX_BFX_PEAKEQ      0x10004
#define BASS_FX_BFX_MIX         0x10007
#define BASS_FX_BFX_DAMP        0x10008
#define BASS_FX_BFX_AUTOWAH     0x10009
#define BASS_FX_BFX_PHASER      0x1000B
#define BASS_FX_BFX_CHORUS      0x1000D
#define BASS_FX_BFX_DISTORTION  0x10010
#define BASS_FX_BFX_COMPRESSOR2 0x10011
#define BASS_FX_BFX_VOLUME_ENV  0x10012
#define BASS_FX_BFX_BQF         0x10013
#define BASS_FX_BFX_ECHO4       0x10014
#define BASS_FX_BFX_PITCHSHIFT  0x10015
#define BASS_FX_BFX_FREEVERB    0x10016

// Channel flags
#define BASS_BFX_CHANALL        -1

// Tempo attributes
#define BASS_ATTRIB_TEMPO       0x10000
#define BASS_ATTRIB_TEMPO_PITCH 0x10001
#define BASS_ATTRIB_TEMPO_FREQ  0x10002

// Tempo/FX stream creation
#define BASS_FX_FREESOURCE      0x10000

// BASS_FX functions
HSTREAM BASS_FX_TempoCreate(DWORD chan, DWORD flags);
DWORD BASS_FX_TempoGetSource(HSTREAM chan);

// Effect parameter structures
typedef struct {
    float fDryMix;
    float fWetMix;
    float fRoomSize;
    float fDamp;
    float fWidth;
    DWORD lMode;
    DWORD lChannel;
} BASS_BFX_FREEVERB;

typedef struct {
    float fDryMix;
    float fWetMix;
    float fFeedback;
    float fDelay;
    BOOL bStereo;
    DWORD lChannel;
} BASS_BFX_ECHO4;

typedef struct {
    DWORD lBand;
    float fBandwidth;
    float fQ;
    float fCenter;
    float fGain;
    DWORD lChannel;
} BASS_BFX_PEAKEQ;

typedef struct {
    DWORD lChannel;
    float fVolume;
} BASS_BFX_VOLUME;

typedef struct {
    float fGain;
    float fThreshold;
    float fRatio;
    float fAttack;
    float fRelease;
    DWORD lChannel;
} BASS_BFX_COMPRESSOR2;

#endif

// Custom DSP callback type (always define our own to ensure it's available)
// BASS's DSPPROC from bass.h may not be imported correctly for Swift
#ifndef FASTPLAY_DSPPROC_DEFINED
#define FASTPLAY_DSPPROC_DEFINED
typedef void (*DSPPROC_Swift)(HDSP handle, DWORD channel, void *buffer, DWORD length, void *user);
#endif

// BASS Encoder for recording
#if __has_include("BASS/bassenc.h")
#include "BASS/bassenc.h"
#endif

// BASSENC format-specific encoders
#if __has_include("BASS/bassenc_mp3.h")
#include "BASS/bassenc_mp3.h"
#endif

#if __has_include("BASS/bassenc_ogg.h")
#include "BASS/bassenc_ogg.h"
#endif

#if __has_include("BASS/bassenc_flac.h")
#include "BASS/bassenc_flac.h"
#endif

// Fallback encoder declarations if headers not found
#ifndef BASS_ENCODE_AUTOFREE
typedef DWORD HENCODE;

#define BASS_ENCODE_PCM         0x00000
#define BASS_ENCODE_AUTOFREE    0x40000
#define BASS_ENCODE_FP_16BIT    0x80000

// Core encoder functions
DWORD BASS_Encode_Start(DWORD handle, const char * _Nonnull cmdline, DWORD flags, void * _Nullable proc, void * _Nullable user);
DWORD BASS_Encode_StartPCMFile(DWORD handle, DWORD flags, const char * _Nonnull filename);
BOOL BASS_Encode_Stop(DWORD handle);
BOOL BASS_Encode_IsActive(DWORD handle);
#endif

// MP3 encoder (bassenc_mp3)
#ifndef BASS_Encode_MP3_StartFile
DWORD BASS_Encode_MP3_StartFile(DWORD handle, const char * _Nullable options, DWORD flags, const char * _Nonnull filename);
#endif

// OGG encoder (bassenc_ogg)
#ifndef BASS_Encode_OGG_StartFile
DWORD BASS_Encode_OGG_StartFile(DWORD handle, const char * _Nullable options, DWORD flags, const char * _Nonnull filename);
#endif

// FLAC encoder (bassenc_flac)
#ifndef BASS_Encode_FLAC_StartFile
DWORD BASS_Encode_FLAC_StartFile(DWORD handle, const char * _Nullable options, DWORD flags, const char * _Nonnull filename);
#endif

// BASS Mix for stream mixing
#if __has_include("BASS/bassmix.h")
#include "BASS/bassmix.h"
#endif

// BASSFLAC for FLAC support (includes TAG_FLAC_PICTURE)
#if __has_include("BASS/bassflac.h")
#include "BASS/bassflac.h"
#endif

// BASSMIDI for MIDI file support
#if __has_include("BASS/bassmidi.h")
#include "BASS/bassmidi.h"
#endif

// Fallback BASSMIDI declarations if header not found
#ifndef BASS_CONFIG_MIDI_VOICES
#define BASS_CONFIG_MIDI_VOICES 0x10401
#define BASS_MIDI_SINCINTER     0x800000

typedef DWORD HSOUNDFONT;

typedef struct {
    HSOUNDFONT font;
    int preset;
    int bank;
} BASS_MIDI_FONT;

// BASSMIDI functions
HSOUNDFONT BASS_MIDI_FontInit(const char * _Nonnull file, DWORD flags);
BOOL BASS_MIDI_FontFree(HSOUNDFONT handle);
HSTREAM BASS_MIDI_StreamCreateFile(BOOL mem, const void * _Nonnull file, QWORD offset, QWORD length, DWORD flags, DWORD freq);
BOOL BASS_MIDI_StreamSetFonts(HSTREAM handle, const BASS_MIDI_FONT * _Nullable fonts, DWORD count);
#endif

// Custom DSP callbacks (C implementations for reliability)
#include "../Audio/DSPCallbacks.h"

// Steam Audio (spatial / binaural / 5.1 virtual surround)
// Only exposed when the SDK has been downloaded by download-deps.sh.
#if __has_include("SteamAudio/phonon.h")
#include "SteamAudio/phonon.h"
#define FASTPLAY_HAS_STEAM_AUDIO 1
#endif

#endif /* FastPlay_Bridging_Header_h */
