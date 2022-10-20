import XCTest
@testable import CrowdinSDK

class CrowdinSDKConfigTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    var providerConfig: CrowdinProviderConfig!
    
    override func setUp() {
        self.providerConfig = CrowdinProviderConfig(hashString: "test_hash", sourceLanguage: "en")
    }
    
    func testProviderConfigInitialization() {
        XCTAssert(providerConfig.hashString == "test_hash")
        
        XCTAssert(providerConfig.sourceLanguage == "en")
    }
    
    func testConfigInitialization() {
        let config = CrowdinSDKConfig.config().with(crowdinProviderConfig: providerConfig)
        XCTAssertNotNil(config.crowdinProviderConfig)
    }
}
