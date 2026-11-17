# 1cd523d4a66f8f9dcfae09c7c885a9d5b0ea83a4
Recover YouTube playback when the stream stalls at the end
@@ -67,6 +67,8 @@ final class Player: ObservableObject {
     private var loadToken = 0
     private var plannedNext: Int? = nil
     private var knownYouTubeDuration: Double? = nil
+    private var lastYouTubeProgressTime: Double? = nil
+    private var lastYouTubeProgressAt = Date()
     private var youtubeRetryCount = 0
     private var prefetchedYouTube: (trackID: String, stream: YouTubeEngine.Stream)?
     private var youtubePrefetchTask: Task<Void, Never>?
@@ -165,6 +167,8 @@ final class Player: ObservableObject {
         loadToken += 1
         let token = loadToken
         knownYouTubeDuration = nil
+        lastYouTubeProgressTime = nil
+        lastYouTubeProgressAt = Date()
         youtubeRetryCount = 0
         completionHandledToken = nil
         planNext()
@@ -541,17 +545,31 @@ final class Player: ObservableObject {
             updateProgress()
         }
         // Some YouTube CDN streams stop producing audio without delivering
-        // AVPlayerItemDidPlayToEndTime. Use the resolved video duration as a
-        // guarded fallback so repeat-one and queue advance still work.
+        // AVPlayerItemDidPlayToEndTime. Track actual clock progress near EOF:
+        // if playback stalls within the final 1.5 seconds for 3 seconds, advance
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
+            let stalled = Date().timeIntervalSince(lastYouTubeProgressAt) >= 3.0
+            if nearEnd, notPaused, stalled,
+               let item = player.currentItem,
+               item.status == .readyToPlay {
+                finishCurrentItem(token: loadToken, item: item)
+                return
+            }
         }
 
         let playing = player.timeControlStatus == .playing


# 7e0ac7b3aa1e29bbfc5cc84a16cd2d30a3f98c51
Avoid premature YouTube end-of-track recovery during brief buffering
@@ -546,7 +546,7 @@ final class Player: ObservableObject {
         }
         // Some YouTube CDN streams stop producing audio without delivering
         // AVPlayerItemDidPlayToEndTime. Track actual clock progress near EOF:
-        // if playback stalls within the final 1.5 seconds for 3 seconds, advance
+        // if playback stalls within the final 1.5 seconds for 5 seconds, advance
         // once rather than leaving the queue stuck. A user-paused item is never
         // auto-advanced by this watchdog.
         if current?.id.first == "y",
@@ -563,7 +563,7 @@ final class Player: ObservableObject {
 
             let nearEnd = s >= expected - 1.5
             let notPaused = player.timeControlStatus != .paused
-            let stalled = Date().timeIntervalSince(lastYouTubeProgressAt) >= 3.0
+            let stalled = Date().timeIntervalSince(lastYouTubeProgressAt) >= 5.0
             if nearEnd, notPaused, stalled,
                let item = player.currentItem,
                item.status == .readyToPlay {


# 23aa63c7b8a48ee1fff2477b79288aca33e60af4
Advance stalled YouTube streams without overriding user pause
@@ -66,6 +66,8 @@ final class Player: ObservableObject {
     private var lastYouTubeDiagnosticState: String? = nil
     private var lastYouTubeDiagnosticAt = Date.distantPast
     private var lastWatchdogBlockedAt = Date.distantPast
+    private var userPausedPlayback = false
+    private var audioSessionInterrupted = false
     private var completionHandledToken: Int? = nil
     private var sleepTask: Task<Void, Never>?
     private var loadToken = 0
@@ -102,10 +104,24 @@ final class Player: ObservableObject {
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
@@ -185,6 +201,7 @@ final class Player: ObservableObject {
         }
         lastYouTubeDiagnosticState = nil
         lastYouTubeDiagnosticAt = .distantPast
+        userPausedPlayback = false
         knownYouTubeDuration = nil
         lastYouTubeProgressTime = nil
         lastYouTubeProgressAt = Date()
@@ -487,6 +504,7 @@ final class Player: ObservableObject {
 
     // MARK: controls
     func resume() {
+        userPausedPlayback = false
         if current?.id.first == "y" { YouTubeDiagnostics.record("playback.user_resume", details: "id=\(current?.id ?? "unknown")") }
         player.play()
         player.rate = Float(speed)
@@ -495,6 +513,7 @@ final class Player: ObservableObject {
     }
 
     func pause() {
+        userPausedPlayback = true
         if current?.id.first == "y" { YouTubeDiagnostics.record("playback.user_pause", details: "id=\(current?.id ?? "unknown")") }
         player.pause()
         isPlaying = false
@@ -626,17 +645,17 @@ final class Player: ObservableObject {
             }
 
             let nearEnd = s >= expected - 1.5
-            let notPaused = player.timeControlStatus != .paused
             let stalled = Date().timeIntervalSince(lastYouTubeProgressAt) >= 5.0
-            if nearEnd, stalled, !notPaused,
+            if nearEnd, stalled, (userPausedPlayback || audioSessionInterrupted),
                Date().timeIntervalSince(lastWatchdogBlockedAt) >= 2.0 {
                 lastWatchdogBlockedAt = Date()
-                YouTubeDiagnostics.record("playback.watchdog_blocked", details: "reason=player_paused, pos=\(String(format: "%.2f", s)), expected=\(String(format: "%.2f", expected)), stalledFor=\(String(format: "%.1f", Date().timeIntervalSince(lastYouTubeProgressAt)))")
+                let reason = userPausedPlayback ? "user_paused" : "audio_interruption"
+                YouTubeDiagnostics.record("playback.watchdog_blocked", details: "reason=\(reason), pos=\(String(format: "%.2f", s)), expected=\(String(format: "%.2f", expected)), stalledFor=\(String(format: "%.1f", Date().timeIntervalSince(lastYouTubeProgressAt)))")
             }
-            if nearEnd, notPaused, stalled,
+            if nearEnd, stalled, !userPausedPlayback, !audioSessionInterrupted,
                let item = player.currentItem,
                item.status == .readyToPlay {
-                YouTubeDiagnostics.record("playback.watchdog_advance", details: "pos=\(String(format: "%.2f", s)), expected=\(String(format: "%.2f", expected))")
+                YouTubeDiagnostics.record("playback.watchdog_advance", details: "pos=\(String(format: "%.2f", s)), expected=\(String(format: "%.2f", expected)), timeControl=\(String(describing: player.timeControlStatus)), bufferEmpty=\(item.isPlaybackBufferEmpty)")
                 finishCurrentItem(token: loadToken, item: item)
                 return
             }


# e75f0c77725b6ae4b642654cb2b2dc69d8199b0b
Keep YouTube end watchdog running during AVPlayer stalls
@@ -63,6 +63,7 @@ final class Player: ObservableObject {
     private var endObs: NSObjectProtocol?
     private var statusObs: NSKeyValueObservation?
     private var timeControlObs: NSKeyValueObservation?
+    private var watchdogTimer: Timer?
     private var lastYouTubeDiagnosticState: String? = nil
     private var lastYouTubeDiagnosticAt = Date.distantPast
     private var lastWatchdogBlockedAt = Date.distantPast
@@ -90,7 +91,7 @@ final class Player: ObservableObject {
         timeObs = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] t in
             Task { @MainActor in self?.tick(t) }
         }
-        timeControlObs = player.observe(\.timeControlStatus, options: [.initial, .new]) { observedPlayer, _ in
+        timeControlObs = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] observedPlayer, _ in
             let status = String(describing: observedPlayer.timeControlStatus)
             let reason = observedPlayer.reasonForWaitingToPlay.map { String(describing: $0) } ?? "none"
             let position = observedPlayer.currentItem?.currentTime().seconds ?? -1
@@ -100,6 +101,14 @@ final class Player: ObservableObject {
                 }
             }
         }
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
@@ -644,7 +653,7 @@ final class Player: ObservableObject {
                 lastYouTubeProgressAt = Date()
             }
 
-            let nearEnd = s >= expected - 1.5
+            let nearEnd = s >= expected - 3.0
             let stalled = Date().timeIntervalSince(lastYouTubeProgressAt) >= 5.0
             if nearEnd, stalled, (userPausedPlayback || audioSessionInterrupted),
                Date().timeIntervalSince(lastWatchdogBlockedAt) >= 2.0 {


# 4a1d3febe6cb1f51b63be658c22d5e7430fb0ce1
Guard YouTube watchdog against duplicate completion
@@ -210,6 +210,7 @@ final class Player: ObservableObject {
         }
         lastYouTubeDiagnosticState = nil
         lastYouTubeDiagnosticAt = .distantPast
+        lastWatchdogBlockedAt = .distantPast
         userPausedPlayback = false
         knownYouTubeDuration = nil
         lastYouTubeProgressTime = nil
@@ -638,10 +639,11 @@ final class Player: ObservableObject {
 
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


# ffaae21c228b35c1a6ff94d1a76c38c0f7fcd556
Restore unfiltered YouTube search request
@@ -75,7 +75,6 @@ enum YouTubeEngine {
                 "gl": "RU"
             ]],
             "query": query,
-            "params": "EgIQAQ=="
         ]
         let raw = try await post(searchURL, body: body, headers: [
             "Origin": "https://www.youtube.com",


# 9df9b2940e11d1427a418f0f35dd8588564da81f
Add local YouTube diagnostics journal
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
