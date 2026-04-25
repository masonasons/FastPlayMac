//
//  PreferencesWindowController.swift
//  FastPlay
//
//  Preferences window with tabbed interface matching Windows version
//

import AppKit
import AVFoundation
import Carbon.HIToolbox
import UniformTypeIdentifiers

/// Custom text field that captures key combinations for hotkeys
class HotkeyCaptureField: NSTextField {
    var capturedKeyCode: UInt16 = 0
    var capturedModifiers: NSEvent.ModifierFlags = []

    override var acceptsFirstResponder: Bool { return true }

    override func keyDown(with event: NSEvent) {
        // Capture the key
        capturedKeyCode = event.keyCode
        capturedModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])

        // Format the key string
        var keyString = ""

        // Add modifier symbols
        if capturedModifiers.contains(.control) { keyString += "⌃" }
        if capturedModifiers.contains(.option) { keyString += "⌥" }
        if capturedModifiers.contains(.shift) { keyString += "⇧" }
        if capturedModifiers.contains(.command) { keyString += "⌘" }

        // Add the key character
        if let keyChar = HotkeyCaptureField.keyCodeToString(event.keyCode) {
            keyString += keyChar
        }

        self.stringValue = keyString
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Capture command key combinations that would normally be handled as key equivalents
        if event.modifierFlags.contains(.command) {
            keyDown(with: event)
            return true
        }
        return false
    }

    /// Convert key code to displayable string
    static func keyCodeToString(_ keyCode: UInt16) -> String? {
        switch Int(keyCode) {
        // Letters
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        // Numbers
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        // Function keys
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        // Special keys
        case kVK_Space: return "Space"
        case kVK_Return: return "Return"
        case kVK_Tab: return "Tab"
        case kVK_Delete: return "Delete"
        case kVK_ForwardDelete: return "Fwd Del"
        case kVK_Escape: return "Esc"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "PgUp"
        case kVK_PageDown: return "PgDn"
        // Punctuation
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Grave: return "`"
        default: return nil
        }
    }
}

class PreferencesWindowController: NSWindowController {

    // MARK: - Singleton

    static let shared = PreferencesWindowController()

    // MARK: - UI Elements

    private var tabView: NSTabView!

    // MARK: - Initialization

    private var eventMonitor: Any?

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Preferences"
        window.center()

        self.init(window: window)
        setupUI()
        setupKeyboardHandling()
    }

    private func setupKeyboardHandling() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.window?.isKeyWindow == true else { return event }

            // Handle Cmd+W to close window
            if event.modifierFlags.contains(.command) && event.keyCode == UInt16(kVK_ANSI_W) {
                self.window?.close()
                return nil
            }

            return event
        }
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func setupUI() {
        guard let window = window, let contentView = window.contentView else { return }

        // Create tab view
        tabView = NSTabView(frame: contentView.bounds)
        tabView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabView)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])

        // Add tabs (matching Windows order)
        addPlaybackTab()
        addRecordingTab()
        addDownloadsTab()
        addSpeechTab()
        addMovementTab()
        addEffectsTab()  // Combined stream effects + DSP effects
        addAdvancedTab()
        addHotkeysTab()
        addSoundTouchTab()
        addYouTubeTab()
        addMIDITab()
    }

    // MARK: - Playback Tab

    private func addPlaybackTab() {
        let item = NSTabViewItem(identifier: "playback")
        item.label = "Playback"

        let view = NSView()

        // Audio device
        let deviceLabel = NSTextField(labelWithString: "Output device:")
        deviceLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(deviceLabel)

        let deviceCombo = NSPopUpButton(frame: .zero, pullsDown: false)
        deviceCombo.translatesAutoresizingMaskIntoConstraints = false
        deviceCombo.tag = 700
        populateAudioDevices(deviceCombo)
        deviceCombo.target = self
        deviceCombo.action = #selector(audioDeviceChanged(_:))
        view.addSubview(deviceCombo)

        // Volume Step
        let volStepLabel = NSTextField(labelWithString: "Volume Step:")
        volStepLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(volStepLabel)

        let volStepSlider = NSSlider(value: Double(SettingsManager.shared.volumeStep * 100),
                                      minValue: 1, maxValue: 10,
                                      target: self, action: #selector(volumeStepChanged(_:)))
        volStepSlider.translatesAutoresizingMaskIntoConstraints = false
        volStepSlider.tag = 1
        view.addSubview(volStepSlider)

        let volStepValue = NSTextField(labelWithString: "\(Int(SettingsManager.shared.volumeStep * 100))%")
        volStepValue.translatesAutoresizingMaskIntoConstraints = false
        volStepValue.tag = 101
        view.addSubview(volStepValue)

        // Allow Amplification
        let ampCheck = NSButton(checkboxWithTitle: "Allow amplification (volume > 100%)",
                                target: self, action: #selector(allowAmplifyChanged(_:)))
        ampCheck.translatesAutoresizingMaskIntoConstraints = false
        ampCheck.state = SettingsManager.shared.allowAmplify ? .on : .off
        view.addSubview(ampCheck)

        // Remember playback state on exit
        let rememberStateCheck = NSButton(checkboxWithTitle: "Remember playback state on exit",
                                          target: self, action: #selector(rememberStateChanged(_:)))
        rememberStateCheck.translatesAutoresizingMaskIntoConstraints = false
        rememberStateCheck.state = SettingsManager.shared.rememberState ? .on : .off
        view.addSubview(rememberStateCheck)

        // Save position if longer than X minutes
        let posMinLabel = NSTextField(labelWithString: "Save position if longer than:")
        posMinLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(posMinLabel)

        let posMinCombo = NSPopUpButton(frame: .zero, pullsDown: false)
        posMinCombo.translatesAutoresizingMaskIntoConstraints = false
        posMinCombo.addItems(withTitles: ["Disabled", "5 minutes", "10 minutes", "15 minutes", "30 minutes", "60 minutes"])
        let posMinValues = [0, 5, 10, 15, 30, 60]
        if let idx = posMinValues.firstIndex(of: SettingsManager.shared.rememberPosMinutes) {
            posMinCombo.selectItem(at: idx)
        } else {
            posMinCombo.selectItem(at: 0)
        }
        posMinCombo.target = self
        posMinCombo.action = #selector(posMinutesChanged(_:))
        view.addSubview(posMinCombo)

        // Auto-advance to next track
        let autoAdvanceCheck = NSButton(checkboxWithTitle: "Auto-advance to next track",
                                        target: self, action: #selector(autoAdvanceChanged(_:)))
        autoAdvanceCheck.translatesAutoresizingMaskIntoConstraints = false
        autoAdvanceCheck.state = SettingsManager.shared.autoAdvance ? .on : .off
        view.addSubview(autoAdvanceCheck)

        // Show track name in window title
        let showTitleCheck = NSButton(checkboxWithTitle: "Show track name in window title",
                                      target: self, action: #selector(showTitleChanged(_:)))
        showTitleCheck.translatesAutoresizingMaskIntoConstraints = false
        showTitleCheck.state = SettingsManager.shared.showTitleInWindow ? .on : .off
        view.addSubview(showTitleCheck)

        // Load all files in folder when opening single file
        let loadFolderCheck = NSButton(checkboxWithTitle: "Load all files in folder when opening single file",
                                       target: self, action: #selector(loadFolderChanged(_:)))
        loadFolderCheck.translatesAutoresizingMaskIntoConstraints = false
        loadFolderCheck.state = SettingsManager.shared.loadFolder ? .on : .off
        view.addSubview(loadFolderCheck)

        NSLayoutConstraint.activate([
            deviceLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            deviceLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            deviceCombo.centerYAnchor.constraint(equalTo: deviceLabel.centerYAnchor),
            deviceCombo.leadingAnchor.constraint(equalTo: deviceLabel.trailingAnchor, constant: 10),
            deviceCombo.widthAnchor.constraint(equalToConstant: 280),

            volStepLabel.topAnchor.constraint(equalTo: deviceLabel.bottomAnchor, constant: 20),
            volStepLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            volStepSlider.centerYAnchor.constraint(equalTo: volStepLabel.centerYAnchor),
            volStepSlider.leadingAnchor.constraint(equalTo: volStepLabel.trailingAnchor, constant: 10),
            volStepSlider.widthAnchor.constraint(equalToConstant: 150),

            volStepValue.centerYAnchor.constraint(equalTo: volStepSlider.centerYAnchor),
            volStepValue.leadingAnchor.constraint(equalTo: volStepSlider.trailingAnchor, constant: 10),

            ampCheck.topAnchor.constraint(equalTo: volStepLabel.bottomAnchor, constant: 20),
            ampCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            rememberStateCheck.topAnchor.constraint(equalTo: ampCheck.bottomAnchor, constant: 10),
            rememberStateCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            posMinLabel.topAnchor.constraint(equalTo: rememberStateCheck.bottomAnchor, constant: 10),
            posMinLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),

            posMinCombo.centerYAnchor.constraint(equalTo: posMinLabel.centerYAnchor),
            posMinCombo.leadingAnchor.constraint(equalTo: posMinLabel.trailingAnchor, constant: 10),
            posMinCombo.widthAnchor.constraint(equalToConstant: 120),

            autoAdvanceCheck.topAnchor.constraint(equalTo: posMinLabel.bottomAnchor, constant: 10),
            autoAdvanceCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            showTitleCheck.topAnchor.constraint(equalTo: autoAdvanceCheck.bottomAnchor, constant: 10),
            showTitleCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            loadFolderCheck.topAnchor.constraint(equalTo: showTitleCheck.bottomAnchor, constant: 10),
            loadFolderCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
        ])

        item.view = view
        tabView.addTabViewItem(item)
    }

    // MARK: - Effects Tab (Combined Stream Effects + DSP Effects - matches Windows)

    private func addEffectsTab() {
        let item = NSTabViewItem(identifier: "effects")
        item.label = "Effects"

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        // === Stream Effects Section ===
        let streamLabel = NSTextField(labelWithString: "Stream Effects (cycle with [ ] keys, adjust with Up/Down):")
        streamLabel.translatesAutoresizingMaskIntoConstraints = false
        streamLabel.font = NSFont.boldSystemFont(ofSize: 12)
        view.addSubview(streamLabel)

        let effectNames = ["Volume", "Pitch", "Tempo", "Rate"]
        var lastAnchor: NSLayoutYAxisAnchor = streamLabel.bottomAnchor

        for (index, name) in effectNames.enumerated() {
            let check = NSButton(checkboxWithTitle: name,
                                 target: self, action: #selector(effectEnabledChanged(_:)))
            check.translatesAutoresizingMaskIntoConstraints = false
            check.tag = index
            check.state = SettingsManager.shared.effectEnabled[index] ? .on : .off
            view.addSubview(check)

            NSLayoutConstraint.activate([
                check.topAnchor.constraint(equalTo: lastAnchor, constant: index == 0 ? 10 : 5),
                check.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            ])
            lastAnchor = check.bottomAnchor
        }

        // Rate step mode
        let rateStepLabel = NSTextField(labelWithString: "Rate step mode:")
        rateStepLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rateStepLabel)

        let rateStepCombo = NSPopUpButton(frame: .zero, pullsDown: false)
        rateStepCombo.translatesAutoresizingMaskIntoConstraints = false
        rateStepCombo.addItems(withTitles: ["0.01x steps", "Semitone-based"])
        rateStepCombo.selectItem(at: SettingsManager.shared.rateStepMode)
        rateStepCombo.target = self
        rateStepCombo.action = #selector(rateStepModeChanged(_:))
        view.addSubview(rateStepCombo)

        NSLayoutConstraint.activate([
            rateStepLabel.topAnchor.constraint(equalTo: lastAnchor, constant: 15),
            rateStepLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            rateStepCombo.centerYAnchor.constraint(equalTo: rateStepLabel.centerYAnchor),
            rateStepCombo.leadingAnchor.constraint(equalTo: rateStepLabel.trailingAnchor, constant: 10),
            rateStepCombo.widthAnchor.constraint(equalToConstant: 130),
        ])

        // === DSP Effects Section ===
        let dspLabel = NSTextField(labelWithString: "DSP Effects:")
        dspLabel.translatesAutoresizingMaskIntoConstraints = false
        dspLabel.font = NSFont.boldSystemFont(ofSize: 12)
        view.addSubview(dspLabel)

        NSLayoutConstraint.activate([
            dspLabel.topAnchor.constraint(equalTo: rateStepLabel.bottomAnchor, constant: 25),
            dspLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
        ])

        // Reverb (algorithm selector, not checkbox)
        let reverbLabel = NSTextField(labelWithString: "Reverb:")
        reverbLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(reverbLabel)

        let reverbCombo = NSPopUpButton(frame: .zero, pullsDown: false)
        reverbCombo.translatesAutoresizingMaskIntoConstraints = false
        reverbCombo.addItems(withTitles: ["Off", "Freeverb", "DX8 Reverb", "I3DL2 Reverb"])
        reverbCombo.selectItem(at: SettingsManager.shared.reverbAlgorithm)
        reverbCombo.target = self
        reverbCombo.action = #selector(reverbAlgorithmChanged(_:))
        view.addSubview(reverbCombo)

        NSLayoutConstraint.activate([
            reverbLabel.topAnchor.constraint(equalTo: dspLabel.bottomAnchor, constant: 10),
            reverbLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            reverbCombo.centerYAnchor.constraint(equalTo: reverbLabel.centerYAnchor),
            reverbCombo.leadingAnchor.constraint(equalTo: reverbLabel.trailingAnchor, constant: 10),
            reverbCombo.widthAnchor.constraint(equalToConstant: 130),
        ])

        lastAnchor = reverbLabel.bottomAnchor

        // Other DSP effects (checkboxes)
        let dspEffects = ["Echo", "3-Band EQ", "Compressor", "Stereo Width", "Center Cancel", "Convolution Reverb", "Spatial Audio (3D)"]
        // Note: Reverb (index 0) is handled by combo above, so these start at index 1
        for (index, name) in dspEffects.enumerated() {
            let check = NSButton(checkboxWithTitle: name,
                                 target: self, action: #selector(dspEffectChanged(_:)))
            check.translatesAutoresizingMaskIntoConstraints = false
            check.tag = 201 + index  // 201=Echo … 206=Convolution, 207=Spatial Audio
            let dspIndex = index + 1  // Skip reverb (index 0)
            check.state = (dspIndex < SettingsManager.shared.dspEffectEnabled.count && SettingsManager.shared.dspEffectEnabled[dspIndex]) ? .on : .off
            view.addSubview(check)

            NSLayoutConstraint.activate([
                check.topAnchor.constraint(equalTo: lastAnchor, constant: 8),
                check.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            ])
            lastAnchor = check.bottomAnchor
        }

        // Add bottom constraint for scroll content
        NSLayoutConstraint.activate([
            streamLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 15),
            streamLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            lastAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20),
        ])

        scrollView.documentView = view
        view.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor).isActive = true

        item.view = scrollView
        tabView.addTabViewItem(item)
    }

    // MARK: - Downloads Tab

    private func addDownloadsTab() {
        let item = NSTabViewItem(identifier: "downloads")
        item.label = "Downloads"

        let view = NSView()

        // Downloads folder
        let pathLabel = NSTextField(labelWithString: "Downloads folder:")
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pathLabel)

        let pathField = NSTextField()
        pathField.translatesAutoresizingMaskIntoConstraints = false
        pathField.stringValue = SettingsManager.shared.downloadPath.isEmpty ? "(Default: ~/Music/FastPlay Downloads)" : SettingsManager.shared.downloadPath
        pathField.isEditable = false
        pathField.tag = 400
        view.addSubview(pathField)

        let browseButton = NSButton(title: "Browse...", target: self, action: #selector(browseDownloadPath(_:)))
        browseButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(browseButton)

        // Organize by feed
        let organizeCheck = NSButton(checkboxWithTitle: "Organize downloads into folders by feed title",
                                     target: self, action: #selector(organizeByFeedChanged(_:)))
        organizeCheck.translatesAutoresizingMaskIntoConstraints = false
        organizeCheck.state = SettingsManager.shared.downloadOrganizeByFeed ? .on : .off
        view.addSubview(organizeCheck)

        NSLayoutConstraint.activate([
            pathLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            pathLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            pathField.topAnchor.constraint(equalTo: pathLabel.bottomAnchor, constant: 5),
            pathField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            pathField.trailingAnchor.constraint(equalTo: browseButton.leadingAnchor, constant: -10),

            browseButton.centerYAnchor.constraint(equalTo: pathField.centerYAnchor),
            browseButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            organizeCheck.topAnchor.constraint(equalTo: pathField.bottomAnchor, constant: 20),
            organizeCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
        ])

        item.view = view
        tabView.addTabViewItem(item)
    }

    // MARK: - Recording Tab

    private func addRecordingTab() {
        let item = NSTabViewItem(identifier: "recording")
        item.label = "Recording"

        let view = NSView()

        // Format
        let formatLabel = NSTextField(labelWithString: "Format:")
        formatLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(formatLabel)

        let formatCombo = NSPopUpButton(frame: .zero, pullsDown: false)
        formatCombo.translatesAutoresizingMaskIntoConstraints = false
        formatCombo.addItems(withTitles: ["WAV (Lossless)", "MP3", "OGG Vorbis", "FLAC (Lossless)"])
        formatCombo.selectItem(at: SettingsManager.shared.recordFormat)
        formatCombo.target = self
        formatCombo.action = #selector(recordFormatChanged(_:))
        view.addSubview(formatCombo)

        // Bitrate
        let bitrateLabel = NSTextField(labelWithString: "Bitrate:")
        bitrateLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bitrateLabel)

        let bitrateCombo = NSPopUpButton(frame: .zero, pullsDown: false)
        bitrateCombo.translatesAutoresizingMaskIntoConstraints = false
        bitrateCombo.addItems(withTitles: ["128 kbps", "192 kbps", "256 kbps", "320 kbps"])
        bitrateCombo.tag = 300
        let bitrateIndex = [128, 192, 256, 320].firstIndex(of: SettingsManager.shared.recordBitrate) ?? 1
        bitrateCombo.selectItem(at: bitrateIndex)
        bitrateCombo.target = self
        bitrateCombo.action = #selector(recordBitrateChanged(_:))
        view.addSubview(bitrateCombo)

        // Path
        let pathLabel = NSTextField(labelWithString: "Save to:")
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pathLabel)

        let pathField = NSTextField()
        pathField.translatesAutoresizingMaskIntoConstraints = false
        pathField.stringValue = SettingsManager.shared.recordPath.isEmpty ? "(Default: ~/Music/FastPlay Recordings)" : SettingsManager.shared.recordPath
        pathField.isEditable = false
        pathField.tag = 301
        view.addSubview(pathField)

        let browseButton = NSButton(title: "Browse...", target: self, action: #selector(browseRecordPath(_:)))
        browseButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(browseButton)

        // Filename template
        let templateLabel = NSTextField(labelWithString: "Filename template:")
        templateLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(templateLabel)

        let templateField = NSTextField()
        templateField.translatesAutoresizingMaskIntoConstraints = false
        templateField.stringValue = SettingsManager.shared.recordTemplate
        templateField.placeholderString = "%Y-%m-%d_%H-%M-%S"
        templateField.tag = 302
        templateField.target = self
        templateField.action = #selector(recordTemplateChanged(_:))
        view.addSubview(templateField)

        let templateHelp = NSTextField(wrappingLabelWithString: "strftime format: %Y=year, %m=month, %d=day, %H=hour (24h), %M=minute, %S=second\nExample: %Y-%m-%d_%H-%M-%S produces 2026-01-26_14-30-00")
        templateHelp.translatesAutoresizingMaskIntoConstraints = false
        templateHelp.font = NSFont.systemFont(ofSize: 10)
        templateHelp.textColor = .secondaryLabelColor
        view.addSubview(templateHelp)

        NSLayoutConstraint.activate([
            formatLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            formatLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            formatCombo.centerYAnchor.constraint(equalTo: formatLabel.centerYAnchor),
            formatCombo.leadingAnchor.constraint(equalTo: formatLabel.trailingAnchor, constant: 10),
            formatCombo.widthAnchor.constraint(equalToConstant: 150),

            bitrateLabel.topAnchor.constraint(equalTo: formatLabel.bottomAnchor, constant: 20),
            bitrateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            bitrateCombo.centerYAnchor.constraint(equalTo: bitrateLabel.centerYAnchor),
            bitrateCombo.leadingAnchor.constraint(equalTo: bitrateLabel.trailingAnchor, constant: 10),
            bitrateCombo.widthAnchor.constraint(equalToConstant: 100),

            pathLabel.topAnchor.constraint(equalTo: bitrateLabel.bottomAnchor, constant: 20),
            pathLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            pathField.topAnchor.constraint(equalTo: pathLabel.bottomAnchor, constant: 5),
            pathField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            pathField.trailingAnchor.constraint(equalTo: browseButton.leadingAnchor, constant: -10),

            browseButton.centerYAnchor.constraint(equalTo: pathField.centerYAnchor),
            browseButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            templateLabel.topAnchor.constraint(equalTo: pathField.bottomAnchor, constant: 20),
            templateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            templateField.topAnchor.constraint(equalTo: templateLabel.bottomAnchor, constant: 5),
            templateField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            templateField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            templateHelp.topAnchor.constraint(equalTo: templateField.bottomAnchor, constant: 5),
            templateHelp.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            templateHelp.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        item.view = view
        tabView.addTabViewItem(item)
    }

    // MARK: - Speech Tab

    // Store references to speech controls for updating
    private var voicePopup: NSPopUpButton?
    private var rateSlider: NSSlider?
    private var rateValueLabel: NSTextField?
    private var pitchSlider: NSSlider?
    private var pitchValueLabel: NSTextField?
    private var speechVolumeSlider: NSSlider?
    private var speechVolumeValueLabel: NSTextField?
    private var testSynthesizer: AVSpeechSynthesizer?

    private func addSpeechTab() {
        let item = NSTabViewItem(identifier: "speech")
        item.label = "Speech"

        let view = NSView()
        let leftMargin: CGFloat = 20
        let indent: CGFloat = 40

        // === Announcements Section Label ===
        let announcementsLabel = NSTextField(labelWithString: "Announcements:")
        announcementsLabel.translatesAutoresizingMaskIntoConstraints = false
        announcementsLabel.font = NSFont.boldSystemFont(ofSize: 12)
        view.addSubview(announcementsLabel)

        // Announce track changes
        let trackCheck = NSButton(checkboxWithTitle: "Announce track changes",
                                  target: self, action: #selector(announceTrackChanged(_:)))
        trackCheck.translatesAutoresizingMaskIntoConstraints = false
        trackCheck.state = SettingsManager.shared.speechTrackChange ? .on : .off
        view.addSubview(trackCheck)

        // Speak volume
        let volCheck = NSButton(checkboxWithTitle: "Speak volume changes",
                                target: self, action: #selector(speakVolumeChanged(_:)))
        volCheck.translatesAutoresizingMaskIntoConstraints = false
        volCheck.state = SettingsManager.shared.speechVolume ? .on : .off
        view.addSubview(volCheck)

        // Speak effect changes
        let effectCheck = NSButton(checkboxWithTitle: "Speak effect value changes",
                                   target: self, action: #selector(speakEffectChanged(_:)))
        effectCheck.translatesAutoresizingMaskIntoConstraints = false
        effectCheck.state = SettingsManager.shared.speechEffect ? .on : .off
        view.addSubview(effectCheck)

        // === Speech Synthesizer Section Label ===
        let synthLabel = NSTextField(labelWithString: "Speech Synthesizer (when app unfocused):")
        synthLabel.translatesAutoresizingMaskIntoConstraints = false
        synthLabel.font = NSFont.boldSystemFont(ofSize: 12)
        view.addSubview(synthLabel)

        // Enable AVSpeech checkbox
        let avSpeechCheck = NSButton(checkboxWithTitle: "Use speech synthesizer when app is in background",
                                      target: self, action: #selector(useAVSpeechChanged(_:)))
        avSpeechCheck.translatesAutoresizingMaskIntoConstraints = false
        avSpeechCheck.state = SettingsManager.shared.speechUseAVSpeech ? .on : .off
        view.addSubview(avSpeechCheck)

        // Voice selection
        let voiceLabel = NSTextField(labelWithString: "Voice:")
        voiceLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(voiceLabel)

        let voiceCombo = NSPopUpButton(frame: .zero, pullsDown: false)
        voiceCombo.translatesAutoresizingMaskIntoConstraints = false
        populateVoices(voiceCombo)
        voiceCombo.target = self
        voiceCombo.action = #selector(voiceChanged(_:))
        view.addSubview(voiceCombo)
        self.voicePopup = voiceCombo

        // Speech Rate slider
        let rateLabel = NSTextField(labelWithString: "Rate:")
        rateLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rateLabel)

        let rateSlider = NSSlider(value: Double(SettingsManager.shared.speechRate),
                                   minValue: 0.0, maxValue: 1.0,
                                   target: self, action: #selector(speechRateChanged(_:)))
        rateSlider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rateSlider)
        self.rateSlider = rateSlider

        let rateValue = NSTextField(labelWithString: formatSpeechRate(SettingsManager.shared.speechRate))
        rateValue.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rateValue)
        self.rateValueLabel = rateValue

        // Speech Pitch slider
        let pitchLabel = NSTextField(labelWithString: "Pitch:")
        pitchLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pitchLabel)

        let pitchSlider = NSSlider(value: Double(SettingsManager.shared.speechPitch),
                                    minValue: 0.5, maxValue: 2.0,
                                    target: self, action: #selector(speechPitchChanged(_:)))
        pitchSlider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pitchSlider)
        self.pitchSlider = pitchSlider

        let pitchValue = NSTextField(labelWithString: formatSpeechPitch(SettingsManager.shared.speechPitch))
        pitchValue.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pitchValue)
        self.pitchValueLabel = pitchValue

        // Speech Volume slider
        let speechVolLabel = NSTextField(labelWithString: "Volume:")
        speechVolLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(speechVolLabel)

        let speechVolSlider = NSSlider(value: Double(SettingsManager.shared.speechSynthVolume),
                                        minValue: 0.0, maxValue: 1.0,
                                        target: self, action: #selector(speechVolumeSliderChanged(_:)))
        speechVolSlider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(speechVolSlider)
        self.speechVolumeSlider = speechVolSlider

        let speechVolValue = NSTextField(labelWithString: "\(Int(SettingsManager.shared.speechSynthVolume * 100))%")
        speechVolValue.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(speechVolValue)
        self.speechVolumeValueLabel = speechVolValue

        // Test button
        let testButton = NSButton(title: "Test Voice", target: self, action: #selector(testVoice(_:)))
        testButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(testButton)

        // Help text
        let helpLabel = NSTextField(wrappingLabelWithString: "When FastPlay is in the background, VoiceOver announcements may not be heard. Enable the speech synthesizer to hear announcements even when the app is unfocused.")
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = NSFont.systemFont(ofSize: 11)
        helpLabel.textColor = .secondaryLabelColor
        view.addSubview(helpLabel)

        NSLayoutConstraint.activate([
            // Announcements section
            announcementsLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 15),
            announcementsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leftMargin),

            trackCheck.topAnchor.constraint(equalTo: announcementsLabel.bottomAnchor, constant: 10),
            trackCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: indent),

            volCheck.topAnchor.constraint(equalTo: trackCheck.bottomAnchor, constant: 5),
            volCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: indent),

            effectCheck.topAnchor.constraint(equalTo: volCheck.bottomAnchor, constant: 5),
            effectCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: indent),

            // Speech Synthesizer section
            synthLabel.topAnchor.constraint(equalTo: effectCheck.bottomAnchor, constant: 25),
            synthLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leftMargin),

            avSpeechCheck.topAnchor.constraint(equalTo: synthLabel.bottomAnchor, constant: 10),
            avSpeechCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: indent),

            // Voice row
            voiceLabel.topAnchor.constraint(equalTo: avSpeechCheck.bottomAnchor, constant: 15),
            voiceLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: indent),
            voiceLabel.widthAnchor.constraint(equalToConstant: 50),
            voiceCombo.centerYAnchor.constraint(equalTo: voiceLabel.centerYAnchor),
            voiceCombo.leadingAnchor.constraint(equalTo: voiceLabel.trailingAnchor, constant: 10),
            voiceCombo.widthAnchor.constraint(equalToConstant: 250),

            // Rate row
            rateLabel.topAnchor.constraint(equalTo: voiceLabel.bottomAnchor, constant: 15),
            rateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: indent),
            rateLabel.widthAnchor.constraint(equalToConstant: 50),
            rateSlider.centerYAnchor.constraint(equalTo: rateLabel.centerYAnchor),
            rateSlider.leadingAnchor.constraint(equalTo: rateLabel.trailingAnchor, constant: 10),
            rateSlider.widthAnchor.constraint(equalToConstant: 150),
            rateValue.centerYAnchor.constraint(equalTo: rateSlider.centerYAnchor),
            rateValue.leadingAnchor.constraint(equalTo: rateSlider.trailingAnchor, constant: 10),
            rateValue.widthAnchor.constraint(equalToConstant: 60),

            // Pitch row
            pitchLabel.topAnchor.constraint(equalTo: rateLabel.bottomAnchor, constant: 15),
            pitchLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: indent),
            pitchLabel.widthAnchor.constraint(equalToConstant: 50),
            pitchSlider.centerYAnchor.constraint(equalTo: pitchLabel.centerYAnchor),
            pitchSlider.leadingAnchor.constraint(equalTo: pitchLabel.trailingAnchor, constant: 10),
            pitchSlider.widthAnchor.constraint(equalToConstant: 150),
            pitchValue.centerYAnchor.constraint(equalTo: pitchSlider.centerYAnchor),
            pitchValue.leadingAnchor.constraint(equalTo: pitchSlider.trailingAnchor, constant: 10),
            pitchValue.widthAnchor.constraint(equalToConstant: 60),

            // Volume row
            speechVolLabel.topAnchor.constraint(equalTo: pitchLabel.bottomAnchor, constant: 15),
            speechVolLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: indent),
            speechVolLabel.widthAnchor.constraint(equalToConstant: 50),
            speechVolSlider.centerYAnchor.constraint(equalTo: speechVolLabel.centerYAnchor),
            speechVolSlider.leadingAnchor.constraint(equalTo: speechVolLabel.trailingAnchor, constant: 10),
            speechVolSlider.widthAnchor.constraint(equalToConstant: 150),
            speechVolValue.centerYAnchor.constraint(equalTo: speechVolSlider.centerYAnchor),
            speechVolValue.leadingAnchor.constraint(equalTo: speechVolSlider.trailingAnchor, constant: 10),
            speechVolValue.widthAnchor.constraint(equalToConstant: 60),

            // Test button
            testButton.topAnchor.constraint(equalTo: speechVolLabel.bottomAnchor, constant: 20),
            testButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: indent),

            // Help text
            helpLabel.topAnchor.constraint(equalTo: testButton.bottomAnchor, constant: 20),
            helpLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leftMargin),
            helpLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -leftMargin),
        ])

        item.view = view
        tabView.addTabViewItem(item)
    }

    // MARK: - Speech Tab Helpers

    private func populateVoices(_ combo: NSPopUpButton) {
        combo.removeAllItems()

        // Add system default option
        combo.addItem(withTitle: "System Default")
        combo.item(at: 0)?.representedObject = ""

        // Get available voices
        let voices = AccessibilityManager.getAvailableVoices()

        for voice in voices {
            combo.addItem(withTitle: voice.name)
            combo.lastItem?.representedObject = voice.identifier
        }

        // Select current voice
        let currentId = SettingsManager.shared.speechVoiceIdentifier
        if currentId.isEmpty {
            combo.selectItem(at: 0)
        } else if let index = voices.firstIndex(where: { $0.identifier == currentId }) {
            combo.selectItem(at: index + 1)  // +1 for "System Default"
        } else {
            combo.selectItem(at: 0)
        }
    }

    private func formatSpeechRate(_ rate: Float) -> String {
        if rate < 0.25 {
            return "Slow"
        } else if rate < 0.45 {
            return "Slower"
        } else if rate < 0.55 {
            return "Normal"
        } else if rate < 0.75 {
            return "Faster"
        } else {
            return "Fast"
        }
    }

    private func formatSpeechPitch(_ pitch: Float) -> String {
        let percent = Int((pitch - 1.0) * 100)
        if percent == 0 {
            return "Normal"
        } else if percent > 0 {
            return "+\(percent)%"
        } else {
            return "\(percent)%"
        }
    }

    // MARK: - Movement Tab

    private func addMovementTab() {
        let item = NSTabViewItem(identifier: "movement")
        item.label = "Movement"

        let view = NSView()

        let label = NSTextField(labelWithString: "Seek amounts (use , and . to cycle):")
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        var lastAnchor: NSLayoutYAxisAnchor = label.bottomAnchor

        // Add the 10 standard seek amounts
        for (index, amount) in SettingsManager.defaultSeekAmounts.enumerated() {
            let check = NSButton(checkboxWithTitle: amount.label,
                                 target: self, action: #selector(seekAmountChanged(_:)))
            check.translatesAutoresizingMaskIntoConstraints = false
            check.tag = index
            check.state = SettingsManager.shared.seekEnabled[index] ? .on : .off
            view.addSubview(check)

            NSLayoutConstraint.activate([
                check.topAnchor.constraint(equalTo: lastAnchor, constant: index == 0 ? 15 : 5),
                check.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            ])
            lastAnchor = check.bottomAnchor
        }

        // Add chapter seek checkbox (index 10 - virtual option)
        let chapterCheck = NSButton(checkboxWithTitle: "Chapter (when available)",
                                    target: self, action: #selector(chapterSeekChanged(_:)))
        chapterCheck.translatesAutoresizingMaskIntoConstraints = false
        chapterCheck.tag = 10
        chapterCheck.state = SettingsManager.shared.chapterSeekEnabled ? .on : .off
        view.addSubview(chapterCheck)

        NSLayoutConstraint.activate([
            chapterCheck.topAnchor.constraint(equalTo: lastAnchor, constant: 5),
            chapterCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
        ])

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
        ])

        item.view = view
        tabView.addTabViewItem(item)
    }

    // MARK: - Advanced Tab

    private func addAdvancedTab() {
        let item = NSTabViewItem(identifier: "advanced")
        item.label = "Advanced"

        let view = NSView()

        // Buffer size
        let bufferLabel = NSTextField(labelWithString: "Buffer size:")
        bufferLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bufferLabel)

        let bufferCombo = NSPopUpButton(frame: .zero, pullsDown: false)
        bufferCombo.translatesAutoresizingMaskIntoConstraints = false
        bufferCombo.addItems(withTitles: ["100ms", "200ms", "300ms", "500ms", "1000ms", "2000ms", "5000ms"])
        let bufferValues = [100, 200, 300, 500, 1000, 2000, 5000]
        if let idx = bufferValues.firstIndex(of: SettingsManager.shared.bufferSize) {
            bufferCombo.selectItem(at: idx)
        } else {
            bufferCombo.selectItem(at: 3)  // Default 500ms
        }
        bufferCombo.target = self
        bufferCombo.action = #selector(bufferSizeChanged(_:))
        view.addSubview(bufferCombo)

        // Update period
        let updateLabel = NSTextField(labelWithString: "Update period:")
        updateLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(updateLabel)

        let updateCombo = NSPopUpButton(frame: .zero, pullsDown: false)
        updateCombo.translatesAutoresizingMaskIntoConstraints = false
        updateCombo.addItems(withTitles: ["5ms", "10ms", "20ms", "50ms", "100ms", "200ms", "500ms"])
        let updateValues = [5, 10, 20, 50, 100, 200, 500]
        if let idx = updateValues.firstIndex(of: SettingsManager.shared.updatePeriod) {
            updateCombo.selectItem(at: idx)
        } else {
            updateCombo.selectItem(at: 4)  // Default 100ms
        }
        updateCombo.target = self
        updateCombo.action = #selector(updatePeriodChanged(_:))
        view.addSubview(updateCombo)

        // EQ Frequency Bands section
        let eqLabel = NSTextField(labelWithString: "EQ Frequency Bands:")
        eqLabel.translatesAutoresizingMaskIntoConstraints = false
        eqLabel.font = NSFont.boldSystemFont(ofSize: 12)
        view.addSubview(eqLabel)

        // Bass frequency
        let bassLabel = NSTextField(labelWithString: "Bass frequency (Hz):")
        bassLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bassLabel)

        let bassField = NSTextField()
        bassField.translatesAutoresizingMaskIntoConstraints = false
        bassField.stringValue = String(format: "%.0f", SettingsManager.shared.eqBassFreq)
        bassField.tag = 1
        bassField.target = self
        bassField.action = #selector(eqFreqChanged(_:))
        view.addSubview(bassField)

        // Mid frequency
        let midLabel = NSTextField(labelWithString: "Mid frequency (Hz):")
        midLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(midLabel)

        let midField = NSTextField()
        midField.translatesAutoresizingMaskIntoConstraints = false
        midField.stringValue = String(format: "%.0f", SettingsManager.shared.eqMidFreq)
        midField.tag = 2
        midField.target = self
        midField.action = #selector(eqFreqChanged(_:))
        view.addSubview(midField)

        // Treble frequency
        let trebleLabel = NSTextField(labelWithString: "Treble frequency (Hz):")
        trebleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(trebleLabel)

        let trebleField = NSTextField()
        trebleField.translatesAutoresizingMaskIntoConstraints = false
        trebleField.stringValue = String(format: "%.0f", SettingsManager.shared.eqTrebleFreq)
        trebleField.tag = 3
        trebleField.target = self
        trebleField.action = #selector(eqFreqChanged(_:))
        view.addSubview(trebleField)

        NSLayoutConstraint.activate([
            bufferLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            bufferLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bufferCombo.centerYAnchor.constraint(equalTo: bufferLabel.centerYAnchor),
            bufferCombo.leadingAnchor.constraint(equalTo: bufferLabel.trailingAnchor, constant: 10),
            bufferCombo.widthAnchor.constraint(equalToConstant: 100),

            updateLabel.topAnchor.constraint(equalTo: bufferLabel.bottomAnchor, constant: 15),
            updateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            updateCombo.centerYAnchor.constraint(equalTo: updateLabel.centerYAnchor),
            updateCombo.leadingAnchor.constraint(equalTo: updateLabel.trailingAnchor, constant: 10),
            updateCombo.widthAnchor.constraint(equalToConstant: 100),

            eqLabel.topAnchor.constraint(equalTo: updateLabel.bottomAnchor, constant: 25),
            eqLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            bassLabel.topAnchor.constraint(equalTo: eqLabel.bottomAnchor, constant: 10),
            bassLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            bassField.centerYAnchor.constraint(equalTo: bassLabel.centerYAnchor),
            bassField.leadingAnchor.constraint(equalTo: bassLabel.trailingAnchor, constant: 10),
            bassField.widthAnchor.constraint(equalToConstant: 80),

            midLabel.topAnchor.constraint(equalTo: bassLabel.bottomAnchor, constant: 10),
            midLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            midField.centerYAnchor.constraint(equalTo: midLabel.centerYAnchor),
            midField.leadingAnchor.constraint(equalTo: midLabel.trailingAnchor, constant: 10),
            midField.widthAnchor.constraint(equalToConstant: 80),

            trebleLabel.topAnchor.constraint(equalTo: midLabel.bottomAnchor, constant: 10),
            trebleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            trebleField.centerYAnchor.constraint(equalTo: trebleLabel.centerYAnchor),
            trebleField.leadingAnchor.constraint(equalTo: trebleLabel.trailingAnchor, constant: 10),
            trebleField.widthAnchor.constraint(equalToConstant: 80),
        ])

        item.view = view
        tabView.addTabViewItem(item)
    }

    // MARK: - Global Hotkeys Tab

    private var hotkeyTableView: NSTableView!
    private var hotkeyData: [[String: Any]] = []

    private func addHotkeysTab() {
        let item = NSTabViewItem(identifier: "hotkeys")
        item.label = "Hotkeys"

        let view = NSView()

        // Enable global hotkeys
        let enableCheck = NSButton(checkboxWithTitle: "Enable global hotkeys",
                                   target: self, action: #selector(hotkeysEnabledChanged(_:)))
        enableCheck.translatesAutoresizingMaskIntoConstraints = false
        enableCheck.state = SettingsManager.shared.hotkeysEnabled ? .on : .off
        view.addSubview(enableCheck)

        // Hotkey list
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        hotkeyTableView = NSTableView()
        hotkeyTableView.headerView = nil

        let actionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("action"))
        actionColumn.title = "Action"
        actionColumn.width = 200
        hotkeyTableView.addTableColumn(actionColumn)

        let keyColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("key"))
        keyColumn.title = "Key"
        keyColumn.width = 150
        hotkeyTableView.addTableColumn(keyColumn)

        hotkeyTableView.delegate = self
        hotkeyTableView.dataSource = self
        scrollView.documentView = hotkeyTableView
        view.addSubview(scrollView)

        // Load hotkey data
        loadHotkeyData()

        // Buttons
        let addButton = NSButton(title: "Add...", target: self, action: #selector(addHotkey(_:)))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addButton)

        let editButton = NSButton(title: "Edit...", target: self, action: #selector(editHotkey(_:)))
        editButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(editButton)

        let removeButton = NSButton(title: "Remove", target: self, action: #selector(removeHotkey(_:)))
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(removeButton)

        // Help text
        let helpLabel = NSTextField(wrappingLabelWithString: "Global hotkeys work even when FastPlay is in the background. Use modifier keys (⌘⌥⌃⇧) with other keys.")
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = NSFont.systemFont(ofSize: 11)
        helpLabel.textColor = .secondaryLabelColor
        view.addSubview(helpLabel)

        NSLayoutConstraint.activate([
            enableCheck.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            enableCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            scrollView.topAnchor.constraint(equalTo: enableCheck.bottomAnchor, constant: 15),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.heightAnchor.constraint(equalToConstant: 200),

            addButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 10),
            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            editButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 10),
            editButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 10),

            removeButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 10),
            removeButton.leadingAnchor.constraint(equalTo: editButton.trailingAnchor, constant: 10),

            helpLabel.topAnchor.constraint(equalTo: addButton.bottomAnchor, constant: 15),
            helpLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            helpLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        item.view = view
        tabView.addTabViewItem(item)
    }

    private func loadHotkeyData() {
        hotkeyData = SettingsManager.shared.hotkeys
        hotkeyTableView?.reloadData()
    }

    // MARK: - SoundTouch Tab

    private func addSoundTouchTab() {
        let item = NSTabViewItem(identifier: "soundtouch")
        item.label = "SoundTouch"

        let view = NSView()

        // Anti-alias filter
        let aaCheck = NSButton(checkboxWithTitle: "Anti-alias filter",
                               target: self, action: #selector(stAntiAliasChanged(_:)))
        aaCheck.translatesAutoresizingMaskIntoConstraints = false
        aaCheck.state = SettingsManager.shared.stAntiAliasFilter ? .on : .off
        view.addSubview(aaCheck)

        // AA filter length
        let aaLengthLabel = NSTextField(labelWithString: "AA filter length:")
        aaLengthLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(aaLengthLabel)

        let aaLengthCombo = NSPopUpButton(frame: .zero, pullsDown: false)
        aaLengthCombo.translatesAutoresizingMaskIntoConstraints = false
        aaLengthCombo.addItems(withTitles: ["8", "16", "32", "64", "128"])
        let aaLengthValues = [8, 16, 32, 64, 128]
        if let idx = aaLengthValues.firstIndex(of: SettingsManager.shared.stAAFilterLength) {
            aaLengthCombo.selectItem(at: idx)
        }
        aaLengthCombo.target = self
        aaLengthCombo.action = #selector(stAALengthChanged(_:))
        view.addSubview(aaLengthCombo)

        // Quick algorithm
        let quickCheck = NSButton(checkboxWithTitle: "Quick algorithm (faster, lower quality)",
                                  target: self, action: #selector(stQuickChanged(_:)))
        quickCheck.translatesAutoresizingMaskIntoConstraints = false
        quickCheck.state = SettingsManager.shared.stQuickAlgorithm ? .on : .off
        view.addSubview(quickCheck)

        // Prevent click
        let clickCheck = NSButton(checkboxWithTitle: "Prevent click (adds latency)",
                                  target: self, action: #selector(stPreventClickChanged(_:)))
        clickCheck.translatesAutoresizingMaskIntoConstraints = false
        clickCheck.state = SettingsManager.shared.stPreventClick ? .on : .off
        view.addSubview(clickCheck)

        // Interpolation
        let interpLabel = NSTextField(labelWithString: "Interpolation:")
        interpLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(interpLabel)

        let interpCombo = NSPopUpButton(frame: .zero, pullsDown: false)
        interpCombo.translatesAutoresizingMaskIntoConstraints = false
        interpCombo.addItems(withTitles: ["Linear", "Cubic", "Shannon"])
        interpCombo.selectItem(at: SettingsManager.shared.stAlgorithm)
        interpCombo.target = self
        interpCombo.action = #selector(stInterpChanged(_:))
        view.addSubview(interpCombo)

        // Sequence length
        let seqLabel = NSTextField(labelWithString: "Sequence (ms):")
        seqLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(seqLabel)

        let seqField = NSTextField()
        seqField.translatesAutoresizingMaskIntoConstraints = false
        seqField.stringValue = "\(SettingsManager.shared.stSequenceMs)"
        seqField.tag = 800
        seqField.target = self
        seqField.action = #selector(stSequenceChanged(_:))
        view.addSubview(seqField)

        // Seek window
        let seekLabel = NSTextField(labelWithString: "Seek window (ms):")
        seekLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(seekLabel)

        let seekField = NSTextField()
        seekField.translatesAutoresizingMaskIntoConstraints = false
        seekField.stringValue = "\(SettingsManager.shared.stSeekWindowMs)"
        seekField.tag = 801
        seekField.target = self
        seekField.action = #selector(stSeekWindowChanged(_:))
        view.addSubview(seekField)

        // Overlap
        let overlapLabel = NSTextField(labelWithString: "Overlap (ms):")
        overlapLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlapLabel)

        let overlapField = NSTextField()
        overlapField.translatesAutoresizingMaskIntoConstraints = false
        overlapField.stringValue = "\(SettingsManager.shared.stOverlapMs)"
        overlapField.tag = 802
        overlapField.target = self
        overlapField.action = #selector(stOverlapChanged(_:))
        view.addSubview(overlapField)

        NSLayoutConstraint.activate([
            aaCheck.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            aaCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            aaLengthLabel.topAnchor.constraint(equalTo: aaCheck.bottomAnchor, constant: 15),
            aaLengthLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            aaLengthCombo.centerYAnchor.constraint(equalTo: aaLengthLabel.centerYAnchor),
            aaLengthCombo.leadingAnchor.constraint(equalTo: aaLengthLabel.trailingAnchor, constant: 10),
            aaLengthCombo.widthAnchor.constraint(equalToConstant: 80),

            quickCheck.topAnchor.constraint(equalTo: aaLengthLabel.bottomAnchor, constant: 15),
            quickCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            clickCheck.topAnchor.constraint(equalTo: quickCheck.bottomAnchor, constant: 10),
            clickCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            interpLabel.topAnchor.constraint(equalTo: clickCheck.bottomAnchor, constant: 20),
            interpLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            interpCombo.centerYAnchor.constraint(equalTo: interpLabel.centerYAnchor),
            interpCombo.leadingAnchor.constraint(equalTo: interpLabel.trailingAnchor, constant: 10),
            interpCombo.widthAnchor.constraint(equalToConstant: 100),

            seqLabel.topAnchor.constraint(equalTo: interpLabel.bottomAnchor, constant: 20),
            seqLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            seqField.centerYAnchor.constraint(equalTo: seqLabel.centerYAnchor),
            seqField.leadingAnchor.constraint(equalTo: seqLabel.trailingAnchor, constant: 10),
            seqField.widthAnchor.constraint(equalToConstant: 60),

            seekLabel.topAnchor.constraint(equalTo: seqLabel.bottomAnchor, constant: 15),
            seekLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            seekField.centerYAnchor.constraint(equalTo: seekLabel.centerYAnchor),
            seekField.leadingAnchor.constraint(equalTo: seekLabel.trailingAnchor, constant: 10),
            seekField.widthAnchor.constraint(equalToConstant: 60),

            overlapLabel.topAnchor.constraint(equalTo: seekLabel.bottomAnchor, constant: 15),
            overlapLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            overlapField.centerYAnchor.constraint(equalTo: overlapLabel.centerYAnchor),
            overlapField.leadingAnchor.constraint(equalTo: overlapLabel.trailingAnchor, constant: 10),
            overlapField.widthAnchor.constraint(equalToConstant: 60),
        ])

        item.view = view
        tabView.addTabViewItem(item)
    }

    // MARK: - YouTube Tab

    private func addYouTubeTab() {
        let item = NSTabViewItem(identifier: "youtube")
        item.label = "YouTube"

        let view = NSView()

        // yt-dlp path
        let ytdlpLabel = NSTextField(labelWithString: "yt-dlp executable path:")
        ytdlpLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ytdlpLabel)

        let ytdlpField = NSTextField()
        ytdlpField.translatesAutoresizingMaskIntoConstraints = false
        ytdlpField.stringValue = SettingsManager.shared.ytdlpPath.isEmpty ? "(Auto-detect)" : SettingsManager.shared.ytdlpPath
        ytdlpField.isEditable = false
        ytdlpField.tag = 500
        view.addSubview(ytdlpField)

        let browseButton = NSButton(title: "Browse...", target: self, action: #selector(browseYtdlpPath(_:)))
        browseButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(browseButton)

        // YouTube API key
        let apiKeyLabel = NSTextField(labelWithString: "YouTube Data API key (optional):")
        apiKeyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(apiKeyLabel)

        let apiKeyField = NSTextField()
        apiKeyField.translatesAutoresizingMaskIntoConstraints = false
        apiKeyField.stringValue = SettingsManager.shared.ytApiKey
        apiKeyField.placeholderString = "Enter API key to enable search"
        apiKeyField.tag = 501
        apiKeyField.target = self
        apiKeyField.action = #selector(ytApiKeyChanged(_:))
        view.addSubview(apiKeyField)

        let apiKeyHelp = NSTextField(wrappingLabelWithString: "An API key enables YouTube search functionality. Get one free from Google Cloud Console.")
        apiKeyHelp.translatesAutoresizingMaskIntoConstraints = false
        apiKeyHelp.font = NSFont.systemFont(ofSize: 10)
        apiKeyHelp.textColor = .secondaryLabelColor
        view.addSubview(apiKeyHelp)

        // Help text
        let helpLabel = NSTextField(wrappingLabelWithString: "yt-dlp is required for YouTube playback.\n\nInstall via Homebrew: brew install yt-dlp\n\nOr download from: https://github.com/yt-dlp/yt-dlp")
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = NSFont.systemFont(ofSize: 11)
        helpLabel.textColor = .secondaryLabelColor
        view.addSubview(helpLabel)

        NSLayoutConstraint.activate([
            ytdlpLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            ytdlpLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            ytdlpField.topAnchor.constraint(equalTo: ytdlpLabel.bottomAnchor, constant: 5),
            ytdlpField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            ytdlpField.trailingAnchor.constraint(equalTo: browseButton.leadingAnchor, constant: -10),

            browseButton.centerYAnchor.constraint(equalTo: ytdlpField.centerYAnchor),
            browseButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            apiKeyLabel.topAnchor.constraint(equalTo: ytdlpField.bottomAnchor, constant: 20),
            apiKeyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            apiKeyField.topAnchor.constraint(equalTo: apiKeyLabel.bottomAnchor, constant: 5),
            apiKeyField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            apiKeyField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            apiKeyHelp.topAnchor.constraint(equalTo: apiKeyField.bottomAnchor, constant: 5),
            apiKeyHelp.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            apiKeyHelp.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            helpLabel.topAnchor.constraint(equalTo: apiKeyHelp.bottomAnchor, constant: 20),
            helpLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            helpLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        item.view = view
        tabView.addTabViewItem(item)
    }

    // MARK: - Actions

    @objc private func volumeStepChanged(_ sender: NSSlider) {
        let value = Float(sender.intValue) / 100.0
        SettingsManager.shared.volumeStep = value
        if let label = sender.superview?.viewWithTag(101) as? NSTextField {
            label.stringValue = "\(sender.intValue)%"
        }
    }

    @objc private func allowAmplifyChanged(_ sender: NSButton) {
        SettingsManager.shared.allowAmplify = sender.state == .on
    }

    @objc private func rememberStateChanged(_ sender: NSButton) {
        SettingsManager.shared.rememberState = sender.state == .on
    }

    @objc private func autoAdvanceChanged(_ sender: NSButton) {
        SettingsManager.shared.autoAdvance = sender.state == .on
    }

    @objc private func showTitleChanged(_ sender: NSButton) {
        SettingsManager.shared.showTitleInWindow = sender.state == .on
        // Post notification to update window title
        NotificationCenter.default.post(name: NSNotification.Name("UpdateWindowTitle"), object: nil)
    }

    @objc private func loadFolderChanged(_ sender: NSButton) {
        SettingsManager.shared.loadFolder = sender.state == .on
    }

    @objc private func effectEnabledChanged(_ sender: NSButton) {
        let index = sender.tag
        SettingsManager.shared.effectEnabled[index] = sender.state == .on

        // If current effect is now disabled, switch to first enabled one
        if !SettingsManager.shared.effectEnabled[SettingsManager.shared.currentEffectIndex] {
            for i in 0..<4 {
                if SettingsManager.shared.effectEnabled[i] {
                    SettingsManager.shared.currentEffectIndex = i
                    break
                }
            }
        }
    }

    @objc private func rateStepModeChanged(_ sender: NSPopUpButton) {
        SettingsManager.shared.rateStepMode = sender.indexOfSelectedItem
    }

    @objc private func announceTrackChanged(_ sender: NSButton) {
        SettingsManager.shared.speechTrackChange = sender.state == .on
    }

    @objc private func speakVolumeChanged(_ sender: NSButton) {
        SettingsManager.shared.speechVolume = sender.state == .on
    }

    @objc private func speakEffectChanged(_ sender: NSButton) {
        SettingsManager.shared.speechEffect = sender.state == .on
    }

    @objc private func useAVSpeechChanged(_ sender: NSButton) {
        SettingsManager.shared.speechUseAVSpeech = sender.state == .on
    }

    @objc private func voiceChanged(_ sender: NSPopUpButton) {
        if let identifier = sender.selectedItem?.representedObject as? String {
            SettingsManager.shared.speechVoiceIdentifier = identifier
        }
    }

    @objc private func speechRateChanged(_ sender: NSSlider) {
        let value = Float(sender.doubleValue)
        SettingsManager.shared.speechRate = value
        rateValueLabel?.stringValue = formatSpeechRate(value)
    }

    @objc private func speechPitchChanged(_ sender: NSSlider) {
        let value = Float(sender.doubleValue)
        SettingsManager.shared.speechPitch = value
        pitchValueLabel?.stringValue = formatSpeechPitch(value)
    }

    @objc private func speechVolumeSliderChanged(_ sender: NSSlider) {
        let value = Float(sender.doubleValue)
        SettingsManager.shared.speechSynthVolume = value
        speechVolumeValueLabel?.stringValue = "\(Int(value * 100))%"
    }

    @objc private func testVoice(_ sender: NSButton) {
        let testMessage = "This is a test of the speech synthesizer settings."

        let utterance = AVSpeechUtterance(string: testMessage)

        let voiceId = SettingsManager.shared.speechVoiceIdentifier
        if !voiceId.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        }

        utterance.rate = SettingsManager.shared.speechRate
        utterance.pitchMultiplier = SettingsManager.shared.speechPitch
        utterance.volume = SettingsManager.shared.speechSynthVolume

        // Store synthesizer as instance variable to prevent deallocation during speech
        testSynthesizer = AVSpeechSynthesizer()
        testSynthesizer?.speak(utterance)
    }

    @objc private func seekAmountChanged(_ sender: NSButton) {
        let index = sender.tag
        SettingsManager.shared.seekEnabled[index] = sender.state == .on
    }

    @objc private func chapterSeekChanged(_ sender: NSButton) {
        SettingsManager.shared.chapterSeekEnabled = sender.state == .on
    }

    @objc private func dspEffectChanged(_ sender: NSButton) {
        // Tags: 201=Echo, 202=EQ, 203=Compressor, 204=StereoWidth, 205=CenterCancel, 206=Convolution
        let index = sender.tag - 200  // 1=Echo, 2=EQ, etc.
        if index >= 0 && index < SettingsManager.shared.dspEffectEnabled.count {
            SettingsManager.shared.dspEffectEnabled[index] = sender.state == .on
            DSPEffectsManager.shared.updateEffects()
        }
    }

    @objc private func reverbAlgorithmChanged(_ sender: NSPopUpButton) {
        SettingsManager.shared.reverbAlgorithm = sender.indexOfSelectedItem
        DSPEffectsManager.shared.updateEffects()
    }

    @objc private func browseDownloadPath(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            SettingsManager.shared.downloadPath = url.path
            if let pathField = sender.superview?.viewWithTag(400) as? NSTextField {
                pathField.stringValue = url.path
            }
        }
    }

    @objc private func organizeByFeedChanged(_ sender: NSButton) {
        SettingsManager.shared.downloadOrganizeByFeed = sender.state == .on
    }

    @objc private func bufferSizeChanged(_ sender: NSPopUpButton) {
        let values = [100, 200, 300, 500, 1000, 2000, 5000]
        SettingsManager.shared.bufferSize = values[sender.indexOfSelectedItem]
    }

    @objc private func updatePeriodChanged(_ sender: NSPopUpButton) {
        let values = [5, 10, 20, 50, 100, 200, 500]
        SettingsManager.shared.updatePeriod = values[sender.indexOfSelectedItem]
    }

    @objc private func posMinutesChanged(_ sender: NSPopUpButton) {
        let values = [0, 5, 10, 15, 30, 60]
        SettingsManager.shared.rememberPosMinutes = values[sender.indexOfSelectedItem]
    }

    @objc private func eqFreqChanged(_ sender: NSTextField) {
        guard let value = Float(sender.stringValue), value >= 1 && value <= 20000 else {
            return
        }
        switch sender.tag {
        case 1:
            SettingsManager.shared.eqBassFreq = value
        case 2:
            SettingsManager.shared.eqMidFreq = value
        case 3:
            SettingsManager.shared.eqTrebleFreq = value
        default:
            break
        }
        // Notify audio engine to update EQ if active
        AudioEngine.shared.updateEQFrequencies()
    }

    @objc private func browseYtdlpPath(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            SettingsManager.shared.ytdlpPath = url.path
            if let pathField = sender.superview?.viewWithTag(500) as? NSTextField {
                pathField.stringValue = url.path
            }
        }
    }

    @objc private func recordFormatChanged(_ sender: NSPopUpButton) {
        SettingsManager.shared.recordFormat = sender.indexOfSelectedItem
    }

    @objc private func recordBitrateChanged(_ sender: NSPopUpButton) {
        let bitrates = [128, 192, 256, 320]
        SettingsManager.shared.recordBitrate = bitrates[sender.indexOfSelectedItem]
    }

    @objc private func browseRecordPath(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            SettingsManager.shared.recordPath = url.path
            if let pathField = sender.superview?.viewWithTag(301) as? NSTextField {
                pathField.stringValue = url.path
            }
        }
    }

    @objc private func recordTemplateChanged(_ sender: NSTextField) {
        SettingsManager.shared.recordTemplate = sender.stringValue
    }

    @objc private func ytApiKeyChanged(_ sender: NSTextField) {
        SettingsManager.shared.ytApiKey = sender.stringValue
    }

    // MARK: - SoundTouch Actions

    @objc private func stAntiAliasChanged(_ sender: NSButton) {
        SettingsManager.shared.stAntiAliasFilter = sender.state == .on
    }

    @objc private func stAALengthChanged(_ sender: NSPopUpButton) {
        let values = [8, 16, 32, 64, 128]
        SettingsManager.shared.stAAFilterLength = values[sender.indexOfSelectedItem]
    }

    @objc private func stQuickChanged(_ sender: NSButton) {
        SettingsManager.shared.stQuickAlgorithm = sender.state == .on
    }

    @objc private func stPreventClickChanged(_ sender: NSButton) {
        SettingsManager.shared.stPreventClick = sender.state == .on
    }

    @objc private func stInterpChanged(_ sender: NSPopUpButton) {
        SettingsManager.shared.stAlgorithm = sender.indexOfSelectedItem
    }

    @objc private func stSequenceChanged(_ sender: NSTextField) {
        if let value = Int(sender.stringValue), value > 0 {
            SettingsManager.shared.stSequenceMs = value
        }
    }

    @objc private func stSeekWindowChanged(_ sender: NSTextField) {
        if let value = Int(sender.stringValue), value > 0 {
            SettingsManager.shared.stSeekWindowMs = value
        }
    }

    @objc private func stOverlapChanged(_ sender: NSTextField) {
        if let value = Int(sender.stringValue), value > 0 {
            SettingsManager.shared.stOverlapMs = value
        }
    }

    // MARK: - Hotkey Actions

    @objc private func hotkeysEnabledChanged(_ sender: NSButton) {
        SettingsManager.shared.hotkeysEnabled = sender.state == .on
        HotkeyManager.shared.setEnabled(sender.state == .on)
    }

    @objc private func addHotkey(_ sender: NSButton) {
        showHotkeyEditor(editing: nil)
    }

    @objc private func editHotkey(_ sender: NSButton) {
        let row = hotkeyTableView.selectedRow
        guard row >= 0 && row < hotkeyData.count else { return }
        showHotkeyEditor(editing: row)
    }

    @objc private func removeHotkey(_ sender: NSButton) {
        let row = hotkeyTableView.selectedRow
        guard row >= 0 && row < hotkeyData.count else { return }
        hotkeyData.remove(at: row)
        SettingsManager.shared.hotkeys = hotkeyData
        hotkeyTableView.reloadData()
        HotkeyManager.shared.reloadHotkeys()
    }

    private func showHotkeyEditor(editing index: Int?) {
        let alert = NSAlert()
        alert.messageText = index == nil ? "Add Hotkey" : "Edit Hotkey"
        alert.informativeText = "Select an action, then click the key field and press your key combination."

        // Action popup
        let actionPopup = NSPopUpButton(frame: NSRect(x: 0, y: 30, width: 250, height: 25))
        let actions = HotkeyManager.HotkeyAction.allCases.map { $0.displayName }
        actionPopup.addItems(withTitles: actions)

        // Key capture field (custom class that properly captures key events)
        let keyField = HotkeyCaptureField(frame: NSRect(x: 0, y: 0, width: 250, height: 25))
        keyField.placeholderString = "Click here, then press key combination..."
        keyField.isEditable = false  // Don't allow text editing, only capture
        keyField.isBezeled = true
        keyField.bezelStyle = .roundedBezel

        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 60))
        containerView.addSubview(actionPopup)
        containerView.addSubview(keyField)

        // Pre-fill if editing
        if let idx = index, idx < hotkeyData.count {
            if let action = hotkeyData[idx]["action"] as? String,
               let actionIndex = actions.firstIndex(of: action) {
                actionPopup.selectItem(at: actionIndex)
            }
            if let key = hotkeyData[idx]["key"] as? String {
                keyField.stringValue = key
            }
        }

        alert.accessoryView = containerView
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        // Make key field first responder after alert appears
        DispatchQueue.main.async {
            alert.window.makeFirstResponder(keyField)
        }

        if alert.runModal() == .alertFirstButtonReturn {
            // Validate that a key was captured
            guard !keyField.stringValue.isEmpty else {
                AccessibilityManager.announce("No key combination captured")
                return
            }

            let newHotkey: [String: Any] = [
                "action": actions[actionPopup.indexOfSelectedItem],
                "key": keyField.stringValue,
                "keyCode": keyField.capturedKeyCode,
                "modifiers": keyField.capturedModifiers.rawValue
            ]

            if let idx = index {
                hotkeyData[idx] = newHotkey
            } else {
                hotkeyData.append(newHotkey)
            }

            SettingsManager.shared.hotkeys = hotkeyData
            hotkeyTableView.reloadData()
            HotkeyManager.shared.reloadHotkeys()
        }
    }

    // MARK: - MIDI Tab

    private func addMIDITab() {
        let item = NSTabViewItem(identifier: "midi")
        item.label = "MIDI"

        let view = NSView()

        // SoundFont path
        let sfLabel = NSTextField(labelWithString: "SoundFont (.sf2/.sf3):")
        sfLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sfLabel)

        let sfField = NSTextField()
        sfField.translatesAutoresizingMaskIntoConstraints = false
        sfField.stringValue = SettingsManager.shared.midiSoundFont.isEmpty ? "(No SoundFont loaded)" : SettingsManager.shared.midiSoundFont
        sfField.isEditable = false
        sfField.tag = 600
        view.addSubview(sfField)

        let sfBrowseButton = NSButton(title: "Browse...", target: self, action: #selector(browseSoundFont(_:)))
        sfBrowseButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sfBrowseButton)

        // Max voices
        let voicesLabel = NSTextField(labelWithString: "Max voices (polyphony):")
        voicesLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(voicesLabel)

        let voicesField = NSTextField()
        voicesField.translatesAutoresizingMaskIntoConstraints = false
        voicesField.stringValue = "\(SettingsManager.shared.midiMaxVoices)"
        voicesField.tag = 601
        voicesField.target = self
        voicesField.action = #selector(midiVoicesChanged(_:))
        view.addSubview(voicesField)

        let voicesHint = NSTextField(labelWithString: "(1-1000, default 128)")
        voicesHint.translatesAutoresizingMaskIntoConstraints = false
        voicesHint.font = NSFont.systemFont(ofSize: 11)
        voicesHint.textColor = .secondaryLabelColor
        view.addSubview(voicesHint)

        // SINC interpolation
        let sincCheck = NSButton(checkboxWithTitle: "Use SINC interpolation (higher quality, more CPU)",
                                 target: self, action: #selector(midiSincChanged(_:)))
        sincCheck.translatesAutoresizingMaskIntoConstraints = false
        sincCheck.state = SettingsManager.shared.midiSincInterp ? .on : .off
        view.addSubview(sincCheck)

        // Help text
        let helpLabel = NSTextField(wrappingLabelWithString: "MIDI files require a SoundFont (.sf2 or .sf3) to play. You can download free SoundFonts from:\n\n• MuseScore General HQ SoundFont\n• FluidR3_GM\n• TimGM6mb (compact)")
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = NSFont.systemFont(ofSize: 11)
        helpLabel.textColor = .secondaryLabelColor
        view.addSubview(helpLabel)

        NSLayoutConstraint.activate([
            sfLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            sfLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            sfField.topAnchor.constraint(equalTo: sfLabel.bottomAnchor, constant: 5),
            sfField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sfField.trailingAnchor.constraint(equalTo: sfBrowseButton.leadingAnchor, constant: -10),

            sfBrowseButton.centerYAnchor.constraint(equalTo: sfField.centerYAnchor),
            sfBrowseButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            voicesLabel.topAnchor.constraint(equalTo: sfField.bottomAnchor, constant: 20),
            voicesLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            voicesField.centerYAnchor.constraint(equalTo: voicesLabel.centerYAnchor),
            voicesField.leadingAnchor.constraint(equalTo: voicesLabel.trailingAnchor, constant: 10),
            voicesField.widthAnchor.constraint(equalToConstant: 60),

            voicesHint.centerYAnchor.constraint(equalTo: voicesLabel.centerYAnchor),
            voicesHint.leadingAnchor.constraint(equalTo: voicesField.trailingAnchor, constant: 10),

            sincCheck.topAnchor.constraint(equalTo: voicesLabel.bottomAnchor, constant: 20),
            sincCheck.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            helpLabel.topAnchor.constraint(equalTo: sincCheck.bottomAnchor, constant: 30),
            helpLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            helpLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])

        item.view = view
        tabView.addTabViewItem(item)
    }

    // MARK: - MIDI Actions

    @objc private func browseSoundFont(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            UTType(filenameExtension: "sf2")!,
            UTType(filenameExtension: "sf3")!
        ]

        if panel.runModal() == .OK, let url = panel.url {
            SettingsManager.shared.midiSoundFont = url.path
            if let pathField = sender.superview?.viewWithTag(600) as? NSTextField {
                pathField.stringValue = url.path
            }
            // Apply MIDI settings immediately
            AudioEngine.shared.applyMidiSettings()
        }
    }

    @objc private func midiVoicesChanged(_ sender: NSTextField) {
        if let voices = Int(sender.stringValue), voices >= 1 && voices <= 1000 {
            SettingsManager.shared.midiMaxVoices = voices
            // Apply MIDI settings immediately
            AudioEngine.shared.applyMidiSettings()
        } else {
            // Reset to valid value
            sender.stringValue = "\(SettingsManager.shared.midiMaxVoices)"
        }
    }

    @objc private func midiSincChanged(_ sender: NSButton) {
        SettingsManager.shared.midiSincInterp = sender.state == .on
    }

    // MARK: - Audio Actions

    @objc private func audioDeviceChanged(_ sender: NSPopUpButton) {
        if let menuItem = sender.selectedItem {
            let deviceIndex = menuItem.tag
            // Actually switch the device now
            if AudioEngine.shared.changeDevice(deviceIndex) {
                AccessibilityManager.announce("Audio device changed to \(menuItem.title)")
            } else {
                AccessibilityManager.announce("Failed to change audio device")
                // Refresh combo to show current device
                populateAudioDevices(sender)
            }
        }
    }

    // MARK: - Helper Methods

    private func populateAudioDevices(_ combo: NSPopUpButton) {
        combo.removeAllItems()

        // Get BASS device info
        var deviceInfo = BASS_DEVICEINFO()
        var deviceIndex: Int32 = 1
        var currentSelection = 0

        while BASS_GetDeviceInfo(DWORD(deviceIndex), &deviceInfo) != 0 {
            if deviceInfo.flags & DWORD(BASS_DEVICE_ENABLED) != 0 {
                // Convert device name from C string to Swift String
                if let namePtr = deviceInfo.name {
                    let name = String(cString: namePtr)
                    combo.addItem(withTitle: name)

                    // Store device index as tag
                    let itemIndex = combo.numberOfItems - 1
                    combo.item(at: itemIndex)?.tag = Int(deviceIndex)

                    // Check if this is the current device
                    let isDefault = deviceInfo.flags & DWORD(BASS_DEVICE_DEFAULT) != 0
                    if deviceIndex == SettingsManager.shared.selectedDevice ||
                       (SettingsManager.shared.selectedDevice == -1 && isDefault) {
                        currentSelection = itemIndex
                    }
                }
            }
            deviceIndex += 1
        }

        combo.selectItem(at: currentSelection)
    }

    // MARK: - Show

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NSTableViewDelegate & NSTableViewDataSource

extension PreferencesWindowController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return hotkeyData.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < hotkeyData.count else { return nil }

        let cellIdentifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")
        let textField = NSTextField()
        textField.isEditable = false
        textField.isBordered = false
        textField.backgroundColor = .clear

        if cellIdentifier.rawValue == "action" {
            textField.stringValue = (hotkeyData[row]["action"] as? String) ?? ""
        } else if cellIdentifier.rawValue == "key" {
            textField.stringValue = (hotkeyData[row]["key"] as? String) ?? ""
        }

        return textField
    }
}
