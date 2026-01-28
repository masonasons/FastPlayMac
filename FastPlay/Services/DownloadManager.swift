//
//  DownloadManager.swift
//  FastPlay
//
//  Manages a persistent download queue for podcast episodes
//

import Foundation

struct DownloadItem {
    let id: UUID
    let url: String
    let destinationPath: String
    let title: String
    var task: URLSessionDownloadTask?
}

class DownloadManager: NSObject {

    // MARK: - Singleton

    static let shared = DownloadManager()

    // MARK: - Properties

    private var queue: [DownloadItem] = []
    private var activeDownloads: [UUID: DownloadItem] = [:]
    private let maxConcurrentDownloads = 3

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600  // 1 hour for large files
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    private var taskToId: [Int: UUID] = [:]  // Map task identifiers to download IDs

    // Callbacks
    var onDownloadComplete: ((String, Bool) -> Void)?  // (title, success)
    var onAllDownloadsComplete: (() -> Void)?
    var onQueueChanged: (() -> Void)?

    // MARK: - Public Interface

    /// Number of items in queue (waiting + active)
    var pendingCount: Int {
        return queue.count + activeDownloads.count
    }

    /// Number of actively downloading items
    var activeCount: Int {
        return activeDownloads.count
    }

    /// Add a download to the queue
    func enqueue(url: String, destinationPath: String, title: String) {
        // Check if already in queue or downloading
        if queue.contains(where: { $0.url == url }) ||
           activeDownloads.values.contains(where: { $0.url == url }) {
            return
        }

        // Check if file already exists
        if FileManager.default.fileExists(atPath: destinationPath) {
            return
        }

        let item = DownloadItem(
            id: UUID(),
            url: url,
            destinationPath: destinationPath,
            title: title,
            task: nil
        )

        queue.append(item)
        onQueueChanged?()
        processQueue()
    }

    /// Add multiple downloads to the queue
    func enqueueMultiple(_ items: [(url: String, destinationPath: String, title: String)]) {
        var addedCount = 0

        for item in items {
            // Check if already in queue or downloading
            if queue.contains(where: { $0.url == item.url }) ||
               activeDownloads.values.contains(where: { $0.url == item.url }) {
                continue
            }

            // Check if file already exists
            if FileManager.default.fileExists(atPath: item.destinationPath) {
                continue
            }

            let downloadItem = DownloadItem(
                id: UUID(),
                url: item.url,
                destinationPath: item.destinationPath,
                title: item.title,
                task: nil
            )

            queue.append(downloadItem)
            addedCount += 1
        }

        if addedCount > 0 {
            onQueueChanged?()
            processQueue()
        }
    }

    /// Cancel all downloads and clear queue
    func cancelAll() {
        // Cancel active downloads
        for (_, item) in activeDownloads {
            item.task?.cancel()
        }
        activeDownloads.removeAll()
        taskToId.removeAll()

        // Clear queue
        queue.removeAll()

        onQueueChanged?()
    }

    // MARK: - Private Methods

    private func processQueue() {
        while activeDownloads.count < maxConcurrentDownloads && !queue.isEmpty {
            var item = queue.removeFirst()

            guard let url = URL(string: item.url) else {
                continue
            }

            let task = session.downloadTask(with: url)
            item.task = task
            taskToId[task.taskIdentifier] = item.id
            activeDownloads[item.id] = item

            task.resume()
        }
    }

    private func completeDownload(id: UUID, tempURL: URL?, error: Error?) {
        guard let item = activeDownloads.removeValue(forKey: id) else { return }

        if let taskId = item.task?.taskIdentifier {
            taskToId.removeValue(forKey: taskId)
        }

        var success = false

        if let tempURL = tempURL, error == nil {
            do {
                // Create directory if needed
                let destURL = URL(fileURLWithPath: item.destinationPath)
                try FileManager.default.createDirectory(
                    at: destURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                // Remove existing file if present
                if FileManager.default.fileExists(atPath: item.destinationPath) {
                    try FileManager.default.removeItem(atPath: item.destinationPath)
                }

                // Move downloaded file
                try FileManager.default.moveItem(at: tempURL, to: destURL)
                success = true
            } catch {
                print("Failed to save download: \(error)")
            }
        }

        onDownloadComplete?(item.title, success)
        onQueueChanged?()

        // Process next in queue
        processQueue()

        // Check if all done
        if activeDownloads.isEmpty && queue.isEmpty {
            onAllDownloadsComplete?()
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = taskToId[downloadTask.taskIdentifier] else { return }
        completeDownload(id: id, tempURL: location, error: nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error,
              let id = taskToId[task.taskIdentifier] else { return }
        completeDownload(id: id, tempURL: nil, error: error)
    }
}
