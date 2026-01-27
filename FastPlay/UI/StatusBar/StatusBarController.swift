//
//  StatusBarController.swift
//  FastPlay
//
//  Menu bar status item (replaces Windows system tray)
//

import AppKit

class StatusBarController {

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    // MARK: - Initialization

    init() {
        setupStatusItem()
    }

    deinit {
        removeStatusItem()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: "FastPlay")
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        buildMenu()
    }

    private func removeStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    private func buildMenu() {
        menu = NSMenu()

        // Show/Hide Window
        let showItem = NSMenuItem(title: "Show Window", action: #selector(showWindow), keyEquivalent: "")
        showItem.target = self
        menu?.addItem(showItem)

        menu?.addItem(NSMenuItem.separator())

        // Playback controls
        let playItem = NSMenuItem(title: "Play", action: #selector(play), keyEquivalent: "")
        playItem.target = self
        menu?.addItem(playItem)

        let pauseItem = NSMenuItem(title: "Pause", action: #selector(pause), keyEquivalent: "")
        pauseItem.target = self
        menu?.addItem(pauseItem)

        let stopItem = NSMenuItem(title: "Stop", action: #selector(stop), keyEquivalent: "")
        stopItem.target = self
        menu?.addItem(stopItem)

        menu?.addItem(NSMenuItem.separator())

        let prevItem = NSMenuItem(title: "Previous", action: #selector(previous), keyEquivalent: "")
        prevItem.target = self
        menu?.addItem(prevItem)

        let nextItem = NSMenuItem(title: "Next", action: #selector(next), keyEquivalent: "")
        nextItem.target = self
        menu?.addItem(nextItem)

        menu?.addItem(NSMenuItem.separator())

        // Volume submenu
        let volumeSubmenu = NSMenu()
        for vol in stride(from: 100, through: 0, by: -10) {
            let volItem = NSMenuItem(title: "\(vol)%", action: #selector(setVolume(_:)), keyEquivalent: "")
            volItem.target = self
            volItem.tag = vol
            volumeSubmenu.addItem(volItem)
        }
        let volumeItem = NSMenuItem(title: "Volume", action: nil, keyEquivalent: "")
        volumeItem.submenu = volumeSubmenu
        menu?.addItem(volumeItem)

        menu?.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit FastPlay", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu?.addItem(quitItem)
    }

    // MARK: - Actions

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right click - show menu
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil  // Reset so left click works
        } else {
            // Left click - toggle window
            showWindow()
        }
    }

    @objc private func showWindow() {
        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.mainWindowController?.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func play() {
        AudioEngine.shared.play()
        updateIcon()
    }

    @objc private func pause() {
        AudioEngine.shared.pause()
        updateIcon()
    }

    @objc private func stop() {
        AudioEngine.shared.stop()
        updateIcon()
    }

    @objc private func previous() {
        PlaylistManager.shared.previous()
    }

    @objc private func next() {
        PlaylistManager.shared.next()
    }

    @objc private func setVolume(_ sender: NSMenuItem) {
        let vol = Float(sender.tag) / 100.0
        AudioEngine.shared.setVolume(vol)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Updates

    func updateIcon() {
        guard let button = statusItem?.button else { return }

        let symbolName: String
        switch AudioEngine.shared.state {
        case .playing:
            symbolName = "play.circle.fill"
        case .paused:
            symbolName = "pause.circle"
        case .stalled:
            symbolName = "arrow.clockwise.circle"
        case .stopped:
            symbolName = "play.circle"
        }

        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "FastPlay")
    }

    func updateTooltip() {
        guard let button = statusItem?.button else { return }

        var tooltip = "FastPlay"

        if let name = PlaylistManager.shared.currentTrackName {
            tooltip += " - \(name)"
        }

        switch AudioEngine.shared.state {
        case .playing:
            tooltip += " (Playing)"
        case .paused:
            tooltip += " (Paused)"
        case .stalled:
            tooltip += " (Buffering)"
        case .stopped:
            break
        }

        button.toolTip = tooltip
    }
}
