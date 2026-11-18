import Foundation

/// Direct YouTube search and audio-stream resolution for Pleer1.
/// Uses YouTube's InnerTube endpoints from the app itself; no Musike server or proxy.
enum YouTubeEngine {
    struct Stream {
        let url: URL
        let mimeType: String
        let duration: Double
    }

    private struct Client {
        let name: String
        let version: String
        let id: String
    }

    // VISIONOS is attempted first because current YouTube responses can restrict
    // some other clients unless a proof-of-origin token is supplied.
    private static let clients = [
        Client(name: "VISIONOS", version: "1.02", id: "101"),
        Client(name: "ANDROID_VR", version: "1.60.19", id: "28"),
        Client(name: "IOS", version: "20.10.4", id: "5")
    ]

    private static let playerURL = URL(string: "https://www.youtube.com/youtubei/v1/player?prettyPrint=false&alt=json")!
    private static let visitorURL = URL(string: "https://www.youtube.com/youtubei/v1/visitor_id?prettyPrint=false")!
    private static let searchURL = URL(string: "https://www.youtube.com/youtubei/v1/search?prettyPrint=false")!
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"
    private static let visitorKey = "pleer1.youtube.visitorData"
    private static let visitorAgeKey = "pleer1.youtube.visitorDataAt"
    private static let visitorTTL: TimeInterval = 24 * 60 * 60
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    /// Two independent search transports:
    /// 1) InnerTube JSON (fast, structured).
    /// 2) YouTube's public results page (HTML + embedded ytInitialData).
    /// Both transports run concurrently; usable results from both are merged and deduplicated.
    static func search(_ query: String) async throws -> [Track] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        let searchID = String(UUID().uuidString.prefix(8))
        let includeCollections = YouTubeSearchIntent.includesCollections(for: normalized)
        YouTubeDiagnostics.record("search.begin", details: "id=\(searchID), query=\(normalized), mode=\(includeCollections ? "collections+videos" : "videos")")
        if let playlist = YouTubePlaylistEngine.playlistTrack(from: normalized) {
            YouTubeDiagnostics.record("search.input_playlist", details: "id=\(playlist.id)")
            return [playlist]
        }

        // Start both independent transports together, but retain each error
        // instead of swallowing it so the exported journal shows which path failed.
        async let primaryTask = searchInnerTube(normalized, searchID: searchID, includeCollections: includeCollections)
        async let fallbackTask = YouTubeHTMLSearch.search(normalized, searchID: searchID, includeCollections: includeCollections)

        var primary: [Track] = []
        var fallback: [Track] = []
        do {
            primary = try await primaryTask
            YouTubeDiagnostics.record("search.innertube.success", details: "id=\(searchID), tracks=\(primary.count)")
        } catch {
            YouTubeDiagnostics.record("search.innertube.failure", details: "id=\(searchID), error=\(error.localizedDescription)")
        }
        do {
            fallback = try await fallbackTask
            YouTubeDiagnostics.record("search.html.success", details: "id=\(searchID), tracks=\(fallback.count)")
        } catch {
            YouTubeDiagnostics.record("search.html.failure", details: "id=\(searchID), error=\(error.localizedDescription)")
        }

        var seen = Set<String>()
        let combined = (primary + fallback).filter { seen.insert($0.id).inserted }
        YouTubeDiagnostics.record("search.complete", details: "id=\(searchID), innertube=\(primary.count), html=\(fallback.count), merged=\(combined.count)")

        guard !combined.isEmpty else {
            throw makeError("YouTube не вернул распознанных видео ни через InnerTube, ни через резервную HTML-страницу.")
        }
        return combined
    }

    private static func searchInnerTube(_ query: String, searchID: String, includeCollections: Bool) async throws -> [Track] {
        var body: [String: Any] = [
            "context": ["client": [
                "clientName": "WEB",
                "clientVersion": "2.20241126.01.00",
                "hl": "ru",
                "gl": "RU"
            ]],
            "query": query
        ]
        // Apply YouTube's Videos filter only to ordinary track searches.
        // Explicit playlist/Mix searches must keep the collection renderers.
        if !includeCollections {
            body["params"] = "EgIQAQ%3D%3D"
        }
        YouTubeDiagnostics.record("search.innertube.request", details: "id=\(searchID), client=WEB, query=\(query), includeCollections=\(includeCollections), videoFilter=\(!includeCollections)")
        let raw = try await post(searchURL, body: body, headers: [
            "Origin": "https://www.youtube.com",
            "Referer": "https://www.youtube.com/"
        ])
        let parsed = tracks(from: raw, includeCollections: includeCollections, searchID: searchID)
        YouTubeDiagnostics.record("search.innertube.parsed", details: "id=\(searchID), tracks=\(parsed.count)")
        return parsed
    }

    static func tracks(from raw: Any, includeCollections: Bool, searchID: String = "fixture") -> [Track] {
        let rootKeys = ((raw as? [String: Any])?.keys.sorted() ?? []).joined(separator: ",")
        let rendererKeys = ["videoRenderer", "gridVideoRenderer", "compactVideoRenderer", "videoWithContextRenderer", "reelItemRenderer", "playlistPanelVideoRenderer", "musicResponsiveListItemRenderer", "lockupViewModel"]
        let rendererCounts = rendererKeys.map { "\($0)=\(countOccurrences(of: $0, in: raw))" }.joined(separator: ",")
        YouTubeDiagnostics.record("search.response.structure", details: "id=\(searchID), rootKeys=\(rootKeys), renderers={\(rendererCounts)}")

        var items: [[String: Any]] = []
        findVideoItems(raw, into: &items)
        YouTubeDiagnostics.record("search.parse.candidates", details: "id=\(searchID), candidateItems=\(items.count)")

        var seen = Set<String>()
        let videos = items.compactMap { item -> Track? in
            guard let track = track(from: item), seen.insert(track.id).inserted else { return nil }
            return track
        }
        let playlists = includeCollections ? YouTubePlaylistEngine.playlistTracks(from: raw) : []
        let radios = includeCollections ? YouTubePlaylistEngine.radioTracks(from: raw) : []
        // Video IDs were already inserted into seen while building videos.
        // Deduplicate only collection results against videos and earlier collections;
        // filtering the whole concatenated array would discard every video.
        let collections = (playlists + radios).filter { seen.insert($0.id).inserted }
        let combined = videos + collections
        YouTubeDiagnostics.record("search.parse.summary", details: "id=\(searchID), candidates=\(items.count), videos=\(videos.count), playlists=\(playlists.count), radios=\(radios.count), returned=\(combined.count)")
        return combined
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

    static func resolve(videoID: String) async throws -> Stream {
        YouTubeDiagnostics.record("resolve.begin", details: "videoID=\(videoID)")
        guard !videoID.isEmpty else {
            throw makeError("Не удалось определить идентификатор видео")
        }

        var failures: [String] = []
        let visitorData: String
        do {
            visitorData = try await fetchVisitorData()
            YouTubeDiagnostics.record("resolve.visitor", details: "available=\(!visitorData.isEmpty)")
            if visitorData.isEmpty { failures.append("visitorData: YouTube не выдал идентификатор посетителя") }
        } catch {
            visitorData = ""
            YouTubeDiagnostics.record("resolve.visitor.failure", details: error.localizedDescription)
            failures.append("visitorData: \(error.localizedDescription)")
        }

        for client in clients {
            do {
                YouTubeDiagnostics.record("resolve.client.begin", details: "videoID=\(videoID), client=\(client.name), version=\(client.version)")
                var clientContext = makeClientContext(client, language: "ru", region: "RU")
                if !visitorData.isEmpty { clientContext["visitorData"] = visitorData }
                clientContext["originalUrl"] = "https://www.youtube.com/watch?v=\(videoID)"

                let body: [String: Any] = [
                    "videoId": videoID,
                    "racyCheckOk": true,
                    "contentCheckOk": true,
                    "context": ["client": clientContext],
                    "playbackContext": [
                        "contentPlaybackContext": ["html5Preference": "HTML5_PREF_WANTS"]
                    ]
                ]

                let raw = try await post(playerURL, body: body, client: client)
                guard let root = raw as? [String: Any] else {
                    failures.append("\(client.name): пустой ответ")
                    continue
                }

                let playability = root["playabilityStatus"] as? [String: Any] ?? [:]
                let status = playability["status"] as? String ?? "UNKNOWN"
                let reason = playability["reason"] as? String ?? status
                YouTubeDiagnostics.record("resolve.client.response", details: "client=\(client.name), status=\(status), reason=\(reason)")
                guard status == "OK" else {
                    failures.append("\(client.name): \(reason)")
                    continue
                }

                let details = root["videoDetails"] as? [String: Any] ?? [:]
                let streaming = root["streamingData"] as? [String: Any] ?? [:]
                let formats = streaming["adaptiveFormats"] as? [[String: Any]] ?? []
                let audio = formats
                    .filter {
                        let mime = string($0["mimeType"]) ?? ""
                        return mime.hasPrefix("audio/mp4") && string($0["url"]) != nil
                    }
                    .sorted { integer($0["bitrate"]) > integer($1["bitrate"]) }

                guard let best = audio.first,
                      let rawURL = string(best["url"]),
                      let url = URL(string: rawURL),
                      url.scheme == "https" else {
                    YouTubeDiagnostics.record("resolve.client.no_audio", details: "client=\(client.name), adaptiveFormats=\(formats.count), directAudio=\(audio.count)")
                    failures.append("\(client.name): нет прямого аудиоформата (форматов: \(formats.count))")
                    continue
                }

                let duration = Double(string(details["lengthSeconds"]) ?? "") ?? 0
                YouTubeDiagnostics.record("resolve.success", details: "videoID=\(videoID), client=\(client.name), audioFormats=\(audio.count), bitrate=\(integer(best["bitrate"])), duration=\(duration)")
                return Stream(
                    url: url,
                    mimeType: string(best["mimeType"]) ?? "audio/mp4",
                    duration: duration
                )
            } catch {
                YouTubeDiagnostics.record("resolve.client.failure", details: "videoID=\(videoID), client=\(client.name), error=\(error.localizedDescription)")
                failures.append("\(client.name): \(error.localizedDescription)")
            }
        }

        let details = failures.isEmpty ? "YouTube не вернул доступные форматы" : failures.joined(separator: " · ")
        YouTubeDiagnostics.record("resolve.failure", details: "videoID=\(videoID), attempts=\(failures.joined(separator: " | "))")
        throw makeError("Не удалось получить аудио. \(details)")
    }

    // MARK: Visitor identity

    private static func fetchVisitorData() async throws -> String {
        let defaults = UserDefaults.standard
        let age = Date().timeIntervalSince1970 - defaults.double(forKey: visitorAgeKey)
        if let cached = defaults.string(forKey: visitorKey),
           !cached.isEmpty, age >= 0, age < visitorTTL {
            return cached
        }

        let client = clients[0]
        let body: [String: Any] = [
            "context": ["client": makeClientContext(client, language: "ru", region: "RU")]
        ]
        let raw = try await post(visitorURL, body: body, client: client)
        let fresh = ((raw as? [String: Any])?["responseContext"] as? [String: Any])?["visitorData"] as? String ?? ""
        if !fresh.isEmpty {
            defaults.set(fresh, forKey: visitorKey)
            defaults.set(Date().timeIntervalSince1970, forKey: visitorAgeKey)
        }
        return fresh
    }

    private static func makeClientContext(_ client: Client, language: String, region: String) -> [String: Any] {
        [
            "clientName": client.name,
            "clientVersion": client.version,
            "hl": language,
            "gl": region,
            "userAgent": "\(userAgent),gzip(gfe)",
            "platform": "DESKTOP"
        ]
    }

    // MARK: HTTP

    private static func post(
        _ url: URL,
        body: [String: Any],
        client: Client? = nil,
        headers extraHeaders: [String: String] = [:]
    ) async throws -> Any {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        if let client {
            request.setValue(client.id, forHTTPHeaderField: "X-YouTube-Client-Name")
            request.setValue(client.version, forHTTPHeaderField: "X-YouTube-Client-Version")
            request.setValue("2", forHTTPHeaderField: "X-Goog-Api-Format-Version")
        }
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        let http = response as? HTTPURLResponse
        YouTubeDiagnostics.record("http.response", details: "path=\(url.path), status=\(http?.statusCode ?? -1), bytes=\(data.count), contentType=\(http?.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
        if let http, !(200...299).contains(http.statusCode) {
            throw makeError("YouTube ответил HTTP \(http.statusCode)")
        }
        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            YouTubeDiagnostics.record("http.json_failure", details: "path=\(url.path), bytes=\(data.count), error=\(error.localizedDescription)")
            throw error
        }
    }

    // MARK: Search response parsing

    private static func countOccurrences(of key: String, in value: Any) -> Int {
        if let object = value as? [String: Any] {
            return (object[key] == nil ? 0 : 1) + object.values.reduce(0) { $0 + countOccurrences(of: key, in: $1) }
        }
        if let array = value as? [Any] {
            return array.reduce(0) { $0 + countOccurrences(of: key, in: $1) }
        }
        return 0
    }

    private static func findVideoItems(_ value: Any, into result: inout [[String: Any]]) {
        if let object = value as? [String: Any] {
            for key in ["videoRenderer", "gridVideoRenderer", "compactVideoRenderer", "videoWithContextRenderer", "reelItemRenderer"] {
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

    private static func integer(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? String { return Int(value) ?? 0 }
        if let value = value as? NSNumber { return value.intValue }
        return 0
    }

    private static func makeError(_ message: String) -> NSError {
        NSError(
            domain: "Pleer1.YouTube",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
