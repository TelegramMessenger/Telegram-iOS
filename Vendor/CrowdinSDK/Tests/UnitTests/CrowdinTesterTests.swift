//
//  CrowdinTesterTests.swift
//  TestsTests
//
//  Created by Serhii Londar on 13.10.2019.
//  Copyright © 2019 Serhii Londar. All rights reserved.
//

import XCTest
@testable import CrowdinSDK

class CrowdinTesterTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let crowdinProviderConfig = CrowdinProviderConfig(hashString: "5290b1cfa1eb44bf2581e78106i",
                                                          sourceLanguage: "en")
        let crowdinSDKConfig = CrowdinSDKConfig.config().with(crowdinProviderConfig: crowdinProviderConfig)
        
        CrowdinSDK.startWithConfig(crowdinSDKConfig, completion: { })
    }
    
    
    override func tearDown() {
        CrowdinSDK.removeAllDownloadHandlers()
        CrowdinSDK.deintegrate()
        CrowdinSDK.stop()
    }
    
    func testDownloadedLocalizations() {
        CrowdinSDK.currentLocalization = "en"
        let expectation = XCTestExpectation(description: "Download handler is called")
        _ = CrowdinSDK.addDownloadHandler {
            let tester = CrowdinTester(localization: "en")
            XCTAssert(tester.inSDKPluralsKeys.count == 2, "Downloaded localization contains 2 plural keys")
            XCTAssert(tester.inSDKStringsKeys.count == 5, "Downloaded localization contains 5 string keys")
            
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 60.0)
    }
    
    
    func testChangeAndDownloadLocalizations() {
        CrowdinSDK.currentLocalization = "de"
        
        let expectation = XCTestExpectation(description: "Download handler is called")
        _ = CrowdinSDK.addDownloadHandler {
            let tester = CrowdinTester(localization: "de")
            XCTAssert(tester.inSDKPluralsKeys.count == 2, "Downloaded localization contains 2 plural keys")
            XCTAssert(tester.inSDKStringsKeys.count == 5, "Downloaded localization contains 5 string keys")
            
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 60.0)
    }
	
    func testNotExistingLocalizations() {
		let tester = CrowdinTester(localization: "zh")
		XCTAssert(tester.inSDKPluralsKeys.count == 0, "Localization contains 0 plural keys as it is not exist")
		XCTAssert(tester.inSDKStringsKeys.count == 0, "Localization contains 0 string keys as it is not exist")
    }
}
