//
//  HandlersTests.swift
//  Tests
//
//  Created by Serhii Londar on 12.10.2019.
//  Copyright © 2019 Serhii Londar. All rights reserved.
//

import XCTest
@testable import CrowdinSDK

class AddErrorHandlersTests: XCTestCase {
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        CrowdinSDK.removeAllErrorHandlers()
        CrowdinSDK.deintegrate()
        CrowdinSDK.stop()
    }
    
    func testAddErrorHandler() {
        let crowdinProviderConfig = CrowdinProviderConfig(hashString: "wrong_hash",
                                                          sourceLanguage: "en")
        let crowdinSDKConfig = CrowdinSDKConfig.config().with(crowdinProviderConfig: crowdinProviderConfig)
                                                        .with(enterprise: true)
        CrowdinSDK.currentLocalization = nil
        
        let expectation = XCTestExpectation(description: "Error handler is called")
        let hendlerId = CrowdinSDK.addErrorUpdateHandler {_ in
            XCTAssert(true, "Error handler called")
            expectation.fulfill()
        }
        
        CrowdinSDK.startWithConfig(crowdinSDKConfig, completion: { })
        
        wait(for: [expectation], timeout: 60.0)
        
        CrowdinSDK.removeErrorHandler(hendlerId)
    }

}
