//
//  StringParamTests.swift
//  CrowdinSDK-Unit-CrowdinSDK_Tests
//
//  Created by Serhii Londar on 10/4/19.
//

import XCTest
@testable import CrowdinSDK

class LocaleExtensionTests: XCTestCase {
	override func setUp() {
		super.setUp()
	}
	
	func testPreferredLocalizations() {
		XCTAssert(Locale.preferredLocalizations.contains("en"), "Should containg en localization")
	}
}
