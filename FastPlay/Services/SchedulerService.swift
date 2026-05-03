//
//  SchedulerService.swift
//  FastPlay
//
//  Background service that fires scheduled events.
//  Mirrors Windows ui.cpp CheckScheduledEvents / HandleScheduledDurationEnd / CalculateNextScheduleTime.
//

import Foundation

class SchedulerService {

    static let shared = SchedulerService()

    private var checkTimer: Timer?
    private var durationTimer: Timer?
    private var pendingStopAction: ScheduleStopAction = .stopBoth
    private var schedulerMuted = false  // True if the scheduler muted playback for a recording-only event

    private init() {}

    /// Start the periodic check (every 60s, matching Windows IDT_SCHEDULER).
    func start() {
        guard checkTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkPendingEvents()
        }
        timer.tolerance = 5
        checkTimer = timer
        // Also do an initial check so events that are already due fire promptly
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkPendingEvents()
        }
    }

    func stop() {
        checkTimer?.invalidate()
        checkTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
    }

    // MARK: - Pending event execution

    private func checkPendingEvents() {
        let pending = DatabaseManager.shared.getPendingScheduledEvents()
        for event in pending {
            execute(event)
        }
    }

    private func execute(_ event: ScheduledEvent) {
        guard let id = event.id else { return }

        // Mark as run immediately so we don't re-trigger
        let now = Int64(Date().timeIntervalSince1970)
        DatabaseManager.shared.setScheduledEventLastRun(id: id, lastRun: now)

        let shouldPlay = event.action == .playback || event.action == .both
        let shouldRecord = event.action == .recording || event.action == .both

        if shouldPlay || shouldRecord {
            // Stop any current playback / recording — match Windows behavior
            if RecordingManager.shared.isRecording {
                RecordingManager.shared.stopRecording()
            }
            AudioEngine.shared.stop()

            // Cancel any prior duration timer
            durationTimer?.invalidate()
            durationTimer = nil
            if schedulerMuted {
                AudioEngine.shared.setMuted(false)
                schedulerMuted = false
            }

            // For Recording-only mode, mute output but keep the stream playing
            // so the encoder still receives audio.
            if shouldRecord && !shouldPlay {
                AudioEngine.shared.setMuted(true)
                schedulerMuted = true
            }

            // Load the source and start playback
            PlaylistManager.shared.clear()
            if event.sourceType == .radio || event.sourcePath.hasPrefix("http://") || event.sourcePath.hasPrefix("https://") {
                PlaylistManager.shared.addURL(event.sourcePath)
            } else {
                PlaylistManager.shared.addFile(event.sourcePath)
            }
            if PlaylistManager.shared.count > 0 {
                PlaylistManager.shared.playTrack(at: 0)
            }

            // Start recording AFTER playback begins
            if shouldRecord && !RecordingManager.shared.isRecording {
                _ = RecordingManager.shared.startRecording()
            }

            // Set up duration timer if specified (duration is in minutes)
            if event.duration > 0 {
                pendingStopAction = event.stopAction
                let interval = TimeInterval(event.duration) * 60.0
                let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                    self?.handleDurationEnd()
                }
                durationTimer = timer
            }
        }

        AccessibilityManager.announce("Scheduled event: \(event.name)")

        // Calculate next run time for repeating events
        calculateNextTime(id: id, lastScheduled: event.scheduledTime, repeatType: event.repeatType)
    }

    // MARK: - Duration timer

    private func handleDurationEnd() {
        durationTimer = nil

        if schedulerMuted {
            AudioEngine.shared.setMuted(false)
            schedulerMuted = false
        }

        switch pendingStopAction {
        case .stopBoth:
            AudioEngine.shared.stop()
            if RecordingManager.shared.isRecording {
                RecordingManager.shared.stopRecording()
            }
            AccessibilityManager.announce("Scheduled event ended")
        case .stopPlayback:
            AudioEngine.shared.stop()
            AccessibilityManager.announce("Scheduled playback ended")
        case .stopRecording:
            if RecordingManager.shared.isRecording {
                RecordingManager.shared.stopRecording()
                AccessibilityManager.announce("Scheduled recording ended")
            }
        }
    }

    // MARK: - Repeat scheduling

    private func calculateNextTime(id: Int64, lastScheduled: Int64, repeatType: ScheduleRepeat) {
        if repeatType == .none {
            // One-time event — disable so it doesn't trigger again
            DatabaseManager.shared.setScheduledEventEnabled(id: id, enabled: false)
            return
        }

        let calendar = Calendar.current
        var nextDate = Date(timeIntervalSince1970: TimeInterval(lastScheduled))

        switch repeatType {
        case .daily:
            nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
        case .weekly:
            nextDate = calendar.date(byAdding: .day, value: 7, to: nextDate) ?? nextDate
        case .weekdays:
            // Skip Sat (7) and Sun (1) in Calendar's 1-based weekday system
            repeat {
                nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
            } while calendar.component(.weekday, from: nextDate) == 1
                || calendar.component(.weekday, from: nextDate) == 7
        case .weekends:
            repeat {
                nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
            } while calendar.component(.weekday, from: nextDate) != 1
                && calendar.component(.weekday, from: nextDate) != 7
        case .monthly:
            nextDate = calendar.date(byAdding: .month, value: 1, to: nextDate) ?? nextDate
        case .none:
            return
        }

        let nextTimestamp = Int64(nextDate.timeIntervalSince1970)
        DatabaseManager.shared.setScheduledEventTime(id: id, scheduledTime: nextTimestamp)
    }
}
