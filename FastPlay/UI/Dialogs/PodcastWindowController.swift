//
//  PodcastWindowController.swift
//  FastPlay
//
//  Podcast dialog - manage subscriptions and episodes
//

import AppKit

class PodcastWindowController: NSWindowController {

    // MARK: - Singleton

    static let shared = PodcastWindowController()

    // MARK: - UI Elements

    private var tabView: NSTabView!
    private var subscriptionsTable: NSTableView!
    private var episodesTable: NSTableView!
    private var descriptionText: NSTextView!
    private var searchField: NSTextField!
    private var searchResultsTable: NSTableView!

    private var subscriptions: [PodcastSubscription] = []
    private var episodes: [PodcastEpisode] = []
    private var searchResults: [PodcastSubscription] = []

    // MARK: - Initialization

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Podcasts"
        window.center()
        window.minSize = NSSize(width: 500, height: 400)

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let window = window, let contentView = window.contentView else { return }

        // Tab view
        tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabView)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            tabView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])

        addSubscriptionsTab()
        addSearchTab()

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

    private func addSubscriptionsTab() {
        let item = NSTabViewItem(identifier: "subscriptions")
        item.label = "Subscriptions"

        let view = NSView()

        // Subscriptions list (left)
        let subsLabel = NSTextField(labelWithString: "Subscriptions:")
        subsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subsLabel)

        subscriptionsTable = NSTableView()
        subscriptionsTable.delegate = self
        subscriptionsTable.dataSource = self
        subscriptionsTable.tag = 1
        subscriptionsTable.doubleAction = #selector(refreshSelectedSubscription)
        subscriptionsTable.target = self

        let subsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("subscription"))
        subsColumn.title = "Subscription"
        subsColumn.width = 180
        subscriptionsTable.addTableColumn(subsColumn)
        subscriptionsTable.headerView = nil

        let subsScroll = NSScrollView()
        subsScroll.translatesAutoresizingMaskIntoConstraints = false
        subsScroll.documentView = subscriptionsTable
        subsScroll.hasVerticalScroller = true
        view.addSubview(subsScroll)

        // Episodes list (right)
        let epsLabel = NSTextField(labelWithString: "Episodes:")
        epsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(epsLabel)

        episodesTable = NSTableView()
        episodesTable.delegate = self
        episodesTable.dataSource = self
        episodesTable.tag = 2
        episodesTable.doubleAction = #selector(playSelectedEpisode)
        episodesTable.target = self

        let epsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("episode"))
        epsColumn.title = "Episode"
        epsColumn.width = 350
        episodesTable.addTableColumn(epsColumn)
        episodesTable.headerView = nil

        let epsScroll = NSScrollView()
        epsScroll.translatesAutoresizingMaskIntoConstraints = false
        epsScroll.documentView = episodesTable
        epsScroll.hasVerticalScroller = true
        view.addSubview(epsScroll)

        // Episode description
        let descScroll = NSScrollView()
        descScroll.translatesAutoresizingMaskIntoConstraints = false
        descScroll.hasVerticalScroller = true
        view.addSubview(descScroll)

        descriptionText = NSTextView()
        descriptionText.isEditable = false
        descriptionText.font = NSFont.systemFont(ofSize: 12)
        descScroll.documentView = descriptionText

        // Buttons
        let downloadButton = NSButton(title: "Download", target: self, action: #selector(downloadSelected))
        downloadButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(downloadButton)

        let downloadAllButton = NSButton(title: "Download All", target: self, action: #selector(downloadAll))
        downloadAllButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(downloadAllButton)

        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshSelectedSubscription))
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(refreshButton)

        // Help label
        let helpLabel = NSTextField(labelWithString: "Enter = play, Delete = unsubscribe, F5 = refresh, Escape = close")
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = NSFont.systemFont(ofSize: 11)
        helpLabel.textColor = .secondaryLabelColor
        view.addSubview(helpLabel)

        NSLayoutConstraint.activate([
            subsLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            subsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),

            subsScroll.topAnchor.constraint(equalTo: subsLabel.bottomAnchor, constant: 5),
            subsScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            subsScroll.widthAnchor.constraint(equalToConstant: 180),
            subsScroll.bottomAnchor.constraint(equalTo: helpLabel.topAnchor, constant: -10),

            epsLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            epsLabel.leadingAnchor.constraint(equalTo: subsScroll.trailingAnchor, constant: 15),

            epsScroll.topAnchor.constraint(equalTo: epsLabel.bottomAnchor, constant: 5),
            epsScroll.leadingAnchor.constraint(equalTo: subsScroll.trailingAnchor, constant: 15),
            epsScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            epsScroll.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.45),

            descScroll.topAnchor.constraint(equalTo: epsScroll.bottomAnchor, constant: 10),
            descScroll.leadingAnchor.constraint(equalTo: subsScroll.trailingAnchor, constant: 15),
            descScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            descScroll.bottomAnchor.constraint(equalTo: downloadButton.topAnchor, constant: -10),

            helpLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            helpLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),

            downloadButton.trailingAnchor.constraint(equalTo: downloadAllButton.leadingAnchor, constant: -10),
            downloadButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),

            downloadAllButton.trailingAnchor.constraint(equalTo: refreshButton.leadingAnchor, constant: -10),
            downloadAllButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),

            refreshButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            refreshButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
        ])

        item.view = view
        tabView.addTabViewItem(item)
    }

    private func addSearchTab() {
        let item = NSTabViewItem(identifier: "search")
        item.label = "Search / Subscribe"

        let view = NSView()

        // Search field
        let searchLabel = NSTextField(labelWithString: "Feed URL or search:")
        searchLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchLabel)

        searchField = NSTextField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Enter podcast feed URL or search term..."
        searchField.target = self
        searchField.action = #selector(performSearch)
        view.addSubview(searchField)

        let searchButton = NSButton(title: "Search", target: self, action: #selector(performSearch))
        searchButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchButton)

        // Results table
        searchResultsTable = NSTableView()
        searchResultsTable.delegate = self
        searchResultsTable.dataSource = self
        searchResultsTable.tag = 3
        searchResultsTable.doubleAction = #selector(subscribeToSelected)
        searchResultsTable.target = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("podcast"))
        column.title = "Podcast"
        column.width = 400
        searchResultsTable.addTableColumn(column)
        searchResultsTable.headerView = nil

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = searchResultsTable
        scrollView.hasVerticalScroller = true
        view.addSubview(scrollView)

        let subscribeButton = NSButton(title: "Subscribe", target: self, action: #selector(subscribeToSelected))
        subscribeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subscribeButton)

        let importButton = NSButton(title: "Import OPML...", target: self, action: #selector(importOPML))
        importButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(importButton)

        NSLayoutConstraint.activate([
            searchLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 15),
            searchLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),

            searchField.topAnchor.constraint(equalTo: searchLabel.bottomAnchor, constant: 5),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: searchButton.leadingAnchor, constant: -10),

            searchButton.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            searchButton.widthAnchor.constraint(equalToConstant: 80),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 15),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: subscribeButton.topAnchor, constant: -10),

            importButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            importButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),

            subscribeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            subscribeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
        ])

        item.view = view
        tabView.addTabViewItem(item)
    }

    // MARK: - Actions

    @objc private func playSelectedEpisode() {
        let row = episodesTable.selectedRow
        guard row >= 0 && row < episodes.count else { return }

        let episode = episodes[row]
        PlaylistManager.shared.clear()
        PlaylistManager.shared.addURL(episode.audioURL)
        PlaylistManager.shared.playTrack(at: 0)
    }

    @objc private func refreshSelectedSubscription() {
        let row = subscriptionsTable.selectedRow
        guard row >= 0 && row < subscriptions.count else { return }

        let sub = subscriptions[row]
        // Just fetch and display episodes (like Windows - no DB storage)
        fetchAndLoadEpisodes(for: sub)
    }

    @objc private func downloadSelected() {
        let row = episodesTable.selectedRow
        guard row >= 0 && row < episodes.count else { return }

        downloadEpisode(episodes[row])
    }

    @objc private func downloadAll() {
        guard !episodes.isEmpty else {
            AccessibilityManager.announce("No episodes to download")
            return
        }

        // Count episodes to download (excluding already downloaded)
        let toDownload = episodes.filter { episode in
            guard let localPath = episode.localPath else { return true }
            return !FileManager.default.fileExists(atPath: localPath)
        }

        guard !toDownload.isEmpty else {
            AccessibilityManager.announce("All episodes already downloaded")
            return
        }

        AccessibilityManager.announce("Downloading \(toDownload.count) episodes")

        for episode in toDownload {
            downloadEpisode(episode, silent: true)
        }
    }

    private func downloadEpisode(_ episode: PodcastEpisode, silent: Bool = false) {
        // Get download path
        var downloadDir = SettingsManager.shared.downloadPath
        if downloadDir.isEmpty {
            let musicURL = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
            downloadDir = musicURL.appendingPathComponent("FastPlay Downloads").path
        }

        // Organize by feed if enabled
        if SettingsManager.shared.downloadOrganizeByFeed, let subId = episode.subscriptionId {
            if let sub = subscriptions.first(where: { $0.id == subId }) {
                downloadDir = (downloadDir as NSString).appendingPathComponent(sanitizeFilename(sub.title))
            }
        }

        // Determine filename
        let fileExtension = URL(string: episode.audioURL)?.pathExtension ?? "mp3"
        let filename = sanitizeFilename(episode.title) + "." + fileExtension
        let localPath = (downloadDir as NSString).appendingPathComponent(filename)

        // Check for existing file
        if FileManager.default.fileExists(atPath: localPath) {
            if !silent {
                AccessibilityManager.announce("Already downloaded: \(episode.title)")
            }
            return
        }

        if !silent {
            AccessibilityManager.announce("Downloading: \(episode.title)")
        }

        NetworkManager.shared.downloadFile(from: episode.audioURL, to: localPath, progress: nil) { result in
            switch result {
            case .success:
                if !silent {
                    AccessibilityManager.announce("Downloaded: \(episode.title)")
                }

            case .failure(let error):
                if !silent {
                    AccessibilityManager.announce("Download failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func sanitizeFilename(_ name: String) -> String {
        var result = name
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
        result = result.components(separatedBy: invalidChars).joined(separator: "_")
        // Truncate if too long
        if result.count > 200 {
            result = String(result.prefix(200))
        }
        return result
    }

    @objc private func performSearch() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }

        // If it's a URL, try to subscribe directly
        if query.hasPrefix("http://") || query.hasPrefix("https://") {
            subscribeTo(feedURL: query)
            AccessibilityManager.announce("Subscribing to feed")
        } else {
            // Search iTunes podcast directory
            searchITunes(query: query)
        }
    }

    private func searchITunes(query: String) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encodedQuery)&media=podcast&limit=50") else {
            return
        }

        AccessibilityManager.announce("Searching...")

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self, let data = data, error == nil else {
                    AccessibilityManager.announce("Search failed")
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let results = json["results"] as? [[String: Any]] {
                        self.searchResults = results.compactMap { item -> PodcastSubscription? in
                            guard let name = item["collectionName"] as? String,
                                  let feedUrl = item["feedUrl"] as? String else { return nil }

                            let artist = item["artistName"] as? String ?? ""
                            let imageUrl = item["artworkUrl100"] as? String

                            // Combine name and artist for display
                            let displayTitle = artist.isEmpty ? name : "\(name) - \(artist)"

                            return PodcastSubscription(
                                id: nil,
                                title: displayTitle,
                                feedURL: feedUrl,
                                description: "",
                                author: artist,
                                imageURL: imageUrl
                            )
                        }
                        self.searchResultsTable.reloadData()
                        AccessibilityManager.announce("\(self.searchResults.count) results")
                    }
                } catch {
                    AccessibilityManager.announce("Search failed")
                }
            }
        }
        task.resume()
    }

    @objc private func subscribeToSelected() {
        let row = searchResultsTable.selectedRow
        guard row >= 0 && row < searchResults.count else { return }

        let sub = searchResults[row]
        DatabaseManager.shared.savePodcastSubscription(sub)
        loadSubscriptions()
        AccessibilityManager.announce("Subscribed to \(sub.title)")
    }

    private func subscribeTo(feedURL: String, title: String? = nil) {
        // Create a subscription with provided title or extract from URL
        let feedTitle = title ?? URL(string: feedURL)?.host ?? "New Podcast"
        let sub = PodcastSubscription(
            id: nil,
            title: feedTitle,
            feedURL: feedURL,
            description: "",
            author: "",
            imageURL: nil
        )
        DatabaseManager.shared.savePodcastSubscription(sub)
    }

    @objc private func importOPML() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.xml]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let fileURL = panel.url {
            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                let feeds = parseOPML(content)

                if feeds.isEmpty {
                    AccessibilityManager.announce("No feeds found in file")
                    return
                }

                AccessibilityManager.announce("Importing feeds")

                var added = 0
                var skipped = 0

                for feed in feeds {
                    // Check if already subscribed
                    let existing = subscriptions.contains { $0.feedURL.lowercased() == feed.url.lowercased() }
                    if existing {
                        skipped += 1
                        continue
                    }

                    subscribeTo(feedURL: feed.url, title: feed.title)
                    added += 1
                }

                loadSubscriptions()

                if skipped > 0 {
                    AccessibilityManager.announce("Imported \(added) feeds, \(skipped) skipped")
                } else {
                    AccessibilityManager.announce("Imported \(added) feeds")
                }
            }
        }
    }

    /// Parse OPML file and extract feed URLs with titles
    private func parseOPML(_ content: String) -> [(title: String, url: String)] {
        var feeds: [(title: String, url: String)] = []

        // Find all <outline elements with xmlUrl attribute
        var searchRange = content.startIndex..<content.endIndex
        while let outlineStart = content.range(of: "<outline", options: .caseInsensitive, range: searchRange) {
            // Find the end of this element (either /> or </outline>)
            guard let elementEnd = content.range(of: "/>", range: outlineStart.upperBound..<content.endIndex) ??
                                   content.range(of: ">", range: outlineStart.upperBound..<content.endIndex) else {
                break
            }

            let element = String(content[outlineStart.lowerBound..<elementEnd.upperBound])

            // Extract xmlUrl (case insensitive)
            let feedUrl = extractXMLAttribute(element, "xmlUrl") ?? extractXMLAttribute(element, "xmlurl") ?? ""

            if !feedUrl.isEmpty {
                // Extract title from text or title attribute
                let title = extractXMLAttribute(element, "text") ?? extractXMLAttribute(element, "title") ?? ""

                // Decode HTML entities in title
                let decodedTitle = title
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&apos;", with: "'")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#39;", with: "'")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")

                // Decode URL entities
                let decodedUrl = feedUrl
                    .replacingOccurrences(of: "&amp;", with: "&")

                feeds.append((title: decodedTitle.isEmpty ? "Unknown Podcast" : decodedTitle, url: decodedUrl))
            }

            searchRange = elementEnd.upperBound..<content.endIndex
        }

        return feeds
    }

    /// Extract XML attribute value (case insensitive for attribute name)
    private func extractXMLAttribute(_ element: String, _ attr: String) -> String? {
        // Try double quotes
        let patterns = [
            "\(attr)=\"",
            "\(attr.lowercased())=\"",
            "\(attr.uppercased())=\""
        ]

        for pattern in patterns {
            if let range = element.range(of: pattern, options: .caseInsensitive) {
                let start = range.upperBound
                if let end = element.range(of: "\"", range: start..<element.endIndex) {
                    return String(element[start..<end.lowerBound])
                }
            }
        }

        // Try single quotes
        for pattern in patterns {
            let singleQuotePattern = pattern.replacingOccurrences(of: "\"", with: "'")
            if let range = element.range(of: singleQuotePattern, options: .caseInsensitive) {
                let start = range.upperBound
                if let end = element.range(of: "'", range: start..<element.endIndex) {
                    return String(element[start..<end.lowerBound])
                }
            }
        }

        return nil
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

        // Enter
        if event.keyCode == 36 {
            // Check which tab is active
            let tabId = tabView.selectedTabViewItem?.identifier as? String

            if tabId == "search" {
                // If search field is focused, perform search
                if window?.firstResponder == searchField ||
                   (window?.firstResponder as? NSText)?.delegate === searchField {
                    performSearch()
                    return true
                }
                // If in search results, subscribe to selected
                subscribeToSelected()
                return true
            }

            // Subscriptions tab - simple logic based on selection state
            // If episodes are loaded and one is selected, play it
            // Otherwise, fetch and load episodes for the selected subscription
            if episodesTable.selectedRow >= 0 && episodes.count > 0 {
                playSelectedEpisode()
            } else if subscriptionsTable.selectedRow >= 0 {
                // Fetch episodes from RSS feed for selected subscription
                let row = subscriptionsTable.selectedRow
                if row < subscriptions.count {
                    let sub = subscriptions[row]
                    fetchAndLoadEpisodes(for: sub)
                }
            }
            return true
        }

        // Delete = Unsubscribe
        if event.keyCode == 51 && tabView.selectedTabViewItem?.identifier as? String == "subscriptions" {
            let row = subscriptionsTable.selectedRow
            if row >= 0 && row < subscriptions.count {
                if let id = subscriptions[row].id {
                    DatabaseManager.shared.deletePodcastSubscription(id: id)
                    loadSubscriptions()
                }
            }
            return true
        }

        // F5 = Refresh
        if event.keyCode == 96 {
            refreshSelectedSubscription()
            return true
        }

        return false
    }

    // MARK: - Data Loading

    private func loadSubscriptions() {
        subscriptions = DatabaseManager.shared.getAllPodcastSubscriptions()
        subscriptionsTable.reloadData()

        // Clear episodes - user will press Enter to load
        episodes = []
        episodesTable.reloadData()
        descriptionText.string = ""

        // Select first subscription if available
        if !subscriptions.isEmpty {
            subscriptionsTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    /// Fetch episodes from RSS feed and display them (like Windows LoadPodcastEpisodes)
    private func fetchAndLoadEpisodes(for subscription: PodcastSubscription) {
        AccessibilityManager.announce("Loading episodes")

        NetworkManager.shared.fetchPodcastFeed(url: subscription.feedURL) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let (_, fetchedEpisodes)):
                // Update episodes array with fetched episodes
                self.episodes = fetchedEpisodes.map { ep in
                    var episode = ep
                    episode.subscriptionId = subscription.id
                    return episode
                }
                self.episodesTable.reloadData()

                // Select first episode and move focus
                if !self.episodes.isEmpty {
                    self.episodesTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                    self.window?.makeFirstResponder(self.episodesTable)
                    // Show description
                    self.descriptionText.string = self.episodes[0].description
                }

                AccessibilityManager.announce("\(self.episodes.count) episodes")

            case .failure(let error):
                AccessibilityManager.announce("Failed to load episodes: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Show

    func show() {
        loadSubscriptions()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Focus subscriptions list
        window?.makeFirstResponder(subscriptionsTable)
    }
}

// MARK: - Table View Data Source & Delegate

extension PodcastWindowController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        switch tableView.tag {
        case 1: return subscriptions.count
        case 2: return episodes.count
        case 3: return searchResults.count
        default: return 0
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("Cell")

        var cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField
        if cell == nil {
            cell = NSTextField(labelWithString: "")
            cell?.identifier = identifier
            cell?.lineBreakMode = .byTruncatingTail
        }

        switch tableView.tag {
        case 1:
            cell?.stringValue = subscriptions[row].title
        case 2:
            cell?.stringValue = episodes[row].title
        case 3:
            cell?.stringValue = searchResults[row].title
        default:
            break
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 22
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else { return }

        if tableView.tag == 1 {
            // Subscription selected - clear episodes, user will press Enter to load
            episodes = []
            episodesTable.reloadData()
            descriptionText.string = ""
        } else if tableView.tag == 2 {
            // Episode selected - show description
            let row = tableView.selectedRow
            if row >= 0 && row < episodes.count {
                descriptionText.string = episodes[row].description
            }
        }
    }
}
