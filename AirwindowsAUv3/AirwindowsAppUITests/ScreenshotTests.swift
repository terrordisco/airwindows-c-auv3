//
//  ScreenshotTests.swift
//  AirwindowsAppUITests
//
//  Not a test of behaviour — a screenshot robot. Walks the app's main
//  screens and attaches a full-screen capture of each, so App Store
//  screenshots can be produced headlessly on a simulator:
//
//      xcodebuild test … -only-testing:AirwindowsAppUITests/ScreenshotTests
//      xcrun xcresulttool export attachments --path <result>.xcresult --output-path <dir>
//
//  Pass SCREENSHOT_APPEARANCE=night (or day) in the test environment to
//  shoot the other theme; it is forwarded to the app as a launch argument
//  that seeds the `airwindows.appearance` default. The startup effect comes
//  from the App Group default `airwindows.defaultEffect`, which the caller
//  seeds with `simctl spawn … defaults write` before running.
//

import XCTest

final class ScreenshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = true
    }

    func testShootAppStoreScreens() {
        let app = XCUIApplication()
        let appearance = ProcessInfo.processInfo.environment["SCREENSHOT_APPEARANCE"] ?? "day"
        app.launchArguments += ["-airwindows.appearance", appearance]
        app.launch()

        // 1. Workspace (lands on the pinned default effect).
        let detail = app.descendants(matching: .any)["effectDetailView"]
        XCTAssertTrue(detail.waitForExistence(timeout: 30), "workspace should appear")
        sleep(1)
        shoot(app, "01-workspace-\(appearance)")

        // 2. Menu drawer.
        app.buttons["Menu"].firstMatch.tap()
        sleep(1)
        shoot(app, "02-menu-\(appearance)")
        app.buttons["Close menu"].firstMatch.tap()
        sleep(1)

        // 3. Browser. It opens where you were: the current effect's category
        //    list with that effect highlighted and its card raised.
        app.buttons["Browse effects"].firstMatch.tap()
        let readAbout = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Read about ")).firstMatch
        XCTAssertTrue(readAbout.waitForExistence(timeout: 10), "effects list with card should appear")
        sleep(1)
        shoot(app, "03-effects-card-\(appearance)")

        // 4. Description page.
        readAbout.tap()
        let backToList = app.buttons["Back to the list"].firstMatch
        XCTAssertTrue(backToList.waitForExistence(timeout: 10), "description page should appear")
        sleep(1)
        shoot(app, "04-description-\(appearance)")

        // 5. Back out to the categories page.
        backToList.tap()
        let backToCategories = app.buttons["Back to categories"].firstMatch
        XCTAssertTrue(backToCategories.waitForExistence(timeout: 10), "list should reappear")
        backToCategories.tap()
        let category = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ambience,")).firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 10), "categories should list Ambience")
        sleep(1)
        shoot(app, "05-categories-\(appearance)")

        // 6. Another category's list, no card.
        category.tap()
        let firstRow = app.descendants(matching: .any).matching(identifier: "effectRow").firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10), "effect list should appear")
        sleep(1)
        shoot(app, "06-effects-\(appearance)")
    }

    private func shoot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
