//
//  MainWindowController.swift
//  FastPlay
//
//  Main application window controller
//

import AppKit

class MainWindowController: NSWindowController {

    // MARK: - UI Elements

    private var statusTextField: NSTextField!
    private var positionLabel: NSTextField!
    private var volumeLabel: NSTextField!
    private var stateLabel: NSTextField!

    // Current stream title (for URL streams)
    private var streamTitle: String?

    // MARK: - Initialization

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 150),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "FastPlay"
        window.center()
        window.minSize = NSSize(width: 400, height: 100)
        window.isReleasedWhenClosed = false

        self.init(window: window)

        setupUI()
        setupMenuShortcuts()
        setupMetadataCallback()
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUpdateWindowTitle),
            name: NSNotification.Name("UpdateWindowTitle"),
            object: nil
        )
    }

    @objc private func handleUpdateWindowTitle() {
        // Update window title based on current setting
        if SettingsManager.shared.showTitleInWindow {
            // Priority: tags (artist - title) > filename
            if let displayTitle = AudioEngine.shared.getDisplayTitle() {
                window?.title = "FastPlay - \(displayTitle)"
            } else if let trackName = PlaylistManager.shared.currentTrackName {
                window?.title = "FastPlay - \(trackName)"
            } else {
                window?.title = "FastPlay"
            }
        } else {
            window?.title = "FastPlay"
        }
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - UI Setup

    private func setupUI() {
        guard let window = window, let contentView = window.contentView else { return }

        // Create status bar-like area at bottom
        let statusBar = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 30))
        statusBar.translatesAutoresizingMaskIntoConstraints = false
        statusBar.wantsLayer = true
        statusBar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        contentView.addSubview(statusBar)

        // Position label (left)
        positionLabel = NSTextField(labelWithString: "0:00 / 0:00")
        positionLabel.translatesAutoresizingMaskIntoConstraints = false
        positionLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        positionLabel.setAccessibilityLabel("Position")
        statusBar.addSubview(positionLabel)

        // Volume label (center)
        volumeLabel = NSTextField(labelWithString: "Vol: 100%")
        volumeLabel.translatesAutoresizingMaskIntoConstraints = false
        volumeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        volumeLabel.setAccessibilityLabel("Volume")
        statusBar.addSubview(volumeLabel)

        // State label (right)
        stateLabel = NSTextField(labelWithString: "Stopped")
        stateLabel.translatesAutoresizingMaskIntoConstraints = false
        stateLabel.font = NSFont.systemFont(ofSize: 12)
        stateLabel.setAccessibilityLabel("Playback state")
        statusBar.addSubview(stateLabel)

        // Main content area
        statusTextField = NSTextField(labelWithString: "No file loaded")
        statusTextField.translatesAutoresizingMaskIntoConstraints = false
        statusTextField.font = NSFont.systemFont(ofSize: 14)
        statusTextField.alignment = .center
        statusTextField.lineBreakMode = .byTruncatingMiddle
        statusTextField.setAccessibilityLabel("Now playing")
        contentView.addSubview(statusTextField)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Status bar at bottom
            statusBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 30),

            // Position label (left)
            positionLabel.leadingAnchor.constraint(equalTo: statusBar.leadingAnchor, constant: 10),
            positionLabel.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),
            positionLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),

            // Volume label (center)
            volumeLabel.centerXAnchor.constraint(equalTo: statusBar.centerXAnchor),
            volumeLabel.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),

            // State label (right)
            stateLabel.trailingAnchor.constraint(equalTo: statusBar.trailingAnchor, constant: -10),
            stateLabel.centerYAnchor.constraint(equalTo: statusBar.centerYAnchor),

            // Status text field (main area)
            statusTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            statusTextField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            statusTextField.bottomAnchor.constraint(equalTo: statusBar.topAnchor, constant: -20),
        ])

        // Set accessibility
        window.setAccessibilityLabel("FastPlay")
        window.setAccessibilityRole(.window)
    }

    private var eventMonitor: Any?

    private func setupMenuShortcuts() {
        // Use a local event monitor to intercept key events before they cause beeps
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Only handle events when our window is key
            guard let self = self, self.window?.isKeyWindow == true else {
                return event
            }
            if self.handleKeyDown(event) {
                return nil  // Consume the event
            }
            return event  // Let unhandled events through
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    /// Handle key event, returns true if handled
    private func handleKeyDown(_ event: NSEvent) -> Bool {
        // Check modifiers, ignoring caps lock and function keys
        let significantFlags: NSEvent.ModifierFlags = [.command, .shift, .control, .option]
        let flags = event.modifierFlags.intersection(significantFlags)
        let hasCmd = flags.contains(.command)
        let hasShift = flags.contains(.shift)
        let hasCtrl = flags.contains(.control)
        let _ = flags.contains(.option)  // hasOption - reserved for future use
        let noMods = flags.isEmpty

        // Cmd+Shift shortcuts
        if hasCmd && hasShift && !hasCtrl {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "e":
                let elapsed = AudioEngine.shared.currentPosition
                AccessibilityManager.announceTime(elapsed)
                return true
            case "r":
                let duration = AudioEngine.shared.duration
                let elapsed = AudioEngine.shared.currentPosition
                if duration > 0 {
                    AccessibilityManager.announceTime(duration - elapsed)
                }
                return true
            case "t":
                let duration = AudioEngine.shared.duration
                if duration > 0 {
                    AccessibilityManager.announceTime(duration)
                }
                return true
            default:
                break
            }
        }

        // Cmd shortcuts (volume, effect min/max)
        if hasCmd && !hasShift && !hasCtrl {
            switch event.keyCode {
            case 126:  // Cmd+Up = Volume Up
                AudioEngine.shared.adjustVolume(by: SettingsManager.shared.volumeStep)
                return true
            case 125:  // Cmd+Down = Volume Down
                AudioEngine.shared.adjustVolume(by: -SettingsManager.shared.volumeStep)
                return true
            case 115:  // Cmd+Home = Effect to minimum
                setCurrentEffectToExtreme(minimum: true)
                return true
            case 119:  // Cmd+End = Effect to maximum
                setCurrentEffectToExtreme(minimum: false)
                return true
            default:
                break
            }
        }

        // Shift + number keys = View tag in dialog
        if hasShift && !hasCmd && !hasCtrl {
            if let chars = event.charactersIgnoringModifiers, chars.count == 1 {
                if let num = Int(chars), num >= 0 && num <= 9 {
                    viewTagInfo(index: num == 0 ? 10 : num)
                    return true
                }
            }
        }

        // No modifier shortcuts (matching Windows accelerators exactly)
        if noMods {
            // First check by keyCode for special keys (more reliable)
            switch event.keyCode {
            case 49:   // Space = Play/Pause
                AudioEngine.shared.togglePlayPause()
                return true
            case 33:   // [ = Previous effect
                cycleEffect(forward: false)
                return true
            case 30:   // ] = Next effect
                cycleEffect(forward: true)
                return true
            case 43:   // , = Decrease seek amount
                cycleSeekAmount(forward: false)
                return true
            case 47:   // . = Increase seek amount
                cycleSeekAmount(forward: true)
                return true
            case 123:  // Left arrow = Seek Back
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
                return true
            case 124:  // Right arrow = Seek Forward
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
                return true
            case 125:  // Down arrow = Effect Down
                adjustCurrentEffect(increase: false)
                return true
            case 126:  // Up arrow = Effect Up
                adjustCurrentEffect(increase: true)
                return true
            case 115:  // Home = Beginning
                AudioEngine.shared.seek(to: 0)
                return true
            case 51:   // Backspace = Reset current effect
                resetCurrentEffect()
                return true
            default:
                break
            }

            // Then check by character for letter keys
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "x":
                AudioEngine.shared.play()
                return true
            case "c":
                AudioEngine.shared.pause()
                return true
            case "v":
                AudioEngine.shared.stop()
                return true
            case "z":
                PlaylistManager.shared.previous()
                return true
            case "b":
                PlaylistManager.shared.next()
                return true
            case "h":
                SettingsManager.shared.shuffle.toggle()
                let state = SettingsManager.shared.shuffle ? "Shuffle on" : "Shuffle off"
                AccessibilityManager.announce(state)
                return true
            case "e":
                PlaylistManager.shared.toggleRepeatMode()
                return true
            case "j":
                showJumpToTimeDialog()
                return true
            case "m":
                addBookmark()
                return true
            case "r":
                toggleRecording()
                return true
            case "u":
                AudioEngine.shared.toggleMute()
                return true
            case "a":
                showAudioDeviceMenu()
                return true
            default:
                break
            }

            // Handle number keys 1-0 for tag info (speak)
            if let chars = event.charactersIgnoringModifiers, chars.count == 1 {
                if let num = Int(chars), num >= 0 && num <= 9 {
                    speakTagInfo(index: num == 0 ? 10 : num)
                    return true
                }
            }
        }

        return false
    }

    private func setupMetadataCallback() {
        AudioEngine.shared.onMetadataChange = { [weak self] title in
            self?.streamTitle = title
            self?.updateUI()
        }

        AudioEngine.shared.onTrackLoad = { [weak self] in
            // Clear stream title when a new track loads (so file tags show instead of stale stream metadata)
            self?.streamTitle = nil
            self?.updateUI()
        }
    }

    // MARK: - UI Updates

    func updateUI() {
        // Update position
        let position = AudioEngine.shared.currentPosition
        let duration = AudioEngine.shared.duration

        let posStr: String
        if duration > 0 {
            posStr = "\(AccessibilityManager.formatTimeDisplay(position)) / \(AccessibilityManager.formatTimeDisplay(duration))"
        } else if AudioEngine.shared.isLiveStream {
            posStr = AccessibilityManager.formatTimeDisplay(position)
        } else {
            posStr = "0:00 / 0:00"
        }
        positionLabel.stringValue = posStr

        // Update volume
        let vol = Int(AudioEngine.shared.currentVolume * 100)
        volumeLabel.stringValue = "Vol: \(vol)%"

        // Update state
        var stateStr: String
        switch AudioEngine.shared.state {
        case .playing:
            stateStr = "Playing"
        case .paused:
            stateStr = "Paused"
        case .stalled:
            stateStr = "Buffering"
        case .stopped:
            stateStr = "Stopped"
        }

        // Add bitrate if available
        let bitrate = AudioEngine.shared.getCurrentBitrate()
        if bitrate > 0 {
            if AudioEngine.shared.isVBR {
                stateStr += " | ~\(bitrate) kbps VBR"
            } else {
                stateStr += " | \(bitrate) kbps"
            }
        }

        stateLabel.stringValue = stateStr

        // Update track name - priority: stream title > tags (artist - title) > filename
        let trackName: String
        if let title = streamTitle, !title.isEmpty {
            // Stream metadata (Shoutcast/Icecast)
            trackName = title
        } else if let displayTitle = AudioEngine.shared.getDisplayTitle() {
            // Tags from file (Artist - Title format)
            trackName = displayTitle
        } else if let name = PlaylistManager.shared.currentTrackName {
            // Fallback to filename
            trackName = name
        } else {
            trackName = "No file loaded"
        }
        statusTextField.stringValue = trackName

        // Update window title if enabled
        if SettingsManager.shared.showTitleInWindow {
            if PlaylistManager.shared.currentTrackPath != nil {
                window?.title = "FastPlay - \(trackName)"
            } else {
                window?.title = "FastPlay"
            }
        }
    }

    // MARK: - Effects

    /// Unified parameter type for effects cycler
    /// Indices 0-3 are stream effects (Volume, Pitch, Tempo, Rate)
    /// Indices 100+ are DSP parameters (100 + DSPParamId.rawValue)
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

    /// Get list of available parameters (matching Windows GetAvailableParams)
    /// Returns both stream effects and DSP parameters based on what's enabled
    private func getAvailableParams() -> [ParamType] {
        var params: [ParamType] = []

        // Stream effects (Volume, Pitch, Tempo, Rate)
        for i in 0..<4 {
            if SettingsManager.shared.effectEnabled[i] {
                params.append(.streamEffect(i))
            }
        }

        // DSP effect parameters - check if each DSP effect is enabled
        // Access SettingsManager directly each time (don't cache the array)
        let reverbAlgorithm = SettingsManager.shared.reverbAlgorithm

        // Iterate through all DSP parameter definitions
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

    private func resetCurrentEffect() {
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
            // Block tempo/rate reset for live streams
            if AudioEngine.shared.isLiveStream {
                if idx == EffectType.tempo.rawValue || idx == EffectType.rate.rawValue {
                    AccessibilityManager.announce("Not available for live streams")
                    return
                }
            }

            switch EffectType(rawValue: idx) {
            case .volume:
                AudioEngine.shared.setVolume(1.0)
            case .pitch:
                AudioEngine.shared.pitchValue = 0
            case .tempo:
                AudioEngine.shared.tempoValue = 0
            case .rate:
                AudioEngine.shared.rateValue = 1.0
            case .none:
                break
            }
            announceCurrentEffect()

        case .dspParam(let paramId):
            DSPEffectsManager.shared.resetParam(paramId)
            // Announcement is handled by DSPEffectsManager.resetParam
        }
    }

    private func setCurrentEffectToExtreme(minimum: Bool) {
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
            // Block tempo/rate for live streams
            if AudioEngine.shared.isLiveStream {
                if idx == EffectType.tempo.rawValue || idx == EffectType.rate.rawValue {
                    AccessibilityManager.announce("Not available for live streams")
                    return
                }
            }

            switch EffectType(rawValue: idx) {
            case .volume:
                let maxVol = SettingsManager.shared.allowAmplify ? AudioEngine.maxVolumeAmplify : AudioEngine.maxVolumeNormal
                AudioEngine.shared.setVolume(minimum ? 0 : maxVol)
            case .pitch:
                AudioEngine.shared.pitchValue = minimum ? -12 : 12
            case .tempo:
                AudioEngine.shared.tempoValue = minimum ? -50 : 100
            case .rate:
                AudioEngine.shared.rateValue = minimum ? 0.5 : 2.0
            case .none:
                break
            }
            announceCurrentEffect()

        case .dspParam(let paramId):
            DSPEffectsManager.shared.setParamToExtreme(paramId, minimum: minimum)
            // Announcement is handled by DSPEffectsManager
        }
    }

    /// Announce current effect value in Windows format
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
            message = DSPEffectsManager.announcementText(for: paramId)
        }

        AccessibilityManager.announce(message)
    }

    // MARK: - Seek Amount

    private func cycleSeekAmount(forward: Bool) {
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

        // Move through available amounts (no wrapping)
        let direction = forward ? 1 : -1
        var newIndex = settings.currentSeekIndex
        for _ in 0..<seekAmountTotal {
            newIndex += direction
            // Stop at boundaries instead of wrapping
            if newIndex >= seekAmountTotal || newIndex < 0 {
                break
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

    // MARK: - Bookmarks

    private func addBookmark() {
        guard let filepath = PlaylistManager.shared.currentTrackPath else {
            AccessibilityManager.announce("No file loaded")
            return
        }

        let position = AudioEngine.shared.currentPosition

        // Generate bookmark name: filename @ time
        let filename = URL(fileURLWithPath: filepath).deletingPathExtension().lastPathComponent
        let timeStr = AccessibilityManager.formatTimeDisplay(position)
        let name = "\(filename) @ \(timeStr)"

        // Save to database
        let bookmarkId = DatabaseManager.shared.addBookmark(name: name, filepath: filepath, position: position)

        if bookmarkId > 0 {
            AccessibilityManager.announce("Bookmark added at \(timeStr)")
        } else {
            AccessibilityManager.announce("Failed to add bookmark")
        }
    }

    func showBookmarksWindow() {
        BookmarksWindowController.shared.show()
    }

    // MARK: - Recording

    private func toggleRecording() {
        RecordingManager.shared.toggleRecording()
    }

    // MARK: - Tag Info

    private func speakTagInfo(index: Int) {
        // 1=Title, 2=Artist, 3=Album, 4=Year, 5=Track, 6=Genre, 7=Comment, 8=Bitrate, 9=Duration, 10=Filename
        guard let path = PlaylistManager.shared.currentTrackPath else {
            AccessibilityManager.announce("No file loaded")
            return
        }

        let tags = AudioEngine.shared.getCurrentTags()
        var info: String

        switch index {
        case 1:
            info = tags["title"] ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        case 2:
            info = tags["artist"] ?? "Unknown artist"
        case 3:
            info = tags["album"] ?? "Unknown album"
        case 4:
            info = tags["year"] ?? "Unknown year"
        case 5:
            info = tags["track"] ?? "Unknown track"
        case 6:
            info = tags["genre"] ?? "Unknown genre"
        case 7:
            info = tags["comment"] ?? "No comment"
        case 8:
            let bitrate = AudioEngine.shared.getCurrentBitrate()
            if bitrate > 0 {
                info = "\(bitrate) kbps"
                if AudioEngine.shared.isVBR {
                    info += " VBR"
                }
            } else {
                info = "Unknown bitrate"
            }
        case 9:
            let duration = AudioEngine.shared.duration
            if duration > 0 {
                info = AccessibilityManager.formatTimeDisplay(duration)
            } else {
                info = "Unknown duration"
            }
        case 10:
            info = URL(fileURLWithPath: path).lastPathComponent
        default:
            info = "Unknown"
        }

        AccessibilityManager.announce(info)
    }

    private func viewTagInfo(index: Int) {
        // Show tag in a dialog instead of speaking
        guard let path = PlaylistManager.shared.currentTrackPath else { return }

        let tags = AudioEngine.shared.getCurrentTags()
        var title: String
        var info: String

        switch index {
        case 1:
            title = "Title"
            info = tags["title"] ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        case 2:
            title = "Artist"
            info = tags["artist"] ?? "Unknown"
        case 3:
            title = "Album"
            info = tags["album"] ?? "Unknown"
        case 4:
            title = "Year"
            info = tags["year"] ?? "Unknown"
        case 5:
            title = "Track"
            info = tags["track"] ?? "Unknown"
        case 6:
            title = "Genre"
            info = tags["genre"] ?? "Unknown"
        case 7:
            title = "Comment"
            info = tags["comment"] ?? "None"
        case 8:
            title = "Bitrate"
            let bitrate = AudioEngine.shared.getCurrentBitrate()
            info = bitrate > 0 ? "\(bitrate) kbps" : "Unknown"
        case 9:
            title = "Duration"
            let duration = AudioEngine.shared.duration
            info = duration > 0 ? AccessibilityManager.formatTimeDisplay(duration) : "Unknown"
        case 10:
            title = "Filename"
            info = URL(fileURLWithPath: path).lastPathComponent
        default:
            return
        }

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Dialogs

    private func showJumpToTimeDialog() {
        let alert = NSAlert()
        alert.messageText = "Jump to Time"
        alert.informativeText = "Enter time (MM:SS or HH:MM:SS):"
        alert.addButton(withTitle: "Jump")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = "0:00"
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let timeStr = textField.stringValue
            if let seconds = parseTimeString(timeStr) {
                AudioEngine.shared.seek(to: seconds)
            }
        }
    }

    private func showAudioDeviceMenu() {
        let devices = AudioEngine.shared.getAvailableDevices()
        guard !devices.isEmpty else {
            AccessibilityManager.announce("No audio devices available")
            return
        }

        let menu = NSMenu(title: "Audio Devices")
        let currentDevice = AudioEngine.shared.currentDeviceIndex

        // Add "Default" option
        let defaultItem = NSMenuItem(title: "Default", action: #selector(selectAudioDevice(_:)), keyEquivalent: "")
        defaultItem.target = self
        defaultItem.tag = -1
        defaultItem.state = (currentDevice == -1) ? .on : .off
        menu.addItem(defaultItem)

        menu.addItem(NSMenuItem.separator())

        // Add each device
        for device in devices {
            let item = NSMenuItem(title: device.name, action: #selector(selectAudioDevice(_:)), keyEquivalent: "")
            item.target = self
            item.tag = device.index
            item.state = (currentDevice == device.index) ? .on : .off
            menu.addItem(item)
        }

        // Show the menu at mouse location or window center
        if let window = self.window {
            let location = NSEvent.mouseLocation
            let windowPoint = window.convertPoint(fromScreen: location)
            menu.popUp(positioning: nil, at: windowPoint, in: window.contentView)
        }
    }

    @objc private func selectAudioDevice(_ sender: NSMenuItem) {
        let deviceIndex = sender.tag
        if AudioEngine.shared.changeDevice(deviceIndex) {
            let deviceName = deviceIndex == -1 ? "Default" : sender.title
            AccessibilityManager.announce("Audio device: \(deviceName)")
        } else {
            AccessibilityManager.announce("Failed to change audio device")
        }
    }

    private func parseTimeString(_ str: String) -> Double? {
        let parts = str.split(separator: ":")
        guard !parts.isEmpty else { return nil }

        var seconds: Double = 0

        if parts.count == 3 {
            // HH:MM:SS
            guard let h = Double(parts[0]), let m = Double(parts[1]), let s = Double(parts[2]) else { return nil }
            seconds = h * 3600 + m * 60 + s
        } else if parts.count == 2 {
            // MM:SS
            guard let m = Double(parts[0]), let s = Double(parts[1]) else { return nil }
            seconds = m * 60 + s
        } else {
            // Just seconds
            guard let s = Double(parts[0]) else { return nil }
            seconds = s
        }

        return seconds
    }

    // MARK: - Window Delegate

    override func windowDidLoad() {
        super.windowDidLoad()
        updateUI()
    }
}

