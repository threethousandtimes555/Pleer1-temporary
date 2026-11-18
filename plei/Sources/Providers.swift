import Foundation

enum Sources {
    static func enc(_ s: String) -> String {
        let ok = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return s.addingPercentEncoding(withAllowedCharacters: ok) ?? s
    }

    static func json(_ s: String, timeout: Double = 10) async throws -> Any {
        guard let u = URL(string: s) else { throw URLError(.badURL) }
        var r = URLRequest(url: u)
        r.timeoutInterval = timeout
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        r.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Plei/0.1", forHTTPHeaderField: "User-Agent")
        let (d, _) = try await URLSession.shared.data(for: r)
        do {
            return try JSONSerialization.jsonObject(with: d)
        } catch {
            throw NSError(domain: "json", code: 2, userInfo: [NSLocalizedDescriptionKey: "сервер ответил не данными (возможно, закрыт для приложений)"])
        }
    }

    static func s(_ v: Any?) -> String? {
        if let x = v as? String { return x }
        if let n = v as? NSNumber { return n.stringValue }
        return nil
    }

    static func first(_ v: Any?) -> String? {
        if let a = v as? [Any] { return a.first.flatMap { s($0) } }
        return s(v)
    }

    static func run(_ name: String, _ f: () async throws -> [Track]) async -> (String, [Track], String?) {
        do {
            let t = try await f()
            return (name, t, nil)
        } catch {
            return (name, [], error.localizedDescription)
        }
    }

    // MARK: Jamendo
    static func jamendo(_ q: String, key: String) async throws -> [Track] {
        let j = try await json("https://api.jamendo.com/v3.0/tracks/?format=json&limit=25&audioformat=mp32&imagesize=600&client_id=\(enc(key))&search=\(enc(q))")
        guard let o = j as? [String: Any], let rs = o["results"] as? [[String: Any]] else {
            throw NSError(domain: "Jamendo", code: 1, userInfo: [NSLocalizedDescriptionKey: "ответ без результатов, проверь ключ"])
        }
        return rs.compactMap { r in
            guard let id = s(r["id"]), let name = s(r["name"]), let audio = s(r["audio"]) else { return nil }
            return Track(id: "j" + id, title: name, artist: s(r["artist_name"]) ?? "", art: s(r["image"]), url: audio)
        }
    }

    // MARK: Audius
    static func audius(_ q: String) async throws -> [Track] {
        let j = try await json("https://discoveryprovider.audius.co/v1/tracks/search?limit=20&app_name=Plei&query=\(enc(q))")
        let ds = (j as? [String: Any])?["data"] as? [[String: Any]] ?? []
        return ds.compactMap { r in
            guard let id = s(r["id"]), let title = s(r["title"]) else { return nil }
            if let st = r["is_streamable"] as? Bool, !st { return nil }
            let user = (r["user"] as? [String: Any]).flatMap { s($0["name"]) } ?? ""
            let art = (r["artwork"] as? [String: Any]).flatMap { s($0["1000x1000"]) ?? s($0["480x480"]) ?? s($0["150x150"]) }
            return Track(id: "d" + id, title: title, artist: user, art: art,
                         url: "https://discoveryprovider.audius.co/v1/tracks/\(id)/stream?app_name=Plei")
        }
    }

    // MARK: Internet Archive
    static func archive(_ q: String) async throws -> [Track] {
        let query = enc("(\(q)) AND mediatype:audio")
        let j = try await json("https://archive.org/advancedsearch.php?output=json&rows=15&fl%5B%5D=identifier&fl%5B%5D=title&fl%5B%5D=creator&sort%5B%5D=downloads+desc&q=\(query)", timeout: 25)
        let docs = ((j as? [String: Any])?["response"] as? [String: Any])?["docs"] as? [[String: Any]] ?? []
        return docs.compactMap { d in
            guard let id = s(d["identifier"]) else { return nil }
            return Track(id: "a" + id, title: first(d["title"]) ?? id, artist: first(d["creator"]) ?? "Internet Archive",
                         art: "https://archive.org/services/img/\(id)", archive: id)
        }
    }

    static func archiveTracks(id: String, title: String, art: String?) async -> [Track] {
        guard let raw = try? await json("https://archive.org/metadata/\(id)") else { return [] }
        guard let j = raw as? [String: Any], let files = j["files"] as? [[String: Any]] else { return [] }
        var out: [Track] = []
        for f in files {
            guard let name = s(f["name"]), name.lowercased().hasSuffix(".mp3") else { continue }
            let path = name.split(separator: "/").map { enc(String($0)) }.joined(separator: "/")
            let t = first(f["title"]) ?? (name as NSString).deletingPathExtension
            out.append(Track(id: "a" + id + name, title: t, artist: title, art: art, url: "https://archive.org/download/\(id)/\(path)"))
            if out.count >= 60 { break }
        }
        return out
    }


}

@MainActor
final class SearchModel: ObservableObject {
    @Published var results: [Track] = []
    @Published var errors: [String] = []
    @Published var loading = false

    func run(_ q: String, key: String, enabledSources: Set<String>) async {
        YouTubeDiagnostics.record("search.all_sources.begin", details: "query=\(q), sources=\(enabledSources.sorted().joined(separator: ","))")
        results = []
        errors = []
        loading = true
        var parts: [String: [Track]] = [:]
        var errs: [String] = []
        await withTaskGroup(of: (String, [Track], String?).self) { g in
            if enabledSources.contains("YouTube") {
                g.addTask { await Sources.run("YouTube") { try await YouTubeEngine.search(q) } }
            }
            if enabledSources.contains("Jamendo") {
                if !key.isEmpty {
                    g.addTask { await Sources.run("Jamendo") { try await Sources.jamendo(q, key: key) } }
                } else {
                    errs.append("Нет ключа Jamendo (Настройки)")
                }
            }
            if enabledSources.contains("Audius") {
                g.addTask { await Sources.run("Audius") { try await Sources.audius(q) } }
            }
            if enabledSources.contains("Archive") {
                g.addTask { await Sources.run("Internet Archive") { try await Sources.archive(q) } }
            }
            for await r in g {
                parts[r.0] = r.1
                if let e = r.2 { errs.append("\(r.0): \(e)") }
            }
        }
        var all: [Track] = []
        for n in ["YouTube", "Jamendo", "Audius", "Internet Archive"] { all += parts[n] ?? [] }
        results = all
        errors = errs
        loading = false
        YouTubeDiagnostics.record("search.all_sources.complete", details: "total=\(all.count), youtube=\(parts["YouTube"]?.count ?? 0), errors=\(errs.joined(separator: " | "))")
    }
}
