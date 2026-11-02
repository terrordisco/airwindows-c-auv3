//
//  FaderDragUITests.swift
//  AirwindowsAppUITests
//
//  Regression test for the iOS 17 dead-controls bug (2026-11-02). Several
//  controls carried a `.simultaneousGesture(…, including: .none)` meant to
//  switch an *added* gesture off. `GestureMask.none` disables every gesture
//  in the subtree, the control's own included; iOS 18+ let Buttons and
//  Sliders through anyway, iOS 17 honoured it literally — faders would not
//  drag and the Menu button did nothing on iOS 17.7 devices, while every
//  dev device on 18/26 looked fine. A green build says nothing here; only a
//  drag does. This test is that drag.
//

import XCTest

final class FaderDragUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Land on an effect page (straight away if a default effect is set,
    /// otherwise via the browser), then drag the first fader and expect its
    /// value to change.
    func testFaderRespondsToDrag() {
        let app = XCUIApplication()
        app.launch()

        let detail = app.descendants(matching: .any)["effectDetailView"]
        if !detail.waitForExistence(timeout: 15) {
            // No default effect: pick one. Same path as SelectFlowUITests.
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

        // The fader is a custom control (LinearFader), exposed with the
        // identifier `parameterFader` and its readout as the value.
        let fader = app.descendants(matching: .any).matching(identifier: "parameterFader").firstMatch
        XCTAssertTrue(fader.waitForExistence(timeout: 10), "the effect page should show at least one fader")
        let before = fader.value as? String ?? ""

        // Relative drag from the middle towards the right end; a working
        // fader lands on a new value.
        let start = fader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = fader.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
        sleep(1)
        let after = fader.value as? String ?? ""
        XCTAssertNotEqual(before, after, "dragging the fader should change its value (was \(before), still \(after))")

        // And the Menu button must open the drawer (same bug, other symptom).
        app.buttons["Menu"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Close menu"].firstMatch.waitForExistence(timeout: 5), "Menu button should open the drawer")
    }
}
