import XCTest

final class SearchSmokeTests: XCTestCase {
    func testSearchCompletesAndReportsVisibleResults() {
        let app = XCUIApplication()
        app.launch()

        let searchField = app.searchFields.firstMatch
        if !searchField.waitForExistence(timeout: 5) {
            let searchButton = app.buttons["Search"]
            if searchButton.exists { searchButton.tap() }
        }
        XCTAssertTrue(searchField.waitForExistence(timeout: 15), "Search field did not appear")

        searchField.tap()
        searchField.typeText("Daft Punk")
        searchField.typeText("\n")

        let jamendoCompletion = app.staticTexts["Нет ключа Jamendo (Настройки)"]
        XCTAssertTrue(
            jamendoCompletion.waitForExistence(timeout: 90),
            "Search did not reach SearchModel completion within 90 seconds"
        )

        let visibleRows = app.cells.count
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Pleer1 search results — Daft Punk"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        print("SEARCH_SMOKE_QUERY=Daft Punk")
        print("SEARCH_SMOKE_VISIBLE_CELLS=\(visibleRows)")
        print("SEARCH_SMOKE_COMPLETION=confirmed")
    }
}
