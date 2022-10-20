//
//  EnableSDKLocalizationTests.swift
//  TestsTests
//
//  Created by Serhii Londar on 13.10.2019.
//  Copyright © 2019 Serhii Londar. All rights reserved.
//

import XCTest
@testable import CrowdinSDK

class EnableSDKLocalizationTests: XCTestCase {
    
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
    
    func testAutoSDKModeEnabled() {
        CrowdinSDK.currentLocalization = nil
        
        let expectation = XCTestExpectation(description: "Download handler is called")
        
        _ = CrowdinSDK.addDownloadHandler {
            XCTAssert(CrowdinSDK.currentLocalization == "en", "Shouuld auto detect current localization as en")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 60.0)
    }
    
    func testManualSDKModeEnabled() {
        CrowdinSDK.currentLocalization = "de"
        
        let expectation = XCTestExpectation(description: "Download handler is called")
        
        _ = CrowdinSDK.addDownloadHandler {
            XCTAssert(CrowdinSDK.currentLocalization == "de", "Shouuld set current localization to de")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 60.0)
    }
    
    
    func testAutoBundleModeEnabled() {
        CrowdinSDK.currentLocalization = nil
        
        let expectation = XCTestExpectation(description: "Download handler is called")
        
        _ = CrowdinSDK.addDownloadHandler {
            XCTAssert(CrowdinSDK.currentLocalization == "en", "Shouuld auto detect current localization as en")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 60.0)
    }
    
    func testManualBundleModeEnabled() {
        CrowdinSDK.currentLocalization = "de"
        
        let expectation = XCTestExpectation(description: "Download handler is called")
        
        _ = CrowdinSDK.addDownloadHandler {
            XCTAssert(CrowdinSDK.currentLocalization == "de", "Shouuld set current localization to de")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 60.0)
    }
}

