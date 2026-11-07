//
//  AppStoreScreenshots.swift
//  ToBeDoneUITests
//
//  Opens the main screens with sample data and saves App Store screenshots.
//  Run it with scripts/take-screenshots.sh (or ⌘U in Xcode; the images are
//  then attached to the test report).
//

import XCTest

final class AppStoreScreenshots: XCTestCase {
    private var app: XCUIApplication!
    private var outputFolder: URL?

    // -demoData: sample content in memory only. The other arguments set the
    // name and settings for this run without changing what's saved.
    private let baseArguments = [
        "-demoData",
        "-hasSeenIntroPage", "YES",
        "-userName", "Alex",
        "-selectedCurrency", "EUR",
        "-selectedTheme", "Light",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = true   // keep taking the other screenshots if one screen fails

        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            outputFolder = URL(fileURLWithPath: dir, isDirectory: true)
        }

        app = XCUIApplication()
    }

    @MainActor
    func testAppStoreScreenshots() throws {
        // Each screenshot starts the app with its own sample data ("-demoScene")
        launch("home")
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 10))
        snap("1-Home")

        launch("todo")
        openRow("To Do")
        snap("2-ToDo")

        launch("routine")
        openRow("Daily Routine")
        sleep(1)
        snap("3-DailyRoutine-Monthly")
        let weekly = app.segmentedControls.buttons["Weekly"]
        if weekly.waitForExistence(timeout: 5) { weekly.tap() }
        sleep(1)
        snap("4-DailyRoutine-Weekly")

        launch("monthly")
        openRow("Monthly Expenses")
        snap("5-MonthlyExpenses")

        launch("projects")
        openRow("Projects")
        snap("6-Projects")

        launch("grocery")
        openRow("Grocery")
        snap("7-Grocery")

        launch("confidence")
        openRow("Confidence")
        sleep(1)   // let the chart finish drawing
        snap("8-Confidence")

        launch("focus")
        openRow("Focus Test")
        sleep(1)
        snap("9-FocusTest")
    }

    /// (Re)starts the app with the sample data for one screenshot.
    private func launch(_ scene: String) {
        app.terminate()
        app.launchArguments = baseArguments + ["-demoScene", scene]
        app.launch()
        _ = app.staticTexts["Today"].waitForExistence(timeout: 10)
    }

    // MARK: - Helpers

    private func openRow(_ title: String) {
        let row = app.staticTexts[title].firstMatch
        // Home is longer now (today's items are listed at the top), so rows such as
        // Confidence and Focus Test can be below the screen: scroll until visible.
        scrollTo(row)
        XCTAssertTrue(row.exists, "Row \(title) not found")
        row.tap()
        sleep(1)
    }

    /// Swipes up (then back down) until `element` is on screen and can be tapped.
    private func scrollTo(_ element: XCUIElement) {
        if element.waitForExistence(timeout: 3), element.isHittable { return }
        for _ in 0..<6 {
            app.swipeUp()
            if element.exists && element.isHittable { return }
        }
        for _ in 0..<12 {
            app.swipeDown()
            if element.exists && element.isHittable { return }
        }
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()

        // Attached to the test report (visible in Xcode's Report navigator)
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // Saved as PNG files when run from the script
        if let folder = outputFolder {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? shot.pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
        }
    }
}
