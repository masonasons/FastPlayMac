//
//  PlaylistWindowController.swift
//  FastPlay
//
//  Playlist Manager dialog - view and manage current playlist
//

import AppKit

class PlaylistWindowController: NSWindowController {

    // MARK: - Singleton

    static let shared = PlaylistWindowController()

    // MARK: - UI Elements

    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var helpLabel: NSTextField!

    // MARK: - Initialization

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Playlist Manager"
        window.center()
        window.minSize = NSSize(width: 400, height: 300)

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let window = window, let contentView = window.contentView else { return }

        // Table view setup
        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        tableView.doubleAction = #selector(doubleClickRow)
        tableView.target = self

        // Single column for track names
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("track"))
        column.title = "Track"
        column.width = 450
        column.minWidth = 200
        tableView.addTableColumn(column)

        tableView.headerView = nil  // Hide header

        // Scroll view
        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        contentView.addSubview(scrollView)

        // Help label
        helpLabel = NSTextField(labelWithString: "⌥↑/↓: Move  |  ⌫: Remove  |  ⏎: Play  |  ⌘V: Paste  |  Esc: Close")
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = NSFont.systemFont(ofSize: 11)
        helpLabel.textColor = .secondaryLabelColor
        contentView.addSubview(helpLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: helpLabel.topAnchor, constant: -10),

            helpLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            helpLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            helpLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])

        // Set up keyboard handling
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.window?.isKeyWindow == true else {
                return event
            }
            if self.handleKeyDown(event) {
                return nil
            }
            return event
        }
    }

    // MARK: - Actions

    @objc private func doubleClickRow() {
        let row = tableView.clickedRow
        if row >= 0 {
            PlaylistManager.shared.playTrack(at: row)
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .control, .option])

        // Command+W = Close
        if event.keyCode == 13 && event.modifierFlags.contains(.command) {
            window?.close()
            return true
        }

        // Escape = Close
        if event.keyCode == 53 {
            window?.close()
            return true
        }

        // Enter = Play selected
        if event.keyCode == 36 && flags.isEmpty {
            if tableView.selectedRow >= 0 {
                PlaylistManager.shared.playTrack(at: tableView.selectedRow)
            }
            return true
        }

        // Delete/Backspace = Remove selected
        if event.keyCode == 51 && flags.isEmpty {
            removeSelectedTracks()
            return true
        }

        // Option+Up = Move up
        if event.keyCode == 126 && flags == .option {
            moveSelectedTracks(up: true)
            return true
        }

        // Option+Down = Move down
        if event.keyCode == 125 && flags == .option {
            moveSelectedTracks(up: false)
            return true
        }

        // Cmd+V = Paste
        if event.keyCode == 9 && flags == .command {
            pasteFromClipboard()
            return true
        }

        // Cmd+A = Select all
        if event.keyCode == 0 && flags == .command {
            tableView.selectAll(nil)
            return true
        }

        return false
    }

    private func removeSelectedTracks() {
        let indices = tableView.selectedRowIndexes.sorted(by: >)  // Remove from end first
        for index in indices {
            PlaylistManager.shared.removeTrack(at: index)
        }
        tableView.reloadData()
    }

    private func moveSelectedTracks(up: Bool) {
        guard tableView.selectedRowIndexes.count == 1 else { return }
        let index = tableView.selectedRow
        let newIndex = up ? index - 1 : index + 1

        if PlaylistManager.shared.moveTrack(from: index, to: newIndex) {
            tableView.reloadData()
            tableView.selectRowIndexes(IndexSet(integer: newIndex), byExtendingSelection: false)
        }
    }

    private func pasteFromClipboard() {
        guard let pasteboard = NSPasteboard.general.string(forType: .string) else { return }

        let lines = pasteboard.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                PlaylistManager.shared.addURL(trimmed)
            } else if FileManager.default.fileExists(atPath: trimmed) {
                PlaylistManager.shared.addFile(trimmed)
            }
        }
        tableView.reloadData()
    }

    // MARK: - Show

    func show() {
        tableView.reloadData()

        // Select current track
        let current = PlaylistManager.shared.currentIndex
        if current >= 0 && current < PlaylistManager.shared.count {
            tableView.selectRowIndexes(IndexSet(integer: current), byExtendingSelection: false)
            tableView.scrollRowToVisible(current)
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Table View Data Source & Delegate

extension PlaylistWindowController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return PlaylistManager.shared.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("TrackCell")

        var cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField
        if cell == nil {
            cell = NSTextField(labelWithString: "")
            cell?.identifier = identifier
            cell?.lineBreakMode = .byTruncatingMiddle
        }

        if let name = PlaylistManager.shared.trackName(at: row) {
            let isCurrent = row == PlaylistManager.shared.currentIndex
            cell?.stringValue = isCurrent ? "▶ \(name)" : name
            cell?.font = isCurrent ? NSFont.boldSystemFont(ofSize: 13) : NSFont.systemFont(ofSize: 13)
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 22
    }
}
