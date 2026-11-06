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

    override func setUpWithError() throws {
        continueAfterFailure = true   // keep taking the other screenshots if one screen fails

        if let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty {
            outputFolder = URL(fileURLWithPath: dir, isDirectory: true)
        }

        app = XCUIApplication()
        // -demoData: sample content in memory only. The other arguments set the
        // name and settings for this run without changing what's saved.
        app.launchArguments += [
            "-demoData",
            "-hasSeenIntroPage", "YES",
            "-userName", "Alex",
            "-selectedCurrency", "EUR",
            "-selectedTheme", "Light",
        ]
    }

    @MainActor
    func testAppStoreScreenshots() throws {
        app.launch()
        XCTAssertTrue(app.staticTexts["To Do"].waitForExistence(timeout: 10))
        snap("1-Home")

        openRow("To Do")
        snap("2-ToDo")
        goBack()

        openRow("Daily Routine")
        let weekly = app.segmentedControls.buttons["Weekly"]
        if weekly.waitForExistence(timeout: 5) { weekly.tap() }
        sleep(1)
        snap("3-DailyRoutine-Weekly")
        goBack()

        openRow("Confidence")
        sleep(1)   // let the chart finish drawing
        snap("4-Confidence")
        goBack()

        openRow("Focus Test")
        sleep(1)
        snap("5-FocusTest")
        goBack()
    }

    // MARK: - Helpers

    private func openRow(_ title: String) {
        let row = app.staticTexts[title].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Row \(title) not found")
        row.tap()
        sleep(1)
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 3) { back.tap() }
        sleep(1)
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
