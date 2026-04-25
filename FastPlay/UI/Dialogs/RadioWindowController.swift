//
//  RadioWindowController.swift
//  FastPlay
//
//  Internet Radio dialog - browse favorites and search stations
//

import AppKit

class RadioWindowController: NSWindowController {

    // MARK: - Singleton

    static let shared = RadioWindowController()

    // MARK: - UI Elements

    private var tabView: NSTabView!
    private var favoritesTable: NSTableView!
    private var searchTable: NSTableView!
    private var searchField: NSTextField!
    private var searchSourceCombo: NSPopUpButton!

    private var favorites: [RadioStation] = []
    private var searchResults: [RadioStation] = []

    // Search providers
    private enum SearchProvider: Int {
        case radioBrowser = 0
        case tuneIn = 1
        case iHeartRadio = 2
    }

    // MARK: - Initialization

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Internet Radio"
        window.center()
        window.minSize = NSSize(width: 400, height: 300)

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

        addFavoritesTab()
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

    private func addFavoritesTab() {
        let item = NSTabViewItem(identifier: "favorites")
        item.label = "Favorites"

        let view = NSView()

        // Table
        favoritesTable = NSTableView()
        favoritesTable.delegate = self
        favoritesTable.dataSource = self
        favoritesTable.tag = 1
        favoritesTable.doubleAction = #selector(playSelectedFavorite)
        favoritesTable.target = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("station"))
        column.title = "Station"
        column.width = 400
        favoritesTable.addTableColumn(column)
        favoritesTable.headerView = nil

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = favoritesTable
        scrollView.hasVerticalScroller = true
        view.addSubview(scrollView)

        // Buttons
        let addButton = NSButton(title: "Add...", target: self, action: #selector(addStation))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addButton)

        let importButton = NSButton(title: "Import...", target: self, action: #selector(importStations))
        importButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(importButton)

        let exportButton = NSButton(title: "Export...", target: self, action: #selector(exportStations))
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(exportButton)

        let helpLabel = NSTextField(labelWithString: "Enter = play, Delete = remove, Escape = close")
        helpLabel.translatesAutoresizingMaskIntoConstraints = false
        helpLabel.font = NSFont.systemFont(ofSize: 11)
        helpLabel.textColor = .secondaryLabelColor
        view.addSubview(helpLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -10),

            helpLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            helpLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),

            addButton.trailingAnchor.constraint(equalTo: importButton.leadingAnchor, constant: -10),
            addButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),

            importButton.trailingAnchor.constraint(equalTo: exportButton.leadingAnchor, constant: -10),
            importButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),

            exportButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            exportButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
        ])

        item.view = view
        tabView.addTabViewItem(item)
    }

    private func addSearchTab() {
        let item = NSTabViewItem(identifier: "search")
        item.label = "Search"

        let view = NSView()

        // Search source selector
        let sourceLabel = NSTextField(labelWithString: "Source:")
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sourceLabel)

        searchSourceCombo = NSPopUpButton(frame: .zero, pullsDown: false)
        searchSourceCombo.translatesAutoresizingMaskIntoConstraints = false
        searchSourceCombo.addItems(withTitles: ["Radio Browser", "TuneIn", "iHeartRadio"])
        view.addSubview(searchSourceCombo)

        // Search field
        let searchLabel = NSTextField(labelWithString: "Search:")
        searchLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchLabel)

        searchField = NSTextField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Enter station name..."
        searchField.target = self
        searchField.action = #selector(performSearch)
        view.addSubview(searchField)

        let searchButton = NSButton(title: "Search", target: self, action: #selector(performSearch))
        searchButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchButton)

        // Results table
        searchTable = NSTableView()
        searchTable.delegate = self
        searchTable.dataSource = self
        searchTable.tag = 2
        searchTable.doubleAction = #selector(playSelectedSearch)
        searchTable.target = self

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("station"))
        column.title = "Station"
        column.width = 400
        searchTable.addTableColumn(column)
        searchTable.headerView = nil

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = searchTable
        scrollView.hasVerticalScroller = true
        view.addSubview(scrollView)

        let addFavButton = NSButton(title: "Add to Favorites", target: self, action: #selector(addSearchToFavorites))
        addFavButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addFavButton)

        NSLayoutConstraint.activate([
            sourceLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 15),
            sourceLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),

            searchSourceCombo.centerYAnchor.constraint(equalTo: sourceLabel.centerYAnchor),
            searchSourceCombo.leadingAnchor.constraint(equalTo: sourceLabel.trailingAnchor, constant: 10),
            searchSourceCombo.widthAnchor.constraint(equalToConstant: 130),

            searchLabel.topAnchor.constraint(equalTo: sourceLabel.bottomAnchor, constant: 10),
            searchLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),

            searchField.centerYAnchor.constraint(equalTo: searchLabel.centerYAnchor),
            searchField.leadingAnchor.constraint(equalTo: searchLabel.trailingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: searchButton.leadingAnchor, constant: -10),

            searchButton.centerYAnchor.constraint(equalTo: searchLabel.centerYAnchor),
            searchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            searchButton.widthAnchor.constraint(equalToConstant: 80),

            scrollView.topAnchor.constraint(equalTo: searchLabel.bottomAnchor, constant: 15),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: addFavButton.topAnchor, constant: -10),

            addFavButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            addFavButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
        ])

        item.view = view
        tabView.addTabViewItem(item)
    }

    // MARK: - Actions

    @objc private func playSelectedFavorite() {
        let row = favoritesTable.selectedRow
        guard row >= 0 && row < favorites.count else { return }
        playStation(favorites[row])
    }

    @objc private func playSelectedSearch() {
        let row = searchTable.selectedRow
        guard row >= 0 && row < searchResults.count else { return }
        playStation(searchResults[row])
    }

    private func playStation(_ station: RadioStation) {
        // Check if this is a TuneIn playlist URL that needs resolution
        if needsTuneInResolution(station.url) {
            AccessibilityManager.announce("Resolving stream...")
            resolveTuneInURL(station.url, depth: 0) { [weak self] resolvedURL in
                guard let self = self else { return }
                if let url = resolvedURL {
                    PlaylistManager.shared.clear()
                    PlaylistManager.shared.addURL(url)
                    PlaylistManager.shared.playTrack(at: 0)
                } else {
                    AccessibilityManager.announce("Could not get stream URL")
                }
            }
        } else if station.url.hasPrefix("iheart://") {
            // iHeartRadio placeholder URL - need to resolve
            let stationId = String(station.url.dropFirst(9))
            resolveIHeartURL(stationId: stationId) { resolvedURL in
                if let url = resolvedURL {
                    PlaylistManager.shared.clear()
                    PlaylistManager.shared.addURL(url)
                    PlaylistManager.shared.playTrack(at: 0)
                } else {
                    AccessibilityManager.announce("Could not get stream URL")
                }
            }
        } else {
            // Direct stream URL
            PlaylistManager.shared.clear()
            PlaylistManager.shared.addURL(station.url)
            PlaylistManager.shared.playTrack(at: 0)
        }
    }

    /// Resolve TuneIn playlist URL to actual stream URL (follows up to 5 redirects)
    private func resolveTuneInURL(_ playlistURL: String, depth: Int = 0, completion: @escaping (String?) -> Void) {
        // Prevent infinite recursion
        if depth > 5 {
            completion(nil)
            return
        }

        // Upgrade HTTP to HTTPS (macOS ATS blocks HTTP by default)
        var urlString = playlistURL
        if urlString.hasPrefix("http://") && urlString.contains("radiotime.com") {
            urlString = urlString.replacingOccurrences(of: "http://", with: "https://")
        }

        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self, let data = data, error == nil,
                      let content = String(data: data, encoding: .utf8) else {
                    completion(nil)
                    return
                }

                // Parse the playlist content (M3U or PLS format)
                if let streamURL = self.parsePlaylistContent(content) {
                    // Check if result is another playlist file - follow the redirect
                    // Only follow if it's actually a playlist extension, not just any radiotime URL
                    if self.isPlaylistFileExtension(streamURL) {
                        self.resolveTuneInURL(streamURL, depth: depth + 1, completion: completion)
                    } else {
                        completion(streamURL)
                    }
                } else {
                    completion(nil)
                }
            }
        }
        task.resume()
    }

    /// Parse playlist content (M3U/PLS) to extract stream URL
    private func parsePlaylistContent(_ content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

            // PLS format: File1=http://...
            if trimmed.lowercased().hasPrefix("file") {
                if let equalsIndex = trimmed.firstIndex(of: "=") {
                    let url = String(trimmed[trimmed.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)
                    if url.hasPrefix("http://") || url.hasPrefix("https://") {
                        return url
                    }
                }
                continue
            }

            // M3U format: direct URL line
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                return trimmed
            }
        }

        return nil
    }

    /// Check if URL is a playlist file that needs resolution (by extension only)
    private func isPlaylistFileExtension(_ url: String) -> Bool {
        let lower = url.lowercased()
        // Check path component for playlist extensions (ignore query string)
        let path = URL(string: lower)?.path ?? lower
        return path.hasSuffix(".m3u") || path.hasSuffix(".m3u8") ||
               path.hasSuffix(".pls") || path.hasSuffix(".asx")
    }

    /// Check if URL needs TuneIn resolution (initial check before playing)
    private func needsTuneInResolution(_ url: String) -> Bool {
        let lower = url.lowercased()
        return lower.contains("radiotime.com") || lower.contains("tunein.com")
    }

    /// Resolve iHeartRadio station ID to stream URL
    private func resolveIHeartURL(stationId: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://api.iheart.com/api/v2/content/liveStations/\(stationId)") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                guard let data = data, error == nil else {
                    completion(nil)
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let hits = json["hits"] as? [[String: Any]],
                       let first = hits.first,
                       let streams = first["streams"] as? [String: Any] {
                        // Try different stream types
                        let streamURL = streams["shoutcast_stream"] as? String ??
                                       streams["secure_shoutcast_stream"] as? String ??
                                       streams["pls_stream"] as? String ??
                                       streams["hls_stream"] as? String
                        completion(streamURL)
                        return
                    }
                } catch {}

                completion(nil)
            }
        }
        task.resume()
    }

    @objc private func addStation() {
        let alert = NSAlert()
        alert.messageText = "Add Radio Station"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 10

        let nameField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        nameField.placeholderString = "Station name"

        let urlField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        urlField.placeholderString = "Stream URL (e.g., http://stream.example.com:8000/radio)"

        stackView.addArrangedSubview(nameField)
        stackView.addArrangedSubview(urlField)
        stackView.frame = NSRect(x: 0, y: 0, width: 300, height: 60)

        alert.accessoryView = stackView

        if alert.runModal() == .alertFirstButtonReturn {
            let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
            let url = urlField.stringValue.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty && !url.isEmpty {
                let station = RadioStation(id: nil, name: name, url: url, genre: nil, country: nil, bitrate: nil)
                DatabaseManager.shared.saveRadioStation(station)
                loadFavorites()
            }
        }
    }

    @objc private func importStations() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .audio]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let fileURL = panel.url {
            let ext = fileURL.pathExtension.lowercased()
            var importedCount = 0

            if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                if ext == "pls" {
                    // Parse PLS format
                    importedCount = importPLS(content)
                } else {
                    // Parse M3U/M3U8 format
                    importedCount = importM3U(content)
                }
            }

            loadFavorites()
            AccessibilityManager.announce(importedCount > 0 ? "Imported \(importedCount) stations" : "No stations found")
        }
    }

    /// Parse M3U playlist and import radio stations
    private func importM3U(_ content: String) -> Int {
        var count = 0
        var pendingName: String?
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            if trimmed.isEmpty { continue }

            // Parse #EXTINF line for station name
            // Format: #EXTINF:-1,Station Name
            if trimmed.hasPrefix("#EXTINF:") {
                if let commaIndex = trimmed.firstIndex(of: ",") {
                    pendingName = String(trimmed[trimmed.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)
                }
                continue
            }

            // Skip other comment lines
            if trimmed.hasPrefix("#") { continue }

            // This should be a URL line
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                let name = pendingName ?? URL(string: trimmed)?.host ?? trimmed
                let station = RadioStation(id: nil, name: name, url: trimmed, genre: nil, country: nil, bitrate: nil)
                DatabaseManager.shared.saveRadioStation(station)
                count += 1
                pendingName = nil
            }
        }

        return count
    }

    /// Parse PLS playlist and import radio stations
    private func importPLS(_ content: String) -> Int {
        var count = 0
        var files: [Int: String] = [:]
        var titles: [Int: String] = [:]

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Parse File entries: File1=http://...
            if trimmed.lowercased().hasPrefix("file") {
                if let equalsIndex = trimmed.firstIndex(of: "=") {
                    let keyPart = String(trimmed[..<equalsIndex]).lowercased()
                    let value = String(trimmed[trimmed.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)

                    if let numStr = keyPart.dropFirst(4).description as String?,
                       let num = Int(numStr) {
                        files[num] = value
                    }
                }
            }

            // Parse Title entries: Title1=Station Name
            if trimmed.lowercased().hasPrefix("title") {
                if let equalsIndex = trimmed.firstIndex(of: "=") {
                    let keyPart = String(trimmed[..<equalsIndex]).lowercased()
                    let value = String(trimmed[trimmed.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)

                    if let numStr = keyPart.dropFirst(5).description as String?,
                       let num = Int(numStr) {
                        titles[num] = value
                    }
                }
            }
        }

        // Match files with titles and import
        for (num, url) in files {
            if url.hasPrefix("http://") || url.hasPrefix("https://") {
                let name = titles[num] ?? URL(string: url)?.host ?? url
                let station = RadioStation(id: nil, name: name, url: url, genre: nil, country: nil, bitrate: nil)
                DatabaseManager.shared.saveRadioStation(station)
                count += 1
            }
        }

        return count
    }

    @objc private func exportStations() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "radio_stations.m3u"

        if panel.runModal() == .OK, let url = panel.url {
            var content = "#EXTM3U\n"
            for station in favorites {
                content += "#EXTINF:-1,\(station.name)\n"
                content += "\(station.url)\n"
            }
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    @objc private func performSearch() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            AccessibilityManager.announce("Enter a search term")
            return
        }

        let provider = SearchProvider(rawValue: searchSourceCombo.indexOfSelectedItem) ?? .radioBrowser

        switch provider {
        case .radioBrowser:
            searchRadioBrowser(query: query)
        case .tuneIn:
            searchTuneIn(query: query)
        case .iHeartRadio:
            searchiHeartRadio(query: query)
        }
    }

    private func searchRadioBrowser(query: String) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://de1.api.radio-browser.info/json/stations/byname/\(encodedQuery)?limit=50") else {
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
                    if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                        self.searchResults = json.compactMap { item -> RadioStation? in
                            guard let name = item["name"] as? String,
                                  let url = item["url_resolved"] as? String ?? item["url"] as? String,
                                  !url.isEmpty else { return nil }

                            let country = item["country"] as? String
                            let bitrate = item["bitrate"] as? Int

                            return RadioStation(id: nil, name: name, url: url, genre: nil, country: country, bitrate: bitrate)
                        }
                        self.searchTable.reloadData()
                        AccessibilityManager.announce("\(self.searchResults.count) stations found")
                    }
                } catch {
                    AccessibilityManager.announce("Search failed")
                }
            }
        }
        task.resume()
    }

    private func searchTuneIn(query: String) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://opml.radiotime.com/Search.ashx?query=\(encodedQuery)") else {
            return
        }

        AccessibilityManager.announce("Searching...")

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self, let data = data, error == nil,
                      let xml = String(data: data, encoding: .utf8) else {
                    AccessibilityManager.announce("Search failed")
                    return
                }

                self.searchResults = self.parseTuneInOPML(xml)
                self.searchTable.reloadData()
                AccessibilityManager.announce("\(self.searchResults.count) stations found")
            }
        }
        task.resume()
    }

    /// Parse TuneIn OPML response
    private func parseTuneInOPML(_ xml: String) -> [RadioStation] {
        var results: [RadioStation] = []

        // Find all <outline elements with type="audio"
        var searchRange = xml.startIndex..<xml.endIndex
        while let outlineStart = xml.range(of: "<outline", range: searchRange) {
            guard let outlineEnd = xml.range(of: "/>", range: outlineStart.upperBound..<xml.endIndex) ??
                                   xml.range(of: "</outline>", range: outlineStart.upperBound..<xml.endIndex) else {
                break
            }

            let element = String(xml[outlineStart.lowerBound..<outlineEnd.upperBound])

            // Check if it's an audio type (station)
            if element.contains("type=\"audio\"") {
                let name = extractXMLAttribute(element, "text")
                let url = extractXMLAttribute(element, "URL")
                let subtext = extractXMLAttribute(element, "subtext")
                let bitrateStr = extractXMLAttribute(element, "bitrate")
                let bitrate = Int(bitrateStr)

                if !name.isEmpty && !url.isEmpty {
                    // Decode HTML entities in name
                    let decodedName = decodeHTMLEntities(name)
                    // Decode HTML entities in URL (important for URLs with & parameters)
                    var decodedURL = decodeHTMLEntities(url)
                    // Upgrade TuneIn URLs to HTTPS (macOS ATS blocks HTTP)
                    if decodedURL.hasPrefix("http://opml.radiotime.com") {
                        decodedURL = decodedURL.replacingOccurrences(of: "http://", with: "https://")
                    }

                    let station = RadioStation(id: nil, name: decodedName, url: decodedURL, genre: nil, country: subtext.isEmpty ? nil : subtext, bitrate: bitrate)
                    results.append(station)
                }
            }

            searchRange = outlineEnd.upperBound..<xml.endIndex
        }

        return results
    }

    /// Decode common HTML entities
    private func decodeHTMLEntities(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }

    private func searchiHeartRadio(query: String) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.iheart.com/api/v2/content/liveStations?countryCode=US&limit=20&q=\(encodedQuery)") else {
            return
        }

        AccessibilityManager.announce("Searching...")

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self, let data = data, error == nil else {
                    AccessibilityManager.announce("Search failed")
                    return
                }

                self.searchResults = self.parseIHeartJSON(data)
                self.searchTable.reloadData()
                AccessibilityManager.announce("\(self.searchResults.count) stations found")
            }
        }
        task.resume()
    }

    /// Parse iHeartRadio JSON response
    private func parseIHeartJSON(_ data: Data) -> [RadioStation] {
        var results: [RadioStation] = []

        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let hits = json["hits"] as? [[String: Any]] {
                for item in hits {
                    guard let name = item["name"] as? String ?? item["description"] as? String,
                          let stationId = item["id"] as? Int else { continue }

                    var displayName = name
                    if let callLetters = item["callLetters"] as? String, !callLetters.isEmpty,
                       !name.contains(callLetters) {
                        displayName = "\(callLetters) - \(name)"
                    }

                    var location: String?
                    if let city = item["city"] as? String {
                        location = city
                        if let state = item["state"] as? String {
                            location = "\(city), \(state)"
                        }
                    }

                    // Get stream URL from nested streams object or construct from ID
                    var streamUrl = ""
                    if let streams = item["streams"] as? [String: Any] {
                        streamUrl = streams["shoutcast_stream"] as? String ??
                                   streams["secure_shoutcast_stream"] as? String ??
                                   streams["pls_stream"] as? String ??
                                   streams["hls_stream"] as? String ?? ""
                    }

                    // If no stream URL in response, we'll need to fetch it separately
                    if streamUrl.isEmpty {
                        streamUrl = "iheart://\(stationId)"  // Placeholder, resolve on play
                    }

                    let station = RadioStation(id: nil, name: displayName, url: streamUrl, genre: nil, country: location, bitrate: nil)
                    results.append(station)
                }
            }
        } catch {
            // Try alternate JSON structure (v3 API)
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let stations = json["stations"] as? [String: Any],
                   let stationResults = stations["results"] as? [[String: Any]] {
                    for item in stationResults {
                        guard let name = item["name"] as? String ?? item["description"] as? String,
                              let stationId = item["id"] as? Int else { continue }

                        let station = RadioStation(id: nil, name: name, url: "iheart://\(stationId)", genre: nil, country: nil, bitrate: nil)
                        results.append(station)
                    }
                }
            } catch {}
        }

        return results
    }

    /// Extract XML attribute value
    private func extractXMLAttribute(_ element: String, _ attr: String) -> String {
        // Try double quotes
        if let range = element.range(of: "\(attr)=\"") {
            let start = range.upperBound
            if let end = element.range(of: "\"", range: start..<element.endIndex) {
                return String(element[start..<end.lowerBound])
            }
        }
        // Try single quotes
        if let range = element.range(of: "\(attr)='") {
            let start = range.upperBound
            if let end = element.range(of: "'", range: start..<element.endIndex) {
                return String(element[start..<end.lowerBound])
            }
        }
        return ""
    }

    @objc private func addSearchToFavorites() {
        let row = searchTable.selectedRow
        guard row >= 0 && row < searchResults.count else { return }
        DatabaseManager.shared.saveRadioStation(searchResults[row])
        loadFavorites()
        AccessibilityManager.announce("Added to favorites")
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        // Cmd+C = copy selected station URL to clipboard (parity with Windows radio dialog).
        if event.keyCode == 8 && event.modifierFlags.contains(.command) {
            // Only steal Cmd+C if a station row is selected; otherwise let text fields copy normally.
            let onFavorites = (tabView.selectedTabViewItem?.identifier as? String) == "favorites"
            let source = onFavorites ? favorites : searchResults
            let table = onFavorites ? favoritesTable : searchTable
            let row = table?.selectedRow ?? -1
            if row >= 0 && row < source.count {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(source[row].url, forType: .string)
                AccessibilityManager.announce("URL copied")
                return true
            }
        }

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
            // If search field is focused, let it handle Enter (triggers performSearch)
            if window?.firstResponder == searchField ||
               (window?.firstResponder as? NSText)?.delegate === searchField {
                performSearch()
                return true
            }

            // Otherwise, play selected station
            if tabView.selectedTabViewItem?.identifier as? String == "favorites" {
                playSelectedFavorite()
            } else {
                playSelectedSearch()
            }
            return true
        }

        // Delete = Remove from favorites
        if event.keyCode == 51 && tabView.selectedTabViewItem?.identifier as? String == "favorites" {
            let row = favoritesTable.selectedRow
            if row >= 0 && row < favorites.count {
                if let id = favorites[row].id {
                    DatabaseManager.shared.deleteRadioStation(id: id)
                    loadFavorites()
                }
            }
            return true
        }

        return false
    }

    // MARK: - Data Loading

    private func loadFavorites() {
        favorites = DatabaseManager.shared.getAllRadioStations()
        favoritesTable.reloadData()
    }

    // MARK: - Show

    func show() {
        loadFavorites()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Focus favorites list and select first item
        if !favorites.isEmpty {
            favoritesTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        window?.makeFirstResponder(favoritesTable)
    }
}

// MARK: - Table View Data Source & Delegate

extension RadioWindowController: NSTableViewDataSource, NSTableViewDelegate {

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView.tag == 1 {
            return favorites.count
        } else {
            return searchResults.count
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("StationCell")

        var cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField
        if cell == nil {
            cell = NSTextField(labelWithString: "")
            cell?.identifier = identifier
            cell?.lineBreakMode = .byTruncatingMiddle
        }

        let station = tableView.tag == 1 ? favorites[row] : searchResults[row]
        cell?.stringValue = station.name

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 22
    }
}
