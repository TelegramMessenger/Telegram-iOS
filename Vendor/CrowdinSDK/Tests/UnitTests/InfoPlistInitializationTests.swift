//
//  BundleStringTests.swift
//  TestsTests
//
//  Created by Serhii Londar on 13.10.2019.
//  Copyright © 2019 Serhii Londar. All rights reserved.
//

import XCTest
@testable import CrowdinSDK

class InfoPlistInitializationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let crowdinProviderConfig = CrowdinProviderConfig()
        let crowdinSDKConfig = CrowdinSDKConfig.config().with(crowdinProviderConfig: crowdinProviderConfig)
        
        CrowdinSDK.startWithConfig(crowdinSDKConfig, completion: { })
        CrowdinSDK.deintegrate()
    }
    
    override func tearDown() {
        super.tearDown()
        CrowdinSDK.removeAllDownloadHandlers()
        CrowdinSDK.deintegrate()
        CrowdinSDK.stop()
    }
    
    func testInfoPlistInitializationTests() {
        let expectation = XCTestExpectation(description: "Download handler is called")
        let hendlerId = CrowdinSDK.addDownloadHandler {
            XCTAssert(true, "Download handler called")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
        
        CrowdinSDK.removeErrorHandler(hendlerId)
    }
}

