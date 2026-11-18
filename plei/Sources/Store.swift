import Foundation
import SwiftUI
import AVFoundation

@MainActor
final class Store: ObservableObject {
    @Published var favorites: [Track] = [] { didSet { save("fav", favorites) } }
    @Published var playlists: [Playlist] = [] { didSet { save("pls", playlists) } }
    @Published var history: [Track] = [] { didSet { save("his", history) } }
    @Published var overrides: [String: [String]] = [:] { didSet { save("ovr", overrides) } }
    @Published var meta: [String: FileMeta] = [:] { didSet { save("meta", meta) } }
    @Published var files: [Track] = []
    @Published var toast: String? = nil
    @Published var jamendoKey: String = UserDefaults.standard.string(forKey: "jk") ?? "" {
        didSet { UserDefaults.standard.set(jamendoKey, forKey: "jk") }
    }
    @Published var enabledSearchSources: Set<String> = Set(
        UserDefaults.standard.stringArray(forKey: "searchSources") ?? ["YouTube", "Jamendo", "Audius", "Archive"]
    ) {
        didSet { UserDefaults.standard.set(Array(enabledSearchSources).sorted(), forKey: "searchSources") }
    }

    private var saveTasks: [String: Task<Void, Never>] = [:]
    static let exts: Set<String> = ["mp3", "m4a", "aac", "wav", "flac", "aif", "aiff", "caf", "opus"]

    init() {
        favorites = load("fav") ?? []
        playlists = load("pls") ?? []
        history = load("his") ?? []
        overrides = load("ovr") ?? [:]
        meta = load("meta") ?? [:]
        scanFiles()
        importInbox()
    }

    // MARK: storage (с задержкой, чтобы не тормозить интерфейс)
    private func save<T: Encodable>(_ key: String, _ value: T) {
        saveTasks[key]?.cancel()
        saveTasks[key] = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
            if let d = try? JSONEncoder().encode(value) { UserDefaults.standard.set(d, forKey: key) }
        }
    }

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let d = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }

    func say(_ s: String) {
        toast = s
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if self.toast == s { self.toast = nil }
        }
    }

    // MARK: files
    static func parse(_ base: String) -> (String, String) {
        if let r = base.range(of: " - ") {
            let a = String(base[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
            let t = String(base[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !a.isEmpty && !t.isEmpty { return (t, a) }
        }
        return (base, "С телефона")
    }

    func scanFiles() {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: Paths.music.path)) ?? []
        var out: [Track] = []
        for n in names.sorted() {
            let ext = (n as NSString).pathExtension.lowercased()
            if !Store.exts.contains(ext) { continue }
            let p = Paths.music.appendingPathComponent(n).path
            let attrs = try? fm.attributesOfItem(atPath: p)
            let date = (attrs?[.creationDate] as? Date)?.timeIntervalSince1970 ?? 0
            let base = (n as NSString).deletingPathExtension
            let m = meta[n]
            let parsed = Store.parse(base)
            let o = overrides[n]
            let title = o?[0] ?? m?.title ?? parsed.0
            let artist = o?[1] ?? m?.artist ?? parsed.1
            out.append(Track(id: "l" + n, title: title, artist: artist, file: n, added: date, artFile: m?.art))
        }
        files = out
    }

    /// Файл, выбранный через «+» (копируем) или пришедший по ссылке
    func importFiles(_ urls: [URL]) {
        var added: [String] = []
        for url in urls {
            if url.path.contains("/Inbox/") { continue }
            let access = url.startAccessingSecurityScopedResource()
            if let n = place(url, move: false) { added.append(n) }
            if access { url.stopAccessingSecurityScopedResource() }
        }
        added += importInboxNames()
        finish(added)
    }

    /// Всё, что пришло через «Поделиться» (например, из Telegram), переносим, а не копируем
    func importInbox() {
        finish(importInboxNames())
    }

    private func importInboxNames() -> [String] {
        let inbox = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Inbox")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: inbox.path)) ?? []
        var out: [String] = []
        for n in names {
            if let r = place(inbox.appendingPathComponent(n), move: true) { out.append(r) }
        }
        return out
    }

    private func place(_ url: URL, move: Bool) -> String? {
        let fm = FileManager.default
        let ext = url.pathExtension.lowercased()
        if !Store.exts.contains(ext) {
            if move { try? fm.removeItem(at: url) }
            return nil
        }
        let name = url.lastPathComponent
        let base = (name as NSString).deletingPathExtension
        var dest = Paths.music.appendingPathComponent(name)
        var i = 1
        while fm.fileExists(atPath: dest.path) {
            dest = Paths.music.appendingPathComponent("\(base) \(i).\(ext)")
            i += 1
        }
        do {
            if move { try fm.moveItem(at: url, to: dest) } else { try fm.copyItem(at: url, to: dest) }
            return dest.lastPathComponent
        } catch {
            return nil
        }
    }

    private func finish(_ names: [String]) {
        if names.isEmpty { return }
        scanFiles()
        say(names.count == 1 ? "Добавлено: " + (names[0] as NSString).deletingPathExtension : "Добавлено файлов: \(names.count)")
        Task {
            for n in names { await readMeta(n) }
            scanFiles()
        }
    }

    /// Название, исполнитель и обложка из тегов файла
    private func readMeta(_ name: String) async {
        let url = Paths.music.appendingPathComponent(name)
        let asset = AVURLAsset(url: url)
        guard let items = try? await asset.load(.commonMetadata) else { return }
        var m = FileMeta()
        for it in items {
            guard let key = it.commonKey else { continue }
            if key == .commonKeyTitle {
                m.title = try? await it.load(.stringValue)
            } else if key == .commonKeyArtist {
                m.artist = try? await it.load(.stringValue)
            } else if key == .commonKeyArtwork {
                if let d = try? await it.load(.dataValue) {
                    let artName = name + ".img"
                    try? d.write(to: Paths.art.appendingPathComponent(artName))
                    m.art = artName
                }
            }
        }
        if let t = m.title?.trimmingCharacters(in: .whitespaces), t.isEmpty { m.title = nil }
        if let a = m.artist?.trimmingCharacters(in: .whitespaces), a.isEmpty { m.artist = nil }
        if m.title != nil || m.artist != nil || m.art != nil { meta[name] = m }
    }

    func deleteFile(_ t: Track) {
        guard let f = t.file else { return }
        try? FileManager.default.removeItem(at: Paths.music.appendingPathComponent(f))
        if let a = t.artFile { try? FileManager.default.removeItem(at: Paths.art.appendingPathComponent(a)) }
        overrides[f] = nil
        meta[f] = nil
        scanFiles()
    }

    var library: [Track] {
        return (files + favorites).sorted { $0.added > $1.added }
    }

    // MARK: favorites / history
    func isFav(_ t: Track) -> Bool { return favorites.contains { $0.id == t.id } }

    func toggleFav(_ t: Track) {
        if let i = favorites.firstIndex(where: { $0.id == t.id }) {
            favorites.remove(at: i)
        } else {
            var x = t
            x.added = Date().timeIntervalSince1970
            favorites.insert(x, at: 0)
        }
    }

    func addHistory(_ t: Track) {
        if history.first?.id == t.id { return }
        history.removeAll { $0.id == t.id }
        history.insert(t, at: 0)
        if history.count > 40 { history.removeLast(history.count - 40) }
    }

    func rename(_ t: Track, title: String, artist: String) {
        let ti = title.isEmpty ? t.title : title
        let ar = artist.isEmpty ? t.artist : artist
        if let f = t.file {
            overrides[f] = [ti, ar]
            scanFiles()
        }
        func patch(_ arr: inout [Track]) {
            for i in arr.indices where arr[i].id == t.id {
                arr[i].title = ti
                arr[i].artist = ar
            }
        }
        patch(&favorites)
        patch(&history)
        for p in playlists.indices { patch(&playlists[p].tracks) }
    }

    // MARK: playlists
    @discardableResult
    func createPlaylist(_ name: String) -> UUID? {
        let n = name.trimmingCharacters(in: .whitespaces)
        if n.isEmpty { return nil }
        let p = Playlist(name: n)
        playlists.append(p)
        return p.id
    }

    func add(_ t: Track, to id: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == id }) else { return }
        if playlists[i].tracks.contains(where: { $0.id == t.id }) {
            say("Уже в «" + playlists[i].name + "»")
        } else {
            playlists[i].tracks.append(t)
            say("Добавлено в «" + playlists[i].name + "»")
        }
    }

    func removeFromPlaylist(_ t: Track, _ id: UUID) {
        guard let i = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[i].tracks.removeAll { $0.id == t.id }
    }

    func renamePlaylist(_ id: UUID, _ name: String) {
        let n = name.trimmingCharacters(in: .whitespaces)
        if n.isEmpty { return }
        if let i = playlists.firstIndex(where: { $0.id == id }) { playlists[i].name = n }
    }

    func deletePlaylist(_ id: UUID) {
        playlists.removeAll { $0.id == id }
    }
}
