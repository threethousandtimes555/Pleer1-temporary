import Foundation

@main
struct SearchLogicHarness {
    static func main() {
        testSearchIntent()
        testInnerTubeParser()
        testHTMLParser()
        testDirectPlaylistURLs()
        testMixClassification()
        print("SEARCH_LOGIC_HARNESS: PASS (5 groups)")
    }

    private static func testSearchIntent() {
        expect(!YouTubeSearchIntent.includesCollections(for: "Concrete"), "Concrete must be a track search")
        expect(!YouTubeSearchIntent.includesCollections(for: "Kunteynir"), "Kunteynir must be a track search")
        expect(!YouTubeSearchIntent.includesCollections(for: "12 шагов до рая"), "Russian song query must be a track search")
        expect(YouTubeSearchIntent.includesCollections(for: "crystal castles playlist"), "English playlist keyword must enable collections")
        expect(YouTubeSearchIntent.includesCollections(for: "Crystal Castles плейлист"), "Russian playlist keyword must enable collections")
        expect(YouTubeSearchIntent.includesCollections(for: "YouTube миксы"), "Russian Mix keyword must enable collections")
    }

    private static func testInnerTubeParser() {
        let payload = fixture()
        let tracksOnly = YouTubeEngine.tracks(from: payload, includeCollections: false)
        expect(tracksOnly.map(\.id) == ["yvideo123"], "InnerTube ordinary mode must preserve the video and exclude collections")
        expect(tracksOnly.first?.youtubePlaylistID == nil, "Track result must not be a playlist")
        expect(tracksOnly.first?.youtubeRadioID == nil, "Track result must not be a Mix")

        let collections = YouTubeEngine.tracks(from: payload, includeCollections: true)
        expect(collections.count == 3, "InnerTube collection mode must return video + playlist + Mix")
        expect(collections.filter { $0.youtubePlaylistID != nil }.count == 1, "Exactly one ordinary playlist expected")
        expect(collections.filter { $0.youtubeRadioID != nil }.count == 1, "Exactly one Mix expected")
    }

    private static func testHTMLParser() {
        let payload = fixture()
        let tracksOnly = YouTubeHTMLSearch.tracks(from: payload, includeCollections: false, searchID: "macos-harness")
        expect(tracksOnly.map(\.id) == ["yvideo123"], "HTML ordinary mode must preserve the video and exclude collections")
        let collections = YouTubeHTMLSearch.tracks(from: payload, includeCollections: true, searchID: "macos-harness")
        expect(collections.count == 3, "HTML collection mode must return video + playlist + Mix")
    }

    private static func testDirectPlaylistURLs() {
        let playlist = YouTubePlaylistEngine.playlistTrack(from: "https://www.youtube.com/playlist?list=PLordinary123")
        expect(playlist?.youtubePlaylistID == "PLordinary123", "Direct playlist URL must remain recognized")
        let mix = YouTubePlaylistEngine.playlistTrack(from: "https://www.youtube.com/watch?v=seedVideo123&list=RDmix123")
        expect(mix?.youtubeRadioID == "RDmix123", "Direct Mix URL must remain recognized")
        expect(mix?.youtubeRadioVideoID == "seedVideo123", "Direct Mix URL must retain its seed video")
    }

    private static func testMixClassification() {
        let ordinaryPayload: [String: Any] = [
            "playlistRenderer": [
                "playlistId": "PLordinary123",
                "title": ["simpleText": "Ordinary playlist"]
            ]
        ]
        let ordinary = YouTubePlaylistEngine.playlistTracks(from: ordinaryPayload)
        expect(ordinary.count == 1 && ordinary.first?.youtubePlaylistID == "PLordinary123", "Ordinary playlist renderer must remain a playlist")
        expect(ordinary.first?.youtubeRadioID == nil, "Ordinary playlist must not become a Mix")

        let mixPayload: [String: Any] = [
            "playlistRenderer": [
                "playlistId": "RDmix123",
                "title": ["simpleText": "YouTube Mix"],
                "navigationEndpoint": ["watchEndpoint": ["videoId": "seedVideo123"]]
            ]
        ]
        let incorrectlyClassified = YouTubePlaylistEngine.playlistTracks(from: mixPayload)
        let mixes = YouTubePlaylistEngine.radioTracks(from: mixPayload)
        expect(incorrectlyClassified.isEmpty, "RD Mix must never be emitted as an ordinary playlist")
        expect(mixes.count == 1, "RD playlistRenderer with seed video must be recognized as a Mix")
        expect(mixes.first?.youtubeRadioID == "RDmix123", "Mix ID must be preserved")
        expect(mixes.first?.youtubeRadioVideoID == "seedVideo123", "Mix seed video must be preserved")
        expect(mixes.first?.youtubePlaylistID == nil, "Mix must not carry an ordinary playlist ID")
    }

    private static func fixture() -> [String: Any] {
        [
            "videoRenderer": ["videoId": "video123", "title": ["simpleText": "Concrete"]],
            "playlistRenderer": ["playlistId": "PLordinary123", "title": ["simpleText": "Ordinary playlist"]],
            "radioRenderer": [
                "playlistId": "RDmix123",
                "title": ["simpleText": "YouTube Mix"],
                "navigationEndpoint": ["watchEndpoint": ["videoId": "seedVideo123"]]
            ]
        ]
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fatalError("SEARCH_LOGIC_HARNESS: FAIL — \(message)")
        }
    }
}
