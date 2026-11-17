import Foundation

/// Independent fallback search implementation.
///
/// Unlike YouTubeEngine's InnerTube JSON POST, this module performs a normal
/// GET request to YouTube's public search-results page and reads ytInitialData.
enum YouTubeHTMLSearch {
    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    static func search(_ query: String) async throws -> [Track] {
        YouTubeDiagnostics.record("search.html.begin", details: "query=\(query)")
        var components = URLComponents(string: "https://www.youtube.com/results")!
        components.queryItems = [URLQueryItem(name: "search_query", value: query)]
        guard let url = components.url else {
            throw makeError("Не удалось сформировать резервный поисковый запрос")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("https://www.youtube.com/", forHTTPHeaderField: "Referer")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let (data, response) = try await session.data(for: request)
        let http = response as? HTTPURLResponse
        YouTubeDiagnostics.record("search.html.response", details: "status=\(http?.statusCode ?? -1), bytes=\(data.count), contentType=\(http?.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
        if let http, !(200...299).contains(http.statusCode) {
            throw makeError("Страница YouTube ответила HTTP \(http.statusCode)")
        }
        guard let html = String(data: data, encoding: .utf8) else {
            YouTubeDiagnostics.record("search.html.decode_failure", details: "bytes=\(data.count)")
            throw makeError("Ответ YouTube не удалось декодировать как UTF-8")
        }
        guard let initialData = extractInitialData(from: html) else {
            let marker = html.contains("ytInitialData")
            YouTubeDiagnostics.record("search.html.initial_data_missing", details: "bytes=\(data.count), hasMarker=\(marker), hasConsent=\(html.localizedCaseInsensitiveContains("consent")), hasCaptcha=\(html.localizedCaseInsensitiveContains("captcha"))")
            throw makeError("Не удалось найти ytInitialData на странице YouTube")
        }
        let result = tracks(from: initialData)
        YouTubeDiagnostics.record("search.html.parsed", details: "tracks=\(result.count)")
        guard !result.isEmpty else {
            throw makeError("HTML-страница YouTube не содержит распознанных видео")
        }
        return result
    }

    /// Extracts the balanced JSON object assigned to ytInitialData.
    private static func extractInitialData(from html: String) -> Any? {
        guard let marker = html.range(of: "ytInitialData") else { return nil }
        let tail = html[marker.upperBound...]
        guard let opening = tail.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var escaped = false
        var cursor = opening
        while cursor < tail.endIndex {
            let character = tail[cursor]
            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
            } else {
                if character == "\"" {
                    inString = true
                } else if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        let json = String(tail[opening...cursor])
                        guard let jsonData = json.data(using: .utf8) else { return nil }
                        return try? JSONSerialization.jsonObject(with: jsonData)
                    }
                }
            }
            cursor = tail.index(after: cursor)
        }
        return nil
    }

    private static func tracks(from raw: Any) -> [Track] {
        var items: [[String: Any]] = []
        findVideoItems(raw, into: &items)

        var seen = Set<String>()
        let videos = items.compactMap { item -> Track? in
            guard let track = track(from: item), seen.insert(track.id).inserted else { return nil }
            return track
        }
        let playlists = YouTubePlaylistEngine.playlistTracks(from: raw)
        let radios = YouTubePlaylistEngine.radioTracks(from: raw)
        return (videos + playlists + radios).filter { seen.insert($0.id).inserted }
    }

    private static func track(from item: [String: Any]) -> Track? {
        if let music = item["__musicRenderer"] as? [String: Any] {
            let columns = music["flexColumns"] as? [[String: Any]] ?? []
            let title = columns.first.flatMap { textValue((($0["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"])) }
                ?? textValue(music["title"])
            guard let id = musicVideoID(music), !id.isEmpty, let title, !title.isEmpty else { return nil }
            let artist = columns.dropFirst().compactMap { column in
                textValue((column["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"])
            }.first ?? "YouTube"
            let thumbs = (music["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]] ?? []
            return Track(id: "y" + id, title: title, artist: artist,
                         art: thumbs.last.flatMap { string($0["url"]) },
                         url: "https://www.youtube.com/watch?v=\(id)")
        }
        if let lockup = item["__lockupViewModel"] as? [String: Any] {
            guard string(lockup["contentType"]) == "LOCKUP_CONTENT_TYPE_VIDEO",
                  let id = string(lockup["contentId"]), !id.isEmpty,
                  let metadata = lockup["metadata"] as? [String: Any],
                  let lockupMetadata = metadata["lockupMetadataViewModel"] as? [String: Any],
                  let title = textValue(lockupMetadata["title"]) else { return nil }

            let rows = ((lockupMetadata["metadata"] as? [String: Any])?["contentMetadataViewModel"] as? [String: Any])?["metadataRows"] as? [[String: Any]] ?? []
            let artist = rows.lazy
                .flatMap { $0["metadataParts"] as? [[String: Any]] ?? [] }
                .compactMap { part -> String? in
                    guard let text = part["text"] as? [String: Any] else { return nil }
                    return string(text["content"]) ?? textValue(text)
                }
                .first ?? "YouTube"

            let image = (lockup["contentImage"] as? [String: Any])?["thumbnailViewModel"] as? [String: Any]
            let imageData = image?["image"] as? [String: Any]
            let sources = imageData?["sources"] as? [[String: Any]] ?? []
            let art = sources.last.flatMap { string($0["url"]) }
            return Track(
                id: "y" + id,
                title: title,
                artist: artist,
                art: art,
                url: "https://www.youtube.com/watch?v=\(id)"
            )
        }

        let renderer = (item["__videoRenderer"] as? [String: Any]) ?? item
        guard let id = string(renderer["videoId"]), !id.isEmpty,
              let title = textValue(renderer["title"]) else { return nil }
        let artist = textValue(renderer["ownerText"]) ?? textValue(renderer["shortBylineText"]) ?? "YouTube"
        let thumbs = (renderer["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]] ?? []
        let art = thumbs.last.flatMap { string($0["url"]) }
        return Track(
            id: "y" + id,
            title: title,
            artist: artist,
            art: art,
            url: "https://www.youtube.com/watch?v=\(id)"
        )
    }

    private static func findVideoItems(_ value: Any, into result: inout [[String: Any]]) {
        if let object = value as? [String: Any] {
            for key in ["videoRenderer", "gridVideoRenderer", "compactVideoRenderer", "videoWithContextRenderer", "reelItemRenderer", "playlistPanelVideoRenderer"] {
                if let renderer = object[key] as? [String: Any],
                   string(renderer["videoId"]) != nil {
                    result.append(["__videoRenderer": renderer])
                }
            }
            if let music = object["musicResponsiveListItemRenderer"] as? [String: Any], musicVideoID(music) != nil {
                result.append(["__musicRenderer": music])
            }
            if let lockup = object["lockupViewModel"] as? [String: Any],
               string(lockup["contentType"]) == "LOCKUP_CONTENT_TYPE_VIDEO",
               string(lockup["contentId"]) != nil {
                result.append(["__lockupViewModel": lockup])
            }
            for child in object.values {
                findVideoItems(child, into: &result)
            }
        } else if let array = value as? [Any] {
            for child in array {
                findVideoItems(child, into: &result)
            }
        }
    }

    private static func musicVideoID(_ renderer: [String: Any]) -> String? {
        let item = renderer["playlistItemData"] as? [String: Any]
        if let id = string(item?["videoId"]), !id.isEmpty { return id }
        let endpoint = renderer["navigationEndpoint"] as? [String: Any]
        let watch = endpoint?["watchEndpoint"] as? [String: Any]
        if let id = string(watch?["videoId"]), !id.isEmpty { return id }
        let overlay = renderer["overlay"] as? [String: Any]
        let content = overlay?["musicItemThumbnailOverlayRenderer"] as? [String: Any]
        let button = content?["content"] as? [String: Any]
        let play = button?["musicPlayButtonRenderer"] as? [String: Any]
        let playEndpoint = play?["playNavigationEndpoint"] as? [String: Any]
        let playWatch = playEndpoint?["watchEndpoint"] as? [String: Any]
        if let id = string(playWatch?["videoId"]), !id.isEmpty { return id }
        return nil
    }

    private static func textValue(_ value: Any?) -> String? {
        guard let object = value as? [String: Any] else { return nil }
        if let simple = string(object["simpleText"]) { return simple }
        if let content = string(object["content"]) { return content }
        if let runs = object["runs"] as? [[String: Any]] {
            let text = runs.compactMap { string($0["text"]) }.joined()
            return text.isEmpty ? nil : text
        }
        return nil
    }

    private static func string(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }

    private static func makeError(_ message: String) -> NSError {
        NSError(
            domain: "Pleer1.YouTube.HTMLSearch",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
