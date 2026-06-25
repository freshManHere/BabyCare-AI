import XCTest

final class BabyCareUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testTabBarExists() {
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    func testAllTabsAccessible() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.buttons["首页"].exists)
        XCTAssertTrue(tabBar.buttons["记录"].exists)
        XCTAssertTrue(tabBar.buttons["助手"].exists)
        XCTAssertTrue(tabBar.buttons["我的"].exists)
    }
}
