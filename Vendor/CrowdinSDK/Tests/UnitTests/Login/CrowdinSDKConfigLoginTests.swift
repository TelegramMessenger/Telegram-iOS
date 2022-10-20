//
//  CrowdinSDKConfigLoginTests.swift
//  CrowdinSDK-Unit-Login_Tests
//
//  Created by Serhii Londar on 28.10.2019.
//

import XCTest
@testable import CrowdinSDK

class CrowdinSDKConfigLoginTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    var config: CrowdinSDKConfig!

    override func setUp() {
        super.setUp()
        guard let loginConfig = try? CrowdinLoginConfig(clientId: "clientId", clientSecret: "clientSecret", scope: "scope", redirectURI: "crowdintest://", organizationName: "organizationName") else { return }
        config = CrowdinSDKConfig.config().with(loginConfig: loginConfig)
    }
    
    func testNonNilConfigAfterSetup() {
        XCTAssertNotNil(config.loginConfig)
    }
    
    func testCorrectConfigAfterSetup() {
        XCTAssertNotNil(config.loginConfig?.clientId)
        XCTAssert(config.loginConfig?.clientId == "clientId")
        XCTAssertNotNil(config.loginConfig?.clientSecret)
        XCTAssert(config.loginConfig?.clientSecret == "clientSecret")
        XCTAssertNotNil(config.loginConfig?.scope)
        XCTAssert(config.loginConfig?.scope == "scope")
        XCTAssertNotNil(config.loginConfig?.redirectURI)
        XCTAssert(config.loginConfig?.redirectURI == "crowdintest://")
    }
    
    func testChangeConfigAfterSetup() {
        guard let loginConfig = try? CrowdinLoginConfig(clientId: "clientId1", clientSecret: "clientSecret1", scope: "scope1", redirectURI: "crowdintest://", organizationName: "organizationName1") else { return }
        config.loginConfig = loginConfig
        
        XCTAssertNotNil(config.loginConfig)
        
        XCTAssertNotNil(config.loginConfig?.clientId)
        XCTAssert(config.loginConfig?.clientId == "clientId1")
        XCTAssertNotNil(config.loginConfig?.clientSecret)
        XCTAssert(config.loginConfig?.clientSecret == "clientSecret1")
        XCTAssertNotNil(config.loginConfig?.scope)
        XCTAssert(config.loginConfig?.scope == "scope1")
        XCTAssertNotNil(config.loginConfig?.redirectURI)
        XCTAssert(config.loginConfig?.redirectURI == "crowdintest://")
        XCTAssertNotNil(config.loginConfig?.organizationName)
        XCTAssert(config.loginConfig?.organizationName == "organizationName1")
    }
}
