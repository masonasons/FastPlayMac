#!/bin/bash
# Download dependencies for FastPlay macOS
set -e

cd "$(dirname "$0")"

echo "============================================"
echo "FastPlay macOS Dependency Downloader"
echo "============================================"
echo ""

# Check for required tools
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed."
    exit 1
fi

if ! command -v unzip &> /dev/null; then
    echo "Error: unzip is not installed."
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo "Error: git is not installed."
    echo "Install with: xcode-select --install"
    exit 1
fi

# Create directories
mkdir -p Frameworks
mkdir -p Libraries
mkdir -p temp_dl

# Helper function to download and extract
download_bass() {
    local name=$1
    local url=$2
    local dylib=$3

    echo "  Downloading $name..."
    if curl -sfL "$url" -o "temp_dl/$name.zip"; then
        if unzip -qo "temp_dl/$name.zip" -d "temp_dl/$name" 2>/dev/null; then
            if [ -f "temp_dl/$name/$dylib" ]; then
                cp "temp_dl/$name/$dylib" Frameworks/
                echo "    ✓ $dylib"
                return 0
            fi
        fi
    fi
    echo "    ✗ Not available for macOS (skipped)"
    return 1
}

echo "Downloading BASS libraries for macOS..."
echo ""

# Core libraries (required)
echo "[1/12] BASS (core)..."
download_bass "bass" "https://www.un4seen.com/files/bass24-osx.zip" "libbass.dylib"

echo "[2/12] BASS_FX (tempo/pitch)..."
download_bass "bass_fx" "https://www.un4seen.com/files/z/0/bass_fx24-osx.zip" "libbass_fx.dylib"

# Format plugins
echo "[3/12] BASSFLAC..."
download_bass "bassflac" "https://www.un4seen.com/files/bassflac24-osx.zip" "libbassflac.dylib"

echo "[4/12] BASSOPUS..."
download_bass "bassopus" "https://www.un4seen.com/files/bassopus24-osx.zip" "libbassopus.dylib"

echo "[5/12] BASSMIDI..."
download_bass "bassmidi" "https://www.un4seen.com/files/bassmidi24-osx.zip" "libbassmidi.dylib"

echo "[6/12] BASS_AAC..."
download_bass "bass_aac" "https://www.un4seen.com/files/z/2/bass_aac24-osx.zip" "libbass_aac.dylib"

echo "[7/12] BASSHLS..."
download_bass "basshls" "https://www.un4seen.com/files/basshls24-osx.zip" "libbasshls.dylib"

echo "[8/12] BASSMIX..."
download_bass "bassmix" "https://www.un4seen.com/files/bassmix24-osx.zip" "libbassmix.dylib"

# Encoding libraries
echo "[9/12] BASSENC..."
download_bass "bassenc" "https://www.un4seen.com/files/bassenc24-osx.zip" "libbassenc.dylib"

echo "[10/12] BASSENC_MP3..."
download_bass "bassenc_mp3" "https://www.un4seen.com/files/bassenc_mp324-osx.zip" "libbassenc_mp3.dylib"

echo "[11/12] BASSENC_OGG..."
download_bass "bassenc_ogg" "https://www.un4seen.com/files/bassenc_ogg24-osx.zip" "libbassenc_ogg.dylib"

echo "[12/12] BASSENC_FLAC..."
download_bass "bassenc_flac" "https://www.un4seen.com/files/bassenc_flac24-osx.zip" "libbassenc_flac.dylib"

# Copy headers - find them wherever they are in the extracted zips
echo ""
echo "Copying headers..."
mkdir -p FastPlay/Supporting/BASS

# Find and copy each header (they may be in root or c/ subdirectory)
find temp_dl/bass -name "bass.h" -exec cp {} FastPlay/Supporting/BASS/ \; 2>/dev/null && echo "  ✓ bass.h"
find temp_dl/bass_fx -name "bass_fx.h" -exec cp {} FastPlay/Supporting/BASS/ \; 2>/dev/null && echo "  ✓ bass_fx.h"
find temp_dl/bassmidi -name "bassmidi.h" -exec cp {} FastPlay/Supporting/BASS/ \; 2>/dev/null && echo "  ✓ bassmidi.h"
find temp_dl/bassenc -name "bassenc.h" -exec cp {} FastPlay/Supporting/BASS/ \; 2>/dev/null && echo "  ✓ bassenc.h"
find temp_dl/bassmix -name "bassmix.h" -exec cp {} FastPlay/Supporting/BASS/ \; 2>/dev/null && echo "  ✓ bassmix.h"
find temp_dl/bassflac -name "bassflac.h" -exec cp {} FastPlay/Supporting/BASS/ \; 2>/dev/null && echo "  ✓ bassflac.h"
find temp_dl/bassopus -name "bassopus.h" -exec cp {} FastPlay/Supporting/BASS/ \; 2>/dev/null && echo "  ✓ bassopus.h"

# Verify we got the essential headers
if [ ! -f "FastPlay/Supporting/BASS/bass.h" ]; then
    echo ""
    echo "ERROR: bass.h not found! Searching temp_dl for headers..."
    find temp_dl -name "*.h" -type f
    exit 1
fi

echo ""
echo "Downloading Steam Audio SDK (spatial audio / HRTF)..."
STEAM_AUDIO_VERSION="4.8.1"
if curl -sfL "https://github.com/ValveSoftware/steam-audio/releases/download/v${STEAM_AUDIO_VERSION}/steamaudio_${STEAM_AUDIO_VERSION}.zip" -o "temp_dl/steamaudio.zip"; then
    if unzip -qo "temp_dl/steamaudio.zip" -d "temp_dl/steamaudio" 2>/dev/null; then
        if [ -f "temp_dl/steamaudio/steamaudio/lib/osx/libphonon.dylib" ]; then
            cp "temp_dl/steamaudio/steamaudio/lib/osx/libphonon.dylib" Frameworks/
            echo "  ✓ libphonon.dylib"
            mkdir -p FastPlay/Supporting/SteamAudio
            cp temp_dl/steamaudio/steamaudio/include/phonon.h            FastPlay/Supporting/SteamAudio/
            cp temp_dl/steamaudio/steamaudio/include/phonon_interfaces.h FastPlay/Supporting/SteamAudio/
            cp temp_dl/steamaudio/steamaudio/include/phonon_version.h    FastPlay/Supporting/SteamAudio/
            echo "  ✓ phonon.h, phonon_interfaces.h, phonon_version.h"
        else
            echo "  ✗ libphonon.dylib not found in archive (skipped — spatial audio unavailable)"
        fi
    fi
else
    echo "  ✗ Steam Audio download failed (skipped — spatial audio unavailable)"
fi

echo ""
echo "Cleaning up..."
rm -rf temp_dl

echo ""
echo "============================================"
echo "Download complete!"
echo "============================================"
echo ""
echo "BASS libraries:"
ls -1 Frameworks/*.dylib 2>/dev/null | while read f; do echo "  ✓ $(basename $f)"; done
echo ""
echo "Next steps:"
echo "  1. Open FastPlay.xcodeproj in Xcode"
echo "  2. Build (Cmd+B)"
echo ""
