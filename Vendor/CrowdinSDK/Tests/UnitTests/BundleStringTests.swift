//
//  BundleStringTests.swift
//  TestsTests
//
//  Created by Serhii Londar on 13.10.2019.
//  Copyright © 2019 Serhii Londar. All rights reserved.
//

import XCTest
@testable import CrowdinSDK

class BundleStringTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() { }
    
    func testBundleStringLocalizationForDefaultLanguage() {
        XCTAssert("test_key".cw_localized == "test_value [B]")
        XCTAssert("test_key_with_string_parameter".cw_localized(with: ["value"]) == "test value with parameter - value [B]")
        XCTAssert("test_key_with_int_parameter".cw_localized(with: [1]) == "test value with parameter - 1 [B]")
    }
}

