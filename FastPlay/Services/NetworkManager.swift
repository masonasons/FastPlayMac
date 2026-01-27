//
//  NetworkManager.swift
//  FastPlay
//
//  Network operations - RSS feed parsing, downloads
//

import Foundation

class NetworkManager {

    // MARK: - Singleton

    static let shared = NetworkManager()

    private init() {}

    // MARK: - RSS Feed Parsing

    /// Fetch and parse an RSS podcast feed
    func fetchPodcastFeed(url: String, completion: @escaping (Result<(PodcastSubscription, [PodcastEpisode]), Error>) -> Void) {
        guard let feedURL = URL(string: url) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let task = URLSession.shared.dataTask(with: feedURL) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.noData))
                }
                return
            }

            let parser = RSSParser(feedURL: url)
            if parser.parse(data: data) {
                DispatchQueue.main.async {
                    completion(.success((parser.subscription, parser.episodes)))
                }
            } else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.parseError))
                }
            }
        }
        task.resume()
    }

    // MARK: - Download

    /// Download a file to a local path
    func downloadFile(from urlString: String, to localPath: String, progress: ((Double) -> Void)?, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(NetworkError.invalidURL))
            return
        }

        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let tempURL = tempURL else {
                DispatchQueue.main.async {
                    completion(.failure(NetworkError.noData))
                }
                return
            }

            do {
                // Create directory if needed
                let destURL = URL(fileURLWithPath: localPath)
                try FileManager.default.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true)

                // Move file
                if FileManager.default.fileExists(atPath: localPath) {
                    try FileManager.default.removeItem(atPath: localPath)
                }
                try FileManager.default.moveItem(at: tempURL, to: destURL)

                DispatchQueue.main.async {
                    completion(.success(localPath))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        task.resume()
    }
}

// MARK: - Errors

enum NetworkError: Error {
    case invalidURL
    case noData
    case parseError
}

// MARK: - RSS Parser

private class RSSParser: NSObject, XMLParserDelegate {

    var subscription: PodcastSubscription
    var episodes: [PodcastEpisode] = []

    private let feedURL: String
    private var currentElement = ""
    private var currentText = ""

    // Channel (podcast) info
    private var channelTitle = ""
    private var channelDescription = ""
    private var channelAuthor = ""
    private var channelImageURL: String?

    // Current item (episode)
    private var isInItem = false
    private var isInImage = false
    private var itemTitle = ""
    private var itemDescription = ""
    private var itemAudioURL = ""
    private var itemDuration = ""
    private var itemPubDate = ""
    private var itemGUID = ""

    init(feedURL: String) {
        self.feedURL = feedURL
        self.subscription = PodcastSubscription(
            id: nil,
            title: "",
            feedURL: feedURL,
            description: "",
            author: "",
            imageURL: nil
        )
        super.init()
    }

    func parse(data: Data) -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = self
        let success = parser.parse()

        if success {
            // Update subscription with parsed data
            subscription = PodcastSubscription(
                id: nil,
                title: channelTitle.isEmpty ? URL(string: feedURL)?.host ?? "Podcast" : channelTitle,
                feedURL: feedURL,
                description: channelDescription,
                author: channelAuthor,
                imageURL: channelImageURL
            )
        }

        return success && !channelTitle.isEmpty
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""

        if elementName == "item" {
            isInItem = true
            itemTitle = ""
            itemDescription = ""
            itemAudioURL = ""
            itemDuration = ""
            itemPubDate = ""
            itemGUID = ""
        } else if elementName == "image" || elementName == "itunes:image" {
            isInImage = true
            if let href = attributeDict["href"] {
                if !isInItem {
                    channelImageURL = href
                }
            }
        } else if elementName == "enclosure" {
            if let url = attributeDict["url"], isInItem {
                itemAudioURL = url
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if isInItem {
            // Episode data
            switch elementName {
            case "title":
                itemTitle = decodeHTMLEntities(trimmed)
            case "description", "content:encoded":
                if itemDescription.isEmpty {
                    itemDescription = decodeHTMLEntities(stripHTML(trimmed))
                }
            case "itunes:duration":
                itemDuration = trimmed
            case "pubDate":
                itemPubDate = trimmed
            case "guid":
                itemGUID = trimmed
            case "item":
                // End of item - create episode
                if !itemAudioURL.isEmpty {
                    let episode = PodcastEpisode(
                        id: nil,
                        subscriptionId: nil,
                        title: itemTitle,
                        description: itemDescription,
                        audioURL: itemAudioURL,
                        duration: parseDuration(itemDuration),
                        publishDate: parseDate(itemPubDate),
                        guid: itemGUID,
                        played: false,
                        localPath: nil
                    )
                    episodes.append(episode)
                }
                isInItem = false
            default:
                break
            }
        } else {
            // Channel (podcast) data
            switch elementName {
            case "title":
                if channelTitle.isEmpty && !isInImage {
                    channelTitle = decodeHTMLEntities(trimmed)
                }
            case "description":
                if channelDescription.isEmpty {
                    channelDescription = decodeHTMLEntities(stripHTML(trimmed))
                }
            case "itunes:author", "author":
                if channelAuthor.isEmpty {
                    channelAuthor = decodeHTMLEntities(trimmed)
                }
            case "url":
                if isInImage && channelImageURL == nil {
                    channelImageURL = trimmed
                }
            case "image":
                isInImage = false
            default:
                break
            }
        }
    }

    // MARK: - Helpers

    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&#x27;": "'",
            "&#039;": "'",
            "&nbsp;": " ",
        ]

        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }

        // Handle numeric entities like &#8217;
        let numericPattern = "&#(\\d+);"
        if let regex = try? NSRegularExpression(pattern: numericPattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: range).reversed()
            for match in matches {
                if let numRange = Range(match.range(at: 1), in: result),
                   let codePoint = Int(result[numRange]),
                   let scalar = Unicode.Scalar(codePoint) {
                    let char = String(Character(scalar))
                    if let fullRange = Range(match.range, in: result) {
                        result.replaceSubrange(fullRange, with: char)
                    }
                }
            }
        }

        return result
    }

    private func stripHTML(_ string: String) -> String {
        // Simple HTML tag removal
        var result = string
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }
        return result
    }

    private func parseDuration(_ string: String) -> Int {
        // Handle formats: "HH:MM:SS", "MM:SS", or seconds
        let parts = string.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 3:
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2:
            return parts[0] * 60 + parts[1]
        case 1:
            return parts[0]
        default:
            return 0
        }
    }

    private func parseDate(_ string: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let f = DateFormatter()
                f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
}
