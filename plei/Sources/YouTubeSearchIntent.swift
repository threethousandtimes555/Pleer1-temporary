import Foundation

/// Keeps ordinary track searches separate from explicit playlist/Mix discovery.
enum YouTubeSearchIntent {
    static func includesCollections(for query: String) -> Bool {
        let normalized = query
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let words = normalized.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        let collectionTerms: Set<String> = ["playlist", "playlists", "плейлист", "плейлисты", "плейлистов", "mix", "микс", "миксы"]
        return words.contains { collectionTerms.contains($0) }
    }
}
