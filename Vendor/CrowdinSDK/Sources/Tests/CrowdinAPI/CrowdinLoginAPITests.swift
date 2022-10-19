//
//  CrowdinLoginAPITests.swift
//  CrowdinSDK-Unit-CrowdinAPI_Tests
//
//  Created by Serhii Londar on 29.10.2019.
//

import XCTest
@testable import CrowdinSDK

class CrowdinLoginAPITests: XCTestCase {
    // swiftlint:disable implicitly_unwrapped_optional
    var loginAPI: LoginAPI!

    let session = URLSessionMock()
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        loginAPI = nil
    }
    
    func testLoginAPIInitialization() {
        loginAPI = LoginAPI(clientId: "clientId", clientSecret: "clientSecret", scope: "scope", redirectURI: "redirectURI")
        XCTAssertNotNil(loginAPI)
        
        XCTAssert(loginAPI.clientId == "clientId")
        XCTAssert(loginAPI.clientSecret == "clientSecret")
        XCTAssert(loginAPI.scope == "scope")
        XCTAssert(loginAPI.redirectURI == "redirectURI")
        
        XCTAssertNil(loginAPI.organizationName)
    }
    
    func testLoginAPIInitializationWithOrganization() {
        loginAPI = LoginAPI(clientId: "clientId", clientSecret: "clientSecret", scope: "scope", redirectURI: "redirectURI", organizationName: "organizationName")
        XCTAssertNotNil(loginAPI)
        
        XCTAssert(loginAPI.clientId == "clientId")
        XCTAssert(loginAPI.clientSecret == "clientSecret")
        XCTAssert(loginAPI.scope == "scope")
        XCTAssert(loginAPI.redirectURI == "redirectURI")
        
        XCTAssertNotNil(loginAPI.organizationName)
        XCTAssert(loginAPI.organizationName == "organizationName")
    }

    func testGetAutorizationToken() {
        let session = URLSessionMock()
        
        session.data = try? JSONEncoder().encode(TokenResponse(tokenType: "tokenType", expiresIn: 111111, accessToken: "accessToken", refreshToken: "refreshToken"))
        
        loginAPI = LoginAPI(clientId: "clientId", clientSecret: "clientSecret", scope: "scope", redirectURI: "redirectURI", organizationName: "organizationName", session: session)
        
        var tokenResponse: TokenResponse? = nil
        
        loginAPI.getAutorizationToken(with: "code", success: { (response) in
            tokenResponse = response
        }) { _ in
            
        }
        
        XCTAssertNotNil(tokenResponse)
        XCTAssert(tokenResponse?.tokenType == "tokenType")
        XCTAssert(tokenResponse?.expiresIn == 111111)
        XCTAssert(tokenResponse?.accessToken == "accessToken")
        XCTAssert(tokenResponse?.refreshToken == "refreshToken")
    }
    
    func testRefreshToken() {
        let session = URLSessionMock()
        
        session.data = try? JSONEncoder().encode(TokenResponse(tokenType: "tokenType", expiresIn: 111111, accessToken: "accessToken", refreshToken: "refreshToken"))
        
        loginAPI = LoginAPI(clientId: "clientId", clientSecret: "clientSecret", scope: "scope", redirectURI: "redirectURI", organizationName: "organizationName", session: session)
        
        var tokenResponse: TokenResponse? = nil
        
        loginAPI.refreshToken(refreshToken: "refreshToken", success: { (response) in
            tokenResponse = response
        }) { _ in
            
        }
        
        XCTAssertNotNil(tokenResponse)
        XCTAssert(tokenResponse?.tokenType == "tokenType")
        XCTAssert(tokenResponse?.expiresIn == 111111)
        XCTAssert(tokenResponse?.accessToken == "accessToken")
        XCTAssert(tokenResponse?.refreshToken == "refreshToken")
    }
    
    func testRefreshTokenSync() {
        let session = URLSessionMock()
        
        session.data = try? JSONEncoder().encode(TokenResponse(tokenType: "tokenType", expiresIn: 111111, accessToken: "accessToken", refreshToken: "refreshToken"))
        
        loginAPI = LoginAPI(clientId: "clientId", clientSecret: "clientSecret", scope: "scope", redirectURI: "redirectURI", organizationName: "organizationName", session: session)
        
        let tokenResponse = loginAPI.refreshTokenSync(refreshToken: "refreshToken")
        
        XCTAssertNotNil(tokenResponse)
        XCTAssert(tokenResponse?.tokenType == "tokenType")
        XCTAssert(tokenResponse?.expiresIn == 111111)
        XCTAssert(tokenResponse?.accessToken == "accessToken")
        XCTAssert(tokenResponse?.refreshToken == "refreshToken")
    }
}
