import XCTest

final class SearchSmokeTests: XCTestCase {
    func testSearchFindsStandaloneYouTubeVideo() {
        let app = XCUIApplication()
        app.launch()

        let searchField = app.searchFields.firstMatch
        guard searchField.waitForExistence(timeout: 20), searchField.isHittable else {
            XCTFail("YouTube search field did not appear or is not hittable")
            return
        }

        let query = "Concrete"
        searchField.tap()
        searchField.typeText(query)
        searchField.typeText("\n")

        // Search for a known standalone song title. This identifier is assigned only
        // to ordinary YouTube video tracks, not Jamendo/Audius, playlists, or Mixes.
        let youtubeTrack = app.buttons.matching(identifier: "search.result.youtube.track").matching(
            NSPredicate(format: "label CONTAINS[cd] %@", query)
        ).firstMatch

        guard youtubeTrack.waitForExistence(timeout: 90) else {
            XCTFail("No standalone YouTube video result for query: \(query)")
            print("PLEER1_YOUTUBE_ONLY_QUERY=\(query)")
            print("PLEER1_YOUTUBE_ONLY_DIAGNOSTIC_BEGIN")
            print(app.debugDescription)
            print("PLEER1_YOUTUBE_ONLY_DIAGNOSTIC_END")
            return
        }

        XCTAssertTrue(youtubeTrack.label.localizedCaseInsensitiveContains("YouTube"),
                      "Matched row is not labelled as a YouTube result: \(youtubeTrack.label)")
        print("PLEER1_YOUTUBE_ONLY_QUERY=\(query)")
        print("PLEER1_YOUTUBE_ONLY_MATCH=\(youtubeTrack.label)")
        print("PLEER1_YOUTUBE_ONLY_RESULT=confirmed")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Pleer1 standalone YouTube search result"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    // Skip the first search result (Mix – Crystal Castles): a Mix selection leaves the search-results list in the queue.
    // Select the ordinary playlist "Crystal Castles PLAYLIST"; its second track is "Concrete".
    private let searchQuery = "crystal castles playlist"
    private let expectedPlaylistTitle = "Crystal Castles PLAYLIST"
    private let expectedSecondTrackTitle = "Concrete"

    func testYouTubePlaylistSecondTrackPlaybackAndSeek() {
        let app = XCUIApplication()
        app.launch()

        let selectedPlaylist = searchAndOpenExpectedPlaylist(in: app)

        let miniPlayer = app.descendants(matching: .any)["player.mini"]
        guard miniPlayer.waitForExistence(timeout: 90) else {
            XCTFail("Mini-player did not appear after selecting playlist: \(selectedPlaylist)")
            print("PLEER1_AFTER_PLAYLIST_SELECTION_DIAGNOSTIC_BEGIN")
            print(app.debugDescription)
            print("PLEER1_AFTER_PLAYLIST_SELECTION_DIAGNOSTIC_END")
            return
        }
        miniPlayer.tap()

        let queueButton = app.buttons["player.queue.open"]
        guard queueButton.waitForExistence(timeout: 30), queueButton.isHittable else {
            XCTFail("Player queue button did not appear")
            print(app.debugDescription)
            return
        }
        queueButton.tap()

        // After selecting the ordinary playlist (not the Mix search result), wait for its actual track list.
        // The second row must be the known second track, Concrete.
        let secondQueueTrack = app.buttons["player.queue.track.1"]
        guard secondQueueTrack.waitForExistence(timeout: 120) else {
            XCTFail("Playlist contents did not load: no second track appeared in the queue for \(selectedPlaylist)")
            print("PLEER1_PLAYLIST_QUEUE_DIAGNOSTIC_BEGIN")
            print(app.debugDescription)
            print("PLEER1_PLAYLIST_QUEUE_DIAGNOSTIC_END")
            return
        }

        // Read the row's own accessibility label. staticTexts.firstMatch can resolve
        // an unrelated search-result label in this SwiftUI sheet.
        let secondQueueRowLabel = secondQueueTrack.label
        guard secondQueueRowLabel.localizedCaseInsensitiveContains(expectedSecondTrackTitle) else {
            XCTFail("Wrong playlist or wrong second track. Expected '\(expectedSecondTrackTitle)', got queue row: '\(secondQueueRowLabel)'")
            print("PLEER1_EXPECTED_PLAYLIST=\(expectedPlaylistTitle)")
            print("PLEER1_ACTUAL_PLAYLIST=\(selectedPlaylist)")
            print("PLEER1_SECOND_QUEUE_ROW=\(secondQueueRowLabel)")
            print("PLEER1_PLAYLIST_QUEUE_DIAGNOSTIC_BEGIN")
            print(app.debugDescription)
            print("PLEER1_PLAYLIST_QUEUE_DIAGNOSTIC_END")
            return
        }
        print("PLEER1_PLAYLIST_SELECTED=\(selectedPlaylist)")
        print("PLEER1_PLAYLIST_SECOND_TRACK=\(secondQueueRowLabel)")
        secondQueueTrack.tap()

        // The queue is presented as a sheet; dismiss it to inspect the player.
        app.swipeDown()

        let currentTitle = app.staticTexts["player.track.title"]
        let selectedTitle = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS[cd] %@", expectedSecondTrackTitle),
            object: currentTitle
        )
        guard XCTWaiter.wait(for: [selectedTitle], timeout: 20) == .completed else {
            XCTFail("Player did not switch to the expected second playlist track: \(expectedSecondTrackTitle)")
            print("PLEER1_SECOND_TRACK_SELECTION_DIAGNOSTIC_BEGIN")
            print(app.debugDescription)
            print("PLEER1_SECOND_TRACK_SELECTION_DIAGNOSTIC_END")
            return
        }

        let durationLabel = app.staticTexts["player.duration"]
        guard durationLabel.waitForExistence(timeout: 30) else {
            XCTFail("Player duration label did not appear for second playlist track")
            return
        }

        let durationReady = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", "0:00"),
            object: durationLabel
        )
        guard XCTWaiter.wait(for: [durationReady], timeout: 120) == .completed else {
            XCTFail("Second playlist track duration stayed at 0:00: \(expectedSecondTrackTitle)")
            print("PLEER1_SECOND_TRACK_DURATION_DIAGNOSTIC_BEGIN")
            print(app.debugDescription)
            print("PLEER1_SECOND_TRACK_DURATION_DIAGNOSTIC_END")
            return
        }

        let durationSeconds = seconds(from: durationLabel.label)
        guard durationSeconds > 20 else {
            XCTFail("Resolved second-track duration is implausibly short: \(durationLabel.label)")
            return
        }

        let seekBar = app.sliders["player.seekbar"]
        guard seekBar.waitForExistence(timeout: 30), seekBar.isHittable else {
            XCTFail("Full player seek bar did not appear or is not hittable")
            return
        }
        let elapsedLabel = app.staticTexts["player.elapsed"]
        guard elapsedLabel.waitForExistence(timeout: 10) else {
            XCTFail("Elapsed-time label did not appear")
            return
        }

        seekBar.adjust(toNormalizedSliderPosition: 0.5)
        let midpoint = durationSeconds / 2
        let movedToMidpoint = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                let current = self.seconds(from: elapsedLabel.label)
                return current >= midpoint - 3 && current <= midpoint + 8
            },
            object: elapsedLabel
        )
        guard XCTWaiter.wait(for: [movedToMidpoint], timeout: 20) == .completed else {
            XCTFail("Second playlist track did not seek to its midpoint")
            return
        }

        let afterSeek = seconds(from: elapsedLabel.label)
        let playbackContinued = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                self.seconds(from: elapsedLabel.label) != afterSeek
            },
            object: elapsedLabel
        )
        guard XCTWaiter.wait(for: [playbackContinued], timeout: 10) == .completed else {
            XCTFail("Second playlist track playback clock did not continue after seeking")
            return
        }

        let settled = seconds(from: elapsedLabel.label)
        XCTAssertGreaterThanOrEqual(settled, midpoint - 3,
                                    "Playback position returned to the beginning after seeking")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Pleer1 Crystal Castles playlist second track playback and seek"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        print("PLEER1_SEARCH_QUERY=\(searchQuery)")
        print("PLEER1_PLAYLIST=\(selectedPlaylist)")
        print("PLEER1_SECOND_TRACK=\(expectedSecondTrackTitle)")
        print("PLEER1_SEEK_DURATION=\(durationSeconds)")
        print("PLEER1_SEEK_MIDPOINT=\(midpoint)")
        print("PLEER1_SEEK_SETTLED=\(settled)")
        print("PLEER1_PLAYLIST_SECOND_TRACK_PLAYBACK_SEEK_RESULT=confirmed")
    }

    private func searchAndOpenExpectedPlaylist(in app: XCUIApplication) -> String {
        let searchField = app.searchFields.firstMatch
        guard searchField.waitForExistence(timeout: 20), searchField.isHittable else {
            XCTFail("YouTube search field did not appear or is not hittable")
            return ""
        }

        searchField.tap()
        searchField.typeText(searchQuery)
        searchField.typeText("\n")

        // A Mix is also labelled YouTube-плейлист, but selecting it leaves search results in the queue.
        // Match the ordinary playlist by its exact title instead of selecting the first playlist-typed result.
        let expectedResult = app.buttons.matching(identifier: "search.result.track").matching(
            NSPredicate(format: "label CONTAINS %@", expectedPlaylistTitle)
        ).firstMatch
        guard expectedResult.waitForExistence(timeout: 90) else {
            XCTFail("Search '\(searchQuery)' did not return the expected playlist '\(expectedPlaylistTitle)'")
            print("PLEER1_SEARCH_DIAGNOSTIC_BEGIN")
            print(app.debugDescription)
            print("PLEER1_SEARCH_DIAGNOSTIC_END")
            return ""
        }

        guard expectedResult.isHittable else {
            XCTFail("Expected YouTube playlist result is not tappable: \(expectedResult.label)")
            return expectedResult.label
        }

        print("PLEER1_SEARCH_SELECTED_PLAYLIST=\(expectedResult.label)")
        expectedResult.tap()
        return expectedResult.label
    }

    private func seconds(from timestamp: String) -> Int {
        let parts = timestamp.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 2: return parts[0] * 60 + parts[1]
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        default: return 0
        }
    }
}
