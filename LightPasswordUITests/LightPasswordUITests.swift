import XCTest

@MainActor
final class LightPasswordUITests: XCTestCase {
    private let masterPassword = "UI-Test-Master-Password-2026"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFirstRunCreateCopyRevealTrashAndRestore() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing-reset")
        app.launch()

        XCTAssertTrue(app.staticTexts["欢迎使用轻密码"].waitForExistence(timeout: 8))
        let master = app.secureTextFields["onboarding.masterPassword"]
        let confirmation = app.secureTextFields["onboarding.confirmation"]
        XCTAssertTrue(master.exists)
        master.tap()
        master.typeText(masterPassword)
        confirmation.tap()
        confirmation.typeText(masterPassword)
        app.buttons["onboarding.createVault"].tap()

        XCTAssertTrue(app.navigationBars["轻密码"].waitForExistence(timeout: 15))
        app.buttons["添加密码"].tap()

        let title = app.textFields["entryEditor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("测试邮箱")
        app.textFields["entryEditor.username"].tap()
        app.textFields["entryEditor.username"].typeText("alice@example.com")
        app.secureTextFields["entryEditor.password"].tap()
        app.secureTextFields["entryEditor.password"].typeText("Secret-For-UI-Test-42!")
        app.buttons["entryEditor.save"].tap()

        XCTAssertTrue(app.staticTexts["测试邮箱"].waitForExistence(timeout: 8))
        app.buttons["复制 测试邮箱 的密码"].tap()
        XCTAssertTrue(app.staticTexts["密码已复制，60 秒后清除"].waitForExistence(timeout: 4))

        app.staticTexts["测试邮箱"].tap()
        XCTAssertTrue(app.navigationBars["密码详情"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Secret-For-UI-Test-42!"].exists)
        app.buttons["passwordDetail.revealPassword"].tap()
        XCTAssertTrue(app.staticTexts["Secret-For-UI-Test-42!"].waitForExistence(timeout: 3))
        app.buttons["passwordDetail.revealPassword"].tap()
        XCTAssertFalse(app.staticTexts["Secret-For-UI-Test-42!"].exists)

        app.buttons["移到回收站"].tap()
        app.sheets.buttons["移到回收站"].tap()
        app.tabBars.buttons["回收站"].tap()
        let deleted = app.staticTexts["测试邮箱"]
        XCTAssertTrue(deleted.waitForExistence(timeout: 5))
        deleted.swipeRight()
        app.buttons["恢复"].tap()

        app.tabBars.buttons["密码"].tap()
        XCTAssertTrue(app.staticTexts["测试邮箱"].waitForExistence(timeout: 5))
    }
}
