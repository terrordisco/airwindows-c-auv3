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

    /// Browser → choose "All" → tap the first effect → Select → the effect
    /// detail view appears. If Select is dead (build-6 bug), the detail view
    /// never shows and this fails.
    ///
    /// Works in both layouts. Full: "All categories" sidebar row, the list
    /// auto-highlights its first effect, Select sits in the preview pane.
    /// Compact (the default since 2026-09-28): an "All, N effects" row in the
    /// browser drawer, tapping the first effect raises the preview card, and
    /// Select sits in that card.
    func testSelectingEffectLoadsTheEffect() {
        let app = XCUIApplication()
        app.launch()

        // Fresh launch opens the browser with nothing picked. The registry
        // (500+ C++ effects) populates on launch, so allow a generous wait.
        let allRow = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH[c] %@", "All"))
            .firstMatch
        XCTAssertTrue(
            allRow.waitForExistence(timeout: 30),
            "The browser's 'All' row should appear on launch"
        )
        allRow.tap()

        // First effect in the list. Both browsers tag rows `effectRow`. In
        // the compact browser this highlights it and raises the preview card;
        // in the full browser the first row is already highlighted, so the
        // tap selects it outright (and the Select step below is skipped).
        let firstRow = app.descendants(matching: .any)
            .matching(identifier: "effectRow")
            .firstMatch
        XCTAssertTrue(
            firstRow.waitForExistence(timeout: 15),
            "An effect list should appear once a category is chosen"
        )
        firstRow.tap()

        // The primary CTA. Its accessibility label is "Select <effect name>".
        let selectButton = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Select "))
            .firstMatch
        if selectButton.waitForExistence(timeout: 5) {
            selectButton.tap()
        }

        // The payoff: the browser must dismiss and the effect must load. The
        // detail view (full or compact) carries the `effectDetailView` identifier.
        let detailView = app.descendants(matching: .any)["effectDetailView"]
        XCTAssertTrue(
            detailView.waitForExistence(timeout: 15),
            "Selecting an effect should load it and show its detail view"
        )
    }
}
