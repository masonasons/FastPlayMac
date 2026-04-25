//
//  SongHistoryWindowController.swift
//  FastPlay
//
//  Song History dialog - displays recent stream titles captured from radio metadata.
//  Mirrors the Windows "Song History" dialog (IDD_SONG_HISTORY).
//

import AppKit

class SongHistoryWindowController: NSWindowController {

    // MARK: - Singleton

    static let shared = SongHistoryWindowController()

    // MARK: - UI Elements

    private var tableView: NSTableView!
    private var entries: [SongHistoryEntry] = []

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .medium
        return f
    }()

    // MARK: - Initialization

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Song History"
        window.center()
        window.minSize = NSSize(width: 400, height: 300)

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let window = window, let contentView = window.contentView else { return }

        let headerLabel = NSTextField(labelWithString: "Recent songs captured from stream metadata (Cmd+C to copy):")
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.font = NSFont.systemFont(ofSize: 12)
        contentView.addSubview(headerLabel)

        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = true
        tableView.usesAlternatingRowBackgroundColors = true

        let whenColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("when"))
        whenColumn.title = "When"
        whenColumn.width = 140
        tableView.addTableColumn(whenColumn)

        let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        titleColumn.title = "Title"
        titleColumn.width = 380
        tableView.addTableColumn(titleColumn)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        contentView.addSubview(scrollView)

        let copyButton = NSButton(title: "Copy", target: self, action: #selector(copySelected))
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(copyButton)

        let clearButton = NSButton(title: "Clear", target: self, action: #selector(clearAll))
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(clearButton)

        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.keyEquivalent = "\r"
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            headerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),

            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -10),

            copyButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            copyButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            clearButton.leadingAnchor.constraint(equalTo: copyButton.trailingAnchor, constant: 10),
            clearButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])

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

    @objc private func copySelected() {
        let rows = tableView.selectedRowIndexes
        let source: [SongHistoryEntry]
        if rows.isEmpty {
            source = entries
        } else {
            source = rows.compactMap { entries.indices.contains($0) ? entries[$0] : nil }
        }
        guard !source.isEmpty else { return }

        let text = source.map { $0.title }.joined(separator: "\n")
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        AccessibilityManager.announce("Copied \(source.count) \(source.count == 1 ? "entry" : "entries")")
    }

    @objc private func clearAll() {
        guard !entries.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Clear song history?"
        alert.informativeText = "This will remove all \(entries.count) recorded entries."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            DatabaseManager.shared.clearSongHistory()
            reload()
            AccessibilityManager.announce("Song history cleared")
        }
    }

    @objc private func closeWindow() {
        window?.close()
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        // Cmd+W or Escape = close
        if event.keyCode == 53 || (event.keyCode == 13 && event.modifierFlags.contains(.command)) {
            closeWindow()
            return true
        }
        // Cmd+C = copy selection
        if event.keyCode == 8 && event.modifierFlags.contains(.command) {
            copySelected()
            return true
        }
        return false
    }

    // MARK: - Data Loading

    private func reload() {
        entries = DatabaseManager.shared.getSongHistory()
        tableView.reloadData()
    }

    // MARK: - Show

    func show() {
        reload()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Table View Data Source & Delegate

extension SongHistoryWindowController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return entries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("cell")

        var cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField
        if cell == nil {
            cell = NSTextField(labelWithString: "")
            cell?.identifier = identifier
            cell?.lineBreakMode = .byTruncatingTail
        }

        let entry = entries[row]

        switch identifier.rawValue {
        case "when":
            cell?.stringValue = SongHistoryWindowController.timestampFormatter.string(from: entry.date)
        case "title":
            cell?.stringValue = entry.title
        default:
            break
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 22
    }
}
