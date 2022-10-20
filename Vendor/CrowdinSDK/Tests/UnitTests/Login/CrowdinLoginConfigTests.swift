import XCTest
@testable import CrowdinSDK

class CrowdinLoginConfigTests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    var loginConfig: CrowdinLoginConfig!
    
    override func setUp() {
        
    }
    
    func testLoginConfigInit() {
        loginConfig = try? CrowdinLoginConfig(clientId: "clientId", clientSecret: "clientSecret", scope: "scope", redirectURI: "crowdintest://")
        
        XCTAssertNotNil(loginConfig)
        XCTAssert(loginConfig.clientId == "clientId")
        XCTAssert(loginConfig.clientSecret == "clientSecret")
        XCTAssert(loginConfig.scope == "scope")
        XCTAssert(loginConfig.redirectURI == "crowdintest://")
    }
    
    func testLoginConfigInitWithoutRedirectURI() {
        loginConfig = try? CrowdinLoginConfig(clientId: "clientId", clientSecret: "clientSecret", scope: "scope")
        
        XCTAssertNotNil(loginConfig)
        XCTAssert(loginConfig.clientId == "clientId")
        XCTAssert(loginConfig.clientSecret == "clientSecret")
        XCTAssert(loginConfig.scope == "scope")
        XCTAssert(loginConfig.redirectURI == "crowdintest://")
    }
    
    func testLoginConfigOrganization() {
        loginConfig = try? CrowdinLoginConfig(clientId: "clientId", clientSecret: "clientSecret", scope: "scope", redirectURI: "crowdintest://", organizationName: "organizationName")
        
        XCTAssertNotNil(loginConfig)
        XCTAssert(loginConfig.clientId == "clientId")
        XCTAssert(loginConfig.clientSecret == "clientSecret")
        XCTAssert(loginConfig.scope == "scope")
        XCTAssert(loginConfig.redirectURI == "crowdintest://")
        XCTAssert(loginConfig.organizationName == "organizationName")
    }
    
    func testLoginConfigOrganizationInitWithoutRedirectURI() {
        loginConfig = try? CrowdinLoginConfig(clientId: "clientId", clientSecret: "clientSecret", scope: "scope", organizationName: "organizationName")
        
        XCTAssertNotNil(loginConfig)
        XCTAssert(loginConfig.clientId == "clientId")
        XCTAssert(loginConfig.clientSecret == "clientSecret")
        XCTAssert(loginConfig.scope == "scope")
        XCTAssert(loginConfig.redirectURI == "crowdintest://")
        XCTAssert(loginConfig.organizationName == "organizationName")
    }
    
    func testLoginConfigInitWithEmptyClientId() {
        do {
            loginConfig = try CrowdinLoginConfig(clientId: "", clientSecret: "clientSecret", scope: "scope", redirectURI: "crowdintest://", organizationName: "organizationName")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    func testLoginConfigInitWithEmptyClientSecret() {
        do {
            loginConfig = try CrowdinLoginConfig(clientId: "clientId", clientSecret: "", scope: "scope", redirectURI: "crowdintest://", organizationName: "organizationName")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    func testLoginConfigInitWithEmptyScope() {
        do {
            loginConfig = try CrowdinLoginConfig(clientId: "clientId", clientSecret: "clientSecret", scope: "", redirectURI: "crowdintest://", organizationName: "organizationName")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    func testLoginConfigInitWithEmptyRedirectURI() {
        do {
            loginConfig = try CrowdinLoginConfig(clientId: "clientId", clientSecret: "clientSecret", scope: "scope", redirectURI: "", organizationName: "organizationName")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    func testLoginConfigInitWithIcorrectRedirectURI() {
        do {
            loginConfig = try CrowdinLoginConfig(clientId: "clientId", clientSecret: "clientSecret", scope: "scope", redirectURI: "crowdintest", organizationName: "organizationName")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
