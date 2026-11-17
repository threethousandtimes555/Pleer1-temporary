import Foundation
import SwiftUI
import UIKit

enum Paths {
    static let music: URL = make(.documentDirectory, "Music")
    static let art: URL = make(.applicationSupportDirectory, "Art")
    static let cache: URL = make(.cachesDirectory, "Audio")

    private static func make(_ dir: FileManager.SearchPathDirectory, _ name: String) -> URL {
        let d = FileManager.default.urls(for: dir, in: .userDomainMask)[0].appendingPathComponent(name)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
}

final class ImageStore: @unchecked Sendable {
    static let shared = ImageStore()
    private let cache = NSCache<NSString, UIImage>()

    func image(url: String) async -> UIImage? {
        if let c = cache.object(forKey: url as NSString) { return c }
        guard let u = URL(string: url) else { return nil }
        var req = URLRequest(url: u)
        req.cachePolicy = .returnCacheDataElseLoad
        req.timeoutInterval = 15
        guard let r = try? await URLSession.shared.data(for: req), let img = UIImage(data: r.0) else { return nil }
        cache.setObject(img, forKey: url as NSString)
        return img
    }

    func local(_ name: String) -> UIImage? {
        if let c = cache.object(forKey: name as NSString) { return c }
        guard let img = UIImage(contentsOfFile: Paths.art.appendingPathComponent(name).path) else { return nil }
        cache.setObject(img, forKey: name as NSString)
        return img
    }
}

final class AudioCache: @unchecked Sendable {
    static let shared = AudioCache()

    private func key(_ t: Track) -> String {
        var h: UInt64 = 5381
        for b in t.id.utf8 { h = (h &* 33) &+ UInt64(b) }
        return String(h, radix: 16)
    }

    func lookup(_ t: Track) -> URL? {
        let k = key(t) + "."
        let names = (try? FileManager.default.contentsOfDirectory(atPath: Paths.cache.path)) ?? []
        if let n = names.first(where: { $0.hasPrefix(k) }) { return Paths.cache.appendingPathComponent(n) }
        return nil
    }

    func download(_ t: Track) async throws -> URL {
        if let ex = lookup(t) { return ex }
        guard let s = t.url, let u = URL(string: s) else {
            throw NSError(domain: "cache", code: 1, userInfo: [NSLocalizedDescriptionKey: "нет адреса трека"])
        }
        var req = URLRequest(url: u)
        req.timeoutInterval = 40
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) Plei/0.2", forHTTPHeaderField: "User-Agent")
        let (tmp, resp) = try await URLSession.shared.download(for: req)
        if let h = resp as? HTTPURLResponse, h.statusCode >= 400 {
            throw NSError(domain: "cache", code: h.statusCode, userInfo: [NSLocalizedDescriptionKey: "сервер ответил \(h.statusCode)"])
        }
        let mime = (resp.mimeType ?? "").lowercased()
        var ext = "mp3"
        if mime.contains("mp4") || mime.contains("m4a") || mime.contains("aac") { ext = "m4a" }
        else if mime.contains("wav") { ext = "wav" }
        else if mime.contains("flac") { ext = "flac" }
        else if mime.contains("ogg") || mime.contains("opus") { ext = "ogg" }
        let dest = Paths.cache.appendingPathComponent(key(t) + "." + ext)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmp, to: dest)
        return dest
    }

    func trim() {
        let fm = FileManager.default
        let names = (try? fm.contentsOfDirectory(atPath: Paths.cache.path)) ?? []
        var items: [(String, Date)] = []
        for n in names {
            let p = Paths.cache.appendingPathComponent(n).path
            let d = ((try? fm.attributesOfItem(atPath: p))?[.modificationDate] as? Date) ?? Date.distantPast
            items.append((n, d))
        }
        items.sort { $0.1 > $1.1 }
        for it in items.dropFirst(40) {
            try? fm.removeItem(at: Paths.cache.appendingPathComponent(it.0))
        }
    }
}

struct ArtView: View {
    let track: Track?
    @State private var img: UIImage? = nil

    var body: some View {
        Color.gray.opacity(0.18)
            .overlay {
                if let i = img {
                    Image(uiImage: i).resizable().scaledToFill()
                } else {
                    Image(systemName: "music.note").foregroundColor(.secondary)
                }
            }
            .clipped()
        .task(id: track?.id ?? "") {
            img = await loadImage()
        }
    }

    private func loadImage() async -> UIImage? {
        guard let t = track else { return nil }
        if let f = t.artFile { return ImageStore.shared.local(f) }
        if let a = t.art { return await ImageStore.shared.image(url: a) }
        return nil
    }
}

struct Cover: View {
    let track: Track?
    let size: CGFloat

    var body: some View {
        ArtView(track: track)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
    }
}
