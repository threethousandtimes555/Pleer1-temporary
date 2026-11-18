import XCTest
@testable import Plei

final class SearchSmokeTests: XCTestCase {
    func testSearchIntentSeparatesTrackSearchFromCollectionSearch() {
        XCTAssertFalse(YouTubeSearchIntent.includesCollections(for: "Concrete"))
        XCTAssertFalse(YouTubeSearchIntent.includesCollections(for: "Kunteynir"))
        XCTAssertFalse(YouTubeSearchIntent.includesCollections(for: "12 шагов до рая"))
        XCTAssertTrue(YouTubeSearchIntent.includesCollections(for: "crystal castles playlist"))
        XCTAssertTrue(YouTubeSearchIntent.includesCollections(for: "Crystal Castles плейлист"))
        XCTAssertTrue(YouTubeSearchIntent.includesCollections(for: "YouTube миксы"))
    }

    func testSearchParserDoesNotLeakPlaylistsOrMixesIntoTrackMode() {
        let payload: [String: Any] = [
            "videoRenderer": ["videoId": "video123", "title": ["simpleText": "Concrete"]],
            "playlistRenderer": ["playlistId": "PLordinary123", "title": ["simpleText": "Ordinary playlist"]],
            "radioRenderer": [
                "playlistId": "RDmix123",
                "title": ["simpleText": "YouTube Mix"],
                "navigationEndpoint": ["watchEndpoint": ["videoId": "seedVideo123"]]
            ]
        ]
        let tracksOnly = YouTubeEngine.tracks(from: payload, includeCollections: false)
        XCTAssertEqual(tracksOnly.map(\.id), ["yvideo123"])
        XCTAssertNil(tracksOnly.first?.youtubePlaylistID)
        XCTAssertNil(tracksOnly.first?.youtubeRadioID)

        let collections = YouTubeEngine.tracks(from: payload, includeCollections: true)
        XCTAssertEqual(collections.count, 3)
        XCTAssertEqual(collections.filter { $0.youtubePlaylistID != nil }.count, 1)
        XCTAssertEqual(collections.filter { $0.youtubeRadioID != nil }.count, 1)
    }

    func testDirectPlaylistAndMixURLsRemainRecognized() {
        let playlist = YouTubePlaylistEngine.playlistTrack(from: "https://www.youtube.com/playlist?list=PLordinary123")
        XCTAssertEqual(playlist?.youtubePlaylistID, "PLordinary123")
        let mix = YouTubePlaylistEngine.playlistTrack(from: "https://www.youtube.com/watch?v=seedVideo123&list=RDmix123")
        XCTAssertEqual(mix?.youtubeRadioID, "RDmix123")
        XCTAssertEqual(mix?.youtubeRadioVideoID, "seedVideo123")
    }

    func testYouTubeMixRendererIsNotClassifiedAsOrdinaryPlaylist() {
        let ordinaryPlaylistPayload: [String: Any] = [
            "playlistRenderer": [
                "playlistId": "PLordinary123",
                "title": ["simpleText": "Ordinary playlist"]
            ]
        ]
        let ordinary = YouTubePlaylistEngine.playlistTracks(from: ordinaryPlaylistPayload)
        XCTAssertEqual(ordinary.count, 1)
        XCTAssertEqual(ordinary.first?.youtubePlaylistID, "PLordinary123")
        XCTAssertNil(ordinary.first?.youtubeRadioID)

        let mixPayload: [String: Any] = [
            "playlistRenderer": [
                "playlistId": "RDmix123",
                "title": ["simpleText": "YouTube Mix"],
                "navigationEndpoint": [
                    "watchEndpoint": ["videoId": "seedVideo123"]
                ]
            ]
        ]
        let incorrectlyClassified = YouTubePlaylistEngine.playlistTracks(from: mixPayload)
        let mixes = YouTubePlaylistEngine.radioTracks(from: mixPayload)

        XCTAssertTrue(incorrectlyClassified.isEmpty,
                      "An RD Mix must never be emitted as an ordinary playlist")
        XCTAssertEqual(mixes.count, 1,
                       "An RD playlistRenderer with a seed video must be recognized as a Mix")
        XCTAssertEqual(mixes.first?.youtubeRadioID, "RDmix123")
        XCTAssertEqual(mixes.first?.youtubeRadioVideoID, "seedVideo123")
        XCTAssertNil(mixes.first?.youtubePlaylistID)
    }
}
