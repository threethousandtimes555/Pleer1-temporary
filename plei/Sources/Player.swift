import Foundation
import AVFoundation
import MediaPlayer
import UIKit

enum RepeatMode: String {
    case off, all, one, shuffle

    var icon: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        case .shuffle: return "shuffle"
        }
    }
    var label: String {
        switch self {
        case .off: return "Повтор выключен"
        case .all: return "Повтор всех треков"
        case .one: return "Повтор одного трека"
        case .shuffle: return "Вперемешку"
        }
    }
    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .shuffle
        case .shuffle: return .off
        }
    }
}

/// Часто меняющиеся значения вынесены отдельно, чтобы не перерисовывать списки
@MainActor
final class Clock: ObservableObject {
    @Published var position: Double = 0
    @Published var duration: Double = 0
}

@MainActor
final class Player: ObservableObject {
    @Published var queue: [Track] = []
    @Published var index: Int = 0
    @Published var isPlaying = false
    @Published var sleepMinutes = 0
    @Published var repeatMode: RepeatMode = RepeatMode(rawValue: UserDefaults.standard.string(forKey: "rm") ?? "off") ?? .off
    @Published var speed: Double = {
        let v = UserDefaults.standard.double(forKey: "sp")
        return v == 0 ? 1.0 : v
    }()

    let clock = Clock()
    weak var store: Store?

    var current: Track? {
        return queue.indices.contains(index) ? queue[index] : nil
    }

    private let player = AVPlayer()
    private var timeObs: Any?
    private var endObs: NSObjectProtocol?
    private var statusObs: NSKeyValueObservation?
    private var timeControlObs: NSKeyValueObservation?
    private var watchdogTimer: Timer?
    private var lastYouTubeDiagnosticState: String? = nil
    private var lastYouTubeDiagnosticAt = Date.distantPast
    private var lastWatchdogBlockedAt = Date.distantPast
    private var userPausedPlayback = false
    private var audioSessionInterrupted = false
    private var completionHandledToken: Int? = nil
    private var sleepTask: Task<Void, Never>?
    private var loadToken = 0
    private var plannedNext: Int? = nil
    private var knownYouTubeDuration: Double? = nil
    private var lastYouTubeProgressTime: Double? = nil
    private var lastYouTubeProgressAt = Date()
    private var youtubeRetryCount = 0
    private var prefetchedYouTube: (trackID: String, stream: YouTubeEngine.Stream)?
    private var youtubePrefetchTask: Task<Void, Never>?
    private var youtubePrefetchTrackID: String?
    private var youtubePrefetchToken = 0

    init() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            YouTubeDiagnostics.record("playback.audio_session", details: "phase=init, active=true, category=playback")
        } catch {
            YouTubeDiagnostics.record("playback.audio_session_error", details: "phase=init, error=\(error.localizedDescription)")
        }
        player.automaticallyWaitsToMinimizeStalling = true

        timeObs = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] t in
            Task { @MainActor in self?.tick(t) }
        }
        timeControlObs = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] observedPlayer, _ in
            let status = String(describing: observedPlayer.timeControlStatus)
            let reason = observedPlayer.reasonForWaitingToPlay.map { String(describing: $0) } ?? "none"
            let position = observedPlayer.currentItem?.currentTime().seconds ?? -1
            Task { @MainActor in
                if self?.current?.id.first == "y" {
                    YouTubeDiagnostics.record("playback.time_control", details: "status=\(status), reason=\(reason), position=\(String(format: "%.2f", position))")
                }
            }
        }
        // AVPlayer's periodic observer may become quiet after a stream stalls.
        // This independent one-second check keeps the end-of-track watchdog alive.
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.current?.id.first == "y" else { return }
                self.tick(self.player.currentTime())
            }
        }

        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            let typeRaw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
            let optRaw = n.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let interruptionType = AVAudioSession.InterruptionType(rawValue: typeRaw)
            let began = interruptionType == .began
            let ended = interruptionType == .ended
            let should = AVAudioSession.InterruptionOptions(rawValue: optRaw).contains(.shouldResume)
            Task { @MainActor in
                if began {
                    self?.audioSessionInterrupted = true
                    if self?.current?.id.first == "y" {
                        YouTubeDiagnostics.record("playback.audio_interruption", details: "phase=began")
                    }
                }
                if ended {
                    self?.audioSessionInterrupted = false
                    if self?.current?.id.first == "y" {
                        YouTubeDiagnostics.record("playback.audio_interruption", details: "phase=ended, shouldResume=\(should)")
                    }
                    if should { self?.resume() }
                }
            }
        }
        setupRemote()
        Task.detached { AudioCache.shared.trim() }
    }

    // MARK: queue
    func play(_ list: [Track], at i: Int = 0) {
        if list.isEmpty { return }
        queue = list
        index = max(0, min(i, list.count - 1))
        load()
    }

    func jump(to i: Int) {
        if queue.indices.contains(i) {
            index = i
            load()
        }
    }

    private func planNext() {
        if queue.count < 2 {
            plannedNext = repeatMode == .off ? nil : (queue.isEmpty ? nil : index)
        } else {
            switch repeatMode {
            case .shuffle:
                var j = index
                while j == index { j = Int.random(in: 0..<queue.count) }
                plannedNext = j
            case .one:
                plannedNext = index
            case .all:
                plannedNext = index < queue.count - 1 ? index + 1 : 0
            case .off:
                plannedNext = index < queue.count - 1 ? index + 1 : nil
            }
        }
        reconcileYouTubePrefetch()
    }

    /// Не даём устаревшему запросу предзагрузки блокировать подготовку нового
    /// следующего трека после перехода по очереди или смены режима повтора.
    private func reconcileYouTubePrefetch() {
        let desiredID = plannedNext.flatMap { queue.indices.contains($0) ? queue[$0].id : nil }
        // Если следующий трек уже стал текущим, не отменяем его запрос:
        // loadYouTube дождётся того же результата вместо второго HTTP-запроса.
        if youtubePrefetchTrackID != desiredID,
           youtubePrefetchTrackID != current?.id {
            youtubePrefetchToken += 1
            youtubePrefetchTask?.cancel()
            youtubePrefetchTask = nil
            youtubePrefetchTrackID = nil
        }
        // Уже подготовленный поток может относиться к треку, на который
        // мы только что переключились. Сохраняем его, чтобы loadYouTube мог
        // использовать готовый URL вместо повторного запроса.
        if let cachedID = prefetchedYouTube?.trackID,
           cachedID != desiredID,
           cachedID != current?.id {
            prefetchedYouTube = nil
        }
    }

    // MARK: loading
    private func localURL(_ t: Track) -> URL? {
        if let f = t.file { return Paths.music.appendingPathComponent(f) }
        return AudioCache.shared.lookup(t)
    }

    private func load() {
        guard let t = current else { return }
        loadToken += 1
        let token = loadToken
        if t.id.first == "y" {
            YouTubeDiagnostics.record("playback.load", details: "id=\(t.id), title=\(t.title), queueCount=\(queue.count), index=\(index)")
        }
        lastYouTubeDiagnosticState = nil
        lastYouTubeDiagnosticAt = .distantPast
        lastWatchdogBlockedAt = .distantPast
        userPausedPlayback = false
        knownYouTubeDuration = nil
        lastYouTubeProgressTime = nil
        lastYouTubeProgressAt = Date()
        youtubeRetryCount = 0
        completionHandledToken = nil
        planNext()
        if let radioID = t.youtubeRadioID, let seedVideoID = t.youtubeRadioVideoID {
            clock.position = 0
            clock.duration = 0
            player.pause()
            player.replaceCurrentItem(with: nil)
            statusObs = nil
            isPlaying = false
            store?.say("Загружаю YouTube-микс…")
            updateNowPlaying()
            Task { await loadYouTubeRadio(t, playlistID: radioID, seedVideoID: seedVideoID, token: token) }
            return
        }
        if let playlistID = t.youtubePlaylistID {
            clock.position = 0
            clock.duration = 0
            player.pause()
            player.replaceCurrentItem(with: nil)
            statusObs = nil
            isPlaying = false
            store?.say("Загружаю плейлист YouTube…")
            updateNowPlaying()
            Task { await loadYouTubePlaylist(t, playlistID: playlistID, token: token) }
            return
        }
        if t.archive != nil {
            Task { await expandArchive(t, token: token) }
            return
        }
        clock.position = 0
        clock.duration = 0
        store?.addHistory(t)

        // YouTube watch-page URLs are not media files. Resolve a fresh, short-lived
        // audio URL before handing the item to AVPlayer; never send it to AudioCache.
        if t.id.first == "y" {
            player.pause()
            player.replaceCurrentItem(with: nil)
            statusObs = nil
            isPlaying = false
            updateNowPlaying()
            Task { await loadYouTube(t, token: token) }
            return
        }

        isPlaying = true
        if let url = localURL(t) {
            start(url, t, streaming: false)
        } else if let s = t.url, let u = URL(string: s) {
            start(u, t, streaming: true)
        } else {
            store?.say("Файл не найден")
        }
        updateNowPlaying()
    }


    private func loadYouTubeRadio(_ track: Track, playlistID: String, seedVideoID: String, token: Int) async {
        YouTubeDiagnostics.record("radio.load.begin", details: "playlist=\(playlistID), seed=\(seedVideoID)")
        do {
            let tracks = try await YouTubePlaylistEngine.loadRadio(playlistID: playlistID, seedVideoID: seedVideoID)
            guard token == loadToken, current?.id == track.id else { return }
            YouTubeDiagnostics.record("radio.load.success", details: "playlist=\(playlistID), tracks=\(tracks.count)")
            guard !tracks.isEmpty else {
                store?.say("В миксе нет доступных видео")
                return
            }
            queue = tracks
            index = 0
            load()
        } catch {
            guard token == loadToken, current?.id == track.id else { return }
            YouTubeDiagnostics.record("radio.load.failure", details: "playlist=\(playlistID), error=\(error.localizedDescription)")
            isPlaying = false
            store?.say("YouTube-микс: " + error.localizedDescription)
            updateProgress()
        }
    }

    private func loadYouTubePlaylist(_ track: Track, playlistID: String, token: Int) async {
        YouTubeDiagnostics.record("playlist.load.begin", details: "playlist=\(playlistID)")
        do {
            let tracks = try await YouTubePlaylistEngine.load(playlistID: playlistID)
            guard token == loadToken, current?.id == track.id else { return }
            YouTubeDiagnostics.record("playlist.load.success", details: "playlist=\(playlistID), tracks=\(tracks.count)")
            guard !tracks.isEmpty else {
                store?.say("В плейлисте нет доступных видео")
                return
            }
            queue = tracks
            index = 0
            load()
        } catch {
            guard token == loadToken, current?.id == track.id else { return }
            YouTubeDiagnostics.record("playlist.load.failure", details: "playlist=\(playlistID), error=\(error.localizedDescription)")
            isPlaying = false
            store?.say("YouTube-плейлист: " + error.localizedDescription)
            updateProgress()
        }
    }

    private func loadYouTube(_ track: Track, token: Int) async {
        YouTubeDiagnostics.record("playback.resolve.begin", details: "id=\(track.id), usingPrefetch=\(prefetchedYouTube?.trackID == track.id || youtubePrefetchTrackID == track.id)")
        do {
            let stream: YouTubeEngine.Stream
            if let cached = prefetchedYouTube, cached.trackID == track.id {
                stream = cached.stream
                prefetchedYouTube = nil
            } else if youtubePrefetchTrackID == track.id,
                      let prefetchTask = youtubePrefetchTask {
                // Используем уже выполняющийся запрос предзагрузки, не запускаем
                // второй параллельный resolve для того же видео.
                await prefetchTask.value
                guard token == loadToken, current?.id == track.id else { return }
                if let cached = prefetchedYouTube, cached.trackID == track.id {
                    stream = cached.stream
                    prefetchedYouTube = nil
                } else {
                    stream = try await YouTubeEngine.resolve(videoID: String(track.id.dropFirst()))
                }
            } else {
                stream = try await YouTubeEngine.resolve(videoID: String(track.id.dropFirst()))
            }
            guard token == loadToken, current?.id == track.id else { return }
            knownYouTubeDuration = stream.duration > 0 ? stream.duration : nil
            YouTubeDiagnostics.record("playback.resolve.success", details: "id=\(track.id), duration=\(String(format: "%.2f", stream.duration)), mime=\(stream.mimeType), host=\(stream.url.host ?? "unknown")")
            if let duration = knownYouTubeDuration {
                clock.duration = duration
                updateProgress()
            }
            isPlaying = true
            start(stream.url, track, streaming: true, recoverable: false)
            updateNowPlaying()
        } catch {
            guard token == loadToken, current?.id == track.id else { return }
            YouTubeDiagnostics.record("playback.resolve.failure", details: "id=\(track.id), error=\(error.localizedDescription)")
            isPlaying = false
            store?.say("YouTube: " + error.localizedDescription)
            updateProgress()
        }
    }

    private func start(_ url: URL, _ t: Track, streaming: Bool, recoverable: Bool = true) {
        let asset: AVURLAsset
        if url.isFileURL {
            asset = AVURLAsset(url: url)
        } else {
            let agent = t.id.first == "y"
                ? "com.google.ios.youtube/20.10.4 (iPhone; U; CPU iOS 18_1_0 like Mac OS X;)"
                : "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Plei/0.2"
            asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": ["User-Agent": agent]])
        }
        let item = AVPlayerItem(asset: asset)
        // Match Musike’s native YouTube buffering strategy without changing other providers.
        if t.id.first == "y" {
            item.preferredForwardBufferDuration = 30
            YouTubeDiagnostics.record("playback.item_created", details: "id=\(t.id), forwardBuffer=30, urlHost=\(url.host ?? "file")")
        }
        if let o = endObs { NotificationCenter.default.removeObserver(o) }
        let token = loadToken
        endObs = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.finishCurrentItem(token: token, item: item) }
        }
        statusObs = item.observe(\.status, options: [.initial, .new]) { [weak self] it, _ in
            let st = it.status
            let msg = it.error?.localizedDescription ?? ""
            Task { @MainActor in self?.itemStatus(st, msg, t, token, streaming, recoverable) }
        }
        if t.id.first == "y" {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true)
                YouTubeDiagnostics.record("playback.audio_session", details: "phase=start, active=true")
            } catch {
                YouTubeDiagnostics.record("playback.audio_session_error", details: "phase=start, error=\(error.localizedDescription)")
            }
            YouTubeDiagnostics.record("playback.start_requested", details: "id=\(t.id), speed=\(speed), pausedByUser=\(userPausedPlayback), interrupted=\(audioSessionInterrupted)")
        }
        player.replaceCurrentItem(with: item)
        player.play()
        player.rate = Float(speed)
        if t.id.first == "y" {
            YouTubeDiagnostics.record("playback.start_state", details: "id=\(t.id), rate=\(player.rate), control=\(player.timeControlStatus.rawValue), item=\(item.status.rawValue)")
        }
    }

    private func finishCurrentItem(token: Int, item: AVPlayerItem) {
        guard token == loadToken,
              player.currentItem === item,
              completionHandledToken != token else { return }
        completionHandledToken = token
        if current?.id.first == "y" {
            YouTubeDiagnostics.record("playback.finish_event", details: "id=\(current?.id ?? "unknown"), position=\(String(format: "%.2f", player.currentTime().seconds)), duration=\(String(format: "%.2f", knownYouTubeDuration ?? 0))")
        }
        if current?.id.first == "y",
           let duration = knownYouTubeDuration,
           duration.isFinite, duration > 0 {
            clock.position = duration
            updateProgress()
        }
        advance(auto: true)
    }

    private func itemStatus(_ st: AVPlayerItem.Status, _ msg: String, _ t: Track, _ token: Int, _ streaming: Bool, _ recoverable: Bool) {
        if token != loadToken { return }
        if t.id.first == "y" {
            let statusName = st == .readyToPlay ? "readyToPlay" : (st == .failed ? "failed" : "unknown")
            YouTubeDiagnostics.record("playback.item_status", details: "id=\(t.id), status=\(statusName), error=\(msg)")
        }
        if st == .readyToPlay {
            if t.id.first == "y" {
                if !userPausedPlayback && !audioSessionInterrupted {
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                        player.play()
                        player.rate = Float(speed)
                        isPlaying = true
                        YouTubeDiagnostics.record("playback.ready_resume", details: "id=\(t.id), rate=\(player.rate), control=\(player.timeControlStatus.rawValue)")
                    } catch {
                        YouTubeDiagnostics.record("playback.audio_session_error", details: "phase=ready_resume, error=\(error.localizedDescription)")
                    }
                } else {
                    YouTubeDiagnostics.record("playback.ready_resume_skipped", details: "id=\(t.id), pausedByUser=\(userPausedPlayback), interrupted=\(audioSessionInterrupted)")
                }
            }
            updateNowPlaying()
            prefetchNext()
        } else if st == .failed {
            if streaming && recoverable {
                Task { await recover(t, token) }
            } else if t.id.first == "y" && youtubeRetryCount == 0 {
                // YouTube CDN URLs expire. Resolve one fresh URL if AVPlayer rejects
                // the first stream (including a late 403), but never retry forever.
                youtubeRetryCount = 1
                player.pause()
                Task { await loadYouTube(t, token: token) }
            } else {
                let reason = msg.isEmpty ? "не удалось открыть аудиопоток" : msg
                store?.say((t.id.first == "y" ? "YouTube: " : "Не воспроизводится: ") + reason)
                isPlaying = false
                updateProgress()
            }
        }
    }

    /// Если поток не открылся, скачиваем трек целиком и играем из файла
    private func recover(_ t: Track, _ token: Int) async {
        store?.say("Докачиваю трек целиком…")
        do {
            let u = try await AudioCache.shared.download(t)
            if token == loadToken { start(u, t, streaming: false) }
        } catch {
            if token == loadToken { store?.say("Не получилось: " + error.localizedDescription) }
        }
    }

    /// Следующий трек подгружается заранее, чтобы переключение не лагало
    private func prefetchNext() {
        guard let n = plannedNext, queue.indices.contains(n) else { return }
        let t = queue[n]
        if t.id.first == "y" {
            guard t.youtubePlaylistID == nil, t.youtubeRadioID == nil else { return }
            guard prefetchedYouTube?.trackID != t.id else { return }
            guard youtubePrefetchTask == nil else { return }

            youtubePrefetchToken += 1
            let token = youtubePrefetchToken
            youtubePrefetchTrackID = t.id
            YouTubeDiagnostics.record("playback.prefetch.begin", details: "id=\(t.id)")
            youtubePrefetchTask = Task { [weak self] in
                defer {
                    if let self, self.youtubePrefetchToken == token {
                        self.youtubePrefetchTask = nil
                        self.youtubePrefetchTrackID = nil
                        // Если ожидавшийся трек уже стал текущим, сразу готовим
                        // следующий за ним, не ожидая ещё одного события AVPlayer.
                        if self.current?.id == t.id {
                            self.prefetchNext()
                        }
                    }
                }
                do {
                    let stream = try await YouTubeEngine.resolve(videoID: String(t.id.dropFirst()))
                    guard !Task.isCancelled,
                          let self,
                          self.youtubePrefetchToken == token,
                          self.queue.indices.contains(n),
                          self.queue[n].id == t.id,
                          (self.plannedNext == n || self.current?.id == t.id) else { return }
                    self.prefetchedYouTube = (trackID: t.id, stream: stream)
                    YouTubeDiagnostics.record("playback.prefetch.success", details: "id=\(t.id), duration=\(String(format: "%.2f", stream.duration))")
                } catch {
                    YouTubeDiagnostics.record("playback.prefetch.failure", details: "id=\(t.id), error=\(error.localizedDescription)")
                    // The next track will resolve normally when playback reaches it.
                }
            }
            return
        }
        if t.file != nil || t.archive != nil || t.url == nil { return }
        Task.detached(priority: .utility) {
            _ = try? await AudioCache.shared.download(t)
        }
    }

    private func expandArchive(_ t: Track, token: Int) async {
        guard let id = t.archive else { return }
        store?.say("Загружаю…")
        let tracks = await Sources.archiveTracks(id: id, title: t.title, art: t.art)

        // The user may have changed tracks or replaced the queue while the
        // archive request was in flight. Never let an old response overwrite
        // the newer playback state.
        guard token == loadToken, current?.id == t.id else { return }

        if tracks.isEmpty {
            store?.say("В этой записи нет mp3")
            return
        }
        queue = tracks
        index = 0
        load()
    }

    // MARK: controls
    func resume() {
        userPausedPlayback = false
        if current?.id.first == "y" { YouTubeDiagnostics.record("playback.user_resume", details: "id=\(current?.id ?? "unknown")") }
        player.play()
        player.rate = Float(speed)
        isPlaying = true
        updateProgress()
    }

    func pause() {
        userPausedPlayback = true
        if current?.id.first == "y" { YouTubeDiagnostics.record("playback.user_pause", details: "id=\(current?.id ?? "unknown")") }
        player.pause()
        isPlaying = false
        updateProgress()
    }

    func toggle() {
        if player.timeControlStatus == .paused { resume() } else { pause() }
    }

    func advance(auto: Bool = false) {
        if current?.id.first == "y" {
            YouTubeDiagnostics.record("playback.advance", details: "auto=\(auto), id=\(current?.id ?? "unknown"), index=\(index), plannedNext=\(plannedNext.map { String($0) } ?? "nil"), timeControl=\(String(describing: player.timeControlStatus))")
        }
        if queue.isEmpty { return }
        var j: Int? = nil
        if auto || repeatMode != .one { j = plannedNext }
        if j == nil {
            if index < queue.count - 1 { j = index + 1 } else if repeatMode != .off { j = 0 }
        }
        if let n = j {
            index = n
            load()
        } else if auto {
            player.pause()
            isPlaying = false
            updateProgress()
        }
    }

    func previous() {
        if clock.position > 3 {
            seek(0)
        } else if index > 0 {
            index -= 1
            load()
        } else {
            seek(0)
        }
    }

    func seek(_ s: Double) {
        let target = CMTime(seconds: s, preferredTimescale: 600)
        let trackID = current?.id ?? "unknown"
        let token = loadToken
        let itemStatus = player.currentItem?.status.rawValue ?? -1
        let duration = player.currentItem?.duration.seconds ?? -1
        YouTubeDiagnostics.record("playback.seek.request", details: "id=\(trackID), target=\(String(format: "%.2f", s)), token=\(token), itemStatus=\(itemStatus), duration=\(String(format: "%.2f", duration))")
        player.seek(to: target) { [weak self] finished in
            Task { @MainActor in
                guard let self else { return }
                let actual = self.player.currentTime().seconds
                YouTubeDiagnostics.record("playback.seek.complete", details: "id=\(trackID), finished=\(finished), requested=\(String(format: "%.2f", s)), actual=\(String(format: "%.2f", actual)), currentID=\(self.current?.id ?? "unknown"), token=\(self.loadToken), control=\(self.player.timeControlStatus.rawValue)")
            }
        }
        clock.position = s
        updateProgress()
    }

    func cycleRepeat() {
        repeatMode = repeatMode.next
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "rm")
        planNext()
        prefetchNext()
        store?.say(repeatMode.label)
    }

    func setSpeed(_ v: Double) {
        speed = v
        UserDefaults.standard.set(v, forKey: "sp")
        if player.timeControlStatus != .paused { player.rate = Float(v) }
        updateProgress()
    }

    func setSleep(_ m: Int) {
        sleepTask?.cancel()
        sleepMinutes = m
        if m <= 0 { return }
        sleepTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(m) * 60_000_000_000)
            if !Task.isCancelled {
                self.pause()
                self.sleepMinutes = 0
            }
        }
    }

    private func tick(_ t: CMTime) {
        let s = t.seconds
        if current?.id.first == "y",
           let expected = knownYouTubeDuration,
           expected.isFinite, expected > 0 {
            // Keep the displayed position and lock-screen elapsed time within
            // the known video duration even if AVPlayer's clock runs past EOF.
            clock.position = s.isFinite ? min(max(s, 0), expected) : 0
        } else {
            clock.position = s.isFinite ? max(s, 0) : 0
        }
        if let expected = knownYouTubeDuration, expected.isFinite, expected > 0 {
            if abs(expected - clock.duration) > 0.5 {
                clock.duration = expected
                updateProgress()
            }
        } else if let d = player.currentItem?.duration.seconds, d.isFinite, d > 0, abs(d - clock.duration) > 0.5 {
            clock.duration = d
            updateProgress()
        }
        // Capture AVPlayer's state transitions and buffer indicators. This is
        // deliberately observational: it does not alter playback or advance the queue.
        if current?.id.first == "y", let item = player.currentItem {
            let nearEnd = knownYouTubeDuration.map { $0 > 0 && s >= $0 - 3.0 } ?? false
            let state = "item=\(item.status.rawValue),control=\(player.timeControlStatus.rawValue),empty=\(item.isPlaybackBufferEmpty),likely=\(item.isPlaybackLikelyToKeepUp),keepUp=\(item.isPlaybackBufferFull)"
            let now = Date()
            if state != lastYouTubeDiagnosticState || (nearEnd && now.timeIntervalSince(lastYouTubeDiagnosticAt) >= 2.0) {
                lastYouTubeDiagnosticState = state
                lastYouTubeDiagnosticAt = now
                let ranges = item.loadedTimeRanges.map { value -> String in
                    let range = value.timeRangeValue
                    return "\(String(format: "%.2f", range.start.seconds))+\(String(format: "%.2f", range.duration.seconds))"
                }.joined(separator: ",")
                let waiting = player.reasonForWaitingToPlay.map { String(describing: $0) } ?? "none"
                YouTubeDiagnostics.record("playback.tick", details: "id=\(current?.id ?? "unknown"), pos=\(String(format: "%.2f", s)), expected=\(String(format: "%.2f", knownYouTubeDuration ?? 0)), state=\(state), waiting=\(waiting), loaded=\(ranges)")
            }
        }

        // Some YouTube CDN streams stop producing audio without delivering
        // AVPlayerItemDidPlayToEndTime. Track actual clock progress near EOF:
        // if playback stalls within the final 3 seconds for 5 seconds, advance
        // once rather than leaving the queue stuck. A user-paused item is never
        // auto-advanced by this watchdog.
        if current?.id.first == "y",
           completionHandledToken != loadToken,
           s.isFinite,
           let expected = knownYouTubeDuration,
           expected.isFinite, expected > 0 {
            if let previous = lastYouTubeProgressTime, s > previous + 0.08 {
                lastYouTubeProgressTime = s
                lastYouTubeProgressAt = Date()
            } else if lastYouTubeProgressTime == nil {
                lastYouTubeProgressTime = s
                lastYouTubeProgressAt = Date()
            }

            let nearEnd = s >= expected - 3.0
            let stalled = Date().timeIntervalSince(lastYouTubeProgressAt) >= 5.0
            if nearEnd, stalled, (userPausedPlayback || audioSessionInterrupted),
               Date().timeIntervalSince(lastWatchdogBlockedAt) >= 2.0 {
                lastWatchdogBlockedAt = Date()
                let reason = userPausedPlayback ? "user_paused" : "audio_interruption"
                YouTubeDiagnostics.record("playback.watchdog_blocked", details: "reason=\(reason), pos=\(String(format: "%.2f", s)), expected=\(String(format: "%.2f", expected)), stalledFor=\(String(format: "%.1f", Date().timeIntervalSince(lastYouTubeProgressAt)))")
            }
            if nearEnd, stalled, !userPausedPlayback, !audioSessionInterrupted,
               let item = player.currentItem,
               item.status == .readyToPlay {
                YouTubeDiagnostics.record("playback.watchdog_advance", details: "pos=\(String(format: "%.2f", s)), expected=\(String(format: "%.2f", expected)), timeControl=\(String(describing: player.timeControlStatus)), bufferEmpty=\(item.isPlaybackBufferEmpty)")
                finishCurrentItem(token: loadToken, item: item)
                return
            }
        }

        let playing = player.timeControlStatus == .playing
        if playing != isPlaying {
            isPlaying = playing
            updateProgress()
        }
    }

    // MARK: lock screen
    private func updateNowPlaying() {
        guard let t = current else { return }
        let info: [String: Any] = [
            MPMediaItemPropertyTitle: t.title,
            MPMediaItemPropertyArtist: t.artist,
            MPMediaItemPropertyPlaybackDuration: clock.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: clock.position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? speed : 0.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        let id = t.id
        Task {
            var img: UIImage? = nil
            if let f = t.artFile {
                img = ImageStore.shared.local(f)
            } else if let a = t.art {
                img = await ImageStore.shared.image(url: a)
            }
            if let image = img, self.current?.id == id {
                let art = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                var cur = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                cur[MPMediaItemPropertyArtwork] = art
                MPNowPlayingInfoCenter.default().nowPlayingInfo = cur
            }
        }
    }

    private func updateProgress() {
        var cur = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        cur[MPMediaItemPropertyPlaybackDuration] = clock.duration
        cur[MPNowPlayingInfoPropertyElapsedPlaybackTime] = clock.position
        cur[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? speed : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = cur
    }

    private func setupRemote() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        c.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }
        c.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.advance() }
            return .success
        }
        c.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        c.changePlaybackPositionCommand.addTarget { [weak self] e in
            if let ev = e as? MPChangePlaybackPositionCommandEvent {
                let pos = ev.positionTime
                Task { @MainActor in self?.seek(pos) }
            }
            return .success
        }
    }
}
