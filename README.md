# FastPlay for macOS

A macOS port of FastPlay audio player, maintaining exact feature parity with the Windows version.

## Requirements

- macOS 12.0 (Monterey) or later
- Xcode 14 or later

## Quick Start

```bash
# Download all dependencies (BASS libraries)
chmod +x download-deps.sh
./download-deps.sh

# Open in Xcode and build
open FastPlay.xcodeproj
```

## Dependencies

The `download-deps.sh` script automatically downloads:

### BASS Audio Library
- **BASS** - Core audio library
- **BASS_FX** - Tempo/pitch effects
- **BASSFLAC** - FLAC support
- **BASSOPUS** - Opus support
- **BASSMIDI** - MIDI support
- **BASSENC** - Recording/encoding
- **BASSENC_MP3/OGG/FLAC** - Encoding formats
- And more format plugins (AAC, ALAC, APE, HLS, WavPack)

Note: SoundTouch is built into BASS_FX, no separate library needed.

### yt-dlp (Optional)

For YouTube functionality, install yt-dlp via Homebrew:

```bash
brew install yt-dlp
```

## Building

1. Run `./download-deps.sh` to download dependencies
2. Open `FastPlay.xcodeproj` in Xcode
3. Build (Cmd+B)

## Project Structure

```
Mac/
├── FastPlay.xcodeproj/          # Xcode project
├── FastPlay/
│   ├── App/                     # Application entry point
│   │   ├── AppDelegate.swift
│   │   └── main.swift
│   ├── Audio/                   # Audio engine (BASS wrapper)
│   │   └── AudioEngine.swift
│   ├── Models/                  # Data models
│   │   └── Models.swift
│   ├── Services/                # Core services
│   │   ├── AccessibilityManager.swift
│   │   ├── DatabaseManager.swift
│   │   ├── HotkeyManager.swift
│   │   ├── PlaylistManager.swift
│   │   └── SettingsManager.swift
│   ├── UI/                      # User interface
│   │   ├── MainWindow/
│   │   └── StatusBar/
│   ├── Resources/               # XIBs, assets
│   └── Supporting/              # Bridging header, Info.plist
└── Frameworks/                  # BASS dylibs
```

## Keyboard Shortcuts

These match the Windows version:

| Key | Action |
|-----|--------|
| Space | Play/Pause |
| X | Play |
| C | Pause |
| V | Stop |
| Z | Previous Track |
| B | Next Track |
| H | Toggle Shuffle |
| J | Jump to Time |
| Left Arrow | Seek Backward |
| Right Arrow | Seek Forward |
| Up Arrow | Increase Effect |
| Down Arrow | Decrease Effect |
| [ | Previous Effect |
| ] | Next Effect |
| Home | Beginning |
| 1-0 | Read Tag Info |
| Cmd+O | Open File |
| Cmd+Shift+O | Add Folder |
| Cmd+P | Playlist |
| Cmd+U | Open URL |
| Cmd+Y | YouTube |
| Cmd+R | Radio |
| Cmd+Shift+P | Podcasts |
| Cmd+S | Scheduler |
| Cmd+, | Preferences |

## Configuration

Settings are stored in `~/Library/Application Support/FastPlay/FastPlay.ini` using the same INI format as Windows for potential cross-platform compatibility.

Database (SQLite) is stored at `~/Library/Application Support/FastPlay/FastPlay.db`.

## Accessibility

FastPlay uses `NSAccessibility.post(notification:)` for screen reader announcements, providing full VoiceOver support.

## License

See main project LICENSE file.
