//
//  JumpToTimeWindowController.swift
//  FastPlay
//
//  Jump to Time dialog - seek to specific position
//

import AppKit

final class JumpToTimeWindowController: NSObject {

    // MARK: - Singleton

    static let shared = JumpToTimeWindowController()

    private override init() {
        super.init()
    }

    private func parseTimeString(_ string: String) -> Double? {
        let parts = string.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.count <= 3 else { return nil }

        let values = parts.compactMap { Double($0) }
        guard values.count == parts.count, values.allSatisfy({ $0 >= 0 }) else { return nil }

        switch values.count {
        case 1:
            return values[0]
        case 2:
            return values[0] * 60 + values[1]
        case 3:
            return values[0] * 3600 + values[1] * 60 + values[2]
        default:
            return nil
        }
    }

    // MARK: - Show

    func show() {
        var timeValue = AccessibilityManager.formatTimeDisplay(AudioEngine.shared.currentPosition)

        while true {
            let (alert, textField) = makeAlert(timeValue: timeValue)
            focus(textField, in: alert)

            NSApp.activate(ignoringOtherApps: true)
            guard alert.runModal() == .alertFirstButtonReturn else { return }

            guard let totalSeconds = parseTimeString(textField.stringValue) else {
                NSSound.beep()
                AccessibilityManager.announce("Invalid time")
                timeValue = textField.stringValue
                continue
            }

            AudioEngine.shared.seek(to: totalSeconds)
            AccessibilityManager.announce("Jumped to \(AccessibilityManager.formatTimeDisplay(totalSeconds))")
            return
        }
    }

    private func makeAlert(timeValue: String) -> (NSAlert, NSTextField) {
        let alert = NSAlert()
        alert.messageText = "Jump to Time"
        alert.informativeText = "Enter time (MM:SS or HH:MM:SS):"
        alert.addButton(withTitle: "Jump")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = timeValue
        textField.placeholderString = "0:00"
        textField.setAccessibilityLabel("Time")
        alert.accessoryView = textField

        return (alert, textField)
    }

    private func focus(_ textField: NSTextField, in alert: NSAlert) {
        alert.window.initialFirstResponder = textField
        alert.window.makeFirstResponder(textField)
        textField.selectText(nil)

        DispatchQueue.main.async {
            alert.window.makeFirstResponder(textField)
            textField.selectText(nil)
            NSAccessibility.post(element: textField as Any, notification: .focusedUIElementChanged)
        }
    }
}
