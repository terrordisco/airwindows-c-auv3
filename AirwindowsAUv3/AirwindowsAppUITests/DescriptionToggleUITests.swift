//
//  DescriptionToggleUITests.swift
//  AirwindowsAppUITests
//
//  The info button in the workspace's bottom bar shows or hides the effect's
//  text (tagline + description). The choice is stored in the App Group, so
//  it must survive a relaunch. This test flips it, relaunches, checks it
//  stuck, then puts it back the way it found it.
//

import XCTest

final class DescriptionToggleUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testDescriptionToggleHidesTextAndPersistsAcrossLaunches() {
        let app = XCUIApplication()
        app.launch()
        let toggle = landOnEffectPage(app)
        let original = toggle.value as? String ?? ""
        XCTAssertTrue(["Showing", "Hidden"].contains(original), "toggle should report its state, got '\(original)'")
        let flipped = original == "Showing" ? "Hidden" : "Showing"

        toggle.tap()
        XCTAssertEqual(toggle.value as? String, flipped, "tapping the info button should flip it")

        // The menu's "Show Effect Info" row is the same setting: it shows
        // the new state, and tapping it flips the bar's button back.
        app.buttons["Menu"].firstMatch.tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Show effect info")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the menu should have a Show Effect Info row")
        XCTAssertTrue(row.label.contains(flipped == "Showing" ? ", on" : ", off"), "menu row should mirror the info button, got '\(row.label)'")
        row.tap()
        app.buttons["Close menu"].firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, original, "the menu row should flip the info button")
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, flipped)

        // Relaunch: the choice is remembered.
        app.terminate()
        app.launch()
        let relaunched = landOnEffectPage(app)
        XCTAssertEqual(relaunched.value as? String, flipped, "the choice should survive a relaunch")

        // Leave the simulator as we found it.
        relaunched.tap()
        XCTAssertEqual(relaunched.value as? String, original)
    }

    /// Lands on an effect page (straight away if a default effect is set,
    /// otherwise via the browser — same path as FaderDragUITests) and
    /// returns the info button.
    private func landOnEffectPage(_ app: XCUIApplication) -> XCUIElement {
        let detail = app.descendants(matching: .any)["effectDetailView"]
        if !detail.waitForExistence(timeout: 15) {
            let allRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "All")).firstMatch
            XCTAssertTrue(allRow.waitForExistence(timeout: 30), "browser 'All' row should appear")
            allRow.tap()
            let firstRow = app.descendants(matching: .any).matching(identifier: "effectRow").firstMatch
            XCTAssertTrue(firstRow.waitForExistence(timeout: 15), "effect list should appear")
            firstRow.tap()
            let select = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Select ")).firstMatch
            if select.waitForExistence(timeout: 5) { select.tap() }
            XCTAssertTrue(detail.waitForExistence(timeout: 15), "effect page should appear")
        }
        // Found by label: the page-level `effectDetailView` identifier
        // propagates onto plain Buttons inside it and would shadow one set here.
        let toggle = app.buttons["Effect description"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 10), "the bottom bar should show the info button")
        return toggle
    }
}
