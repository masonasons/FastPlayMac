//
//  BookmarksWindowController.swift
//  FastPlay
//
//  Bookmarks dialog - view and manage saved bookmarks
//

import AppKit

class BookmarksWindowController: NSWindowController {

    // MARK: - Singleton

    static let shared = BookmarksWindowController()

    // MARK: - UI Elements

    private var tableView: NSTableView!
    private var bookmarks: [Bookmark] = []

    // MARK: - Initialization

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Bookmarks"
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
        tableView.doubleAction = #selector(loadSelectedBookmark)
        tableView.target = self

        // Columns
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 150
        tableView.addTableColumn(nameColumn)

        let fileColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        fileColumn.title = "File"
        fileColumn.width = 250
        tableView.addTableColumn(fileColumn)

        let posColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("position"))
        posColumn.title = "Position"
        posColumn.width = 80
        tableView.addTableColumn(posColumn)

        // Scroll view
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        contentView.addSubview(scrollView)

        // Buttons
        let deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteSelected))
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(deleteButton)

        let loadButton = NSButton(title: "Load", target: self, action: #selector(loadSelectedBookmark))
        loadButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(loadButton)

        // Help label
        let helpLabel = NSTextField(labelWithString: "Enter = load, Delete = remove, Escape = close")
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
            helpLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            loadButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            loadButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            deleteButton.trailingAnchor.constraint(equalTo: loadButton.leadingAnchor, constant: -10),
            deleteButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])

        // Keyboard handling
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

    @objc private func loadSelectedBookmark() {
        let row = tableView.selectedRow
        guard row >= 0 && row < bookmarks.count else { return }

        let bookmark = bookmarks[row]

        // Check if file exists
        guard FileManager.default.fileExists(atPath: bookmark.filepath) else {
            AccessibilityManager.announce("File not found")
            return
        }

        // Load and seek
        PlaylistManager.shared.clear()
        PlaylistManager.shared.addFile(bookmark.filepath)
        PlaylistManager.shared.playTrack(at: 0)

        // Seek to position after a short delay to ensure playback started
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            AudioEngine.shared.seek(to: bookmark.position)
        }

        window?.close()
    }

    @objc private func deleteSelected() {
        let row = tableView.selectedRow
        guard row >= 0 && row < bookmarks.count else { return }

        if let id = bookmarks[row].id {
            DatabaseManager.shared.deleteBookmark(id: id)
            loadBookmarks()
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
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

        // Enter = Load selected
        if event.keyCode == 36 {
            loadSelectedBookmark()
            return true
        }

        // Delete = Remove selected
        if event.keyCode == 51 {
            deleteSelected()
            return true
        }

        return false
    }

    // MARK: - Data Loading

    private func loadBookmarks() {
        bookmarks = DatabaseManager.shared.getBookmarks()
        tableView.reloadData()
    }

    // MARK: - Show

    func show() {
        loadBookmarks()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Add Bookmark

    static func addBookmark(name: String? = nil) {
        guard let path = PlaylistManager.shared.currentTrackPath else {
            AccessibilityManager.announce("No file loaded")
            return
        }

        let position = AudioEngine.shared.currentPosition
        let displayName = name ?? PlaylistManager.shared.currentTrackName ?? "Bookmark"

        _ = DatabaseManager.shared.addBookmark(name: displayName, filepath: path, position: position)
        AccessibilityManager.announce("Bookmark added at \(AccessibilityManager.formatTimeDisplay(position))")
    }
}

// MARK: - Table View Data Source & Delegate

extension BookmarksWindowController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return bookmarks.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("cell")

        var cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField
        if cell == nil {
            cell = NSTextField(labelWithString: "")
            cell?.identifier = identifier
            cell?.lineBreakMode = .byTruncatingMiddle
        }

        let bookmark = bookmarks[row]

        switch identifier.rawValue {
        case "name":
            cell?.stringValue = bookmark.name
        case "file":
            cell?.stringValue = URL(fileURLWithPath: bookmark.filepath).lastPathComponent
        case "position":
            cell?.stringValue = AccessibilityManager.formatTimeDisplay(bookmark.position)
        default:
            break
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 22
    }
}
