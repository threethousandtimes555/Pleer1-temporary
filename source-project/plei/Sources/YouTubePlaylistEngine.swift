import Foundation

/// Loads the videos that belong to a YouTube playlist.
/// Search results are represented as lightweight Track entries; selecting one
/// resolves the playlist into ordinary YouTube video tracks before playback.
enum YouTubePlaylistEngine {
    private static let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/browse?prettyPrint=false&alt=json")!
    private static let nextEndpoint = URL(string: "https://www.youtube.com/youtubei/v1/next?prettyPrint=false&alt=json")!
    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    private static let clientVersion = "2.20241126.01.00"
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    static func playlistTrack(from query: String) -> Track? {
        guard let components = URLComponents(string: query),
              let host = components.host?.lowercased(),
              host.contains("youtube.com"),
              let playlistID = components.queryItems?.first(where: { $0.name == "list" })?.value,
              !playlistID.isEmpty else { return nil }
        if playlistID.hasPrefix("RD") {
            guard let seedVideoID = components.queryItems?.first(where: { $0.name == "v" })?.value,
                  !seedVideoID.isEmpty else { return nil }
            return Track(
                id: "yr" + playlistID,
                title: "YouTube-микс",
                artist: "YouTube",
                url: "https://www.youtube.com/watch?v=\(seedVideoID)&list=\(playlistID)",
                youtubeRadioID: playlistID,
                youtubeRadioVideoID: seedVideoID
            )
        }
        return Track(
            id: "yp" + playlistID,
            title: "YouTube-плейлист",
            artist: "YouTube",
            url: "https://www.youtube.com/playlist?list=\(playlistID)",
            youtubePlaylistID: playlistID
        )
    }

    static func playlistTracks(from raw: Any) -> [Track] {
        var found: [[String: Any]] = []
        collectPlaylistRenderers(raw, into: &found)
        var seen = Set<String>()
        return found.compactMap { renderer in
            guard let playlistID = string(renderer["playlistId"]), !playlistID.isEmpty,
                  seen.insert(playlistID).inserted else { return nil }
            let title = text(renderer["title"]) ?? "YouTube-плейлист"
            let artist = text(renderer["shortBylineText"]) ?? text(renderer["longBylineText"]) ?? "YouTube"
            let thumbnails = (renderer["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]] ?? []
            let art = thumbnails.reversed().compactMap { thumbnail in
                thumbnailURL(thumbnail) ??
                ((thumbnail["thumbnails"] as? [[String: Any]])?.last.flatMap { thumbnailURL($0) })
            }.first
            return Track(
                id: "yp" + playlistID,
                title: title,
                artist: artist,
                art: art,
                url: "https://www.youtube.com/playlist?list=\(playlistID)",
                youtubePlaylistID: playlistID
            )
        }
    }


    /// YouTube radio mixes are not ordinary playlists. They must be expanded
    /// through the /next endpoint using both the RD playlist ID and a seed video.
    static func radioTracks(from raw: Any) -> [Track] {
        var found: [[String: Any]] = []
        collectRadioRenderers(raw, into: &found)
        var seen = Set<String>()
        return found.compactMap { renderer in
            guard let playlistID = string(renderer["playlistId"]), playlistID.hasPrefix("RD"),
                  let videoID = radioSeedVideoID(renderer), !videoID.isEmpty,
                  seen.insert(playlistID).inserted else { return nil }
            let title = text(renderer["title"]) ?? "YouTube-микс"
            let artist = text(renderer["shortBylineText"]) ?? text(renderer["longBylineText"]) ?? "YouTube"
            let thumbnails = (renderer["thumbnails"] as? [[String: Any]]) ?? []
            let art = thumbnails.last.flatMap { thumbnailURL($0) }
            return Track(
                id: "yr" + playlistID,
                title: title,
                artist: artist,
                art: art,
                url: "https://www.youtube.com/watch?v=\(videoID)&list=\(playlistID)",
                youtubeRadioID: playlistID,
                youtubeRadioVideoID: videoID
            )
        }
    }

    static func loadRadio(playlistID: String, seedVideoID: String) async throws -> [Track] {
        guard playlistID.hasPrefix("RD"), !seedVideoID.isEmpty else {
            throw makeError("Не удалось определить параметры YouTube-микса")
        }
        let context: [String: Any] = [
            "client": [
                "clientName": "WEB",
                "clientVersion": clientVersion,
                "hl": "ru",
                "gl": "RU"
            ]
        ]
        var body: [String: Any] = [
            "context": context,
            "videoId": seedVideoID,
            "playlistId": playlistID
        ]
        var all: [Track] = []
        var seenVideos = Set<String>()
        var seenContinuations = Set<String>()

        for pageIndex in 0..<20 {
            let raw = try await post(nextEndpoint, body: body)
            let page = radioVideoTracks(from: raw)
            YouTubeDiagnostics.record("radio.page", details: "page=\(pageIndex + 1), parsed=\(page.count), totalBeforeMerge=\(all.count)")
            for track in page where seenVideos.insert(track.id).inserted {
                all.append(track)
                if all.count >= 500 { return all }
            }
            guard let continuation = continuationToken(from: raw),
                  !continuation.isEmpty,
                  seenContinuations.insert(continuation).inserted else { break }
            body = ["context": context, "continuation": continuation]
        }
        guard !all.isEmpty else {
            throw makeError("YouTube не вернул видео из этого микса")
        }
        return all
    }

    private static func radioVideoTracks(from raw: Any) -> [Track] {
        var renderers: [[String: Any]] = []
        collectRadioVideoRenderers(raw, into: &renderers)
        var seen = Set<String>()
        return renderers.compactMap { renderer in
            guard let videoID = string(renderer["videoId"]) ?? string((renderer["playlistItemData"] as? [String: Any])?["videoId"]),
                  !videoID.isEmpty, seen.insert(videoID).inserted,
                  let title = text(renderer["title"]) else { return nil }
            let artist = text(renderer["longBylineText"]) ?? text(renderer["shortBylineText"]) ?? "YouTube"
            let thumbnails = (renderer["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]] ?? []
            let art = thumbnails.last.flatMap { thumbnailURL($0) }
            return Track(id: "y" + videoID, title: title, artist: artist, art: art,
                         url: "https://www.youtube.com/watch?v=\(videoID)")
        }
    }

    private static func collectRadioVideoRenderers(_ value: Any, into result: inout [[String: Any]]) {
        if let object = value as? [String: Any] {
            if let renderer = object["playlistPanelVideoRenderer"] as? [String: Any] {
                result.append(renderer)
            } else if let wrapper = object["playlistPanelVideoWrapperRenderer"] as? [String: Any] {
                collectRadioVideoRenderers(wrapper, into: &result)
            }
            for child in object.values { collectRadioVideoRenderers(child, into: &result) }
        } else if let array = value as? [Any] {
            for child in array { collectRadioVideoRenderers(child, into: &result) }
        }
    }

    private static func collectRadioRenderers(_ value: Any, into result: inout [[String: Any]]) {
        if let object = value as? [String: Any] {
            if let renderer = object["radioRenderer"] as? [String: Any],
               string(renderer["playlistId"]) != nil {
                result.append(renderer)
            }
            for child in object.values { collectRadioRenderers(child, into: &result) }
        } else if let array = value as? [Any] {
            for child in array { collectRadioRenderers(child, into: &result) }
        }
    }

    private static func radioSeedVideoID(_ renderer: [String: Any]) -> String? {
        if let id = string(renderer["videoId"]), !id.isEmpty { return id }
        let endpoint = renderer["navigationEndpoint"] as? [String: Any]
        let watch = endpoint?["watchEndpoint"] as? [String: Any]
        if let id = string(watch?["videoId"]), !id.isEmpty { return id }
        let playlistWatch = endpoint?["watchPlaylistEndpoint"] as? [String: Any]
        if let id = string(playlistWatch?["videoId"]), !id.isEmpty { return id }
        if let videos = renderer["videos"] as? [[String: Any]],
           let first = videos.first?["childVideoRenderer"] as? [String: Any],
           let id = string(first["videoId"]), !id.isEmpty { return id }
        return nil
    }

    static func load(playlistID: String) async throws -> [Track] {
        guard !playlistID.isEmpty else {
            throw makeError("Не удалось определить ID YouTube-плейлиста")
        }

        let context: [String: Any] = [
            "client": [
                "clientName": "WEB",
                "clientVersion": clientVersion,
                "hl": "ru",
                "gl": "RU"
            ]
        ]
        var body: [String: Any] = [
            "context": context,
            "browseId": "VL" + playlistID
        ]

        var all: [Track] = []
        var seenVideos = Set<String>()
        var seenContinuations = Set<String>()

        // A page usually contains many videos. The cap prevents an unbounded
        // request chain for extremely large playlists or changing continuations.
        for pageIndex in 0..<20 {
            let raw = try await post(body)
            let page = videoTracks(from: raw)
            YouTubeDiagnostics.record("playlist.page", details: "page=\(pageIndex + 1), parsed=\(page.count), totalBeforeMerge=\(all.count)")
            for track in page where seenVideos.insert(track.id).inserted {
                all.append(track)
                if all.count >= 1000 { return all }
            }

            guard let continuation = continuationToken(from: raw),
                  !continuation.isEmpty,
                  seenContinuations.insert(continuation).inserted else {
                break
            }
            body = [
                "context": context,
                "continuation": continuation
            ]
        }

        guard !all.isEmpty else {
            throw makeError("YouTube не вернул видео из этого плейлиста")
        }
        return all
    }

    private static func post(_ body: [String: Any]) async throws -> Any {
        try await post(endpoint, body: body)
    }

    private static func post(_ url: URL, body: [String: Any]) async throws -> Any {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.youtube.com/", forHTTPHeaderField: "Referer")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        let http = response as? HTTPURLResponse
        YouTubeDiagnostics.record("playlist.http", details: "path=\(url.path), status=\(http?.statusCode ?? -1), bytes=\(data.count)")
        if let http, !(200...299).contains(http.statusCode) {
            throw makeError("YouTube ответил HTTP \(http.statusCode) при загрузке плейлиста")
        }
        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            YouTubeDiagnostics.record("playlist.json_failure", details: "path=\(url.path), bytes=\(data.count), error=\(error.localizedDescription)")
            throw error
        }
    }

    private static func videoTracks(from raw: Any) -> [Track] {
        var renderers: [[String: Any]] = []
        collectPlaylistVideoRenderers(raw, into: &renderers)
        if renderers.isEmpty {
            collectVideoRenderers(raw, into: &renderers)
        }
        var seen = Set<String>()
        return renderers.compactMap { renderer in
            guard let videoID = string(renderer["videoId"]), !videoID.isEmpty,
                  seen.insert(videoID).inserted,
                  let title = text(renderer["title"]) else { return nil }
            let artist = text(renderer["shortBylineText"]) ?? text(renderer["longBylineText"]) ?? text(renderer["ownerText"]) ?? "YouTube"
            let thumbnails = (renderer["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]] ?? []
            let art = thumbnails.last.flatMap { thumbnailURL($0) }
            return Track(
                id: "y" + videoID,
                title: title,
                artist: artist,
                art: art,
                url: "https://www.youtube.com/watch?v=\(videoID)"
            )
        }
    }

    private static func collectPlaylistRenderers(_ value: Any, into result: inout [[String: Any]]) {
        if let object = value as? [String: Any] {
            for key in ["playlistRenderer", "compactPlaylistRenderer", "gridPlaylistRenderer"] {
                if let renderer = object[key] as? [String: Any],
                   string(renderer["playlistId"]) != nil {
                    result.append(renderer)
                }
            }
            if let lockup = object["lockupViewModel"] as? [String: Any],
               string(lockup["contentType"]) == "LOCKUP_CONTENT_TYPE_PLAYLIST",
               let id = string(lockup["contentId"]), !id.isEmpty {
                let metadata = lockup["metadata"] as? [String: Any]
                let model = metadata?["lockupMetadataViewModel"] as? [String: Any]
                let image = lockup["contentImage"] as? [String: Any]
                let imageModel = image?["thumbnailViewModel"] as? [String: Any]
                let imageData = imageModel?["image"] as? [String: Any]
                let sources = imageData?["sources"] as? [[String: Any]] ?? []
                result.append([
                    "playlistId": id,
                    "title": model?["title"] ?? ["simpleText": "YouTube-плейлист"],
                    "shortBylineText": ["simpleText": "YouTube"],
                    "thumbnails": sources.map { ["url": $0["url"] ?? ""] }
                ])
            }
            for child in object.values {
                collectPlaylistRenderers(child, into: &result)
            }
        } else if let array = value as? [Any] {
            for child in array {
                collectPlaylistRenderers(child, into: &result)
            }
        }
    }

    private static func collectPlaylistVideoRenderers(_ value: Any, into result: inout [[String: Any]]) {
        if let object = value as? [String: Any] {
            if let renderer = object["playlistVideoRenderer"] as? [String: Any],
               string(renderer["videoId"]) != nil {
                result.append(renderer)
            }
            for child in object.values {
                collectPlaylistVideoRenderers(child, into: &result)
            }
        } else if let array = value as? [Any] {
            for child in array {
                collectPlaylistVideoRenderers(child, into: &result)
            }
        }
    }

    private static func collectVideoRenderers(_ value: Any, into result: inout [[String: Any]]) {
        if let object = value as? [String: Any] {
            for key in ["playlistVideoRenderer", "videoRenderer", "gridVideoRenderer", "compactVideoRenderer"] {
                if let renderer = object[key] as? [String: Any],
                   string(renderer["videoId"]) != nil {
                    result.append(renderer)
                }
            }
            if let lockup = object["lockupViewModel"] as? [String: Any],
               string(lockup["contentType"]) == "LOCKUP_CONTENT_TYPE_VIDEO",
               let id = string(lockup["contentId"]) {
                let metadata = lockup["metadata"] as? [String: Any]
                let model = metadata?["lockupMetadataViewModel"] as? [String: Any]
                result.append([
                    "videoId": id,
                    "title": model?["title"] ?? ["simpleText": "Видео"],
                    "shortBylineText": ["simpleText": "YouTube"],
                    "thumbnail": [
                        "thumbnails": (((lockup["contentImage"] as? [String: Any])?["thumbnailViewModel"] as? [String: Any])?["image"] as? [String: Any])?["sources"] ?? []
                    ]
                ])
            }
            for child in object.values {
                collectVideoRenderers(child, into: &result)
            }
        } else if let array = value as? [Any] {
            for child in array {
                collectVideoRenderers(child, into: &result)
            }
        }
    }

    private static func continuationToken(from raw: Any) -> String? {
        var tokens: [String] = []
        collectContinuations(raw, into: &tokens)
        return tokens.first
    }

    private static func collectContinuations(_ value: Any, into result: inout [String]) {
        if let object = value as? [String: Any] {
            if let item = object["continuationItemRenderer"] as? [String: Any] {
                let endpoint = item["continuationEndpoint"] as? [String: Any]
                let command = endpoint?["continuationCommand"] as? [String: Any]
                if let token = string(command?["token"]) { result.append(token) }
            }
            if let next = object["nextContinuationData"] as? [String: Any],
               let token = string(next["continuation"]) {
                result.append(token)
            }
            for child in object.values {
                collectContinuations(child, into: &result)
            }
        } else if let array = value as? [Any] {
            for child in array {
                collectContinuations(child, into: &result)
            }
        }
    }

    private static func text(_ value: Any?) -> String? {
        guard let object = value as? [String: Any] else { return nil }
        if let simple = string(object["simpleText"]) { return simple }
        if let runs = object["runs"] as? [[String: Any]] {
            let joined = runs.compactMap { string($0["text"]) }.joined()
            return joined.isEmpty ? nil : joined
        }
        return string(object["content"])
    }

    private static func thumbnailURL(_ value: [String: Any]) -> String? {
        return string(value["url"])
    }

    private static func string(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }

    private static func makeError(_ message: String) -> NSError {
        NSError(domain: "Pleer1.YouTube.Playlists", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
