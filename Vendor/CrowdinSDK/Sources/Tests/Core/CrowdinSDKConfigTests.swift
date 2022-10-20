import XCTest
@testable import CrowdinSDK

class CrowdinSDKConfigTests: XCTestCase {
    func testConfigInitialization() {
        let config = CrowdinSDKConfig.config()
        XCTAssertNil(config.crowdinProviderConfig)
    }
    
    func testConfigNotConfiguredEnterprise() {
        let config = CrowdinSDKConfig.config()
        XCTAssert(config.enterprise == false, "Showuldn't be true as default value is false")
    }
    
    func testConfigFalseEnterprise() {
        let config = CrowdinSDKConfig.config().with(enterprise: false)
        XCTAssert(config.enterprise == false, "Showuldn't be true as default value is false")
    }
    
    func testConfigTrueEnterprise() {
        let config = CrowdinSDKConfig.config().with(enterprise: true)
        XCTAssert(config.enterprise, "Showuld be true as per set-up")
    }
}
