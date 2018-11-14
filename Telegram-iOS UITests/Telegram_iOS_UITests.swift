import XCTest

class Telegram_iOS_UITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        
        self.continueAfterFailure = false
        
        self.app = XCUIApplication()
        let path = Bundle(for: type(of: self)).bundlePath
        
        self.app.launchEnvironment["snapshot-data-path"] = path
        setupSnapshot(app)
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testChatList() {
        self.app.launchArguments = ["snapshot:chat-list"]
        self.app.launch()
        XCTAssert(self.app.wait(for: .runningForeground, timeout: 10.0))
        snapshot("01ChatList")
        sleep(1)
    }
    
    func testSecretChat() {
        self.app.launchArguments = ["snapshot:secret-chat"]
        self.app.launch()
        XCTAssert(self.app.wait(for: .runningForeground, timeout: 10.0))
        snapshot("02SecretChat")
        sleep(1)
    }
    
    func testSettings() {
        self.app.launchArguments = ["snapshot:settings"]
        self.app.launch()
        XCTAssert(self.app.wait(for: .runningForeground, timeout: 10.0))
        snapshot("04Settings")
        sleep(1)
    }
    
    func testAppearanceSettings() {
        self.app.launchArguments = ["snapshot:appearance-settings"]
        self.app.launch()
        XCTAssert(self.app.wait(for: .runningForeground, timeout: 10.0))
        snapshot("05AppearanceSettings")
        sleep(1)
    }
}
