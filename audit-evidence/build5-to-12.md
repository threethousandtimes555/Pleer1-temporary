# build5-to-12
Base: 6ff25c7b249e01f7ae9867dbffe6ee0f34c6d9e3
Head: f6ef9ad4d20b1526f9affcda21796ae9fe0178c2
Total commits: 15

## Commit sequence
223ca694c175568f7ee307faeb2813be26ef867b | 2026-11-16T13:40:17Z | Add distinct YouTube radio mix metadata
a5ff2ed5dc182a1cee64c90db895e5d79a8d3f82 | 2026-11-16T13:40:27Z | Handle YouTube radio mixes through the next endpoint
a28578403ece06d8c3df6fce6e6d16621d311658 | 2026-11-16T13:40:32Z | Route YouTube mixes to their dedicated loader
557d7d3cd5d701a2d3f151a0dea230801a04ec40 | 2026-11-16T13:40:43Z | Broaden YouTube video search parsing and filter primary results to videos
5c0940648501819fdabdd74ff51e8d433b70eb56 | 2026-11-16T13:40:51Z | Recognize additional YouTube music video search renderers
a44247f8846ef1a20b31dbd004b206533663df15 | 2026-11-16T13:40:56Z | Display YouTube mixes as distinct search items
1cd523d4a66f8f9dcfae09c7c885a9d5b0ea83a4 | 2026-11-16T13:41:05Z | Recover YouTube playback when the stream stalls at the end
501334337287587f0362f8e81d523ab057b58098 | 2026-11-16T13:41:23Z | Correct Swift interpolation and parser formatting
597c02c08727c838c9adbcb4fca0129c8242e51e | 2026-11-16T13:41:26Z | Correct Swift interpolation and parser formatting
ec67e3b8f8b3c3d136fbd6a7e3ad6bcd4bd191c4 | 2026-11-16T13:41:29Z | Correct Swift interpolation and parser formatting
3bf4106a27b16cc0af2ed98d2f7f969c6cb65fdf | 2026-11-16T13:41:52Z | Support direct YouTube mix links and improve radio metadata
7e0ac7b3aa1e29bbfc5cc84a16cd2d30a3f98c51 | 2026-11-16T13:42:14Z | Avoid premature YouTube end-of-track recovery during brief buffering
c2ebb705d7314bb637b4182b04f8c8c55bca9d95 | 2026-11-16T13:42:24Z | Hide favorite actions for YouTube mix pseudo-tracks
d603e383ba81b5a78d271ee4c459dfbb9df9276b | 2026-11-16T13:42:30Z | Skip radio mix placeholders during single-track prefetch
f6ef9ad4d20b1526f9affcda21796ae9fe0178c2 | 2026-11-16T16:30:30Z | Test Intel macOS hosted runner for IPA build

## Per-file diffs
### .github/workflows/build.yml (modified; +1/-1)
@@ -3,7 +3,7 @@ on:
   workflow_dispatch:
 jobs:
   build:
-    runs-on: macos-latest
+    runs-on: macos-15-intel
     defaults:
       run:
         working-directory: plei

### plei/Sources/Models.swift (modified; +2/-0)
@@ -11,6 +11,8 @@ struct Track: Codable, Identifiable, Hashable {
     var added: Double = 0
     var artFile: String? = nil
     var youtubePlaylistID: String? = nil
+    var youtubeRadioID: String? = nil
+    var youtubeRadioVideoID: String? = nil
 
     var isLocal: Bool { return file != nil }
 

### plei/Sources/Player.swift (modified; +60/-10)
@@ -67,6 +67,8 @@ final class Player: ObservableObject {
     private var loadToken = 0
     private var plannedNext: Int? = nil
     private var knownYouTubeDuration: Double? = nil
+    private var lastYouTubeProgressTime: Double? = nil
+    private var lastYouTubeProgressAt = Date()
     private var youtubeRetryCount = 0
     private var prefetchedYouTube: (trackID: String, stream: YouTubeEngine.Stream)?
     private var youtubePrefetchTask: Task<Void, Never>?
@@ -165,9 +167,23 @@ final class Player: ObservableObject {
         loadToken += 1
         let token = loadToken
         knownYouTubeDuration = nil
+        lastYouTubeProgressTime = nil
+        lastYouTubeProgressAt = Date()
         youtubeRetryCount = 0
         completionHandledToken = nil
         planNext()
+        if let radioID = t.youtubeRadioID, let seedVideoID = t.youtubeRadioVideoID {
+            clock.position = 0
+            clock.duration = 0
+            player.pause()
+            player.replaceCurrentItem(with: nil)
+            statusObs = nil
+            isPlaying = false
+            store?.say("Загружаю YouTube-микс…")
+            updateNowPlaying()
+            Task { await loadYouTubeRadio(t, playlistID: radioID, seedVideoID: seedVideoID, token: token) }
+            return
+        }
         if let playlistID = t.youtubePlaylistID {
             clock.position = 0
             clock.duration = 0
@@ -211,6 +227,26 @@ final class Player: ObservableObject {
         updateNowPlaying()
     }
 
+
+    private func loadYouTubeRadio(_ track: Track, playlistID: String, seedVideoID: String, token: Int) async {
+        do {
+            let tracks = try await YouTubePlaylistEngine.loadRadio(playlistID: playlistID, seedVideoID: seedVideoID)
+            guard token == loadToken, current?.id == track.id else { return }
+            guard !tracks.isEmpty else {
+                store?.say("В миксе нет доступных видео")
+                return
+            }
+            queue = tracks
+            index = 0
+            load()
+        } catch {
+            guard token == loadToken, current?.id == track.id else { return }
+            isPlaying = false
+            store?.say("YouTube-микс: " + error.localizedDescription)
+            updateProgress()
+        }
+    }
+
     private func loadYouTubePlaylist(_ track: Track, playlistID: String, token: Int) async {
         do {
             let tracks = try await YouTubePlaylistEngine.load(playlistID: playlistID)
@@ -349,7 +385,7 @@ final class Player: ObservableObject {
         guard let n = plannedNext, queue.indices.contains(n) else { return }
         let t = queue[n]
         if t.id.first == "y" {
-            guard t.youtubePlaylistID == nil else { return }
+            guard t.youtubePlaylistID == nil, t.youtubeRadioID == nil else { return }
             guard prefetchedYouTube?.trackID != t.id else { return }
             guard youtubePrefetchTask == nil else { return }
 
@@ -509,17 +545,31 @@ final class Player: ObservableObject {
             updateProgress()
         }
         // Some YouTube CDN streams stop producing audio without delivering
-        // AVPlayerItemDidPlayToEndTime. Use the resolved video duration as a
-        // guarded fallback so repeat-one and queue advance still work.
+        // AVPlayerItemDidPlayToEndTime. Track actual clock progress near EOF:
+        // if playback stalls within the final 1.5 seconds for 5 seconds, advance
+        // once rather than leaving the queue stuck. A user-paused item is never
+        // auto-advanced by this watchdog.
         if current?.id.first == "y",
+           s.isFinite,
            let expected = knownYouTubeDuration,
-           expected.isFinite, expected > 0,
-           s.isFinite, s >= expected - 0.05,
-           player.timeControlStatus == .playing,
-           let item = player.currentItem,
-           item.status == .readyToPlay {
-            finishCurrentItem(token: loadToken, item: item)
-            return
+           expected.isFinite, expected > 0 {
+            if let previous = lastYouTubeProgressTime, s > previous + 0.08 {
+                lastYouTubeProgressTime = s
+                lastYouTubeProgressAt = Date()
+            } else if lastYouTubeProgressTime == nil {
+                lastYouTubeProgressTime = s
+                lastYouTubeProgressAt = Date()
+            }
+
+            let nearEnd = s >= expected - 1.5
+            let notPaused = player.timeControlStatus != .paused
+            let stalled = Date().timeIntervalSince(lastYouTubeProgressAt) >= 5.0
+            if nearEnd, notPaused, stalled,
+               let item = player.currentItem,
+               item.status == .readyToPlay {
+                finishCurrentItem(token: loadToken, item: item)
+                return
+            }
         }
 
         let playing = player.timeControlStatus == .playing

### plei/Sources/Views.swift (modified; +4/-4)
@@ -93,7 +93,7 @@ struct TrackRow: View {
                     Cover(track: track, size: 56)
                     VStack(alignment: .leading, spacing: 2) {
                         Text(track.title).lineLimit(2)
-                        Text(track.artist + (track.youtubePlaylistID == nil ? (track.tag.isEmpty ? "" : " · " + track.tag) : " · YouTube-плейлист"))
+                        Text(track.artist + (track.youtubeRadioID != nil ? " · YouTube-микс" : (track.youtubePlaylistID == nil ? (track.tag.isEmpty ? "" : " · " + track.tag) : " · YouTube-плейлист")))
                             .font(.footnote)
                             .foregroundColor(.secondary)
                             .lineLimit(1)
@@ -104,7 +104,7 @@ struct TrackRow: View {
             }
             .buttonStyle(.plain)
 
-            if !track.isLocal && track.archive == nil && track.youtubePlaylistID == nil {
+            if !track.isLocal && track.archive == nil && track.youtubePlaylistID == nil && track.youtubeRadioID == nil {
                 Button { store.toggleFav(track) } label: {
                     Image(systemName: store.isFav(track) ? "heart.fill" : "heart").foregroundColor(accent)
                 }
@@ -123,7 +123,7 @@ struct TrackRow: View {
                         }
                     }
                 }
-                if !track.isLocal && track.archive == nil && track.youtubePlaylistID == nil {
+                if !track.isLocal && track.archive == nil && track.youtubePlaylistID == nil && track.youtubeRadioID == nil {
                     Button(store.isFav(track) ? "Убрать из избранного" : "В избранное") { store.toggleFav(track) }
                 }
                 if track.isLocal || store.isFav(track) || removeLabel != nil {
@@ -142,7 +142,7 @@ struct TrackRow: View {
             .buttonStyle(.borderless)
         }
         .swipeActions(edge: .leading) {
-            if !track.isLocal && track.archive == nil && track.youtubePlaylistID == nil {
+            if !track.isLocal && track.archive == nil && track.youtubePlaylistID == nil && track.youtubeRadioID == nil {
                 Button { store.toggleFav(track) } label: { Label("Лайк", systemImage: "heart") }
                     .tint(.pink)
             }

### plei/Sources/YouTubeEngine.swift (modified; +37/-3)
@@ -74,7 +74,8 @@ enum YouTubeEngine {
                 "hl": "ru",
                 "gl": "RU"
             ]],
-            "query": query
+            "query": query,
+            "params": "EgIQAQ=="
         ]
         let raw = try await post(searchURL, body: body, headers: [
             "Origin": "https://www.youtube.com",
@@ -93,10 +94,24 @@ enum YouTubeEngine {
             return track
         }
         let playlists = YouTubePlaylistEngine.playlistTracks(from: raw)
-        return (videos + playlists).filter { seen.insert($0.id).inserted }
+        let radios = YouTubePlaylistEngine.radioTracks(from: raw)
+        return (videos + playlists + radios).filter { seen.insert($0.id).inserted }
     }
 
     private static func track(from item: [String: Any]) -> Track? {
+        if let music = item["__musicRenderer"] as? [String: Any] {
+            let columns = music["flexColumns"] as? [[String: Any]] ?? []
+            let title = columns.first.flatMap { textValue((($0["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"])) }
+                ?? textValue(music["title"])
+            guard let id = musicVideoID(music), !id.isEmpty, let title, !title.isEmpty else { return nil }
+            let artist = columns.dropFirst().compactMap { column in
+                textValue((column["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"])
+            }.first ?? "YouTube"
+            let thumbs = (music["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]] ?? []
+            return Track(id: "y" + id, title: title, artist: artist,
+                         art: thumbs.last.flatMap { string($0["url"]) },
+                         url: "https://www.youtube.com/watch?v=\(id)")
+        }
         if let lockup = item["__lockupViewModel"] as? [String: Any] {
             guard string(lockup["contentType"]) == "LOCKUP_CONTENT_TYPE_VIDEO",
                   let id = string(lockup["contentId"]), !id.isEmpty,
@@ -288,12 +303,15 @@ enum YouTubeEngine {
 
     private static func findVideoItems(_ value: Any, into result: inout [[String: Any]]) {
         if let object = value as? [String: Any] {
-            for key in ["videoRenderer", "gridVideoRenderer", "compactVideoRenderer", "videoWithContextRenderer"] {
+            for key in ["videoRenderer", "gridVideoRenderer", "compactVideoRenderer", "videoWithContextRenderer", "reelItemRenderer", "playlistPanelVideoRenderer"] {
                 if let renderer = object[key] as? [String: Any],
                    string(renderer["videoId"]) != nil {
                     result.append(["__videoRenderer": renderer])
                 }
             }
+            if let music = object["musicResponsiveListItemRenderer"] as? [String: Any], musicVideoID(music) != nil {
+                result.append(["__musicRenderer": music])
+            }
             if let lockup = object["lockupViewModel"] as? [String: Any],
                string(lockup["contentType"]) == "LOCKUP_CONTENT_TYPE_VIDEO",
                string(lockup["contentId"]) != nil {
@@ -309,6 +327,22 @@ enum YouTubeEngine {
         }
     }
 
+    private static func musicVideoID(_ renderer: [String: Any]) -> String? {
+        let item = renderer["playlistItemData"] as? [String: Any]
+        if let id = string(item?["videoId"]), !id.isEmpty { return id }
+        let endpoint = renderer["navigationEndpoint"] as? [String: Any]
+        let watch = endpoint?["watchEndpoint"] as? [String: Any]
+        if let id = string(watch?["videoId"]), !id.isEmpty { return id }
+        let overlay = renderer["overlay"] as? [String: Any]
+        let content = overlay?["musicItemThumbnailOverlayRenderer"] as? [String: Any]
+        let button = content?["content"] as? [String: Any]
+        let play = button?["musicPlayButtonRenderer"] as? [String: Any]
+        let playEndpoint = play?["playNavigationEndpoint"] as? [String: Any]
+        let playWatch = playEndpoint?["watchEndpoint"] as? [String: Any]
+        if let id = string(playWatch?["videoId"]), !id.isEmpty { return id }
+        return nil
+    }
+
     private static func textValue(_ value: Any?) -> String? {
         guard let object = value as? [String: Any] else { return nil }
         if let simple = string(object["simpleText"]) { return simple }

### plei/Sources/YouTubeHTMLSearch.swift (modified; +35/-2)
@@ -92,10 +92,24 @@ enum YouTubeHTMLSearch {
             return track
         }
         let playlists = YouTubePlaylistEngine.playlistTracks(from: raw)
-        return (videos + playlists).filter { seen.insert($0.id).inserted }
+        let radios = YouTubePlaylistEngine.radioTracks(from: raw)
+        return (videos + playlists + radios).filter { seen.insert($0.id).inserted }
     }
 
     private static func track(from item: [String: Any]) -> Track? {
+        if let music = item["__musicRenderer"] as? [String: Any] {
+            let columns = music["flexColumns"] as? [[String: Any]] ?? []
+            let title = columns.first.flatMap { textValue((($0["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"])) }
+                ?? textValue(music["title"])
+            guard let id = musicVideoID(music), !id.isEmpty, let title, !title.isEmpty else { return nil }
+            let artist = columns.dropFirst().compactMap { column in
+                textValue((column["musicResponsiveListItemFlexColumnRenderer"] as? [String: Any])?["text"])
+            }.first ?? "YouTube"
+            let thumbs = (music["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]] ?? []
+            return Track(id: "y" + id, title: title, artist: artist,
+                         art: thumbs.last.flatMap { string($0["url"]) },
+                         url: "https://www.youtube.com/watch?v=\(id)")
+        }
         if let lockup = item["__lockupViewModel"] as? [String: Any] {
             guard string(lockup["contentType"]) == "LOCKUP_CONTENT_TYPE_VIDEO",
                   let id = string(lockup["contentId"]), !id.isEmpty,
@@ -142,12 +156,15 @@ enum YouTubeHTMLSearch {
 
     private static func findVideoItems(_ value: Any, into result: inout [[String: Any]]) {
         if let object = value as? [String: Any] {
-            for key in ["videoRenderer", "gridVideoRenderer", "compactVideoRenderer", "videoWithContextRenderer"] {
+            for key in ["videoRenderer", "gridVideoRenderer", "compactVideoRenderer", "videoWithContextRenderer", "reelItemRenderer", "playlistPanelVideoRenderer"] {
                 if let renderer = object[key] as? [String: Any],
                    string(renderer["videoId"]) != nil {
                     result.append(["__videoRenderer": renderer])
                 }
             }
+            if let music = object["musicResponsiveListItemRenderer"] as? [String: Any], musicVideoID(music) != nil {
+                result.append(["__musicRenderer": music])
+            }
             if let lockup = object["lockupViewModel"] as? [String: Any],
                string(lockup["contentType"]) == "LOCKUP_CONTENT_TYPE_VIDEO",
                string(lockup["contentId"]) != nil {
@@ -163,6 +180,22 @@ enum YouTubeHTMLSearch {
         }
     }
 
+    private static func musicVideoID(_ renderer: [String: Any]) -> String? {
+        let item = renderer["playlistItemData"] as? [String: Any]
+        if let id = string(item?["videoId"]), !id.isEmpty { return id }
+        let endpoint = renderer["navigationEndpoint"] as? [String: Any]
+        let watch = endpoint?["watchEndpoint"] as? [String: Any]
+        if let id = string(watch?["videoId"]), !id.isEmpty { return id }
+        let overlay = renderer["overlay"] as? [String: Any]
+        let content = overlay?["musicItemThumbnailOverlayRenderer"] as? [String: Any]
+        let button = content?["content"] as? [String: Any]
+        let play = button?["musicPlayButtonRenderer"] as? [String: Any]
+        let playEndpoint = play?["playNavigationEndpoint"] as? [String: Any]
+        let playWatch = playEndpoint?["watchEndpoint"] as? [String: Any]
+        if let id = string(playWatch?["videoId"]), !id.isEmpty { return id }
+        return nil
+    }
+
     private static func textValue(_ value: Any?) -> String? {
         guard let object = value as? [String: Any] else { return nil }
         if let simple = string(object["simpleText"]) { return simple }

### plei/Sources/YouTubePlaylistEngine.swift (modified; +140/-3)
@@ -5,6 +5,7 @@ import Foundation
 /// resolves the playlist into ordinary YouTube video tracks before playback.
 enum YouTubePlaylistEngine {
     private static let endpoint = URL(string: "https://www.youtube.com/youtubei/v1/browse?prettyPrint=false&alt=json")!
+    private static let nextEndpoint = URL(string: "https://www.youtube.com/youtubei/v1/next?prettyPrint=false&alt=json")!
     private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
     private static let clientVersion = "2.20241126.01.00"
     private static let session: URLSession = {
@@ -21,6 +22,18 @@ enum YouTubePlaylistEngine {
               host.contains("youtube.com"),
               let playlistID = components.queryItems?.first(where: { $0.name == "list" })?.value,
               !playlistID.isEmpty else { return nil }
+        if playlistID.hasPrefix("RD") {
+            guard let seedVideoID = components.queryItems?.first(where: { $0.name == "v" })?.value,
+                  !seedVideoID.isEmpty else { return nil }
+            return Track(
+                id: "yr" + playlistID,
+                title: "YouTube-микс",
+                artist: "YouTube",
+                url: "https://www.youtube.com/watch?v=\(seedVideoID)&list=\(playlistID)",
+                youtubeRadioID: playlistID,
+                youtubeRadioVideoID: seedVideoID
+            )
+        }
         return Track(
             id: "yp" + playlistID,
             title: "YouTube-плейлист",
@@ -39,7 +52,7 @@ enum YouTubePlaylistEngine {
                   seen.insert(playlistID).inserted else { return nil }
             let title = text(renderer["title"]) ?? "YouTube-плейлист"
             let artist = text(renderer["shortBylineText"]) ?? text(renderer["longBylineText"]) ?? "YouTube"
-            let thumbnails = (renderer["thumbnails"] as? [[String: Any]]) ?? []
+            let thumbnails = (renderer["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]] ?? []
             let art = thumbnails.reversed().compactMap { thumbnail in
                 thumbnailURL(thumbnail) ??
                 ((thumbnail["thumbnails"] as? [[String: Any]])?.last.flatMap { thumbnailURL($0) })
@@ -55,6 +68,126 @@ enum YouTubePlaylistEngine {
         }
     }
 
+
+    /// YouTube radio mixes are not ordinary playlists. They must be expanded
+    /// through the /next endpoint using both the RD playlist ID and a seed video.
+    static func radioTracks(from raw: Any) -> [Track] {
+        var found: [[String: Any]] = []
+        collectRadioRenderers(raw, into: &found)
+        var seen = Set<String>()
+        return found.compactMap { renderer in
+            guard let playlistID = string(renderer["playlistId"]), playlistID.hasPrefix("RD"),
+                  let videoID = radioSeedVideoID(renderer), !videoID.isEmpty,
+                  seen.insert(playlistID).inserted else { return nil }
+            let title = text(renderer["title"]) ?? "YouTube-микс"
+            let artist = text(renderer["shortBylineText"]) ?? text(renderer["longBylineText"]) ?? "YouTube"
+            let thumbnails = (renderer["thumbnails"] as? [[String: Any]]) ?? []
+            let art = thumbnails.last.flatMap { thumbnailURL($0) }
+            return Track(
+                id: "yr" + playlistID,
+                title: title,
+                artist: artist,
+                art: art,
+                url: "https://www.youtube.com/watch?v=\(videoID)&list=\(playlistID)",
+                youtubeRadioID: playlistID,
+                youtubeRadioVideoID: videoID
+            )
+        }
+    }
+
+    static func loadRadio(playlistID: String, seedVideoID: String) async throws -> [Track] {
+        guard playlistID.hasPrefix("RD"), !seedVideoID.isEmpty else {
+            throw makeError("Не удалось определить параметры YouTube-микса")
+        }
+        let context: [String: Any] = [
+            "client": [
+                "clientName": "WEB",
+                "clientVersion": clientVersion,
+                "hl": "ru",
+                "gl": "RU"
+            ]
+        ]
+        var body: [String: Any] = [
+            "context": context,
+            "videoId": seedVideoID,
+            "playlistId": playlistID
+        ]
+        var all: [Track] = []
+        var seenVideos = Set<String>()
+        var seenContinuations = Set<String>()
+
+        for _ in 0..<20 {
+            let raw = try await post(nextEndpoint, body: body)
+            let page = radioVideoTracks(from: raw)
+            for track in page where seenVideos.insert(track.id).inserted {
+                all.append(track)
+                if all.count >= 500 { return all }
+            }
+            guard let continuation = continuationToken(from: raw),
+                  !continuation.isEmpty,
+                  seenContinuations.insert(continuation).inserted else { break }
+            body = ["context": context, "continuation": continuation]
+        }
+        guard !all.isEmpty else {
+            throw makeError("YouTube не вернул видео из этого микса")
+        }
+        return all
+    }
+
+    private static func radioVideoTracks(from raw: Any) -> [Track] {
+        var renderers: [[String: Any]] = []
+        collectRadioVideoRenderers(raw, into: &renderers)
+        var seen = Set<String>()
+        return renderers.compactMap { renderer in
+            guard let videoID = string(renderer["videoId"]) ?? string((renderer["playlistItemData"] as? [String: Any])?["videoId"]),
+                  !videoID.isEmpty, seen.insert(videoID).inserted,
+                  let title = text(renderer["title"]) else { return nil }
+            let artist = text(renderer["longBylineText"]) ?? text(renderer["shortBylineText"]) ?? "YouTube"
+            let thumbnails = (renderer["thumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]] ?? []
+            let art = thumbnails.last.flatMap { thumbnailURL($0) }
+            return Track(id: "y" + videoID, title: title, artist: artist, art: art,
+                         url: "https://www.youtube.com/watch?v=\(videoID)")
+        }
+    }
+
+    private static func collectRadioVideoRenderers(_ value: Any, into result: inout [[String: Any]]) {
+        if let object = value as? [String: Any] {
+            if let renderer = object["playlistPanelVideoRenderer"] as? [String: Any] {
+                result.append(renderer)
+            } else if let wrapper = object["playlistPanelVideoWrapperRenderer"] as? [String: Any] {
+                collectRadioVideoRenderers(wrapper, into: &result)
+            }
+            for child in object.values { collectRadioVideoRenderers(child, into: &result) }
+        } else if let array = value as? [Any] {
+            for child in array { collectRadioVideoRenderers(child, into: &result) }
+        }
+    }
+
+    private static func collectRadioRenderers(_ value: Any, into result: inout [[String: Any]]) {
+        if let object = value as? [String: Any] {
+            if let renderer = object["radioRenderer"] as? [String: Any],
+               string(renderer["playlistId"]) != nil {
+                result.append(renderer)
+            }
+            for child in object.values { collectRadioRenderers(child, into: &result) }
+        } else if let array = value as? [Any] {
+            for child in array { collectRadioRenderers(child, into: &result) }
+        }
+    }
+
+    private static func radioSeedVideoID(_ renderer: [String: Any]) -> String? {
+        if let id = string(renderer["videoId"]), !id.isEmpty { return id }
+        let endpoint = renderer["navigationEndpoint"] as? [String: Any]
+        let watch = endpoint?["watchEndpoint"] as? [String: Any]
+        if let id = string(watch?["videoId"]), !id.isEmpty { return id }
+        let playlistWatch = endpoint?["watchPlaylistEndpoint"] as? [String: Any]
+        if let id = string(playlistWatch?["videoId"]), !id.isEmpty { return id }
+        if let videos = renderer["videos"] as? [[String: Any]],
+           let first = videos.first?["childVideoRenderer"] as? [String: Any],
+           let id = string(first["videoId"]), !id.isEmpty { return id }
+        return nil
+    }
+
     static func load(playlistID: String) async throws -> [Track] {
         guard !playlistID.isEmpty else {
             throw makeError("Не удалось определить ID YouTube-плейлиста")
@@ -105,7 +238,11 @@ enum YouTubePlaylistEngine {
     }
 
     private static func post(_ body: [String: Any]) async throws -> Any {
-        var request = URLRequest(url: endpoint)
+        try await post(endpoint, body: body)
+    }
+
+    private static func post(_ url: URL, body: [String: Any]) async throws -> Any {
+        var request = URLRequest(url: url)
         request.httpMethod = "POST"
         request.timeoutInterval = 25
         request.setValue("application/json", forHTTPHeaderField: "Content-Type")
@@ -147,7 +284,7 @@ enum YouTubePlaylistEngine {
 
     private static func collectPlaylistRenderers(_ value: Any, into result: inout [[String: Any]]) {
         if let object = value as? [String: Any] {
-            for key in ["playlistRenderer", "compactPlaylistRenderer", "gridPlaylistRenderer", "radioRenderer"] {
+            for key in ["playlistRenderer", "compactPlaylistRenderer", "gridPlaylistRenderer"] {
                 if let renderer = object[key] as? [String: Any],
                    string(renderer["playlistId"]) != nil {
                     result.append(renderer)
