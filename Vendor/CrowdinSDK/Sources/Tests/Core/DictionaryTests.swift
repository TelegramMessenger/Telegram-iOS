//
//  StringParamTests.swift
//  CrowdinSDK-Unit-CrowdinSDK_Tests
//
//  Created by Serhii Londar on 10/4/19.
//

import XCTest
@testable import CrowdinSDK

class DictionaryTests: XCTestCase {
    func testSimpleMerge() {
		var dict1 = ["key1": "value1"]
		let dict2 = ["key2": "value2"]
		dict1.merge(with: dict2)
		XCTAssert(dict1.keys.count == 2, "Merged successfully")
		XCTAssert(dict1.keys.contains("key1"), "Contains key1 key")
		XCTAssert(dict1.keys.contains("key2"), "Contains key2 key")
		
		XCTAssert(dict1.values.contains("value1"), "Contains value1 value")
		XCTAssert(dict1.values.contains("value1"), "Contains value2 value")
    }
	
	func testComplexMerge() {
		var dict1 = ["key1": "value1"]
		let dict2 = ["key1": "value2"]
		dict1.merge(with: dict2)
		XCTAssert(dict1.keys.count == 1, "Merged successfully, contains one key because booth dictionaries have same key")
		XCTAssert(dict1.keys.contains("key1"), "Contains key1 key")
		
		XCTAssert(dict1.values.contains("value2"), "Contains value2 value, value from second dictionary has bigger priority")
    }
    
    func testPlusSimpleMerge() {
		var dict1 = ["key1": "value1"]
		let dict2 = ["key2": "value2"]
		
		let result = dict1 + dict2
		
		XCTAssert(result.keys.count == 2, "Merged successfully")
		XCTAssert(result.keys.contains("key1"), "Contains key1 key")
		XCTAssert(result.keys.contains("key2"), "Contains key2 key")
		
		XCTAssert(result.values.contains("value1"), "Contains value1 value")
		XCTAssert(result.values.contains("value1"), "Contains value2 value")
    }
	
    func testPlusComplexMerge() {
		var dict1 = ["key1": "value1"]
		let dict2 = ["key1": "value2"]
		
		let result = dict1 + dict2
		
		XCTAssert(result.keys.count == 1, "Merged successfully, contains one key because booth dictionaries have same key")
		XCTAssert(result.keys.contains("key1"), "Contains key1 key")
		
		XCTAssert(result.values.contains("value1"), "Contains value1 value, value from first dictionary has bigger priority")
    }
	
    func testPlusEqualSimpleMerge() {
		var dict1 = ["key1": "value1"]
		let dict2 = ["key2": "value2"]
		dict1 += dict2
		XCTAssert(dict1.keys.count == 2, "Merged successfully")
		XCTAssert(dict1.keys.contains("key1"), "Contains key1 key")
		XCTAssert(dict1.keys.contains("key2"), "Contains key2 key")
		
		XCTAssert(dict1.values.contains("value1"), "Contains value1 value")
		XCTAssert(dict1.values.contains("value1"), "Contains value2 value")
    }
	
    func testPlusEqualComplexMerge() {
		var dict1 = ["key1": "value1"]
		let dict2 = ["key1": "value2"]
		
		dict1 += dict2
		
		XCTAssert(dict1.keys.count == 1, "Merged successfully, contains one key because booth dictionaries have same key")
		XCTAssert(dict1.keys.contains("key1"), "Contains key1 key")
		
		XCTAssert(dict1.values.contains("value2"), "Contains value2 value, value from second dictionary has bigger priority")
    }
}
