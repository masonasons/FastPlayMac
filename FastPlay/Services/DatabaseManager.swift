//
//  DatabaseManager.swift
//  FastPlay
//
//  SQLite database for bookmarks, radio, podcasts, scheduler
//  Uses same schema as Windows version
//

import Foundation
import SQLite3

class DatabaseManager {

    // MARK: - Singleton

    static let shared = DatabaseManager()

    // MARK: - Properties

    private var db: OpaquePointer?

    // MARK: - Initialization

    private init() {}

    func initialize() {
        let path = SettingsManager.shared.databasePath.path

        if sqlite3_open(path, &db) != SQLITE_OK {
            print("Failed to open database at \(path)")
            return
        }

        createTables()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    // MARK: - Table Creation

    private func createTables() {
        // Bookmarks table
        execute("""
            CREATE TABLE IF NOT EXISTS Bookmarks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                filepath TEXT NOT NULL,
                position REAL NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

        // Radio stations table
        execute("""
            CREATE TABLE IF NOT EXISTS RadioStations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                url TEXT NOT NULL,
                genre TEXT,
                country TEXT,
                bitrate INTEGER,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

        // Podcast subscriptions table
        execute("""
            CREATE TABLE IF NOT EXISTS PodcastSubscriptions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                feed_url TEXT NOT NULL UNIQUE,
                description TEXT,
                author TEXT,
                image_url TEXT,
                last_updated TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

        // Podcast episodes table
        execute("""
            CREATE TABLE IF NOT EXISTS PodcastEpisodes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                subscription_id INTEGER NOT NULL,
                title TEXT NOT NULL,
                description TEXT,
                audio_url TEXT NOT NULL,
                pub_date TEXT,
                duration INTEGER,
                played INTEGER DEFAULT 0,
                position REAL DEFAULT 0,
                guid TEXT,
                local_path TEXT,
                FOREIGN KEY (subscription_id) REFERENCES PodcastSubscriptions(id) ON DELETE CASCADE
            )
        """)

        // Add columns if they don't exist (for upgrades)
        execute("ALTER TABLE PodcastEpisodes ADD COLUMN guid TEXT")
        execute("ALTER TABLE PodcastEpisodes ADD COLUMN local_path TEXT")

        // Scheduled events table
        execute("""
            CREATE TABLE IF NOT EXISTS ScheduledEvents (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                filepath TEXT NOT NULL,
                hour INTEGER NOT NULL,
                minute INTEGER NOT NULL,
                days TEXT NOT NULL,
                enabled INTEGER DEFAULT 1,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

        // File positions table (for remember position feature)
        execute("""
            CREATE TABLE IF NOT EXISTS FilePositions (
                filepath TEXT PRIMARY KEY,
                position REAL NOT NULL,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

        // Song history table (stream metadata captured during radio playback)
        execute("""
            CREATE TABLE IF NOT EXISTS song_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                timestamp INTEGER NOT NULL
            )
        """)
    }

    private func execute(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let err = errMsg {
                print("SQL error: \(String(cString: err))")
                sqlite3_free(errMsg)
            }
        }
    }

    // MARK: - Bookmarks

    func addBookmark(name: String, filepath: String, position: Double) -> Int64 {
        let sql = "INSERT INTO Bookmarks (name, filepath, position) VALUES (?, ?, ?)"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return -1 }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, filepath, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 3, position)

        guard sqlite3_step(stmt) == SQLITE_DONE else { return -1 }
        return sqlite3_last_insert_rowid(db)
    }

    func getBookmarks() -> [Bookmark] {
        let sql = "SELECT id, name, filepath, position, created_at FROM Bookmarks ORDER BY created_at DESC"
        var stmt: OpaquePointer?
        var bookmarks: [Bookmark] = []

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let filepath = String(cString: sqlite3_column_text(stmt, 2))
            let position = sqlite3_column_double(stmt, 3)
            let createdAt = String(cString: sqlite3_column_text(stmt, 4))

            bookmarks.append(Bookmark(id: id, name: name, filepath: filepath, position: position, createdAt: createdAt))
        }

        return bookmarks
    }

    func getBookmarks(forFile filepath: String) -> [Bookmark] {
        let sql = "SELECT id, name, filepath, position, created_at FROM Bookmarks WHERE filepath = ? ORDER BY position ASC"
        var stmt: OpaquePointer?
        var bookmarks: [Bookmark] = []

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, filepath, -1, SQLITE_TRANSIENT)

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let filepath = String(cString: sqlite3_column_text(stmt, 2))
            let position = sqlite3_column_double(stmt, 3)
            let createdAt = String(cString: sqlite3_column_text(stmt, 4))

            bookmarks.append(Bookmark(id: id, name: name, filepath: filepath, position: position, createdAt: createdAt))
        }

        return bookmarks
    }

    func deleteBookmark(id: Int64) {
        execute("DELETE FROM Bookmarks WHERE id = \(id)")
    }

    // MARK: - Radio Stations

    func addRadioStation(name: String, url: String, genre: String? = nil, country: String? = nil, bitrate: Int? = nil) -> Int64 {
        let sql = "INSERT INTO RadioStations (name, url, genre, country, bitrate) VALUES (?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return -1 }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, url, -1, SQLITE_TRANSIENT)

        if let genre = genre {
            sqlite3_bind_text(stmt, 3, genre, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 3)
        }

        if let country = country {
            sqlite3_bind_text(stmt, 4, country, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 4)
        }

        if let bitrate = bitrate {
            sqlite3_bind_int(stmt, 5, Int32(bitrate))
        } else {
            sqlite3_bind_null(stmt, 5)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else { return -1 }
        return sqlite3_last_insert_rowid(db)
    }

    func getRadioStations() -> [RadioStation] {
        let sql = "SELECT id, name, url, genre, country, bitrate FROM RadioStations ORDER BY name"
        var stmt: OpaquePointer?
        var stations: [RadioStation] = []

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let url = String(cString: sqlite3_column_text(stmt, 2))
            let genre = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
            let country = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let bitrate = sqlite3_column_type(stmt, 5) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 5)) : nil

            stations.append(RadioStation(id: id, name: name, url: url, genre: genre, country: country, bitrate: bitrate))
        }

        return stations
    }

    func deleteRadioStation(id: Int64) {
        execute("DELETE FROM RadioStations WHERE id = \(id)")
    }

    /// Get all radio stations (alias for getRadioStations)
    func getAllRadioStations() -> [RadioStation] {
        return getRadioStations()
    }

    /// Save a radio station (insert or update)
    func saveRadioStation(_ station: RadioStation) {
        if let id = station.id {
            // Update existing
            let sql = "UPDATE RadioStations SET name = ?, url = ?, genre = ?, country = ?, bitrate = ? WHERE id = ?"
            var stmt: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, station.name, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, station.url, -1, SQLITE_TRANSIENT)

            if let genre = station.genre {
                sqlite3_bind_text(stmt, 3, genre, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 3)
            }

            if let country = station.country {
                sqlite3_bind_text(stmt, 4, country, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 4)
            }

            if let bitrate = station.bitrate {
                sqlite3_bind_int(stmt, 5, Int32(bitrate))
            } else {
                sqlite3_bind_null(stmt, 5)
            }

            sqlite3_bind_int64(stmt, 6, id)
            sqlite3_step(stmt)
        } else {
            // Insert new
            _ = addRadioStation(name: station.name, url: station.url, genre: station.genre, country: station.country, bitrate: station.bitrate)
        }
    }

    // MARK: - Podcast Subscriptions

    func addPodcastSubscription(title: String, feedURL: String, description: String? = nil, author: String? = nil, imageURL: String? = nil) -> Int64 {
        let sql = "INSERT OR IGNORE INTO PodcastSubscriptions (title, feed_url, description, author, image_url) VALUES (?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return -1 }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, feedURL, -1, SQLITE_TRANSIENT)

        if let description = description {
            sqlite3_bind_text(stmt, 3, description, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 3)
        }

        if let author = author {
            sqlite3_bind_text(stmt, 4, author, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 4)
        }

        if let imageURL = imageURL {
            sqlite3_bind_text(stmt, 5, imageURL, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 5)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else { return -1 }
        return sqlite3_last_insert_rowid(db)
    }

    func getAllPodcastSubscriptions() -> [PodcastSubscription] {
        let sql = "SELECT id, title, feed_url, description, author, image_url FROM PodcastSubscriptions ORDER BY title"
        var stmt: OpaquePointer?
        var subscriptions: [PodcastSubscription] = []

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let title = String(cString: sqlite3_column_text(stmt, 1))
            let feedURL = String(cString: sqlite3_column_text(stmt, 2))
            let description = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
            let author = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? ""
            let imageURL = sqlite3_column_text(stmt, 5).map { String(cString: $0) }

            subscriptions.append(PodcastSubscription(
                id: id, title: title, feedURL: feedURL,
                description: description, author: author, imageURL: imageURL
            ))
        }

        return subscriptions
    }

    func savePodcastSubscription(_ subscription: PodcastSubscription) {
        if let id = subscription.id {
            // Update existing
            let sql = "UPDATE PodcastSubscriptions SET title = ?, feed_url = ?, description = ?, author = ?, image_url = ? WHERE id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, subscription.title, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, subscription.feedURL, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, subscription.description, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, subscription.author, -1, SQLITE_TRANSIENT)
            if let imageURL = subscription.imageURL {
                sqlite3_bind_text(stmt, 5, imageURL, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 5)
            }
            sqlite3_bind_int64(stmt, 6, id)
            sqlite3_step(stmt)
        } else {
            // Insert new
            _ = addPodcastSubscription(title: subscription.title, feedURL: subscription.feedURL,
                                       description: subscription.description, author: subscription.author,
                                       imageURL: subscription.imageURL)
        }
    }

    func deletePodcastSubscription(id: Int64) {
        execute("DELETE FROM PodcastEpisodes WHERE subscription_id = \(id)")
        execute("DELETE FROM PodcastSubscriptions WHERE id = \(id)")
    }

    // MARK: - Podcast Episodes

    func addPodcastEpisode(subscriptionId: Int64, title: String, description: String?, audioURL: String, pubDate: String?, duration: Int?) -> Int64 {
        let sql = "INSERT INTO PodcastEpisodes (subscription_id, title, description, audio_url, pub_date, duration) VALUES (?, ?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return -1 }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, subscriptionId)
        sqlite3_bind_text(stmt, 2, title, -1, SQLITE_TRANSIENT)

        if let description = description {
            sqlite3_bind_text(stmt, 3, description, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 3)
        }

        sqlite3_bind_text(stmt, 4, audioURL, -1, SQLITE_TRANSIENT)

        if let pubDate = pubDate {
            sqlite3_bind_text(stmt, 5, pubDate, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 5)
        }

        if let duration = duration {
            sqlite3_bind_int(stmt, 6, Int32(duration))
        } else {
            sqlite3_bind_null(stmt, 6)
        }

        guard sqlite3_step(stmt) == SQLITE_DONE else { return -1 }
        return sqlite3_last_insert_rowid(db)
    }

    func getEpisodes(forSubscription subscriptionId: Int64) -> [PodcastEpisode] {
        let sql = "SELECT id, title, description, audio_url, pub_date, duration, played, guid, local_path FROM PodcastEpisodes WHERE subscription_id = ? ORDER BY pub_date DESC"
        var stmt: OpaquePointer?
        var episodes: [PodcastEpisode] = []

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, subscriptionId)

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let title = String(cString: sqlite3_column_text(stmt, 1))
            let description = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
            let audioURL = String(cString: sqlite3_column_text(stmt, 3))
            let pubDateStr = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
            let duration = sqlite3_column_type(stmt, 5) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 5)) : 0
            let played = sqlite3_column_int(stmt, 6) != 0
            let guid = sqlite3_column_text(stmt, 7).map { String(cString: $0) } ?? ""
            let localPath = sqlite3_column_text(stmt, 8).map { String(cString: $0) }

            // Parse date string to Date
            var publishDate: Date? = nil
            if let dateStr = pubDateStr {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                publishDate = formatter.date(from: dateStr)
            }

            episodes.append(PodcastEpisode(
                id: id, subscriptionId: subscriptionId, title: title,
                description: description, audioURL: audioURL,
                duration: duration, publishDate: publishDate, guid: guid,
                played: played, localPath: localPath
            ))
        }

        return episodes
    }

    func savePodcastEpisode(_ episode: PodcastEpisode, subscriptionId: Int64) {
        // Format date for storage
        var pubDateStr: String? = nil
        if let date = episode.publishDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            pubDateStr = formatter.string(from: date)
        }

        if let id = episode.id {
            // Update existing
            let sql = "UPDATE PodcastEpisodes SET title = ?, description = ?, audio_url = ?, pub_date = ?, duration = ?, played = ?, guid = ?, local_path = ? WHERE id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, episode.title, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, episode.description, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, episode.audioURL, -1, SQLITE_TRANSIENT)
            if let pubDate = pubDateStr {
                sqlite3_bind_text(stmt, 4, pubDate, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 4)
            }
            sqlite3_bind_int(stmt, 5, Int32(episode.duration))
            sqlite3_bind_int(stmt, 6, episode.played ? 1 : 0)
            sqlite3_bind_text(stmt, 7, episode.guid, -1, SQLITE_TRANSIENT)
            if let localPath = episode.localPath {
                sqlite3_bind_text(stmt, 8, localPath, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 8)
            }
            sqlite3_bind_int64(stmt, 9, id)
            sqlite3_step(stmt)
        } else {
            // Insert new
            let sql = "INSERT INTO PodcastEpisodes (subscription_id, title, description, audio_url, pub_date, duration, played, guid, local_path) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_int64(stmt, 1, subscriptionId)
            sqlite3_bind_text(stmt, 2, episode.title, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, episode.description, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, episode.audioURL, -1, SQLITE_TRANSIENT)
            if let pubDate = pubDateStr {
                sqlite3_bind_text(stmt, 5, pubDate, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 5)
            }
            sqlite3_bind_int(stmt, 6, Int32(episode.duration))
            sqlite3_bind_int(stmt, 7, episode.played ? 1 : 0)
            sqlite3_bind_text(stmt, 8, episode.guid, -1, SQLITE_TRANSIENT)
            if let localPath = episode.localPath {
                sqlite3_bind_text(stmt, 9, localPath, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 9)
            }
            sqlite3_step(stmt)
        }
    }

    func updateEpisodePosition(id: Int64, position: Double, played: Bool) {
        let sql = "UPDATE PodcastEpisodes SET position = ?, played = ? WHERE id = ?"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_double(stmt, 1, position)
        sqlite3_bind_int(stmt, 2, played ? 1 : 0)
        sqlite3_bind_int64(stmt, 3, id)

        sqlite3_step(stmt)
    }

    // MARK: - Scheduled Events

    func addScheduledEvent(name: String, filepath: String, hour: Int, minute: Int, days: String) -> Int64 {
        let sql = "INSERT INTO ScheduledEvents (name, filepath, hour, minute, days) VALUES (?, ?, ?, ?, ?)"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return -1 }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, name, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, filepath, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 3, Int32(hour))
        sqlite3_bind_int(stmt, 4, Int32(minute))
        sqlite3_bind_text(stmt, 5, days, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(stmt) == SQLITE_DONE else { return -1 }
        return sqlite3_last_insert_rowid(db)
    }

    func getAllScheduledEvents() -> [ScheduledEvent] {
        let sql = "SELECT id, name, filepath, hour, minute, days, enabled FROM ScheduledEvents ORDER BY hour, minute"
        var stmt: OpaquePointer?
        var events: [ScheduledEvent] = []

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let filepath = String(cString: sqlite3_column_text(stmt, 2))
            let hour = Int(sqlite3_column_int(stmt, 3))
            let minute = Int(sqlite3_column_int(stmt, 4))
            let days = String(cString: sqlite3_column_text(stmt, 5))
            let enabled = sqlite3_column_int(stmt, 6) != 0

            events.append(ScheduledEvent(
                id: id, name: name, filepath: filepath,
                hour: hour, minute: minute, days: days, enabled: enabled
            ))
        }

        return events
    }

    func saveScheduledEvent(_ event: ScheduledEvent) {
        if let id = event.id {
            // Update existing
            let sql = "UPDATE ScheduledEvents SET name = ?, filepath = ?, hour = ?, minute = ?, days = ?, enabled = ? WHERE id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, event.name, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, event.filepath, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 3, Int32(event.hour))
            sqlite3_bind_int(stmt, 4, Int32(event.minute))
            sqlite3_bind_text(stmt, 5, event.days, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 6, event.enabled ? 1 : 0)
            sqlite3_bind_int64(stmt, 7, id)
            sqlite3_step(stmt)
        } else {
            // Insert new
            _ = addScheduledEvent(name: event.name, filepath: event.filepath,
                                  hour: event.hour, minute: event.minute, days: event.days)
        }
    }

    func deleteScheduledEvent(id: Int64) {
        execute("DELETE FROM ScheduledEvents WHERE id = \(id)")
    }

    func setScheduledEventEnabled(id: Int64, enabled: Bool) {
        execute("UPDATE ScheduledEvents SET enabled = \(enabled ? 1 : 0) WHERE id = \(id)")
    }

    // MARK: - File Positions

    func saveFilePosition(filepath: String, position: Double) {
        let sql = "INSERT OR REPLACE INTO FilePositions (filepath, position, updated_at) VALUES (?, ?, datetime('now'))"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, filepath, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, position)

        sqlite3_step(stmt)
    }

    func getFilePosition(filepath: String) -> Double? {
        let sql = "SELECT position FROM FilePositions WHERE filepath = ?"
        var stmt: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, filepath, -1, SQLITE_TRANSIENT)

        if sqlite3_step(stmt) == SQLITE_ROW {
            return sqlite3_column_double(stmt, 0)
        }

        return nil
    }

    func clearOldFilePositions(olderThanDays days: Int) {
        execute("DELETE FROM FilePositions WHERE updated_at < datetime('now', '-\(days) days')")
    }

    // MARK: - Song History

    /// Record a captured stream title. Skips if identical to the most recent entry
    /// and keeps only the last 100 rows, matching the Windows implementation.
    func addSongHistoryEntry(title: String) {
        guard db != nil, !title.isEmpty else { return }

        // Skip consecutive duplicates
        let checkSql = "SELECT title FROM song_history ORDER BY id DESC LIMIT 1"
        var checkStmt: OpaquePointer?
        if sqlite3_prepare_v2(db, checkSql, -1, &checkStmt, nil) == SQLITE_OK {
            if sqlite3_step(checkStmt) == SQLITE_ROW,
               let cStr = sqlite3_column_text(checkStmt, 0),
               String(cString: cStr) == title {
                sqlite3_finalize(checkStmt)
                return
            }
            sqlite3_finalize(checkStmt)
        }

        let insertSql = "INSERT INTO song_history (title, timestamp) VALUES (?, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(stmt, 2, Int64(Date().timeIntervalSince1970))
        sqlite3_step(stmt)

        execute("""
            DELETE FROM song_history WHERE id NOT IN (
                SELECT id FROM song_history ORDER BY id DESC LIMIT 100
            )
        """)
    }

    func getSongHistory() -> [SongHistoryEntry] {
        let sql = "SELECT id, title, timestamp FROM song_history ORDER BY id DESC LIMIT 100"
        var stmt: OpaquePointer?
        var entries: [SongHistoryEntry] = []

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = sqlite3_column_int64(stmt, 0)
            let title = String(cString: sqlite3_column_text(stmt, 1))
            let timestamp = sqlite3_column_int64(stmt, 2)
            entries.append(SongHistoryEntry(
                id: id,
                title: title,
                date: Date(timeIntervalSince1970: TimeInterval(timestamp))
            ))
        }

        return entries
    }

    func clearSongHistory() {
        execute("DELETE FROM song_history")
    }
}

// MARK: - SQLite Helpers

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
