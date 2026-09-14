import XCTest

final class SuperTrekUITests: XCTestCase {
    private func launch(fixture: String = "battle") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-autoFixture", fixture]
        app.launch()
        return app
    }

    private func logContains(_ app: XCUIApplication, _ text: String, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return app.staticTexts.matching(predicate).firstMatch.waitForExistence(timeout: timeout)
    }

    func testNavigationPanelEngages() {
        let app = launch()
        app.buttons["command.NAV"].tap()
        XCTAssertTrue(app.buttons["nav.engage"].waitForExistence(timeout: 3))
        app.buttons["nav.engage"].tap()
        XCTAssertTrue(logContains(app, "> NAV 1 1"))
        // The fixture's star at 4,7 stops a warp 1 run east.
        XCTAssertTrue(logContains(app, "WARP ENGINES SHUT DOWN"))
        XCTAssertTrue(app.buttons["command.NAV"].waitForExistence(timeout: 3), "panel should return to commands")
    }

    func testTapEmptySectorPlotsCourse() {
        let app = launch()
        app.buttons["sector.4.6"].tap()
        XCTAssertTrue(app.buttons["nav.engage"].waitForExistence(timeout: 3))
        app.buttons["nav.engage"].tap()
        XCTAssertTrue(logContains(app, "> NAV 1 0.25"))
        XCTAssertTrue(logContains(app, "SCANNING QUADRANT 4 , 4"))
        let sector = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "4 , 6")).firstMatch
        XCTAssertTrue(sector.waitForExistence(timeout: 3), "readout shows the new sector")
    }

    func testTapEnemyAimsAndFiresTorpedo() {
        let app = launch()
        app.buttons["sector.2.6"].tap()
        XCTAssertTrue(app.buttons["torpedo.fire"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["2.00"].exists, "course to (2,6) from (4,4) is 2")
        app.buttons["torpedo.fire"].tap()
        XCTAssertTrue(logContains(app, "> TOR 2"))
        XCTAssertTrue(logContains(app, "*** INVADER WARBIRD DESTROYED ***"))
    }

    func testShieldsPanelSets() {
        let app = launch()
        app.buttons["command.SHE"].tap()
        XCTAssertTrue(app.buttons["energy.commit"].waitForExistence(timeout: 3))
        app.buttons["1000"].tap()
        app.buttons["energy.commit"].tap()
        XCTAssertTrue(logContains(app, "> SHE 1000"))
        XCTAssertTrue(logContains(app, "SHIELDS NOW AT 1000 UNITS"))
    }

    func testBeamsPanelFires() {
        let app = launch()
        app.buttons["command.LAS"].tap()
        XCTAssertTrue(app.buttons["energy.commit"].waitForExistence(timeout: 3))
        app.buttons["500"].tap()
        app.buttons["energy.commit"].tap()
        XCTAssertTrue(logContains(app, "> LAS 500"))
        XCTAssertTrue(logContains(app, "UNIT HIT ON INVADER"))
    }

    func testLongRangeScanOverlayDismisses() {
        let app = launch()
        app.buttons["command.LRS"].tap()
        let overlay = app.otherElements["lrs.overlay"]
        XCTAssertTrue(overlay.waitForExistence(timeout: 3))
        overlay.tap()
        XCTAssertFalse(overlay.waitForExistence(timeout: 1))
    }

    func testComputerChartPlotsCourse() {
        let app = launch()
        app.buttons["command.COM"].tap()
        XCTAssertTrue(app.buttons["chart.6.7"].waitForExistence(timeout: 3))
        app.buttons["chart.6.7"].tap()
        XCTAssertTrue(app.buttons["nav.engage"].waitForExistence(timeout: 3))
        app.buttons["nav.engage"].tap()
        XCTAssertTrue(logContains(app, "NOW ENTERING REGULUS III QUADRANT"))
    }

    func testComputerHelpOpens() {
        let app = launch()
        app.buttons["command.COM"].tap()
        XCTAssertTrue(app.buttons["computer.help"].waitForExistence(timeout: 3))
        app.buttons["computer.help"].tap()
        XCTAssertTrue(app.staticTexts["SENSOR LEGEND"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["STRATEGY"].exists || app.staticTexts["COMMANDS"].exists)
        app.buttons["help.back"].tap()
        XCTAssertTrue(app.buttons["computer.help"].waitForExistence(timeout: 3))
    }

    func testNewMissionChoosesLengthAndSkill() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetSave", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["length.long"].waitForExistence(timeout: 3))
        app.buttons["length.long"].tap()
        app.buttons["skill.expert"].tap()
        app.buttons["newgame.begin"].tap()
        XCTAssertTrue(logContains(app, "THIS IS A LONG GAME AT EXPERT SKILL."))
    }

    func testCancelReturnsToCommands() {
        let app = launch()
        app.buttons["command.TOR"].tap()
        XCTAssertTrue(app.buttons["panel.cancel"].waitForExistence(timeout: 3))
        app.buttons["panel.cancel"].tap()
        XCTAssertTrue(app.buttons["command.TOR"].waitForExistence(timeout: 3))
    }
}
