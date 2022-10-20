//
//  StringParamTests.swift
//  CrowdinSDK-Unit-CrowdinSDK_Tests
//
//  Created by Serhii Londar on 10/4/19.
//

import XCTest
@testable import CrowdinSDK

class StringsTests: XCTestCase {
    func testIsFormatedWithFormatedString() {
        let string = "test string with parameter - %@"
        XCTAssert(string.isFormated == true, "String has format parameter - %@")
	}
    
    func testIsFormatedWithNonFormatedString() {
        let string = "test string without parameters"
        XCTAssert(string.isFormated == false, "String has no any parameters")
    }
    
    func testFindMatchWithFormatedString() {
        let formatedString = "test string with parameter - %@"
        let string = "test string with parameter - value"
        
        let result = String.findMatch(for: formatedString, with: string)
        
        XCTAssert(result == true, "Expected because value is parameter for formattedString")
    }
    
    func testFindMatchWithNonFormatedString() {
        let formatedString = "test string"
        let string = "test string with parameter - value"
        
        let result = String.findMatch(for: formatedString, with: string)
        
        XCTAssert(result == false, "Expected because formattedString is not formatted")
    }
    
    func testNSStringSplitByRanges() {
        let string: NSString = "Test string"
        let result = string.splitBy(ranges: [NSRange(location: 4, length: 1)])
        
        XCTAssert(result.count == 2, "Expect 2 strings")
        XCTAssert(result[0] == "Test", "First string is \"Test\"")
        XCTAssert(result[1] == "string", "First string is \"string\"")
    }
    
    func testNSStringSplitByRanges2() {
        let string: NSString = "test string with parameter - value"
        let result = string.splitBy(ranges: [NSRange(location: 0, length: 29)])
        
        XCTAssert(result.count == 1, "Expect 1 string")
        XCTAssert(result[0] == "value", "Expect value string")
    }
    
    func testFindValuesForString() {
        let formatedString = "test string with parameter - %@"
        let string = "test string with parameter - value"
        
        let result = String.findValues(for: string, with: formatedString)
        
        XCTAssertNotNil(result, "Expect non nil result")
        if let result = result {
            XCTAssert(result.count == 1, "Expect 1 string")
            // swiftlint:disable force_cast
            XCTAssert(result[0] as! String == "value", "Expect 1 string")
        }
    }
    
    func testFindValuesForUInt() {
        let formatedString = "Int value = %llu"
        let string = "Int value = 23"
        
        let result = String.findValues(for: string, with: formatedString)
        
        XCTAssertNotNil(result, "Expect non nil result")
        if let result = result {
            XCTAssert(result.count == 1, "Expect 1 result")
            XCTAssertNotNil(result[0] as? UInt, "Expect 1 UInt")
            // swiftlint:disable force_cast
            XCTAssert(result[0] as! UInt == 23, "Expect 23")
        }
    }
}
