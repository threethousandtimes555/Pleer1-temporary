# build12-to-14
Base: f6ef9ad4d20b1526f9affcda21796ae9fe0178c2
Head: 14956c5fbe07d39af97f73d4b462efc3fb42e66f
Total commits: 18

## Commit sequence
ffaae21c228b35c1a6ff94d1a76c38c0f7fcd556 | 2026-11-16T18:11:59Z | Restore unfiltered YouTube search request
9df9b2940e11d1427a418f0f35dd8588564da81f | 2026-11-16T18:33:22Z | Add local YouTube diagnostics journal
66d3e7f598cfd43df62406f1b7fdecd38030c11c | 2026-11-16T18:33:42Z | Instrument YouTube search transports and HTTP responses
9c75f62a92acc25e65fc3997cee172424bcb801d | 2026-11-16T18:33:45Z | Instrument YouTube HTML fallback diagnostics
a291c35741168f580acc6d7ef628f97181424627 | 2026-11-16T18:33:48Z | Record search orchestration summary
763d34817abca58276bc83d09665723cc7496dc9 | 2026-11-16T18:34:14Z | Add YouTube playback state and end-of-track diagnostics
386bb1a609fb34747fe05b9b55e3d5ad21bc1c89 | 2026-11-16T18:34:30Z | Add shareable YouTube diagnostics in Settings
f804123e6790faa86e999469cbacfd89c4f7fb64 | 2026-11-16T18:34:33Z | Use known-good macOS 15 Intel runner for diagnostic build
94aa9966c885398a049baa27f0078793eb1fc89c | 2026-11-16T18:34:36Z | Throttle end-of-track watchdog diagnostics
571346dc5baa803333e78e6f5f3861607b55e8fa | 2026-11-16T18:35:18Z | Add playlist, radio and prefetch diagnostics
77f32c7e0f67a2501d2b6a4fa9e96701457e416e | 2026-11-16T18:35:21Z | Log YouTube search result classification
c07beb5d3596ec915c3796a14839d7906e51b3e1 | 2026-11-16T18:35:32Z | Add YouTube playlist and radio request diagnostics
23aa63c7b8a48ee1fff2477b79288aca33e60af4 | 2026-11-16T18:36:45Z | Advance stalled YouTube streams without overriding user pause
e75f0c77725b6ae4b642654cb2b2dc69d8199b0b | 2026-11-16T18:37:09Z | Keep YouTube end watchdog running during AVPlayer stalls
4a1d3febe6cb1f51b63be658c22d5e7430fb0ce1 | 2026-11-16T18:37:36Z | Guard YouTube watchdog against duplicate completion
586b08bb15b3b07b0eb66dda3a999ca9a4b1802d | 2026-11-16T18:38:22Z | Refresh local YouTube journal before sharing
3fd47fd9d9331fcb5a898bb7776ed92e76683a14 | 2026-11-16T18:38:40Z | Log YouTube stream resolution client outcomes
14956c5fbe07d39af97f73d4b462efc3fb42e66f | 2026-11-16T19:39:51Z | ci: use macos-latest runner for YouTube diagnostics build

## Per-file diffs
### plei/Sources/Player.swift (modified; +107/-7)
@@ -62,6 +62,13 @@ final class Player: ObservableObject {
     private var timeObs: Any?
     private var endObs: NSObjectProtocol?
     private var statusObs: NSKeyValueObservation?
+    private var timeControlObs: NSKeyValueObservation?
+    private var watchdogTimer: Timer?
+    private var lastYouTubeDiagnosticState: String? = nil
+    private var lastYouTubeDiagnosticAt = Date.distantPast
+    private var lastWatchdogBlockedAt = Date.distantPast
+    private var userPausedPlayback = false
+    private var audioSessionInterrupted = false
     private var completionHandledToken: Int? = nil
     private var sleepTask: Task<Void, Never>?
     private var loadToken = 0
@@ -84,14 +91,46 @@ final class Player: ObservableObject {
         timeObs = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] t in
             Task { @MainActor in self?.tick(t) }
         }
+        timeControlObs = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] observedPlayer, _ in
+            let status = String(describing: observedPlayer.timeControlStatus)
+            let reason = observedPlayer.reasonForWaitingToPlay.map { String(describing: $0) } ?? "none"
+            let position = observedPlayer.currentItem?.currentTime().seconds ?? -1
+            Task { @MainActor in
+                if self?.current?.id.first == "y" {
+                    YouTubeDiagnostics.record("playback.time_control", details: "status=\(status), reason=\(reason), position=\(String(format: "%.2f", position))")
+                }
+            }
+        }
+        // AVPlayer's periodic observer may become quiet after a stream stalls.
+        // This independent one-second check keeps the end-of-track watchdog alive.
+        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
+            Task { @MainActor in
+                guard let self, self.current?.id.first == "y" else { return }
+                self.tick(self.player.currentTime())
+            }
+        }
 
         NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
             let typeRaw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
             let optRaw = n.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
-            let ended = AVAudioSession.InterruptionType(rawValue: typeRaw) == .ended
+            let interruptionType = AVAudioSession.InterruptionType(rawValue: typeRaw)
+            let began = interruptionType == .began
+            let ended = interruptionType == .ended
             let should = AVAudioSession.InterruptionOptions(rawValue: optRaw).contains(.shouldResume)
             Task { @MainActor in
-                if ended && should { self?.resume() }
+                if began {
+                    self?.audioSessionInterrupted = true
+                    if self?.current?.id.first == "y" {
+                        YouTubeDiagnostics.record("playback.audio_interruption", details: "phase=began")
+                    }
+                }
+                if ended {
+                    self?.audioSessionInterrupted = false
+                    if self?.current?.id.first == "y" {
+                        YouTubeDiagnostics.record("playback.audio_interruption", details: "phase=ended, shouldResume=\(should)")
+                    }
+                    if should { self?.resume() }
+                }
             }
         }
         setupRemote()
@@ -166,6 +205,13 @@ final class Player: ObservableObject {
         guard let t = current else { return }
         loadToken += 1
         let token = loadToken
+        if t.id.first == "y" {
+            YouTubeDiagnostics.record("playback.load", details: "id=\(t.id), title=\(t.title), queueCount=\(queue.count), index=\(index)")
+        }
+        lastYouTubeDiagnosticState = nil
+        lastYouTubeDiagnosticAt = .distantPast
+        lastWatchdogBlockedAt = .distantPast
+        userPausedPlayback = false
         knownYouTubeDuration = nil
         lastYouTubeProgressTime = nil
         lastYouTubeProgressAt = Date()
@@ -229,9 +275,11 @@ final class Player: ObservableObject {
 
 
     private func loadYouTubeRadio(_ track: Track, playlistID: String, seedVideoID: String, token: Int) async {
+        YouTubeDiagnostics.record("radio.load.begin", details: "playlist=\(playlistID), seed=\(seedVideoID)")
         do {
             let tracks = try await YouTubePlaylistEngine.loadRadio(playlistID: playlistID, seedVideoID: seedVideoID)
             guard token == loadToken, current?.id == track.id else { return }
+            YouTubeDiagnostics.record("radio.load.success", details: "playlist=\(playlistID), tracks=\(tracks.count)")
             guard !tracks.isEmpty else {
                 store?.say("В миксе нет доступных видео")
                 return
@@ -241,16 +289,19 @@ final class Player: ObservableObject {
             load()
         } catch {
             guard token == loadToken, current?.id == track.id else { return }
+            YouTubeDiagnostics.record("radio.load.failure", details: "playlist=\(playlistID), error=\(error.localizedDescription)")
             isPlaying = false
             store?.say("YouTube-микс: " + error.localizedDescription)
             updateProgress()
         }
     }
 
     private func loadYouTubePlaylist(_ track: Track, playlistID: String, token: Int) async {
+        YouTubeDiagnostics.record("playlist.load.begin", details: "playlist=\(playlistID)")
         do {
             let tracks = try await YouTubePlaylistEngine.load(playlistID: playlistID)
             guard token == loadToken, current?.id == track.id else { return }
+            YouTubeDiagnostics.record("playlist.load.success", details: "playlist=\(playlistID), tracks=\(tracks.count)")
             guard !tracks.isEmpty else {
                 store?.say("В плейлисте нет доступных видео")
                 return
@@ -260,13 +311,15 @@ final class Player: ObservableObject {
             load()
         } catch {
             guard token == loadToken, current?.id == track.id else { return }
+            YouTubeDiagnostics.record("playlist.load.failure", details: "playlist=\(playlistID), error=\(error.localizedDescription)")
             isPlaying = false
             store?.say("YouTube-плейлист: " + error.localizedDescription)
             updateProgress()
         }
     }
 
     private func loadYouTube(_ track: Track, token: Int) async {
+        YouTubeDiagnostics.record("playback.resolve.begin", details: "id=\(track.id), usingPrefetch=\(prefetchedYouTube?.trackID == track.id || youtubePrefetchTrackID == track.id)")
         do {
             let stream: YouTubeEngine.Stream
             if let cached = prefetchedYouTube, cached.trackID == track.id {
@@ -289,6 +342,7 @@ final class Player: ObservableObject {
             }
             guard token == loadToken, current?.id == track.id else { return }
             knownYouTubeDuration = stream.duration > 0 ? stream.duration : nil
+            YouTubeDiagnostics.record("playback.resolve.success", details: "id=\(track.id), duration=\(String(format: "%.2f", stream.duration)), mime=\(stream.mimeType), host=\(stream.url.host ?? "unknown")")
             if let duration = knownYouTubeDuration {
                 clock.duration = duration
                 updateProgress()
@@ -298,6 +352,7 @@ final class Player: ObservableObject {
             updateNowPlaying()
         } catch {
             guard token == loadToken, current?.id == track.id else { return }
+            YouTubeDiagnostics.record("playback.resolve.failure", details: "id=\(track.id), error=\(error.localizedDescription)")
             isPlaying = false
             store?.say("YouTube: " + error.localizedDescription)
             updateProgress()
@@ -316,7 +371,10 @@ final class Player: ObservableObject {
         }
         let item = AVPlayerItem(asset: asset)
         // Match Musike’s native YouTube buffering strategy without changing other providers.
-        if t.id.first == "y" { item.preferredForwardBufferDuration = 30 }
+        if t.id.first == "y" {
+            item.preferredForwardBufferDuration = 30
+            YouTubeDiagnostics.record("playback.item_created", details: "id=\(t.id), forwardBuffer=30, urlHost=\(url.host ?? "file")")
+        }
         if let o = endObs { NotificationCenter.default.removeObserver(o) }
         let token = loadToken
         endObs = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
@@ -337,6 +395,9 @@ final class Player: ObservableObject {
               player.currentItem === item,
               completionHandledToken != token else { return }
         completionHandledToken = token
+        if current?.id.first == "y" {
+            YouTubeDiagnostics.record("playback.finish_event", details: "id=\(current?.id ?? "unknown"), position=\(String(format: "%.2f", player.currentTime().seconds)), duration=\(String(format: "%.2f", knownYouTubeDuration ?? 0))")
+        }
         if current?.id.first == "y",
            let duration = knownYouTubeDuration,
            duration.isFinite, duration > 0 {
@@ -348,6 +409,10 @@ final class Player: ObservableObject {
 
     private func itemStatus(_ st: AVPlayerItem.Status, _ msg: String, _ t: Track, _ token: Int, _ streaming: Bool, _ recoverable: Bool) {
         if token != loadToken { return }
+        if t.id.first == "y" {
+            let statusName = st == .readyToPlay ? "readyToPlay" : (st == .failed ? "failed" : "unknown")
+            YouTubeDiagnostics.record("playback.item_status", details: "id=\(t.id), status=\(statusName), error=\(msg)")
+        }
         if st == .readyToPlay {
             updateNowPlaying()
             prefetchNext()
@@ -392,6 +457,7 @@ final class Player: ObservableObject {
             youtubePrefetchToken += 1
             let token = youtubePrefetchToken
             youtubePrefetchTrackID = t.id
+            YouTubeDiagnostics.record("playback.prefetch.begin", details: "id=\(t.id)")
             youtubePrefetchTask = Task { [weak self] in
                 defer {
                     if let self, self.youtubePrefetchToken == token {
@@ -413,7 +479,9 @@ final class Player: ObservableObject {
                           self.queue[n].id == t.id,
                           (self.plannedNext == n || self.current?.id == t.id) else { return }
                     self.prefetchedYouTube = (trackID: t.id, stream: stream)
+                    YouTubeDiagnostics.record("playback.prefetch.success", details: "id=\(t.id), duration=\(String(format: "%.2f", stream.duration))")
                 } catch {
+                    YouTubeDiagnostics.record("playback.prefetch.failure", details: "id=\(t.id), error=\(error.localizedDescription)")
                     // The next track will resolve normally when playback reaches it.
                 }
             }
@@ -446,13 +514,17 @@ final class Player: ObservableObject {
 
     // MARK: controls
     func resume() {
+        userPausedPlayback = false
+        if current?.id.first == "y" { YouTubeDiagnostics.record("playback.user_resume", details: "id=\(current?.id ?? "unknown")") }
         player.play()
         player.rate = Float(speed)
         isPlaying = true
         updateProgress()
     }
 
     func pause() {
+        userPausedPlayback = true
+        if current?.id.first == "y" { YouTubeDiagnostics.record("playback.user_pause", details: "id=\(current?.id ?? "unknown")") }
         player.pause()
         isPlaying = false
         updateProgress()
@@ -463,6 +535,9 @@ final class Player: ObservableObject {
     }
 
     func advance(auto: Bool = false) {
+        if current?.id.first == "y" {
+            YouTubeDiagnostics.record("playback.advance", details: "auto=\(auto), id=\(current?.id ?? "unknown"), index=\(index), plannedNext=\(plannedNext.map { String($0) } ?? "nil"), timeControl=\(String(describing: player.timeControlStatus))")
+        }
         if queue.isEmpty { return }
         var j: Int? = nil
         if auto || repeatMode != .one { j = plannedNext }
@@ -544,12 +619,31 @@ final class Player: ObservableObject {
             clock.duration = d
             updateProgress()
         }
+        // Capture AVPlayer's state transitions and buffer indicators. This is
+        // deliberately observational: it does not alter playback or advance the queue.
+        if current?.id.first == "y", let item = player.currentItem {
+            let nearEnd = knownYouTubeDuration.map { $0 > 0 && s >= $0 - 3.0 } ?? false
+            let state = "item=\(item.status.rawValue),control=\(player.timeControlStatus.rawValue),empty=\(item.isPlaybackBufferEmpty),likely=\(item.isPlaybackLikelyToKeepUp),keepUp=\(item.isPlaybackBufferFull)"
+            let now = Date()
+            if state != lastYouTubeDiagnosticState || (nearEnd && now.timeIntervalSince(lastYouTubeDiagnosticAt) >= 2.0) {
+                lastYouTubeDiagnosticState = state
+                lastYouTubeDiagnosticAt = now
+                let ranges = item.loadedTimeRanges.map { value -> String in
+                    let range = value.timeRangeValue
+                    return "\(String(format: "%.2f", range.start.seconds))+\(String(format: "%.2f", range.duration.seconds))"
+                }.joined(separator: ",")
+                let waiting = player.reasonForWaitingToPlay.map { String(describing: $0) } ?? "none"
+                YouTubeDiagnostics.record("playback.tick", details: "id=\(current?.id ?? "unknown"), pos=\(String(format: "%.2f", s)), expected=\(String(format: "%.2f", knownYouTubeDuration ?? 0)), state=\(state), waiting=\(waiting), loaded=\(ranges)")
+            }
+        }
+
         // Some YouTube CDN streams stop producing audio without delivering
         // AVPlayerItemDidPlayToEndTime. Track actual clock progress near EOF:
-        // if playback stalls within the final 1.5 seconds for 5 seconds, advance
+        // if playback stalls within the final 3 seconds for 5 seconds, advance
         // once rather than leaving the queue stuck. A user-paused item is never
         // auto-advanced by this watchdog.
         if current?.id.first == "y",
+           completionHandledToken != loadToken,
            s.isFinite,
            let expected = knownYouTubeDuration,
            expected.isFinite, expected > 0 {
@@ -561,12 +655,18 @@ final class Player: ObservableObject {
                 lastYouTubeProgressAt = Date()
             }
 
-            let nearEnd = s >= expected - 1.5
-            let notPaused = player.timeControlStatus != .paused
+            let nearEnd = s >= expected - 3.0
             let stalled = Date().timeIntervalSince(lastYouTubeProgressAt) >= 5.0
-            if nearEnd, notPaused, stalled,
+            if nearEnd, stalled, (userPausedPlayback || audioSessionInterrupted),
+               Date().timeIntervalSince(lastWatchdogBlockedAt) >= 2.0 {
+                lastWatchdogBlockedAt = Date()
+                let reason = userPausedPlayback ? "user_paused" : "audio_interruption"
+                YouTubeDiagnostics.record("playback.watchdog_blocked", details: "reason=\(reason), pos=\(String(format: "%.2f", s)), expected=\(String(format: "%.2f", expected)), stalledFor=\(String(format: "%.1f", Date().timeIntervalSince(lastYouTubeProgressAt)))")
+            }
+            if nearEnd, stalled, !userPausedPlayback, !audioSessionInterrupted,
                let item = player.currentItem,
                item.status == .readyToPlay {
+                YouTubeDiagnostics.record("playback.watchdog_advance", details: "pos=\(String(format: "%.2f", s)), expected=\(String(format: "%.2f", expected)), timeControl=\(String(describing: player.timeControlStatus)), bufferEmpty=\(item.isPlaybackBufferEmpty)")
                 finishCurrentItem(token: loadToken, item: item)
                 return
             }

### plei/Sources/Providers.swift (modified; +2/-0)
@@ -161,6 +161,7 @@ final class SearchModel: ObservableObject {
     @Published var loading = false
 
     func run(_ q: String, key: String, host: String) async {
+        YouTubeDiagnostics.record("search.all_sources.begin", details: "query=\(q)")
         results = []
         errors = []
         loading = true
@@ -186,5 +187,6 @@ final class SearchModel: ObservableObject {
         results = all
         errors = errs
         loading = false
+        YouTubeDiagnostics.record("search.all_sources.complete", details: "total=\(all.count), youtube=\(parts["YouTube"]?.count ?? 0), errors=\(errs.joined(separator: " | "))")
     }
 }

### plei/Sources/Views.swift (modified; +19/-0)
@@ -362,6 +362,7 @@ struct SettingsView: View {
     @EnvironmentObject var store: Store
     @EnvironmentObject var player: Player
     @Binding var showPlayer: Bool
+    @State private var diagnosticsRevision = 0
 
     var body: some View {
         NavigationStack {
@@ -376,6 +377,24 @@ struct SettingsView: View {
                         .textInputAutocapitalization(.never)
                         .autocorrectionDisabled()
                 }
+                Section("Отладка YouTube") {
+                    Text("Журнал хранится только на этом iPhone. В нём есть поисковые запросы, ответы YouTube и состояние аудиоплеера. Он не отправляется автоматически.")
+                        .font(.footnote)
+                        .foregroundColor(.secondary)
+                    Button {
+                        diagnosticsRevision += 1
+                    } label: {
+                        Label("Обновить журнал", systemImage: "arrow.clockwise")
+                    }
+                    ShareLink(item: YouTubeDiagnostics.exportText) {
+                        Label("Поделиться журналом", systemImage: "square.and.arrow.up")
+                    }
+                    .id(diagnosticsRevision)
+                    Button("Очистить журнал", role: .destructive) {
+                        YouTubeDiagnostics.clear()
+                        diagnosticsRevision += 1
+                    }
+                }
                 Section {
                     Text("Файлы можно класть и через приложение «Файлы»: На iPhone, Плеер, Music. Они появятся в «Моё».")
                         .font(.footnote)

### plei/Sources/YouTubeDiagnostics.swift (added; +43/-0)
@@ -0,0 +1,43 @@
+import Foundation
+
+/// Local, opt-in diagnostic journal for YouTube search and playback.
+/// Entries stay on the device until the user explicitly shares them from Settings.
+enum YouTubeDiagnostics {
+    private static let lock = NSLock()
+    private static let storageKey = "pleer1.youtube.diagnostics.v1"
+    private static let capacity = 600
+
+    static func record(_ event: String, details: String = "") {
+        lock.lock()
+        defer { lock.unlock() }
+
+        let formatter = ISO8601DateFormatter()
+        let timestamp = formatter.string(from: Date())
+        let cleanDetails = details
+            .replacingOccurrences(of: "\n", with: " ")
+            .replacingOccurrences(of: "\r", with: " ")
+        let line = "[\(timestamp)] \(event)\(cleanDetails.isEmpty ? "" : " | " + cleanDetails)"
+
+        var entries = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
+        entries.append(line)
+        if entries.count > capacity {
+            entries.removeFirst(entries.count - capacity)
+        }
+        UserDefaults.standard.set(entries, forKey: storageKey)
+        NSLog("Pleer1 YouTube: %@", line)
+    }
+
+    static var exportText: String {
+        lock.lock()
+        defer { lock.unlock() }
+        let entries = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
+        return (["Pleer1 YouTube diagnostics", "Entries: \(entries.count)", ""] + entries)
+            .joined(separator: "\n")
+    }
+
+    static func clear() {
+        lock.lock()
+        defer { lock.unlock() }
+        UserDefaults.standard.removeObject(forKey: storageKey)
+    }
+}

### plei/Sources/YouTubeEngine.swift (modified; +46/-12)
@@ -45,20 +45,35 @@ enum YouTubeEngine {
     static func search(_ query: String) async throws -> [Track] {
         let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
         guard !normalized.isEmpty else { return [] }
+        YouTubeDiagnostics.record("search.begin", details: "query=\(normalized)")
         if let playlist = YouTubePlaylistEngine.playlistTrack(from: normalized) {
+            YouTubeDiagnostics.record("search.input_playlist", details: "id=\(playlist.id)")
             return [playlist]
         }
 
-        // Run independent transports concurrently so the fallback does not
-        // add a second full network timeout to every successful search.
-        async let primaryTask: [Track]? = try? searchInnerTube(normalized)
-        async let fallbackTask: [Track]? = try? YouTubeHTMLSearch.search(normalized)
-        let (primaryResults, fallbackResults) = await (primaryTask, fallbackTask)
+        // Start both independent transports together, but retain each error
+        // instead of swallowing it so the exported journal shows which path failed.
+        async let primaryTask = searchInnerTube(normalized)
+        async let fallbackTask = YouTubeHTMLSearch.search(normalized)
+
+        var primary: [Track] = []
+        var fallback: [Track] = []
+        do {
+            primary = try await primaryTask
+            YouTubeDiagnostics.record("search.innertube.success", details: "tracks=\(primary.count)")
+        } catch {
+            YouTubeDiagnostics.record("search.innertube.failure", details: error.localizedDescription)
+        }
+        do {
+            fallback = try await fallbackTask
+            YouTubeDiagnostics.record("search.html.success", details: "tracks=\(fallback.count)")
+        } catch {
+            YouTubeDiagnostics.record("search.html.failure", details: error.localizedDescription)
+        }
 
-        let primary = primaryResults ?? []
-        let fallback = fallbackResults ?? []
         var seen = Set<String>()
         let combined = (primary + fallback).filter { seen.insert($0.id).inserted }
+        YouTubeDiagnostics.record("search.complete", details: "innertube=\(primary.count), html=\(fallback.count), merged=\(combined.count)")
 
         guard !combined.isEmpty else {
             throw makeError("YouTube не вернул распознанных видео ни через InnerTube, ни через резервную HTML-страницу.")
@@ -75,13 +90,15 @@ enum YouTubeEngine {
                 "gl": "RU"
             ]],
             "query": query,
-            "params": "EgIQAQ=="
         ]
+        YouTubeDiagnostics.record("search.innertube.request", details: "client=WEB, query=\(query)")
         let raw = try await post(searchURL, body: body, headers: [
             "Origin": "https://www.youtube.com",
             "Referer": "https://www.youtube.com/"
         ])
-        return tracks(from: raw)
+        let parsed = tracks(from: raw)
+        YouTubeDiagnostics.record("search.innertube.parsed", details: "tracks=\(parsed.count)")
+        return parsed
     }
 
     private static func tracks(from raw: Any) -> [Track] {
@@ -95,6 +112,7 @@ enum YouTubeEngine {
         }
         let playlists = YouTubePlaylistEngine.playlistTracks(from: raw)
         let radios = YouTubePlaylistEngine.radioTracks(from: raw)
+        YouTubeDiagnostics.record("search.parse.summary", details: "videos=\(videos.count), playlists=\(playlists.count), radios=\(radios.count)")
         return (videos + playlists + radios).filter { seen.insert($0.id).inserted }
     }
 
@@ -157,6 +175,7 @@ enum YouTubeEngine {
     }
 
     static func resolve(videoID: String) async throws -> Stream {
+        YouTubeDiagnostics.record("resolve.begin", details: "videoID=\(videoID)")
         guard !videoID.isEmpty else {
             throw makeError("Не удалось определить идентификатор видео")
         }
@@ -165,14 +184,17 @@ enum YouTubeEngine {
         let visitorData: String
         do {
             visitorData = try await fetchVisitorData()
+            YouTubeDiagnostics.record("resolve.visitor", details: "available=\(!visitorData.isEmpty)")
             if visitorData.isEmpty { failures.append("visitorData: YouTube не выдал идентификатор посетителя") }
         } catch {
             visitorData = ""
+            YouTubeDiagnostics.record("resolve.visitor.failure", details: error.localizedDescription)
             failures.append("visitorData: \(error.localizedDescription)")
         }
 
         for client in clients {
             do {
+                YouTubeDiagnostics.record("resolve.client.begin", details: "videoID=\(videoID), client=\(client.name), version=\(client.version)")
                 var clientContext = makeClientContext(client, language: "ru", region: "RU")
                 if !visitorData.isEmpty { clientContext["visitorData"] = visitorData }
                 clientContext["originalUrl"] = "https://www.youtube.com/watch?v=\(videoID)"
@@ -195,8 +217,9 @@ enum YouTubeEngine {
 
                 let playability = root["playabilityStatus"] as? [String: Any] ?? [:]
                 let status = playability["status"] as? String ?? "UNKNOWN"
+                let reason = playability["reason"] as? String ?? status
+                YouTubeDiagnostics.record("resolve.client.response", details: "client=\(client.name), status=\(status), reason=\(reason)")
                 guard status == "OK" else {
-                    let reason = playability["reason"] as? String ?? status
                     failures.append("\(client.name): \(reason)")
                     continue
                 }
@@ -215,22 +238,26 @@ enum YouTubeEngine {
                       let rawURL = string(best["url"]),
                       let url = URL(string: rawURL),
                       url.scheme == "https" else {
+                    YouTubeDiagnostics.record("resolve.client.no_audio", details: "client=\(client.name), adaptiveFormats=\(formats.count), directAudio=\(audio.count)")
                     failures.append("\(client.name): нет прямого аудиоформата (форматов: \(formats.count))")
                     continue
                 }
 
                 let duration = Double(string(details["lengthSeconds"]) ?? "") ?? 0
+                YouTubeDiagnostics.record("resolve.success", details: "videoID=\(videoID), client=\(client.name), audioFormats=\(audio.count), bitrate=\(integer(best["bitrate"])), duration=\(duration)")
                 return Stream(
                     url: url,
                     mimeType: string(best["mimeType"]) ?? "audio/mp4",
                     duration: duration
                 )
             } catch {
+                YouTubeDiagnostics.record("resolve.client.failure", details: "videoID=\(videoID), client=\(client.name), error=\(error.localizedDescription)")
                 failures.append("\(client.name): \(error.localizedDescription)")
             }
         }
 
         let details = failures.isEmpty ? "YouTube не вернул доступные форматы" : failures.joined(separator: " · ")
+        YouTubeDiagnostics.record("resolve.failure", details: "videoID=\(videoID), attempts=\(failures.joined(separator: " | "))")
         throw makeError("Не удалось получить аудио. \(details)")
     }
 
@@ -293,10 +320,17 @@ enum YouTubeEngine {
         request.httpBody = try JSONSerialization.data(withJSONObject: body)
 
         let (data, response) = try await session.data(for: request)
-        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
+        let http = response as? HTTPURLResponse
+        YouTubeDiagnostics.record("http.response", details: "path=\(url.path), status=\(http?.statusCode ?? -1), bytes=\(data.count), contentType=\(http?.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
+        if let http, !(200...299).contains(http.statusCode) {
             throw makeError("YouTube ответил HTTP \(http.statusCode)")
         }
-        return try JSONSerialization.jsonObject(with: data)
+        do {
+            return try JSONSerialization.jsonObject(with: data)
+        } catch {
+            YouTubeDiagnostics.record("http.json_failure", details: "path=\(url.path), bytes=\(data.count), error=\(error.localizedDescription)")
+            throw error
+        }
     }
 
     // MARK: Search response parsing

### plei/Sources/YouTubeHTMLSearch.swift (modified; +13/-4)
@@ -8,6 +8,7 @@ enum YouTubeHTMLSearch {
     private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
 
     static func search(_ query: String) async throws -> [Track] {
+        YouTubeDiagnostics.record("search.html.begin", details: "query=\(query)")
         var components = URLComponents(string: "https://www.youtube.com/results")!
         components.queryItems = [URLQueryItem(name: "search_query", value: query)]
         guard let url = components.url else {
@@ -29,14 +30,22 @@ enum YouTubeHTMLSearch {
         defer { session.invalidateAndCancel() }
 
         let (data, response) = try await session.data(for: request)
-        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
+        let http = response as? HTTPURLResponse
+        YouTubeDiagnostics.record("search.html.response", details: "status=\(http?.statusCode ?? -1), bytes=\(data.count), contentType=\(http?.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
+        if let http, !(200...299).contains(http.statusCode) {
             throw makeError("Страница YouTube ответила HTTP \(http.statusCode)")
         }
-        guard let html = String(data: data, encoding: .utf8),
-              let initialData = extractInitialData(from: html) else {
-            throw makeError("Не удалось прочитать данные результатов со страницы YouTube")
+        guard let html = String(data: data, encoding: .utf8) else {
+            YouTubeDiagnostics.record("search.html.decode_failure", details: "bytes=\(data.count)")
+            throw makeError("Ответ YouTube не удалось декодировать как UTF-8")
+        }
+        guard let initialData = extractInitialData(from: html) else {
+            let marker = html.contains("ytInitialData")
+            YouTubeDiagnostics.record("search.html.initial_data_missing", details: "bytes=\(data.count), hasMarker=\(marker), hasConsent=\(html.localizedCaseInsensitiveContains("consent")), hasCaptcha=\(html.localizedCaseInsensitiveContains("captcha"))")
+            throw makeError("Не удалось найти ytInitialData на странице YouTube")
         }
         let result = tracks(from: initialData)
+        YouTubeDiagnostics.record("search.html.parsed", details: "tracks=\(result.count)")
         guard !result.isEmpty else {
             throw makeError("HTML-страница YouTube не содержит распознанных видео")
         }

### plei/Sources/YouTubePlaylistEngine.swift (modified; +13/-4)
@@ -116,9 +116,10 @@ enum YouTubePlaylistEngine {
         var seenVideos = Set<String>()
         var seenContinuations = Set<String>()
 
-        for _ in 0..<20 {
+        for pageIndex in 0..<20 {
             let raw = try await post(nextEndpoint, body: body)
             let page = radioVideoTracks(from: raw)
+            YouTubeDiagnostics.record("radio.page", details: "page=\(pageIndex + 1), parsed=\(page.count), totalBeforeMerge=\(all.count)")
             for track in page where seenVideos.insert(track.id).inserted {
                 all.append(track)
                 if all.count >= 500 { return all }
@@ -212,9 +213,10 @@ enum YouTubePlaylistEngine {
 
         // A page usually contains many videos. The cap prevents an unbounded
         // request chain for extremely large playlists or changing continuations.
-        for _ in 0..<20 {
+        for pageIndex in 0..<20 {
             let raw = try await post(body)
             let page = videoTracks(from: raw)
+            YouTubeDiagnostics.record("playlist.page", details: "page=\(pageIndex + 1), parsed=\(page.count), totalBeforeMerge=\(all.count)")
             for track in page where seenVideos.insert(track.id).inserted {
                 all.append(track)
                 if all.count >= 1000 { return all }
@@ -252,10 +254,17 @@ enum YouTubePlaylistEngine {
         request.httpBody = try JSONSerialization.data(withJSONObject: body)
 
         let (data, response) = try await session.data(for: request)
-        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
+        let http = response as? HTTPURLResponse
+        YouTubeDiagnostics.record("playlist.http", details: "path=\(url.path), status=\(http?.statusCode ?? -1), bytes=\(data.count)")
+        if let http, !(200...299).contains(http.statusCode) {
             throw makeError("YouTube ответил HTTP \(http.statusCode) при загрузке плейлиста")
         }
-        return try JSONSerialization.jsonObject(with: data)
+        do {
+            return try JSONSerialization.jsonObject(with: data)
+        } catch {
+            YouTubeDiagnostics.record("playlist.json_failure", details: "path=\(url.path), bytes=\(data.count), error=\(error.localizedDescription)")
+            throw error
+        }
     }
 
     private static func videoTracks(from raw: Any) -> [Track] {
