import XCTest

final class SearchSmokeTests: XCTestCase {
    func testSearchFindsPrygaiKiska() {
        let app = XCUIApplication()
        app.launch()

        let searchField = app.searchFields.firstMatch
        if !searchField.waitForExistence(timeout: 5) {
            let searchButton = app.buttons["Search"]
            if searchButton.exists { searchButton.tap() }
        }
        XCTAssertTrue(searchField.waitForExistence(timeout: 15), "Search field did not appear")

        let query = "Прыгай киска"
        searchField.tap()
        searchField.typeText(query)
        searchField.typeText("\n")

        let expectedTrack = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[cd] %@", query)
        ).firstMatch

        XCTAssertTrue(
            expectedTrack.waitForExistence(timeout: 90),
            "Search completed without showing a result containing: \(query)"
        )

        let visibleRows = app.cells.count
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Pleer1 search results — Прыгай киска"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        print("SEARCH_SMOKE_QUERY=\(query)")
        print("SEARCH_SMOKE_MATCH=\(expectedTrack.label)")
        print("SEARCH_SMOKE_VISIBLE_CELLS=\(visibleRows)")
        print("SEARCH_SMOKE_RESULT=confirmed")
    }
}
