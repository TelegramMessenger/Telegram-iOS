//
//  HandlersTests.swift
//  Tests
//
//  Created by Serhii Londar on 12.10.2019.
//  Copyright © 2019 Serhii Londar. All rights reserved.
//

import XCTest
@testable import CrowdinSDK

class AddDownloadHandlersTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let crowdinProviderConfig = CrowdinProviderConfig(hashString: "5290b1cfa1eb44bf2581e78106i",
                                                          sourceLanguage: "en")
        let crowdinSDKConfig = CrowdinSDKConfig.config().with(crowdinProviderConfig: crowdinProviderConfig)
        CrowdinSDK.startWithConfig(crowdinSDKConfig, completion: {})
    }
    
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        CrowdinSDK.removeAllDownloadHandlers()
        CrowdinSDK.deintegrate()
        CrowdinSDK.stop()
    }
    
    func testAddDownloadHandler() {
        let expectation = XCTestExpectation(description: "Download handler is called")
        let hendlerId = CrowdinSDK.addDownloadHandler {
            XCTAssert(true, "Download handler called")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
        
        CrowdinSDK.removeDownloadHandler(hendlerId)
    }

}
