//
//  StringParamTests.swift
//  CrowdinSDK-Unit-CrowdinSDK_Tests
//
//  Created by Serhii Londar on 10/4/19.
//

import XCTest
@testable import CrowdinSDK

class ConstantsTests: XCTestCase {
    func testDefaultLocalizationValue() {
        XCTAssert(defaultLocalization == "en")
    }
    
    func testBaseLocalizationValue() {
        XCTAssert(baseLocalization == "Base")
    }
    
    func testDefaultCrowdinErrorCodeValue() {
        XCTAssert(defaultCrowdinErrorCode == 99999)
    }
}
