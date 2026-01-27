//
//  SchedulerWindowController.swift
//  FastPlay
//
//  Scheduler dialog - manage scheduled playback/recording events
//

import AppKit

class SchedulerWindowController: NSWindowController {

    // MARK: - Singleton

    static let shared = SchedulerWindowController()

    // MARK: - UI Elements

    private var tableView: NSTableView!
    private var events: [ScheduledEvent] = []

    // MARK: - Initialization

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Scheduler"
        window.center()
        window.minSize = NSSize(width: 450, height: 300)

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let window = window, let contentView = window.contentView else { return }

        // Help label at top
        let helpLabel = NSTextField(labelWithString: "Scheduled events (Enter = toggle, Delete = remove, Escape = close):")
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(helpLabel)

        // Table view setup
        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(toggleSelectedEvent)
        tableView.target = self

        // Columns
        let enabledColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled"))
        enabledColumn.title = "On"
        enabledColumn.width = 30
        tableView.addTableColumn(enabledColumn)

        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 150
        tableView.addTableColumn(nameColumn)

        let timeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeColumn.title = "Time"
        timeColumn.width = 80
        tableView.addTableColumn(timeColumn)

        let daysColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("days"))
        daysColumn.title = "Days"
        daysColumn.width = 150
        tableView.addTableColumn(daysColumn)

        let fileColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        fileColumn.title = "File/URL"
        fileColumn.width = 200
        tableView.addTableColumn(fileColumn)

        // Scroll view
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        contentView.addSubview(scrollView)

        // Buttons
        let addButton = NSButton(title: "Add...", target: self, action: #selector(addEvent))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addButton)

        let deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteSelected))
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            helpLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            helpLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),

            scrollView.topAnchor.constraint(equalTo: helpLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -10),

            addButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            addButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            deleteButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 10),
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

    @objc private func addEvent() {
        let alert = NSAlert()
        alert.messageText = "Add Scheduled Event"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10

        // Name field
        let nameLabel = NSTextField(labelWithString: "Name:")
        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        nameField.placeholderString = "Event name"

        // Time picker
        let timeLabel = NSTextField(labelWithString: "Time:")
        let timePicker = NSDatePicker(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
        timePicker.datePickerMode = .single
        timePicker.datePickerElements = .hourMinute
        timePicker.dateValue = Date()

        // Days checkboxes
        let daysLabel = NSTextField(labelWithString: "Days:")
        let daysStack = NSStackView()
        daysStack.orientation = .horizontal
        daysStack.spacing = 5

        let dayNames = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        var dayChecks: [NSButton] = []
        for (i, day) in dayNames.enumerated() {
            let check = NSButton(checkboxWithTitle: day, target: nil, action: nil)
            check.tag = i
            check.state = (i >= 1 && i <= 5) ? .on : .off  // Weekdays by default
            dayChecks.append(check)
            daysStack.addArrangedSubview(check)
        }

        // File/URL field
        let fileLabel = NSTextField(labelWithString: "File/URL:")
        let fileField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        fileField.placeholderString = "Path to audio file or stream URL"

        let browseButton = NSButton(title: "Browse...", target: nil, action: nil)

        stackView.addArrangedSubview(nameLabel)
        stackView.addArrangedSubview(nameField)
        stackView.addArrangedSubview(timeLabel)
        stackView.addArrangedSubview(timePicker)
        stackView.addArrangedSubview(daysLabel)
        stackView.addArrangedSubview(daysStack)
        stackView.addArrangedSubview(fileLabel)
        stackView.addArrangedSubview(fileField)
        stackView.addArrangedSubview(browseButton)

        stackView.frame = NSRect(x: 0, y: 0, width: 350, height: 250)
        alert.accessoryView = stackView

        // Browse button action
        browseButton.target = self
        browseButton.action = #selector(browseForFile(_:))
        browseButton.tag = Int(bitPattern: Unmanaged.passUnretained(fileField).toOpaque())

        if alert.runModal() == .alertFirstButtonReturn {
            let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
            let filePath = fileField.stringValue.trimmingCharacters(in: .whitespaces)

            guard !name.isEmpty && !filePath.isEmpty else { return }

            // Get time components
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: timePicker.dateValue)
            let minute = calendar.component(.minute, from: timePicker.dateValue)

            // Get days string (e.g., "0,1,2,3,4" for weekdays)
            var selectedDays: [Int] = []
            for check in dayChecks {
                if check.state == .on {
                    selectedDays.append(check.tag)
                }
            }
            let daysStr = selectedDays.map { String($0) }.joined(separator: ",")

            let event = ScheduledEvent(
                id: nil,
                name: name,
                filepath: filePath,
                hour: hour,
                minute: minute,
                days: daysStr,
                enabled: true
            )

            DatabaseManager.shared.saveScheduledEvent(event)
            loadEvents()
        }
    }

    @objc private func browseForFile(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            // Find the text field using the tag (pointer to the field)
            if let ptr = UnsafeMutableRawPointer(bitPattern: sender.tag) {
                let field = Unmanaged<NSTextField>.fromOpaque(ptr).takeUnretainedValue()
                field.stringValue = url.path
            }
        }
    }

    @objc private func toggleSelectedEvent() {
        let row = tableView.selectedRow
        guard row >= 0 && row < events.count else { return }

        var event = events[row]
        event.enabled = !event.enabled
        DatabaseManager.shared.saveScheduledEvent(event)
        loadEvents()
    }

    @objc private func deleteSelected() {
        let row = tableView.selectedRow
        guard row >= 0 && row < events.count else { return }

        if let id = events[row].id {
            DatabaseManager.shared.deleteScheduledEvent(id: id)
            loadEvents()
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

        // Enter = Toggle selected
        if event.keyCode == 36 {
            toggleSelectedEvent()
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

    private func loadEvents() {
        events = DatabaseManager.shared.getAllScheduledEvents()
        tableView.reloadData()
    }

    // MARK: - Show

    func show() {
        loadEvents()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Helpers

    private func formatDays(_ daysStr: String) -> String {
        let dayNames = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        let indices = daysStr.split(separator: ",").compactMap { Int($0) }

        if indices.count == 7 {
            return "Every day"
        } else if indices == [1, 2, 3, 4, 5] {
            return "Weekdays"
        } else if indices == [0, 6] {
            return "Weekends"
        } else {
            return indices.map { dayNames[$0] }.joined(separator: ", ")
        }
    }
}

// MARK: - Table View Data Source & Delegate

extension SchedulerWindowController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return events.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("cell")

        var cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField
        if cell == nil {
            cell = NSTextField(labelWithString: "")
            cell?.identifier = identifier
            cell?.lineBreakMode = .byTruncatingTail
        }

        let event = events[row]

        switch identifier.rawValue {
        case "enabled":
            cell?.stringValue = event.enabled ? "✓" : ""
            cell?.alignment = .center
        case "name":
            cell?.stringValue = event.name
        case "time":
            cell?.stringValue = event.time
        case "days":
            cell?.stringValue = formatDays(event.days)
        case "file":
            cell?.stringValue = URL(fileURLWithPath: event.filepath).lastPathComponent
        default:
            break
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 22
    }
}
