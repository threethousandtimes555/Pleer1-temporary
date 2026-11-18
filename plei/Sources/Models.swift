import Foundation

struct Track: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var artist: String
    var art: String? = nil
    var url: String? = nil
    var file: String? = nil
    var archive: String? = nil
    var added: Double = 0
    var artFile: String? = nil
    var youtubePlaylistID: String? = nil
    var youtubeRadioID: String? = nil
    var youtubeRadioVideoID: String? = nil

    var isLocal: Bool { return file != nil }

    var tag: String {
        switch id.first {
        case "j": return "Jamendo"
        case "d": return "Audius"
        case "a": return "Archive"
        case "c": return "ccMixter"
        case "f": return "Funkwhale"
        case "l": return "Файл"
        case "y": return "YouTube"
        default: return ""
        }
    }
}

struct FileMeta: Codable {
    var title: String? = nil
    var artist: String? = nil
    var art: String? = nil
}

struct Playlist: Codable, Identifiable {
    var id = UUID()
    var name: String
    var tracks: [Track] = []
}

func fmt(_ s: Double) -> String {
    guard s.isFinite, s > 0 else { return "0:00" }
    let i = Int(s)
    return String(format: "%d:%02d", i / 60, i % 60)
}
