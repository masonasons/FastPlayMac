//
//  SchedulerWindowController.swift
//  FastPlay
//
//  Scheduler dialog — manage scheduled playback/recording events.
//  Mirrors Windows IDD_SCHEDULER + IDD_SCHED_ADD.
//

import AppKit

class SchedulerWindowController: NSWindowController {

    static let shared = SchedulerWindowController()

    private var tableView: NSTableView!
    private var events: [ScheduledEvent] = []

    // Holds the active editor sheet — NSControl.target is weak, so without
    // a strong reference the editor deallocates and clicks beep.
    private var activeEditor: SchedulerEditorController?

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Scheduler"
        window.center()
        window.minSize = NSSize(width: 480, height: 320)

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let window = window, let contentView = window.contentView else { return }

        let helpLabel = NSTextField(labelWithString: "Scheduled events (Enter = toggle, Delete = remove, Escape = close):")
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(helpLabel)

        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(toggleSelectedEvent)
        tableView.target = self
        tableView.usesAlternatingRowBackgroundColors = true

        addColumn("enabled", title: "On", width: 36)
        addColumn("name", title: "Name", width: 130)
        addColumn("action", title: "Action", width: 90)
        addColumn("time", title: "Time", width: 130)
        addColumn("repeat", title: "Repeat", width: 80)
        addColumn("duration", title: "Duration", width: 70)
        addColumn("source", title: "Source", width: 220)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        contentView.addSubview(scrollView)

        let addButton = NSButton(title: "Add...", target: self, action: #selector(addEvent))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addButton)

        let editButton = NSButton(title: "Edit...", target: self, action: #selector(editSelected))
        editButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(editButton)

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

            editButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 8),
            editButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            deleteButton.leadingAnchor.constraint(equalTo: editButton.trailingAnchor, constant: 8),
            deleteButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.window?.isKeyWindow == true else { return event }
            if self.handleKeyDown(event) { return nil }
            return event
        }
    }

    private func addColumn(_ ident: String, title: String, width: CGFloat) {
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(ident))
        col.title = title
        col.width = width
        tableView.addTableColumn(col)
    }

    // MARK: - Actions

    @objc private func addEvent() {
        guard let parent = window else { return }
        let editor = SchedulerEditorController(event: nil)
        activeEditor = editor
        editor.run(parent: parent) { [weak self] saved in
            self?.activeEditor = nil
            guard let saved = saved else { return }
            DatabaseManager.shared.addScheduledEvent(saved)
            self?.loadEvents()
        }
    }

    @objc private func editSelected() {
        let row = tableView.selectedRow
        guard row >= 0 && row < events.count else {
            AccessibilityManager.announce("No schedule selected")
            return
        }
        guard let parent = window else { return }
        let editor = SchedulerEditorController(event: events[row])
        activeEditor = editor
        editor.run(parent: parent) { [weak self] saved in
            self?.activeEditor = nil
            guard let saved = saved else { return }
            DatabaseManager.shared.updateScheduledEvent(saved)
            self?.loadEvents()
        }
    }

    @objc private func toggleSelectedEvent() {
        let row = tableView.selectedRow
        guard row >= 0 && row < events.count else { return }
        let event = events[row]
        guard let id = event.id else { return }
        DatabaseManager.shared.setScheduledEventEnabled(id: id, enabled: !event.enabled)
        AccessibilityManager.announce(event.enabled ? "Disabled" : "Enabled")
        loadEvents()
    }

    @objc private func deleteSelected() {
        let row = tableView.selectedRow
        guard row >= 0 && row < events.count else { return }
        if let id = events[row].id {
            DatabaseManager.shared.deleteScheduledEvent(id: id)
            AccessibilityManager.announce("Schedule removed")
            loadEvents()
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        if event.keyCode == 13 && event.modifierFlags.contains(.command) {
            window?.close(); return true
        }
        if event.keyCode == 53 {  // Escape
            window?.close(); return true
        }
        if event.keyCode == 36 {  // Return
            toggleSelectedEvent(); return true
        }
        if event.keyCode == 51 {  // Delete
            deleteSelected(); return true
        }
        return false
    }

    private func loadEvents() {
        events = DatabaseManager.shared.getAllScheduledEvents()
        tableView.reloadData()
    }

    func show() {
        loadEvents()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension SchedulerWindowController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int { events.count }

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
            cell?.stringValue = event.enabled ? "Yes" : "No"
        case "name":
            cell?.stringValue = event.name
        case "action":
            cell?.stringValue = event.action.displayName
        case "time":
            let f = DateFormatter()
            f.dateStyle = .short
            f.timeStyle = .short
            cell?.stringValue = f.string(from: Date(timeIntervalSince1970: TimeInterval(event.scheduledTime)))
        case "repeat":
            cell?.stringValue = event.repeatType.displayName
        case "duration":
            cell?.stringValue = event.duration > 0 ? "\(event.duration) min" : "—"
        case "source":
            if event.sourceType == .file {
                cell?.stringValue = (event.sourcePath as NSString).lastPathComponent
            } else {
                cell?.stringValue = event.sourcePath
            }
        default:
            cell?.stringValue = ""
        }
        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 22 }
}

// MARK: - Add/Edit dialog

private class SchedulerEditorController: NSObject {

    private let editingEvent: ScheduledEvent?
    private var completion: ((ScheduledEvent?) -> Void)?

    private var window: NSWindow!
    private var nameField: NSTextField!
    private var actionPopup: NSPopUpButton!
    private var sourcePopup: NSPopUpButton!
    private var fileField: NSTextField!
    private var browseButton: NSButton!
    private var radioPopup: NSPopUpButton!
    private var datePicker: NSDatePicker!
    private var repeatPopup: NSPopUpButton!
    private var enabledCheckbox: NSButton!
    private var durationField: NSTextField!
    private var stopActionPopup: NSPopUpButton!

    private var radioStations: [RadioStation] = []

    init(event: ScheduledEvent?) {
        self.editingEvent = event
    }

    func run(parent: NSWindow, completion: @escaping (ScheduledEvent?) -> Void) {
        self.completion = completion
        buildWindow()
        populate()
        parent.beginSheet(window) { _ in }
    }

    private func buildWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 460),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        win.title = editingEvent == nil ? "Add Scheduled Event" : "Edit Scheduled Event"
        let content = NSView(frame: win.contentLayoutRect)
        content.translatesAutoresizingMaskIntoConstraints = false
        win.contentView = content

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        // Name
        stack.addArrangedSubview(NSTextField(labelWithString: "Name:"))
        nameField = NSTextField()
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.widthAnchor.constraint(equalToConstant: 440).isActive = true
        stack.addArrangedSubview(nameField)

        // Action
        stack.addArrangedSubview(NSTextField(labelWithString: "Action:"))
        actionPopup = NSPopUpButton()
        actionPopup.addItems(withTitles: ["Playback", "Recording", "Both"])
        stack.addArrangedSubview(actionPopup)

        // Source
        stack.addArrangedSubview(NSTextField(labelWithString: "Source:"))
        sourcePopup = NSPopUpButton()
        sourcePopup.addItems(withTitles: ["File", "Radio"])
        sourcePopup.target = self
        sourcePopup.action = #selector(sourceChanged)
        stack.addArrangedSubview(sourcePopup)

        // File row
        let fileRow = NSStackView()
        fileRow.orientation = .horizontal
        fileRow.spacing = 6
        fileField = NSTextField()
        fileField.placeholderString = "Path to audio file or stream URL"
        fileField.translatesAutoresizingMaskIntoConstraints = false
        fileField.widthAnchor.constraint(equalToConstant: 360).isActive = true
        browseButton = NSButton(title: "Browse...", target: self, action: #selector(browse))
        fileRow.addArrangedSubview(fileField)
        fileRow.addArrangedSubview(browseButton)
        stack.addArrangedSubview(fileRow)

        // Radio
        radioPopup = NSPopUpButton()
        radioPopup.translatesAutoresizingMaskIntoConstraints = false
        radioPopup.widthAnchor.constraint(equalToConstant: 440).isActive = true
        radioStations = DatabaseManager.shared.getRadioStations()
        for station in radioStations {
            radioPopup.addItem(withTitle: station.name)
        }
        if radioStations.isEmpty {
            radioPopup.addItem(withTitle: "(no radio stations saved)")
            radioPopup.isEnabled = false
        }
        stack.addArrangedSubview(radioPopup)

        // Date / time
        stack.addArrangedSubview(NSTextField(labelWithString: "Date and time:"))
        datePicker = NSDatePicker()
        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.datePickerElements = [.yearMonthDay, .hourMinute]
        datePicker.dateValue = Date().addingTimeInterval(60 * 60)  // default: now + 1 hour
        stack.addArrangedSubview(datePicker)

        // Repeat
        stack.addArrangedSubview(NSTextField(labelWithString: "Repeat:"))
        repeatPopup = NSPopUpButton()
        repeatPopup.addItems(withTitles: ["Once", "Daily", "Weekly", "Weekdays", "Weekends", "Monthly"])
        stack.addArrangedSubview(repeatPopup)

        // Duration
        let durationRow = NSStackView()
        durationRow.orientation = .horizontal
        durationRow.spacing = 6
        durationRow.addArrangedSubview(NSTextField(labelWithString: "Duration (minutes, 0 = no limit):"))
        durationField = NSTextField()
        durationField.stringValue = "0"
        durationField.translatesAutoresizingMaskIntoConstraints = false
        durationField.widthAnchor.constraint(equalToConstant: 60).isActive = true
        durationRow.addArrangedSubview(durationField)
        stack.addArrangedSubview(durationRow)

        // Stop action
        stack.addArrangedSubview(NSTextField(labelWithString: "When duration expires, stop:"))
        stopActionPopup = NSPopUpButton()
        stopActionPopup.addItems(withTitles: ["Both", "Playback only", "Recording only"])
        stack.addArrangedSubview(stopActionPopup)

        // Enabled
        enabledCheckbox = NSButton(checkboxWithTitle: "Enabled", target: nil, action: nil)
        enabledCheckbox.state = .on
        stack.addArrangedSubview(enabledCheckbox)

        // OK / Cancel
        let buttons = NSStackView()
        buttons.orientation = .horizontal
        buttons.spacing = 8
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"  // Escape
        let okButton = NSButton(title: editingEvent == nil ? "Add" : "Save", target: self, action: #selector(save))
        okButton.keyEquivalent = "\r"
        buttons.addArrangedSubview(cancelButton)
        buttons.addArrangedSubview(okButton)
        content.addSubview(buttons)
        buttons.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -14),

            buttons.topAnchor.constraint(greaterThanOrEqualTo: stack.bottomAnchor, constant: 12),
            buttons.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            buttons.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
        ])

        self.window = win
    }

    private func populate() {
        if let ev = editingEvent {
            nameField.stringValue = ev.name
            actionPopup.selectItem(at: ev.action.rawValue)
            sourcePopup.selectItem(at: ev.sourceType.rawValue)
            if ev.sourceType == .file {
                fileField.stringValue = ev.sourcePath
            } else {
                if let idx = radioStations.firstIndex(where: { $0.id == ev.radioStationId }) {
                    radioPopup.selectItem(at: idx)
                }
            }
            datePicker.dateValue = Date(timeIntervalSince1970: TimeInterval(ev.scheduledTime))
            repeatPopup.selectItem(at: ev.repeatType.rawValue)
            durationField.stringValue = "\(ev.duration)"
            stopActionPopup.selectItem(at: ev.stopAction.rawValue)
            enabledCheckbox.state = ev.enabled ? .on : .off
        } else {
            // Pre-fill file from currently playing track
            if let path = PlaylistManager.shared.currentTrackPath, !path.hasPrefix("http") {
                fileField.stringValue = path
            }
        }
        sourceChanged()
    }

    @objc private func sourceChanged() {
        let isFile = sourcePopup.indexOfSelectedItem == 0
        fileField.isHidden = !isFile
        browseButton.isHidden = !isFile
        radioPopup.isHidden = isFile
    }

    @objc private func browse() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.fileField.stringValue = url.path
            }
        }
    }

    @objc private func cancel() {
        finish(with: nil)
    }

    @objc private func save() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            beep("Please enter a name.")
            return
        }
        let action = ScheduleAction(rawValue: actionPopup.indexOfSelectedItem) ?? .playback
        let sourceType = ScheduleSource(rawValue: sourcePopup.indexOfSelectedItem) ?? .file

        var sourcePath = ""
        var radioStationId: Int64 = 0
        if sourceType == .file {
            sourcePath = fileField.stringValue.trimmingCharacters(in: .whitespaces)
            guard !sourcePath.isEmpty else {
                beep("Please select a file.")
                return
            }
        } else {
            let idx = radioPopup.indexOfSelectedItem
            guard idx >= 0 && idx < radioStations.count else {
                beep("Please select a radio station.")
                return
            }
            let station = radioStations[idx]
            sourcePath = station.url
            radioStationId = station.id ?? 0
        }

        let scheduledTime = Int64(datePicker.dateValue.timeIntervalSince1970)
        let repeatType = ScheduleRepeat(rawValue: repeatPopup.indexOfSelectedItem) ?? .none
        let enabled = enabledCheckbox.state == .on
        let duration = max(0, Int(durationField.stringValue) ?? 0)
        let stopAction = ScheduleStopAction(rawValue: stopActionPopup.indexOfSelectedItem) ?? .stopBoth

        let result = ScheduledEvent(
            id: editingEvent?.id,
            name: name,
            action: action,
            sourceType: sourceType,
            sourcePath: sourcePath,
            radioStationId: radioStationId,
            scheduledTime: scheduledTime,
            repeatType: repeatType,
            enabled: enabled,
            lastRun: editingEvent?.lastRun ?? 0,
            duration: duration,
            stopAction: stopAction
        )
        finish(with: result)
    }

    private func beep(_ message: String) {
        NSSound.beep()
        let alert = NSAlert()
        alert.messageText = message
        alert.beginSheetModal(for: window) { _ in }
    }

    private func finish(with result: ScheduledEvent?) {
        let parent = window.sheetParent
        parent?.endSheet(window)
        completion?(result)
    }
}
