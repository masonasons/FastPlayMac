//
//  JumpToTimeWindowController.swift
//  FastPlay
//
//  Jump to Time dialog - seek to specific position
//

import AppKit

class JumpToTimeWindowController: NSWindowController {

    // MARK: - Singleton

    static let shared = JumpToTimeWindowController()

    // MARK: - UI Elements

    private var hoursField: NSTextField!
    private var minutesField: NSTextField!
    private var secondsField: NSTextField!
    private var totalLabel: NSTextField!

    // MARK: - Initialization

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Jump to Time"
        window.center()

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let window = window, let contentView = window.contentView else { return }

        // Instructions
        let instructionLabel = NSTextField(labelWithString: "Enter time to jump to:")
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(instructionLabel)

        // Time fields
        let hoursLabel = NSTextField(labelWithString: "Hours:")
        hoursLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hoursLabel)

        hoursField = NSTextField()
        hoursField.translatesAutoresizingMaskIntoConstraints = false
        hoursField.placeholderString = "0"
        hoursField.alignment = .center
        hoursField.delegate = self
        contentView.addSubview(hoursField)

        let minutesLabel = NSTextField(labelWithString: "Minutes:")
        minutesLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(minutesLabel)

        minutesField = NSTextField()
        minutesField.translatesAutoresizingMaskIntoConstraints = false
        minutesField.placeholderString = "0"
        minutesField.alignment = .center
        minutesField.delegate = self
        contentView.addSubview(minutesField)

        let secondsLabel = NSTextField(labelWithString: "Seconds:")
        secondsLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(secondsLabel)

        secondsField = NSTextField()
        secondsField.translatesAutoresizingMaskIntoConstraints = false
        secondsField.placeholderString = "0"
        secondsField.alignment = .center
        secondsField.delegate = self
        contentView.addSubview(secondsField)

        // Total time display
        totalLabel = NSTextField(labelWithString: "Total: 0:00:00")
        totalLabel.translatesAutoresizingMaskIntoConstraints = false
        totalLabel.textColor = .secondaryLabelColor
        contentView.addSubview(totalLabel)

        // Buttons
        let jumpButton = NSButton(title: "Jump", target: self, action: #selector(jumpToTime))
        jumpButton.translatesAutoresizingMaskIntoConstraints = false
        jumpButton.keyEquivalent = "\r"
        contentView.addSubview(jumpButton)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.keyEquivalent = "\u{1b}"
        contentView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 15),
            instructionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            hoursLabel.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 15),
            hoursLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            hoursField.centerYAnchor.constraint(equalTo: hoursLabel.centerYAnchor),
            hoursField.leadingAnchor.constraint(equalTo: hoursLabel.trailingAnchor, constant: 5),
            hoursField.widthAnchor.constraint(equalToConstant: 40),

            minutesLabel.centerYAnchor.constraint(equalTo: hoursLabel.centerYAnchor),
            minutesLabel.leadingAnchor.constraint(equalTo: hoursField.trailingAnchor, constant: 15),

            minutesField.centerYAnchor.constraint(equalTo: hoursLabel.centerYAnchor),
            minutesField.leadingAnchor.constraint(equalTo: minutesLabel.trailingAnchor, constant: 5),
            minutesField.widthAnchor.constraint(equalToConstant: 40),

            secondsLabel.centerYAnchor.constraint(equalTo: hoursLabel.centerYAnchor),
            secondsLabel.leadingAnchor.constraint(equalTo: minutesField.trailingAnchor, constant: 15),

            secondsField.centerYAnchor.constraint(equalTo: hoursLabel.centerYAnchor),
            secondsField.leadingAnchor.constraint(equalTo: secondsLabel.trailingAnchor, constant: 5),
            secondsField.widthAnchor.constraint(equalToConstant: 40),

            totalLabel.topAnchor.constraint(equalTo: hoursLabel.bottomAnchor, constant: 15),
            totalLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            cancelButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -15),

            jumpButton.trailingAnchor.constraint(equalTo: cancelButton.leadingAnchor, constant: -10),
            jumpButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -15),
        ])
    }

    // MARK: - Actions

    @objc private func jumpToTime() {
        let hours = Double(hoursField.stringValue) ?? 0
        let minutes = Double(minutesField.stringValue) ?? 0
        let seconds = Double(secondsField.stringValue) ?? 0

        let totalSeconds = hours * 3600 + minutes * 60 + seconds

        if totalSeconds >= 0 {
            AudioEngine.shared.seek(to: totalSeconds)
            AccessibilityManager.announce("Jumped to \(formatTime(totalSeconds))")
        }

        window?.close()
    }

    @objc private func cancel() {
        window?.close()
    }

    private func updateTotal() {
        let hours = Double(hoursField.stringValue) ?? 0
        let minutes = Double(minutesField.stringValue) ?? 0
        let seconds = Double(secondsField.stringValue) ?? 0

        let totalSeconds = hours * 3600 + minutes * 60 + seconds
        totalLabel.stringValue = "Total: \(formatTime(totalSeconds))"
    }

    private func formatTime(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }

    // MARK: - Show

    func show() {
        // Pre-fill with current position
        let current = AudioEngine.shared.currentPosition
        let h = Int(current) / 3600
        let m = (Int(current) % 3600) / 60
        let s = Int(current) % 60

        hoursField.stringValue = "\(h)"
        minutesField.stringValue = "\(m)"
        secondsField.stringValue = "\(s)"
        updateTotal()

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        hoursField.becomeFirstResponder()
    }
}

// MARK: - Text Field Delegate

extension JumpToTimeWindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        updateTotal()
    }
}
