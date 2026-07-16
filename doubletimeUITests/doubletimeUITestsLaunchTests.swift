//
//  doubletimeUITestsLaunchTests.swift
//  doubletimeUITests
//

import XCTest

final class doubletimeUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Regression: a degenerate invisible settings-opener window used to
        // trip AppKit's update-constraints loop guard (NSGenericException →
        // SIGTRAP) within ~1s of launch. Ensure the app survives past that.
        sleep(3)
        XCTAssertNotEqual(app.state, .notRunning, "app crashed shortly after launch")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
