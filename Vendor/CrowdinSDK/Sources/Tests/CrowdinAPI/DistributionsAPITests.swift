//
//  File.swift
//  CrowdinSDK-Unit-CrowdinAPI_Tests
//
//  Created by Serhii Londar on 11.02.2020.
//

import XCTest
@testable import CrowdinSDK

class DistributionsAPITests: XCTestCase {
    var session = URLSessionMock()
    // swiftlint:disable implicitly_unwrapped_optional
    var api: DistributionsAPI!
    var testHashString = "dssdasd7as8dasd9asd9ds9ad9sa"
    var testOrganization = "test_organization"
    let defaultTimeoutForExpectation = 2.0
    
    func testAPIInitialization() {
        api = DistributionsAPI(hashString: testHashString)
        
        XCTAssert(api.baseURL == "https://crowdin.com/api/v2/")
        XCTAssert(api.apiPath == "distributions/metadata?hash=\(testHashString)")
        XCTAssertNil(api.organizationName)
        XCTAssert(api.fullPath == "https://crowdin.com/api/v2/distributions/metadata?hash=\(testHashString)")
    }
    
    func testAPIInitializationWithOrganization() {
        api = DistributionsAPI(hashString: testHashString, organizationName: testOrganization)
        
        XCTAssert(api.baseURL == "https://\(testOrganization).crowdin.com/api/v2/")
        XCTAssert(api.apiPath == "distributions/metadata?hash=\(testHashString)")
        XCTAssert(api.organizationName == testOrganization)
        XCTAssert(api.fullPath == "https://\(testOrganization).crowdin.com/api/v2/distributions/metadata?hash=\(testHashString)")
    }
    
    func testGetDistribution() {
        let expectation = XCTestExpectation(description: "Wait for callback")
        
        session.data = """
        {
            "data": {
                "project": {
                    "id": "202187",
                    "wsHash": "df2142d1"
                },
                "user": {
                    "id": "1383818"
                },
                "wsUrl": "wss://ws-lb.crowdin.com"
            }
        }
        """.data(using: .utf8)
        api = DistributionsAPI(hashString: testHashString, organizationName: testOrganization, session: session)
        
        var result: DistributionsResponse? = nil
        api.getDistribution { (response, _) in
            result = response
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: defaultTimeoutForExpectation)
        
        XCTAssertNotNil(result)
        if let result = result {
            XCTAssert(result.data.wsUrl == "wss://ws-lb.crowdin.com")
            
            XCTAssert(result.data.project.id == "202187")
            XCTAssert(result.data.project.wsHash == "df2142d1")
            
            XCTAssert(result.data.user.id == "1383818")
        }
    }
}
