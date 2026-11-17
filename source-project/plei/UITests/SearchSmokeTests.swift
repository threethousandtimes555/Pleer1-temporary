import XCTest

final class SearchSmokeTests: XCTestCase {
    // Search by artist only. Do not depend on one specific video being returned:
    // YouTube search results can vary between runs and regions.
    private let searchQuery = "прыгай киска"

    func testSearchByArtistFindsAndStartsAnyTrack() {
        let app = XCUIApplication()
        app.launch()

        let selectedTrack = searchArtistAndPlayFirstIndividualTrack(in: app)

        let miniPlayer = app.descendants(matching: .any)["player.mini"]
        XCTAssertTrue(
            miniPlayer.waitForExistence(timeout: 30),
            "Mini-player did not appear after selecting the first individual track for artist '\(searchQuery)'"
        )

        print("PLEER1_SEARCH_QUERY=\(searchQuery)")
        print("PLEER1_SEARCH_SELECTED_TRACK=\(selectedTrack)")
        print("PLEER1_SEARCH_RESULT=track_started")
        
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Pleer1 artist search - first available track started"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testFirstArtistSearchResultCanSeek() {
        let app = XCUIApplication()
        app.launch()

        let selectedTrack = searchArtistAndPlayFirstIndividualTrack(in: app)

        let miniPlayer = app.descendants(matching: .any)["player.mini"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 30),
                      "Mini-player did not appear after selecting '\(selectedTrack)'")
        miniPlayer.tap()

        let seekBar = app.sliders["player.seekbar"]
        XCTAssertTrue(seekBar.waitForExistence(timeout: 30), "Full player seek bar did not appear")
        XCTAssertTrue(seekBar.isHittable)

        let durationLabel = app.staticTexts["player.duration"]
        XCTAssertTrue(durationLabel.waitForExistence(timeout: 30))
        let durationReady = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label != %@", "0:00"),
            object: durationLabel
        )
        XCTAssertEqual(XCTWaiter.wait(for: [durationReady], timeout: 90), .completed,
                       "YouTube duration was not resolved")

        let durationSeconds = seconds(from: durationLabel.label)
        XCTAssertGreaterThan(durationSeconds, 20, "Resolved track duration is implausibly short")

        let elapsedLabel = app.staticTexts["player.elapsed"]
        XCTAssertTrue(elapsedLabel.waitForExistence(timeout: 10))
        seekBar.adjust(toNormalizedSliderPosition: 0.5)

        let midpoint = durationSeconds / 2
        let movedToMidpoint = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                let current = self.seconds(from: elapsedLabel.label)
                return current >= midpoint - 3 && current <= midpoint + 8
            },
            object: elapsedLabel
        )
        XCTAssertEqual(XCTWaiter.wait(for: [movedToMidpoint], timeout: 10), .completed,
                       "Elapsed time did not move to the selected midpoint")

        let afterSeek = seconds(from: elapsedLabel.label)
        let playbackContinued = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                self.seconds(from: elapsedLabel.label) != afterSeek
            },
            object: elapsedLabel
        )
        XCTAssertEqual(XCTWaiter.wait(for: [playbackContinued], timeout: 8), .completed,
                       "Playback clock did not continue after seeking")

        let settled = seconds(from: elapsedLabel.label)
        XCTAssertGreaterThanOrEqual(settled, midpoint - 3,
                                    "Playback position returned to the beginning after seeking")

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Pleer1 first artist result seek at midpoint"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        print("PLEER1_SEEK_QUERY=\(searchQuery)")
        print("PLEER1_SEEK_TRACK=\(selectedTrack)")
        print("PLEER1_SEEK_DURATION=\(durationSeconds)")
        print("PLEER1_SEEK_MIDPOINT=\(midpoint)")
        print("PLEER1_SEEK_SETTLED=\(settled)")
        print("PLEER1_SEEK_RESULT=confirmed")
    }

    @discardableResult
    private func searchArtistAndPlayFirstIndividualTrack(in app: XCUIApplication) -> String {
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(
            searchField.waitForExistence(timeout: 20),
            "YouTube search field did not appear on the first tab"
        )
        XCTAssertTrue(searchField.isHittable, "Search field is present but not hittable")

        searchField.tap()
        searchField.typeText(searchQuery)
        searchField.typeText("\n")

        // Select any individual track returned for the artist; do not require
        // a hard-coded song title, and exclude playlist result rows.
        // Search only for a real YouTube video row. This both avoids
        // accidentally selecting Audius/Jamendo results and verifies the
        // YouTube provider independently of other sources.
        let firstTrack = app.buttons["search.result.youtube.track"].firstMatch
        XCTAssertTrue(
            firstTrack.waitForExistence(timeout: 90),
            "YouTube search '\(searchQuery)' returned no individual video row (other providers may still have results)"
        )
        XCTAssertTrue(firstTrack.isHittable, "First individual track result is not tappable")

        let selectedTrack = firstTrack.label
        firstTrack.tap()
        return selectedTrack
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
