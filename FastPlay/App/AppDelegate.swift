//
//  AppDelegate.swift
//  FastPlay
//
//  Main application delegate handling app lifecycle and menu setup
//

import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    var mainWindowController: MainWindowController?
    var statusBarController: StatusBarController?

    // Timer for UI updates
    private var updateTimer: Timer?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize settings first
        SettingsManager.shared.load()

        // Initialize BASS audio engine
        guard AudioEngine.shared.initialize() else {
            let alert = NSAlert()
            alert.messageText = "Audio Initialization Failed"
            alert.informativeText = "Failed to initialize the audio engine. Please check your audio device."
            alert.alertStyle = .critical
            alert.runModal()
            NSApp.terminate(nil)
            return
        }

        // Initialize database
        DatabaseManager.shared.initialize()

        // Create main window
        mainWindowController = MainWindowController()
        mainWindowController?.showWindow(nil)

        // Set up status bar if enabled
        if SettingsManager.shared.minimizeToTray {
            statusBarController = StatusBarController()
        }

        // Set up global hotkeys
        HotkeyManager.shared.registerHotkeys()

        // Start UI update timer (matches Windows UPDATE_INTERVAL = 250ms)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.mainWindowController?.updateUI()
        }

        // Restore playback state if enabled
        if SettingsManager.shared.rememberState {
            if let state = SettingsManager.shared.restorePlaybackState() {
                PlaylistManager.shared.addFile(state.path)
                if PlaylistManager.shared.count > 0 {
                    // Load and seek to saved position, then start playback
                    PlaylistManager.shared.loadTrack(at: 0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        AudioEngine.shared.seek(to: state.position)
                        AudioEngine.shared.play()
                    }
                }
            }
        }

        // Files passed on launch are handled by application(_:openFiles:)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop update timer
        updateTimer?.invalidate()
        updateTimer = nil

        // Save settings
        SettingsManager.shared.save()

        // Save position if enabled
        if SettingsManager.shared.rememberState {
            SettingsManager.shared.savePlaybackState()
        }

        // Stop playback and free resources
        AudioEngine.shared.stop()
        AudioEngine.shared.shutdown()

        // Free DSP processors
        DSP_FreeCenterCancelProcessor()

        // Unregister hotkeys
        HotkeyManager.shared.unregisterAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when window closes if minimize to tray is enabled
        return !SettingsManager.shared.minimizeToTray
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Show main window when clicking dock icon
        if !flag {
            mainWindowController?.showWindow(nil)
        }
        return true
    }

    // MARK: - File Handling

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        handleOpenURLs(urls)
        sender.reply(toOpenOrPrint: .success)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        handleOpenURLs(urls)
    }

    private func handleOpenURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        // Clear playlist and add all files
        PlaylistManager.shared.clear()

        // Check if we should load entire folder when opening a single file
        if urls.count == 1 && urls[0].isFileURL && SettingsManager.shared.loadFolder {
            let fileURL = urls[0]
            let folderURL = fileURL.deletingLastPathComponent()

            // Load only audio files from the immediate folder (not recursive)
            let supportedExtensions = ["mp3", "wav", "ogg", "flac", "m4a", "aac", "opus", "wma", "aiff", "ape", "wv", "mid", "midi"]
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: folderURL.path) {
                var files: [String] = []
                for file in contents {
                    let ext = (file as NSString).pathExtension.lowercased()
                    if supportedExtensions.contains(ext) {
                        let fullPath = (folderURL.path as NSString).appendingPathComponent(file)
                        files.append(fullPath)
                    }
                }
                // Sort alphabetically
                files.sort { $0.localizedStandardCompare($1) == .orderedAscending }
                for file in files {
                    PlaylistManager.shared.addFile(file)
                }
            }

            // Find and select the originally requested file
            let targetPath = fileURL.path
            if let index = PlaylistManager.shared.tracks.firstIndex(of: targetPath) {
                PlaylistManager.shared.playTrack(at: index)
            } else if PlaylistManager.shared.count > 0 {
                PlaylistManager.shared.playTrack(at: 0)
            }
        } else {
            // Normal behavior - add only the specified files
            for url in urls {
                if url.isFileURL {
                    PlaylistManager.shared.addFile(url.path)
                } else {
                    PlaylistManager.shared.addURL(url.absoluteString)
                }
            }

            // Start playing first track
            if PlaylistManager.shared.count > 0 {
                PlaylistManager.shared.playTrack(at: 0)
            }
        }
    }

    // MARK: - Menu Actions

    @IBAction func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = AudioEngine.supportedFileTypes

        panel.begin { [weak self] response in
            guard response == .OK else { return }
            self?.handleOpenURLs(panel.urls)
        }
    }

    @IBAction func addFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            PlaylistManager.shared.addFolder(url.path)
        }
    }

    @IBAction func openURL(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Open URL"
        alert.informativeText = "Enter the URL of the audio stream:"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "https://..."
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let urlString = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !urlString.isEmpty {
                PlaylistManager.shared.clear()
                PlaylistManager.shared.addURL(urlString)
                PlaylistManager.shared.playTrack(at: 0)
            }
        }
    }

    @IBAction func showPlaylist(_ sender: Any?) {
        PlaylistWindowController.shared.show()
    }

    @IBAction func showYouTube(_ sender: Any?) {
        // TODO: Implement YouTube window (requires yt-dlp integration)
        AccessibilityManager.announce("YouTube not yet implemented")
    }

    @IBAction func showRadio(_ sender: Any?) {
        RadioWindowController.shared.show()
    }

    @IBAction func showPodcasts(_ sender: Any?) {
        PodcastWindowController.shared.show()
    }

    @IBAction func showScheduler(_ sender: Any?) {
        SchedulerWindowController.shared.show()
    }

    @IBAction func showBookmarks(_ sender: Any?) {
        BookmarksWindowController.shared.show()
    }

    @IBAction func showPreferences(_ sender: Any?) {
        PreferencesWindowController.shared.show()
    }

    @IBAction func showLoadedPlugins(_ sender: Any?) {
        var pluginInfo = "Loaded BASS Plugins:\n\n"
        pluginInfo += AudioEngine.shared.getLoadedPlugins()

        let alert = NSAlert()
        alert.messageText = "Loaded Plugins"
        alert.informativeText = pluginInfo
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Playback Actions

    @IBAction func playPause(_ sender: Any?) {
        AudioEngine.shared.togglePlayPause()
    }

    @IBAction func play(_ sender: Any?) {
        AudioEngine.shared.play()
    }

    @IBAction func pause(_ sender: Any?) {
        AudioEngine.shared.pause()
    }

    @IBAction func stop(_ sender: Any?) {
        AudioEngine.shared.stop()
    }

    @IBAction func previousTrack(_ sender: Any?) {
        PlaylistManager.shared.previous()
    }

    @IBAction func nextTrack(_ sender: Any?) {
        PlaylistManager.shared.next()
    }

    @IBAction func seekBackward(_ sender: Any?) {
        let amount = SettingsManager.shared.currentSeekAmount
        AudioEngine.shared.seek(by: -amount)
    }

    @IBAction func seekForward(_ sender: Any?) {
        let amount = SettingsManager.shared.currentSeekAmount
        AudioEngine.shared.seek(by: amount)
    }

    @IBAction func seekToBeginning(_ sender: Any?) {
        AudioEngine.shared.seek(to: 0)
    }

    @IBAction func jumpToTime(_ sender: Any?) {
        JumpToTimeWindowController.shared.show()
    }

    @IBAction func toggleShuffle(_ sender: Any?) {
        SettingsManager.shared.shuffle.toggle()
        if SettingsManager.shared.speechEffect {
            let state = SettingsManager.shared.shuffle ? "Shuffle on" : "Shuffle off"
            AccessibilityManager.announce(state)
        }
    }

    @IBAction func volumeUp(_ sender: Any?) {
        AudioEngine.shared.adjustVolume(by: SettingsManager.shared.volumeStep)
    }

    @IBAction func volumeDown(_ sender: Any?) {
        AudioEngine.shared.adjustVolume(by: -SettingsManager.shared.volumeStep)
    }

    @IBAction func toggleMute(_ sender: Any?) {
        AudioEngine.shared.toggleMute()
    }

    @IBAction func toggleRecording(_ sender: Any?) {
        RecordingManager.shared.toggleRecording()
    }

    @IBAction func addBookmark(_ sender: Any?) {
        BookmarksWindowController.addBookmark()
    }
}
