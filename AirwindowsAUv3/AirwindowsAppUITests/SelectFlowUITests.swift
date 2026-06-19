//
//  SelectFlowUITests.swift
//  AirwindowsAppUITests
//
//  Critical-path smoke test for the standalone host app. Exercises the one
//  flow a user cannot do without: open the browser, pick an effect, tap
//  Select, and land on that effect's page.
//
//  This exists because of a real regression: in build 6 the Select button
//  (and other chips) silently did nothing — an unlabeled trailing closure had
//  bound to the wrong Chip parameter, which compiles cleanly. A green build
//  said nothing; only a tap would reveal it. This test is that tap.
//

import XCTest

final class SelectFlowUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Browser → choose a category → Select the highlighted effect → the
    /// effect detail view appears. If Select is dead (build-6 bug), the detail
    /// view never shows and this fails.
    func testSelectingEffectLoadsTheEffect() {
        let app = XCUIApplication()
        app.launch()

        // Fresh launch opens the browser with nothing picked. Choosing a
        // category populates the effect list and auto-highlights the first
        // effect, so a Select button appears in the preview pane. The registry
        // (500+ C++ effects) populates on launch, so allow a generous wait.
        let allCategories = app.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] %@", "All categories"))
            .firstMatch
        XCTAssertTrue(
            allCategories.waitForExistence(timeout: 30),
            "The browser's 'All categories' row should appear on launch"
        )
        allCategories.tap()

        // The preview pane's primary CTA. Its accessibility label is
        // "Select <effect name>".
        let selectButton = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Select "))
            .firstMatch
        XCTAssertTrue(
            selectButton.waitForExistence(timeout: 15),
            "A Select button should appear once a category is chosen"
        )
        selectButton.tap()

        // The payoff: tapping Select must dismiss the browser and load the
        // effect. The detail view carries the `effectDetailView` identifier.
        let detailView = app.descendants(matching: .any)["effectDetailView"]
        XCTAssertTrue(
            detailView.waitForExistence(timeout: 15),
            "Tapping Select should load the effect and show its detail view"
        )
    }
}
